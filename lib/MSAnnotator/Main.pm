package MSAnnotator::Main;

# Load custom modules
use MSAnnotator::Base;
use MSAnnotator::Config;
use MSAnnotator::NCBI qw(get_assemblies download_assemblies);
use MSAnnotator::RAST qw(rast_submit rast_complete);
use MSAnnotator::KnownAssemblies qw(update_known get_tasks);

# Export functions
require Exporter;
our @ISA = 'Exporter';
our @EXPORT_OK = qw(main);

sub main {
  my $config = load_config();
  my $assemblies = get_assemblies($config);
  #download_assemblies($config, $assemblies);

  # Do SEED things...
  # For testing...
  update_known('433392', $assemblies->{'GCA_001266695.1_ASM126669v1'});
  update_known('419360', $assemblies->{'GCA_001266735.1_ASM126673v1'});
  update_known('123444', $assemblies->{'GCA_000337155.1_ASM33715v1'});

  my @asmids = keys %{$assemblies};
  my $tasks = get_tasks(@asmids);
  say Dumper $tasks;

  rast_complete($tasks->{pending_rast});
  
  #submit_rast($tasks->{needs_rast}, $assemblies);

}

1;
