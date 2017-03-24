package MSAnnotator::Main;

# Load custom modules
use MSAnnotator::Base;
use MSAnnotator::Config;
use MSAnnotator::NCBI qw(get_assemblies download_assemblies);
use MSAnnotator::RAST qw(rast_submit rast_get_results);
use MSAnnotator::ModelSEED qw(ms_checkjobs);
use MSAnnotator::KnownAssemblies qw(update_known get_tasks);

# Export functions
require Exporter;
our @ISA = 'Exporter';
our @EXPORT_OK = qw(main);

sub main {
  my $config = load_config();
  my $assemblies = get_assemblies($config);
  #download_assemblies($config, $assemblies);
  ms_checkjobs();

  # Get current tasks
  my @asmids = keys %{$assemblies};
  my $tasks = get_tasks(@asmids);

  my $x = ms_checkjobs();
  say Dumper $x;

  #say "Tasks:";
  #say Dumper $tasks;

  #if ($tasks->{needs_rast}) {
  #  rast_submit($tasks->{needs_rast}, $assemblies);
  #}

  #if ($tasks->{pending_rast}) {
  #  rast_get_results($tasks->{pending_rast}, $assemblies)
  #}

  #if ($tasks->{needs_modelseed}) {
  #  ms_submit($taskss->{needs_modelseed}, $assemblies)
  #}


}

1;
