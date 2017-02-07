package MSAnnotator::Main;

# Load custom modules
use MSAnnotator::Base;
use MSAnnotator::Config;
use MSAnnotator::NCBI qw(get_assemblies download_assemblies);
use MSAnnotator::KnownAssemblies qw(update_known get_known);
use MSAnnotator::RAST 'prepare_genbankfile';

# Export functions
require Exporter;
our @ISA = 'Exporter';
our @EXPORT_OK = qw(main);

sub main {
  my $config = load_config();
  my $assemblies = get_assemblies($config);
  my @asmids = keys %{$assemblies};
  #download_assemblies($config, $assemblies);

  # Do SEED things...
  # Determine tasks
  #   asmids with no keys in known need to be submitted to RAST
  #   asmids with rast_jobid id and no rast_taxid need to check if complete
  #   asmids with rast_taxid and no modelseed_id, need to be run through MS
  #my $known = get_known(@asmids);

}

1;
