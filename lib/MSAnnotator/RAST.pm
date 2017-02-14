package MSAnnotator::RAST;
require Exporter;
use YAML 'LoadFile';
use File::Basename;
use Parallel::ForkManager;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use RASTserver;

# Load custom modules
use MSAnnotator::Base

# Export functions
our @ISA = 'Exporter';
our @EXPORT_OK = qw(rast_submit rast_complete);

# Constants
use constant genbank_suffix => "_genomic.gbff";

# Load credentials
my ($user, $password) = @{LoadFile("credentials.yaml")}{qw(user password)};


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
      gunzip $gzfile => $gbfile or croak "Error: $GunzipError";
      chmod 0440, $gbfile;
      $pm->finish;
    }
  }
}

sub rast_submit {
  # Options from RASTserver:
  #  -file -filetype -taxonomyID -domain -organismName
  #  -keepGeneCalls -geneticCode -geneCaller
  my ($asmids, $assemblies) = @_;
  my %opts = (
    -filetype => 'genbank',
    -domain => 'archaea',
    -geneCaller => 'rast',
    -geneticCode => 11,
    -keepGeneCalls => 1);

  # Ensure genbank files are extracted
  prepare_genbankfile($asmids, $assemblies);

  # Make connection and coak if not OK
  my $rast_client = RASTserver->new($user, $password);

  # Iterate through ids, submit, and add rast_jobid to known
  for my $asmid (@{$asmids}) {
    my $asm = $assemblies->{$asmid};
    my $gbfile = "$asm->{local_path}/$asmid" . genbank_suffix;
    croak "Error: Could not find: $gbfile" if ! -e $gbfile;

    # Need to pass file, taxid, and organism name
    my $params = {
      -file => $gbfile,
      -taxonomyID => $asm->{taxid},
      -organismName => $asm->{organism_name},
      %opts};
    my $ret = $rast_client->submit_RAST_job($params);

    # Catch errors 
    if ($ret->{status} eq 'error') {
      my $err = "Error: Durring RAST submission for $asmid\n";
      if ($ret->{error_message}) {
        $err = $err . "  RAST issued the following message: $ret->{error_message}";
      }
      croak $err;
    } elsif ($ret->{status} eq 'ok') {
      croak "Error: Absent jobid from RAST server for $asmid" unless $ret->{job_id};
      update_known($ret->{job_id}, $asm);
    } else {
      say Dumper $ret;
      croak "Unknown status from RAST: $ret->{status}\n";
    }
  }
}

sub rast_complete {
  # Takes array of jobids and returns jobids that are complete
  my $jobids = shift;
  my @ret;

  # Make connection and coak if not OK
  my $rast_client = RASTserver->new($user, $password);
  my $stat = $rast_client->status_of_RAST_job({-job => $jobids});
  for my $jobid (@{$jobids}) {
    if ($stat->{$jobid}->{status} eq "error") {
      my $err = "Error: RAST error while checking status for job: $jobid\n";
      if ($stat->{$jobid}->{'error_msg'}) {
        $err = $err . "  RAST error message: $stat->{$jobid}->{'error_msg'}\n";
      }
      croak "$err";
    } elsif ($stat->{$jobid}->{status} eq "complete") {
      push @ret, $jobid;
    } else {
      say Dumper $stat->{$jobid};
      croak "Unknown status from RAST: $stat->{$jobid}->{status}\n";
    }
  }
  return \@ret;
}

1;
