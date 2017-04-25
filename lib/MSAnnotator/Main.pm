package MSAnnotator::Main;

# Load custom modules
use MSAnnotator::Base;
use MSAnnotator::Config;
use MSAnnotator::NCBI qw(get_input_asmids get_new_asmids  download_asmids);
use MSAnnotator::KnownAssemblies qw(update_known add_known get_known);
#use MSAnnotator::RAST qw(rast_submit rast_check_jobs rast_get_results);
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
  my $known_asmids = get_known(keys %$input_asmids);
  my $new_asmids = get_new_asmids($input_asmids, $known_asmids);
  download_asmids($config, $new_asmids) if %$new_asmids;
  #$known_asmids = get_known($input_asmids) if @new_asmids;

  ## Get current RAST / MS status
  #my $rast_job_status = rast_check_jobs(...);
  #my $ms_job_status = ms_check_jobs(...);
  #my $ms_rast_status = ms_check_rast(...);

  ## Check complete
  #my %rast_complete = rast_get_complete(...);
  #my %ms_complete = rast_get_complete(...);

  ## Determine number of tasks submitted to rast/modelseed
  #my @rast_running = rast_get_running(...);
  #my @ms_running = ms_get_running(...);

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
