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
our @EXPORT_OK = qw(update_known get_tasks get_known_assemblies);

# Order does not matter
# Any all columns can be added or removed except:
#   rast_jobid, rast_taxid, rast_result, modelseed_id, modelseed_result
# Note that rast_jobid is used as a primary key
# Values for all other keys are added via the assembly hash
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
  "UPDATE $known_table SET " . join(" = ?, ", @column_header) . " = ? " .
  "WHERE rast_jobid = ?");

# Fetch via rast_jobid
my $query_rastjob_sth= $dbh->prepare(
  "SELECT * FROM $known_table WHERE rast_jobid = ?");

# Fetch via assembly
my $query_assembly_sth= $dbh->prepare(
  "SELECT * FROM $known_table WHERE assembly = ?");

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
  # Given a rast_jobid, and hash of values to be added
  # Adds new row if rast_jobid does not exit, otherwise updates existing row
  my ($id, $vals) = @_;
  $query_rastjob_sth->execute($id);

  # Ensure rast_jobid is unique
  my $nrows = $query_rastjob_sth->rows;

  # Add to file no rows are retured otherwise, get current row and update
  if ($nrows == 0) {
    do_insert_known({rast_jobid => $id, %{$vals}});
  } elsif ($nrows == 1) {
    my %res = %{$query_rastjob_sth->fetchrow_hashref};
    for (keys %{$vals}) {
      $res{$_} = $vals->{$_} if $_ ~~ @column_header;
    }
    do_update_known($id, \%res);
  } else {
    carp "Error - Multiple entries for jobid: $id" if $nrows > 1;
  }
  $query_rastjob_sth->finish;
}

sub get_known_assemblies {
  # Given a ref of jobids, returns a hash of associated assembly ids
  # This is likely a many to one relationship
  my $jobids = shift;
  my %ret;
  for my $jobid (@{$jobids}) {
    $query_rastjob_sth->execute($jobid);
    if ($query_rastjob_sth->rows == 1) {
      my $res = $query_rastjob_sth->fetchrow_hashref;
      $ret{$jobid} = $res->{assembly};
    } elsif ($query_rastjob_sth->rows > 1) {
      croak "Error - Found > 1 assemblies for rast_jobid: $jobid\n";
    } else {
      croak "Error - Could not determine assembly id for rast_jobid: $jobid\n";
    }
  }
  return \%ret;
}


sub get_known_jobids {
  # Given an array of asmids, returns a hash of hashes keyed by assembly
  # Each sub-hash is keyed by rast_jobid and contains values for:
  #   rast_jobid, rast_taxid, rast_result, modelseed_id, modelseed_result
  # This can be a one to many relationship
  my @asmids = @_;
  my @task_list = qw(
    rast_jobid rast_taxid rast_result
    modelseed_id modelseed_result);

  my %ret;
  for my $asmid (@asmids) {
    $query_assembly_sth->execute($asmid);
    if ($query_assembly_sth->rows == 0) {
      $ret{$asmid} = undef;
    } else {
      my %ids;
      while (my $res = $query_assembly_sth->fetchrow_hashref) {
        $ids{$res->{rast_jobid}} = { map { $_ => $res->{$_} } @task_list };
      }
      $ret{$asmid} = { %ids };
    }
  }
  return \%ret;
}

sub get_tasks {
  # Given a array of asmids
  # Returns a hash of the following form:
  #   needs_rast         => (asmids)
  #   pending_rast       => (rast_jobids)
  #   complete_rast      => (rast_jobids)
  #   needs_modelseed    => (rast_jobids)
  #   pending_modelseed  => (rast_jobids)
  #   complete_modelseed => (rast_jobids)
  #
  # known_assemblies are parsed as follows
  #   needs_rast:         asmids without rast_jobids
  #   pending_rast:       rast_jobids without rast_result
  #   complete_rast:      rast_jobids with a rast_result
  #   needs_modelseed:    rast_taxid without modelseed_id
  #   pending_modelseed:  modelseed_id without smbl file
  #   complete_modelseed: has smbl file
  my @asmids = @_;
  my %ret;

  my $known_asmids = get_known_jobids(@asmids);
  for my $asmid (keys %{$known_asmids}) {
    my $known_asm = $known_asmids->{$asmid};
    if (!$known_asm) {
      push @{$ret{needs_rast}}, $asmid;
    } else {
      while (my ($jobid, $asm) = each %{$known_asm}) {
        push @{$ret{complete_rast}}, $jobid if $asm->{rast_result};
        push @{$ret{complete_modelseed}}, $jobid if $asm->{modelseed_result};
        push @{$ret{needs_modelseed}}, $jobid if !$asm->{modelseed_id};
        push @{$ret{pending_rast}}, $jobid if !$asm->{rast_result};
        push @{$ret{pending_modelseed}}, $jobid if
        $asm->{modelseed_id} && !$asm->{modelseed_result};
      }
    }
  }
  return \%ret;
}

1;
