package MSAnnotator::RAST;
require Exporter;
use YAML 'LoadFile';
use File::Basename;
use Parallel::ForkManager;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use RASTserver;

# Load custom modules
use MSAnnotator::Base;
use MSAnnotator::KnownAssemblies qw(update_records get_records);

# Export functions
our @ISA = 'Exporter';
our @EXPORT_OK = qw(rast_update_status rast_get_results rast_submit);

# Constants
use constant genbank_suffix => "_genomic.gbff";

# Load credentials
# NOTE RASTserver.pm will die uppon catching an error
my ($user, $password) = @{LoadFile("credentials.yaml")}{qw(user password)};
my $rast_client = RASTserver->new($user, $password);

sub rast_update_status {
  # Takes list of asmids, for each asmid with a rast jobid
  # Checks status with rast / ms servers to ensure the job is usable
  # Returns hash keyed by asmids
  # Updates assembly_records
  # Should be the only funciton setting rast_status aside from initial submit
  my @input_asmids = @_;
  my $records = get_records(@input_asmids);
  my %ret;

  # Get asmids with a valid rast_jobid
  # Ignore 'complete' and 'failed'
  my @checkids;
  for my $asmid (keys %$records) {
    my %asm = %{$records->{$asmid}};
    if ($asm{rast_jobid} && $asm{rast_status} eq 'in-progress') {
      push(@checkids, $asmid);
    }
  }

  # Early return if there is nothing to do
  if (!@checkids) {
    return \%ret;
  }

  # Lookup table
  my %jobids = map { $records->{$_}->{rast_jobid} => $_ } @checkids;

  # Get RAST status from rast
  my $rast_status = $rast_client->status_of_RAST_job({-job => [keys %jobids]});

  # Loop through jobids and assign values to ret
  for my $jobid (keys %jobids) {
    my $asmid = $jobids{$jobid};
    my $status = $rast_status->{$jobid}->{status} || "failed";

    if ($status eq "complete") {
      $ret{$asmid} = {rast_status => "complete"};
    } elsif ($status eq "running" || $status eq "not_started") {
      $ret{$asmid} = {rast_status => "in-progress"};
    } else {
      $ret{$asmid} = {rast_status => "failed"};
    }
  }

  # Update records
  update_records(\%ret);
  return \%ret;
}

sub prepare_genbankfile {
  # Extracts genbank file from gzip archive
  my ($asmids, $ids) = @_;
  my $pm = new Parallel::ForkManager(10);
  for my $id (@$ids) {
    my $gzfile = $asmids->{$id}->{local_path} .
      "/NCBI/$id" . genbank_suffix . ".gz";
    my $gbfile = $asmids->{$id}->{local_path} .
      "/$id" . genbank_suffix;

    # Extract gz file
    if (! -e $gbfile) {
      $pm->start and next;
      gunzip $gzfile => $gbfile or croak "Error - GunzipError: $GunzipError";
      chmod 0440, $gbfile;
      $pm->finish;
    }
  }
  $pm->wait_all_children;
}

sub rast_get_inprogress {
  my $asmids = shift;
  my $records = get_records(@$asmids);
  my $ret;
  for my $asm (values %$records) {
    $ret += 1 if $asm->{rast_status} eq "in-progress";
  }
  return $ret;
}


sub rast_submit {
  # Options from RASTserver:
  # The equivalent of the "Keep Original Genecalls" flag is '--reannotate_only'.
  # The currently-supported arguments are:
  #   --fasta            => filename of FASTA-format file for upload
  #   --genbank          => filename of GenBank-format file for upload
  #   --bioname          => quoted name of genome (i.e., "Genus species strain")
  #   --domain           => Domain of genome (Bacteria|Archaea|Virus)
  #   --taxon_ID         => NCBI Taxonomy-ID (def: 6666666)
  #   --genetic_code     => NCBI genetic-code number (def: 11)
  #   --gene_caller      => rast or glimmer3
  #   --reannotate_only  => Keep uploaded GenBank genecalls; only assign functions, etc.
  #   --determine_family => Use slow BLAST instead of fast Kmers to determine family memberships
  #   --kmerDataset      => Which set of FIGfam Kmers to use (def: 'Release70')
  #   --fix_frameshifts  => Attempt to reconstruct frameshifts errors
  #   --rasttk           => Use RASTtk pipeline instead of "Classic RAST."
  #  NOTE:
  #   This does not check to ensure that genes are present in gbff file
  my ($asmids, $maxjobs) = @_;
  my $records = get_records(@$asmids);

  # Rast options
  my %opts = (
    -filetype => 'genbank',
    -domain => 'archaea',
    -geneCaller => 'rast',
    -keepGeneCalls => 1,
    -geneticCode => 11);

  # Get ids that need a rast submission
  my @submit;
  for my $asmid (keys %$records) {
    push(@submit, $asmid) if !$records->{$asmid}->{rast_jobid};
  }

  # Ensure all genbank files are available
  prepare_genbankfile($records, \@submit);

  # Iterate through ids, submit, and add rast_jobid to records
  for my $asmid (@submit) {
    my $asm = $records->{$asmid};
    my $rast_inprogress = rast_get_inprogress($asmids);
    last if $rast_inprogress >= $maxjobs && $maxjobs != 0;

    my $gbfile = "$asm->{local_path}/$asmid" . genbank_suffix;
    croak "Error - Could not find: $gbfile" if ! -e $gbfile;

    # Need to pass file, taxid, and organism name
    my $params = {
      -file => $gbfile,
      -taxonomyID => $asm->{taxid},
      -organismName => $asm->{organism_name},
      %opts};
    my $res = $rast_client->submit_RAST_job($params);

    # Check status and update records
    if ($res->{status} eq 'ok') {
      my %rast_update = (
        $asmid => {
          rast_jobid => $res->{job_id},
          rast_status => 'in-progress',
          rast_taxid => ''});
      update_records(\%rast_update);
    } else {
      croak "Error - Durring RAST submission for $asmid";
    }
  }
}

sub rast_get_results {
  # Takes array of jobids and returns jobids that are complete
  # Fetches resulting gbff from RAST server and updates records
  my @asmids = @_;
  my $records = get_records(@asmids);
  my (%ret, @error);

  while ( my ($asmid, $asm) = each %$records ) {
    next if $asm->{rast_status} ne 'complete' || $asm->{rast_result};
    my $jobid = $asm->{rast_jobid};
    my $local_path = $asm->{local_path};
    my $rast_taxid = $asm->{rast_taxid};

    # Download resulting genbank files
    my ($buffer, $content, $res);
    open($buffer, '>', \$content);
    $res = $rast_client->retrieve_RAST_job({
        -job => $jobid,
        -filehandle => $buffer,
        -format => "genbank"});

    # Print result to file or croak on error
    if ($res->{status} ne 'ok') {
      push(@error, $jobid);
      next;
    }

    # Write file
    my $outfile= "$local_path/RAST$rast_taxid.gbff";
    open(my $outfh, '>', $outfile) or croak "Error - Writing to $outfile: $!\n";
    print $outfh $content;
    chmod 0440, $outfile;
    close $outfile;
    close $buffer;

    # Update records
    update_records({$asmid => {rast_result => $outfile}})
  }
}

1;
