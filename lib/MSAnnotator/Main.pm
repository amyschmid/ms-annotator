package MSAnnotator::Main;

# Load custom modules
use MSAnnotator::Base;
use MSAnnotator::Config;
use MSAnnotator::NCBI qw(get_assemblies download_assemblies);
use MSAnnotator::KnownAssemblies 'update_known';

# Export functions
require Exporter;
our @ISA = 'Exporter';
our @EXPORT_OK = qw(main);

sub main {
  my $config = load_config();
  my $assemblies = get_assemblies($config);
  #download_assemblies($config, $assemblies);
  
  # Test insert_rast_jobid
  update_known(1234, $assemblies->{'GCA_000016605.1_ASM1660v1'});
  update_known(1234, {rast_taxid => 9999});
  update_known(1234, $assemblies->{'GCA_000016605.1_ASM1660v1'});

  ## Do SEED things...
  ## Load known_assemblies and check for existing data 
  #my $known = read_knownfile($config->{known_assemblies});

  ## Determine tasks
  ##   asmids with no keys in known need to be submitted to RAST
  ##   asmids with rast_job id and no rast_id need to check complete / wait
  ##   asmids with rast_id and no modelseed_id, need to be run through MS
  #my $tasks = get_tasks($known);
  #

  ## Do tasks...

  #$known = update_knownfile($known);



}

1;
