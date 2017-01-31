package MSAnnotator::KnownAssemblies;
require Exporter;
use Clone 'clone';
use File::Basename;
use DBI;

# Load custom modules
use MSAnnotator::Base;
use MSAnnotator::Config;

# Export functions
our @ISA = 'Exporter';
our @EXPORT_OK = qw(check_known);

use constant COLUMN_HEADER => (
  "assembly",
  "assembly_accession",
  "rast_jobid",
  "rast_taxid",
  "modelseed_id",
  "modelseed_complete",
  "species_name",
  "taxid",
  "species_taxid",
  "version_status",
  "assembly_level",
  "refseq_category",
  "ftp_path");

# Get global dbh
my $config = load_config();
my $known_filename = $config->{known_assemblies};
my $known_basename = basename($known_filename);
my $known_dirname = dirname($known_filename);

# Set dbh options
my $dbh = DBI->connect("dbi:CSV:", undef, undef, {
  f_dir => $known_dirname,
  csv_sep_char => ',',
  csv_quote_char => undef,
  csv_escape_char => undef});

# Create file if it does not exist
if (! -e $known_filename) {
  my $colstr = join(" CHAR(0), ", (COLUMN_HEADER)) . " CHAR(0)";
  $dbh->do("CREATE TABLE $known_basename ($colstr)");
}

# Ensure known file is write protected
chmod 0440, $known_filename;

1;










