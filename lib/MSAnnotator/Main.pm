package MSAnnotator::Main;

# Load custom modules
use MSAnnotator::Base;
use MSAnnotator::Config;
use MSAnnotator::NCBI qw(get_input_asmids get_new_asmids  add_asmids);
use MSAnnotator::KnownAssemblies qw(update_records add_records get_records);
use MSAnnotator::RAST qw(rast_update_status rast_get_results rast_submit);
use MSAnnotator::ModelSEED qw(modelseed_update_status modelseed_submit modelseed_get_results);

# Export functions
require Exporter;
our @ISA = 'Exporter';
our @EXPORT_OK = qw(main);

sub main {
  # Read config, determine assemblies, check against assembly_records, download new
  my $config = load_config();

  # Get lists of input and determine needed asmids
  my $input_asmids = get_input_asmids($config);
  my $new_asmids = get_new_asmids($input_asmids);
  add_asmids($config, $new_asmids) if %$new_asmids;

  # All ids to process
  my @asmids = keys %$input_asmids;

  # Get current RAST / MS  status and update assembly_records
  rast_update_status(@asmids);
  modelseed_update_status(@asmids);

  # Download complete RAST / MS analyses
  rast_get_results(@asmids);
  modelseed_get_results(@asmids);

  # Make submisions
  rast_submit(@asmids);
  modelseed_submit(@asmids);

  # TODO
  #   Rerun script to see if modelseed_submit works
  #   Fishish modelseed_download
  #   Print some kind of status

  ### Print status
  ##print_status(
  ##  $config,
  ##  $assemblies,
  ##  @rast_running

}

1;
