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
our @EXPORT_OK = qw(update_known);

# Order does not matter
# Any all columns can be added or removed except:
#   rast_jobid, rast_taxid, rast_result, modelseed_id, modelseed_result,
# Note that rast_jobid is used as a primary key
# Valuses for all other keys are added via the assembly hash
use constant COLUMN_HEADER => (
  "assembly",
  "rast_jobid",
  "rast_taxid",
  "rast_result",
  "modelseed_id",
  "modelseed_result",
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
  "VALUES (". "?, " x $#column_header . "?)");

# Update whole row with given rast_jobid
my $update_sth = $dbh->prepare(
  "UPDATE $known_table SET " . join(" = ?, ", @column_header) . " = ? " .
  "WHERE rast_jobid = ?");

# Check rast_jobid as it serves as a unique key
my $check_rastjob = $dbh->prepare(
  "SELECT * FROM $known_table WHERE rast_jobid = ?");

# Check rast_jobid as it serves as a unique key
my $check_msid= $dbh->prepare(
  "SELECT * FROM $known_table WHERE model_seed_id = ?");

sub do_insert_known {
  my ($vals) = @_;
  chmod 0660, $known_filename;
  $insert_sth->execute(@{$vals}{@column_header});
  $insert_sth->finish;
  chmod 0440, $known_filename;
}

sub do_update_known {
  my ($id, $vals) = @_;
  chmod 0660, $known_filename;
  $update_sth->execute(@{$vals}{@column_header}, $id);
  $update_sth->finish;
  chmod 0440, $known_filename;
}

sub update_known {
  # Input known jobid, and hash of values to be added
  my ($id, $vals) = @_;
  $check_rastjob->execute($id);

  # Ensure rast_jobid is unique
  my $nrows = $check_rastjob->rows;
  say "jobid query: $nrows";

  # Add to file no rows are retured otherwise, get current row and update
  if ($nrows == 0) {
    do_insert_known({rast_jobid => $id, %{$vals}});
  } elsif ($nrows == 1) {
    my %res = %{$check_rastjob->fetchrow_hashref};
    for (keys %{$vals}) {
      $res{$_} = $vals->{$_} if $_ ~~ @column_header;
    }
    do_update_known($id, \%res);
  } else {
    carp "Error: Multiple entries for jobid: $id" if $nrows > 1;
  }
}

 1; 
