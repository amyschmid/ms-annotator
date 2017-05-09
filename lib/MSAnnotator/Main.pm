package MSAnnotator::Main;

# Load custom modules
use MSAnnotator::Base;
use MSAnnotator::Config;
use MSAnnotator::NCBI qw(get_input_asmids get_new_asmids  add_asmids);
use MSAnnotator::KnownAssemblies qw(update_known add_known get_known);
use MSAnnotator::RAST qw(rast_update_status);
#use MSAnnotator::ModelSEED qw(ms_modelrecon ms_check_jobs ms_get_results);

# Export functions
require Exporter;
our @ISA = 'Exporter';
our @EXPORT_OK = qw(main);

sub main {
  # Read config, determine assemblies, check against known, download new
  my $config = load_config();

  # Get lists of input / needed asmids
  my $input_asmids = get_input_asmids($config);
  my $new_asmids = get_new_asmids($input_asmids);
  add_asmids($config, $new_asmids) if %$new_asmids;

  # Get current RAST status and update known_assemblies
  rast_update_status(keys %$input_asmids);

  # Get current MS status  and update known_assemblies
  #my $ms_status = ms_check_status($known_asmids);


  ## Make submisions
  #my %rast_submisions = rast_submit(...);
  #my %ms_submissions = ms_submit(..);

  ### Print status
  ##print_status(
  ##  $config,
  ##  $assemblies,
  ##  @rast_running

}

1;
