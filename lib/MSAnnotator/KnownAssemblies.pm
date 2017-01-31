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
our @EXPORT_OK = qw(insert_rast_jobid);

use constant COLUMN_HEADER => (
  "assembly",
  "assembly_accession",
  "rast_jobid",
  "rast_taxid",
  "modelseed_id",
  "modelseed_complete",
  "organism_name",
  "taxid",
  "species_taxid",
  "version_status",
  "assembly_level",
  "refseq_category",
  "ftp_path");

# Add array
my @column_header = (COLUMN_HEADER);

# Get global dbh
my $config = load_config();
my $known_filename = $config->{known_assemblies};
my ($known_table, $known_path) = fileparse($known_filename);

# Set dbh options
my $dbh = DBI->connect("dbi:CSV:", undef, undef, {
  f_dir => $known_path,
  csv_sep_char => ',',
  csv_quote_char => undef,
  csv_escape_char => undef});

# Create file if it does not exist
if (! -e $known_filename) {
  my $colstr = join(" CHAR(0), ", @column_header) . " CHAR(0)";
  $dbh->do("CREATE TABLE $known_table ($colstr)");
}

# Ensure known file is write protected
chmod 0440, $known_filename;

# Insert statement
my $insert_sth = $dbh->prepare(
  "INSERT INTO $known_table (" . join(", ", @column_header) . ") " .
  "VALUES (". "?, " x (scalar @column_header - 1) . "?)");

# Check rast_jobid as it serves as a unique key
my $check_rastjob = $dbh->prepare(
  "SELECT * FROM $known_table WHERE rast_jobid = ?");

sub insert_known {
  # Check if rast_jobid exists
  # if not, add given values
  my ($vals) = @_;

  chmod 0660, $known_filename;
  $insert_sth->execute(@{$vals}{@column_header});
  chmod 0440, $known_filename;
}


1;










