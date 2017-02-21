package MSAnnotator::ModelSeed
require Exporter;
use RASTserver;

# Load custom modules
use MSAnnotator::Base;
use MSAnnotator::KnownAssemblies qw(update_known get_known_assemblies);

# Export functions
our @ISA = 'Exporter';
our @EXPORT_OK = qw( );

# Constants
use constant genbank_suffix => "_genomic.gbff";

# Load credentials
my ($user, $password) = @{LoadFile("credentials.yaml")}{qw(user password)};
my $rast_client = RASTserver->new($user, $password);

