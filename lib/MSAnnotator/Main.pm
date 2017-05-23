package MSAnnotator::Main;

# Load custom modules
use MSAnnotator::Base;
use MSAnnotator::Config;
use MSAnnotator::NCBI qw(get_input_asmids get_new_asmids  add_asmids);
use MSAnnotator::KnownAssemblies qw(update_known add_known get_known);
use MSAnnotator::RAST qw(rast_update_status rast_submit);
use MSAnnotator::ModelSEED qw(ms_update_status);

# Export functions
require Exporter;
our @ISA = 'Exporter';
our @EXPORT_OK = qw(main);

sub main {
  # Read config, determine assemblies, check against known, download new
  my $config = load_config();

  # Get lists of input and determine needed asmids
  my $input_asmids = get_input_asmids($config);
  my $new_asmids = get_new_asmids($input_asmids);
  add_asmids($config, $new_asmids) if %$new_asmids;

  # All ids to process
  my @asmids = keys %$input_asmids;

  # Get current RAST / MS  status and update known_assemblies
  rast_update_status(@asmids);
  ms_update_status(@asmids);

  # Download complete RAST / MS analyses
  # rast_download(...)
  # ms_download(...)

  # Make submisions
  rast_submit(@asmids);
  #%ms_submissions = ms_submit(..);

  ### Print status
  ##print_status(
  ##  $config,
  ##  $assemblies,
  ##  @rast_running

}

1;
