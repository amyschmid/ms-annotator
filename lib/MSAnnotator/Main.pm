package MSAnnotator::Main;

# Load custom modules
use MSAnnotator::Base;
use MSAnnotator::Config;
use MSAnnotator::NCBI 'get_assembly_summary';

# Export functions
require Exporter;
our @ISA = 'Exporter';
our @EXPORT_OK = qw(main);

sub main {
  my $config = load_config();

  # Get all associated taxon ids
  get_assembly_summary($config);

  #my $known_assemblies = load_known_assemblies();
  #my $ncbi_assemblies = load_ncbi_assemblies();
  # ...
}

1;
