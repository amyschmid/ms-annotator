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
our @EXPORT_OK = qw(update_known get_known_assemblies query_rast_jobids);

# Order does not matter
# Any all columns can be added or removed except:
#   asmid, rast_jobid, rast_taxid, rast_result, modelseed_id, modelseed_result
#
# Note that asmid is used as a primary key
# Values for all other keys are added via the assembly hash
use constant COLUMN_HEADER => (
  "asmid",
  "rast_jobid",
  "rast_taxid",
  "rast_result",
  "modelseed_id",
  "modelseed_name",
  "modelseed_result",
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
my $query_asmid_sth= $dbh->prepare(
  "SELECT * FROM $known_table WHERE asmid = ?");

sub do_insert_known {
  my ($vals) = @_;
  chmod 0660, $known_filename;
  $insert_sth->execute(@{$vals}{@column_header});
  $insert_sth->finish;
  chmod 0440, $known_filename;
}

sub do_update_known {
  # Update known given an asmid, ensures asmid column is updated
  my ($asmid, $values) = @_;
  delete $values->{asmid} if exists $values->{asmid};
  chmod 0660, $known_filename;
  $update_sth->execute(@{$values}{@column_header}, $asmid);
  $update_sth->finish;
  chmod 0440, $known_filename;
}

sub add_known {
  # Given a hash keyed by asmid containing valid column types
  # Adds new row containing new values
  # Returns hash of values added



}

sub update_known {
  # Given a hash of keyed by asmid containing valid column types
  # updates the row associated with the supplyed asmid or adds
  # new row if the asmid is not in known_assemblies
  # Will exit with error if asmid is not found
  my $asmids = shift;
  for my $asmid (keys %{$asmids}) {
    if (!exists $known->{$asmid}) {
      croak "Error - Could not determine assembly id for asmid: $asmid\n";
    }
    do_update_known($asmid, $asmids->{$asmid});
  }
}

sub get_known_assemblies {
  # Given a list of asmids, returns hash of all rows of know_assemblies
  # Returned hash of values keyed by asmid
  my @asmids = @_;
  my %ret;
  # TODO Run query and return hash of asmid by values
  $query_asmid_sth->execute(@asmids);


  #for my $asmid (@{$asmids}) {
  #  if ($query_asmid_sth->rows == 1) {
  #    my $ret{$asmid} = %{$query_asmid_sth->fetchrow_hashref};
  #  } elsif ($query_asmid_sth->rows > 1) {
  #    croak "Error - Found > 1 assemblies for asmid: $asmid\n";
  #  } else {
  #    croak "Error - Could not determine assembly id for asmid: $asmid\n";
  #  }
  #}
  return \%ret;
}


#sub query_rast_jobids {
#  # Given an array of asmids, returns a hash of hashes keyed by assembly
#  # Each sub-hash is keyed by rast_jobid and contains values for:
#  #   rast_jobid, rast_taxid, rast_result, modelseed_id, modelseed_result
#  # This can be a one to many relationship
#  my @asmids = @_;
#  my @field_list = qw(
#    rast_jobid rast_taxid rast_result
#    modelseed_id modelseed_result
#  );
#
#  my %ret;
#  for my $asmid (@asmids) {
#    $query_assembly_sth->execute($asmid);
#    if ($query_assembly_sth->rows == 0) {
#      $ret{$asmid} = undef;
#    } else {
#      my %ids;
#      while (my $res = $query_assembly_sth->fetchrow_hashref) {
#        $ids{$res->{rast_jobid}} = { map { $_ => $res->{$_} } @field_list };
#      }
#      $ret{$asmid} = { %ids };
#    }
#  }
#  return \%ret;
#}

1;
