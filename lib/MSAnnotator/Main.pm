package MSAnnotator::Main;
require Exporter;

# Load custom modules
use MSAnnotator::Base;
use MSAnnotator::Config;

# Export functions
our @ISA = 'Exporter';
our @EXPORT = qw(main);

sub main {
  my $config = load_config();
  say Dumper $config;
  #my $known_assemblies = load_known_assemblies();
  #my $ncbi_assemblies = load_ncbi_assemblies();
  # ...
}

1;
