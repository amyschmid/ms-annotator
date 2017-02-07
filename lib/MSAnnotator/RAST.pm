package MSAnnotator::RAST;
require Exporter;
use File::Basename;
use Parallel::ForkManager;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use RASTserver;

# Load custom modules
use MSAnnotator::Base

# Export functions
our @ISA = 'Exporter';
our @EXPORT_OK = qw(prepare_genbankfile);

# Constants
use constant genbank_suffix => "_genomic.gbff";

sub prepare_genbankfile {
  my ($assemblies, @ids) = @_;
  my $pm = new Parallel::ForkManager(10);
  for my $asmid (@ids) {
    my $gz_file = $assemblies->{$asmid}->{local_path} . 
      "/NCBI/$asmid" . genbank_suffix . ".gz";
    my $gb_file = $assemblies->{$asmid}->{local_path} .
      "/$asmid" . genbank_suffix;

    # Extract gz file
    if (! -e $gb_file) {
      $pm->start and next;
      gunzip $gz_file => $gb_file or croak "Error: $GunzipError";
      chmod 0440, $gb_file;
      $pm->finish;
    }
  }
}

sub submit_rast {
  my ($assemblies, @ids) = @_;
  default_params = {
    user => $user,
    filetype => 'genbank',
    domain => 'archaea',
    geneCaller => 'rast',
    geneticCode => 11,
    keepGeneCalls => 1};

  # Make connection
  my $rast = RASTserver->new($usr, $passwd);
}

1;
