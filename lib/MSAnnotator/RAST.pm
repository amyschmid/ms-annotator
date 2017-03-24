package MSAnnotator::RAST;
require Exporter;
use YAML 'LoadFile';
use File::Basename;
use Parallel::ForkManager;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use RASTserver;

# Load custom modules
use MSAnnotator::Base;
use MSAnnotator::KnownAssemblies qw(update_known get_known_assemblies);

# Export functions
our @ISA = 'Exporter';
our @EXPORT_OK = qw(rast_submit rast_get_results);

# Constants
use constant genbank_suffix => "_genomic.gbff";

# Load credentials
my ($user, $password) = @{LoadFile("credentials.yaml")}{qw(user password)};
my $rast_client = RASTserver->new($user, $password);


sub prepare_genbankfile {
  # Extracts genbank file from gzip archive
  my ($asmids, $assemblies) = @_;
  my $pm = new Parallel::ForkManager(10);
  for my $asmid (@{$asmids}) {
    my $gzfile = $assemblies->{$asmid}->{local_path} .
      "/NCBI/$asmid" . genbank_suffix . ".gz";
    my $gbfile = $assemblies->{$asmid}->{local_path} .
      "/$asmid" . genbank_suffix;

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

sub rast_submit {
  # TODO Fix this
  # Options from RASTserver:
  #
  # The equivalent of the "Keep Original Genecalls" flag is '--reannotate_only'.
  # The currently-supported arguments are:
  #   --help             => {Print 'help' information}
  #   --user             => RAST username,
  #   --passwd           => RAST password,
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

  my ($asmids, $assemblies) = @_;
  my %opts = (
    -filetype => 'genbank',
    -domain => 'archaea',
    -geneCaller => 'rast',
    -reannotate_only => 1,
    -genetic_code => 11,
    -keepGeneCalls => 1);

  # Ensure genbank files are extracted
  prepare_genbankfile($asmids, $assemblies);

  # Iterate through ids, submit, and add rast_jobid to known
  for my $asmid (@{$asmids}) {
    my $asm = $assemblies->{$asmid};
    my $gbfile = "$asm->{local_path}/$asmid" . genbank_suffix;
    croak "Error - Could not find: $gbfile" if ! -e $gbfile;

    # Need to pass file, taxid, and organism name
    my $params = {
      -file => $gbfile,
      -taxonomyID => $asm->{taxid},
      -organismName => $asm->{organism_name},
      %opts};
    my $ret = $rast_client->submit_RAST_job($params);

    # TODO RASTserver.pm will die uppon catching an error
    say $ret->{status};
    if ($ret->{status} eq 'ok') {
      update_known($ret->{job_id}, $asm);
    } else {
      my $msg = $ret->{error_message};
      my $err = "Error - Durring RAST submission for $asmid".
        $msg ? "\n  RAST error message: $msg" : "\n";
      croak $err;
    }
  }
}

sub rast_get_complete {
  # Takes array of jobids and returns jobids that are complete
  my $jobids = shift;
  my @ret;

  # Make connection and coak if not OK
  my $stat = $rast_client->status_of_RAST_job({-job => $jobids});
  for my $jobid (@{$jobids}) {
    if ($stat->{$jobid}->{status} eq "complete") {
      push @ret, $jobid;
    } else {
      my $msg = $stat->{$jobid}->{'error_msg'};
      my $err = "Error - While checking status for job: $jobid".
        $msg ? "\n  RAST error message: $msg\n" : "\n";
      croak $err;
    }
  }
  return \@ret;
}

sub rast_get_rastid {
  # Given a filename of genbank formatted RAST result
  # Returns rast_taxid found in the "/genome_id" field
  my $file = shift;
  open(my $fh, "<", $file) or croak "Error - Cannot read $file: $!\n";
  my $ret;
  while (my $line = <$fh>) {
    next unless $line =~ /\/genome_id="([^"]+)/;
    $ret = $1;
    last;
  }
  croak "Error - Could not determine rast_taxid for: $file" unless $ret;
  return $ret;
}

sub rast_get_results {
  # Takes array of jobids and returns jobids that are complete
  # Fetches resulting gbff from RAST server and updates known
  my ($jobids, $assemblies) = @_;
  my (@ret, $asm_jobids);

  # Get all complete jobs
  my $comp_jobids = rast_get_complete($jobids);

  if ($comp_jobids) {
    $asm_jobids = get_known_assemblies($comp_jobids);
  }

  if ($asm_jobids) {
    # Download resulting genbank files
    while (my ($jobid, $asmid) = each %{$asm_jobids}) {
      my $content = "";
      open(my $buffer, '>', \$content);
      my $res = $rast_client->retrieve_RAST_job({
          -job => $jobid,
          -filehandle => $buffer,
          -format => "genbank"});

      # Print result to file or croak on error
      if ($res->{status} eq 'ok') {
        my $asm = $assemblies->{$asmid};
        my $fn= "$asm->{local_path}/RAST$jobid.gbff";

        # Save results
        open(my $fh, '>', $fn) or croak "Error - Writing to $fn: $!\n";
        print $fh $content;
        chmod 0440, $fn;
        close $fh;

        # Get rast_taxid and update known
        my $rast_taxid = rast_get_rastid($fn);
        update_known($jobid, {rast_result => $fn});
        update_known($jobid, {rast_taxid => $rast_taxid});

      } else {
        my $msg = $res->{error_mesg};
        my $err = "Error - While fetching RAST results for $jobid".
          $msg ? ":\n  RAST error message: $msg\n" : "\n";
        croak $err;
      }
      close $buffer;
    }
  }
}

1;
