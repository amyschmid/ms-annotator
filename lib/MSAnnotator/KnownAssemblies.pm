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
our @EXPORT_OK = qw(update_known add_known get_known);

# Order does not matter
# Any all columns can be added or removed except:
#   asmid, rast_jobid, rast_taxid, rast_result, modelseed_id, modelseed_result
#
# Note that asmid is used as a primary key
# Values for all other keys are added via the assembly hash
use constant COLUMN_HEADER => (
  "asmid",
  "rast_jobid",
  "rast_status",
  "rast_taxid",
  "rast_result",
  "modelseed_id",
  "modelseed_status",
  "modelseed_name",
  "modelseed_result",
  "organism_name",
  "taxid",
  "species_taxid",
  "version_status",
  "assembly_level",
  "refseq_category",
  "local_path",
  "ftp_path");

# Convert to array
my @column_header = (COLUMN_HEADER);

# Get global dbh
my $config = load_config();
my $known_filename = $config->{known_assemblies};
my ($known_table, $known_path) = fileparse($known_filename);

# Set dbh options
my $dbh = DBI->connect("dbi:CSV:", undef, undef, {
  f_dir => $known_path,
  csv_eol => "\n",
  csv_sep_char => ',',
  csv_quote_char => undef,
  csv_escape_char => undef});

# Create file if it does not exist and ensure file is write protected
if (! -e $known_filename) {
  my $colstr = join(" CHAR(0), ", @column_header) . " CHAR(0)";
  $dbh->do("CREATE TABLE $known_table ($colstr)");
  chmod 0440, $known_filename;
}

# Insert statement
my $insert_sth = $dbh->prepare(
  "INSERT INTO $known_table (" . join(", ", @column_header) . ") " .
  "VALUES (". "?, " x $#column_header . "?)");

# Update whole row with given rast_jobid
my $update_sth = $dbh->prepare(
  "UPDATE $known_table " .
  "SET " . join(" = ?, ", @column_header) . " = ? " .
  "WHERE asmid = ?");

# Fetch via assembly
my $query_asmids_sth= $dbh->prepare(
  "SELECT * FROM $known_table WHERE asmid = ?");

sub do_insert_known {
  my ($vals) = @_;
  chmod 0660, $known_filename;
  $insert_sth->execute(@{$vals}{@column_header});
  chmod 0440, $known_filename;
}

sub do_update_known {
  # Update known given an asmid and hash ref
  # Constructs a prepare statement and executes update
  my ($asmid, $values) = @_;
  delete $values->{asmid} if exists $values->{asmid};

  # Prepare values to be updated
  my (@update_cols, @update_vals);
  for my $col (@column_header) {
    if (exists $values->{$col}) {
      push @update_cols, $col;
      push @update_vals, $values->{$col};
    }
  }

  # Prepare statement
  my $statement = "UPDATE $known_table " .
    "SET " . join(" = ?, ", @update_cols) . " = ? " .
    "WHERE asmid = ?";

  # Do the update
  $update_sth = $dbh->prepare_cached($statement);
  chmod 0660, $known_filename;
  $update_sth->execute(@update_vals, $asmid);
  chmod 0440, $known_filename;
}

sub get_known {
  # Given a list of asmids, returns hash of all rows of know_assemblies
  # Return hash is keyed by asmid
  my @asmids = @_;
  my %ret;
  for my $asmid (@asmids) {
    $query_asmids_sth->execute($asmid);
    while (my $res = $query_asmids_sth->fetchrow_hashref) {
      $ret{$res->{asmid}} = clone($res);
    }
  }
  return \%ret;
}

sub add_known {
  # Given a hashref keyed by asmid containing valid column types
  # Adds new row containing values from hash
  # Will exit with error if asmid already exists
  my $asmids = shift;

  # Ensure asmid is present in hash
  for my $asmid (keys %$asmids) {
    $asmids->{$asmid}->{asmid} = $asmid if !exists $asmids->{$asmid}->{asmid};
  }

  # Check known assemblies
  my $known = get_known(keys %$asmids);
  my @found = map { $_ if exists($known->{$_}) } keys %$known;
  my $err = "Error: Found already existing entry for: ". join("\n  ", @found);
  croak $err if (scalar(@found) > 0);

  # Add values
  do_insert_known($_) for values(%$asmids);
}

sub update_known {
  # Given a hashref of keyed by asmid containing valid column types
  # updates the row associated with the supplied asmid
  # Will exit with an error if no asmids are found
  my $asmids = shift;

  # Check known assemblies
  my @missing;

  my $known = get_known(keys %$asmids);
  for my $asmid (keys %$asmids) {
    push @missing, $asmid if !exists $known->{$asmid};
  }
  croak "Error: Found missing entry for:\n   " .
    join("\n  ", @missing) . "\n" if @missing;

  # Update values
  while (my($asm, $vals) = each %$asmids) {
    do_update_known($asm, $vals)
  }
}


1;
