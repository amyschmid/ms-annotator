
use strict;
package MgRastSims;
use DBI;

=pod 

=head1 MgRastSims

A generic module to access the MG Rast Sims. This only really access the data and returns it in a couple of simple ways. Intended to simplify and clarify the data access for downstream analysis.

=cut


my $self;

END {
	$self->{dbh}->disconnect if (defined $self->{dbh});
}

sub new {
# connect to the database
	my ($class)  = @_;
# connect to database
	my $dbh;
	eval {

		my $dbms     = $FIG_Config::mgrast_dbms;
		my $host     = $FIG_Config::mgrast_dbhost;
		my $database = $FIG_Config::mgrast_db;
		my $user     = $FIG_Config::mgrast_dbuser;
		my $password = $FIG_Config::mgrast_dbpass;

		if ($dbms eq 'Pg')
		{   
			$dbh = DBI->connect("DBI:Pg:dbname=$database;host=$host", $user, $password,
					{ RaiseError => 1, AutoCommit => 0, PrintError => 0 }) ||
			die "database connect error.";
		}
		elsif ($dbms eq 'mysql' or $dbms eq '') # Default to mysql
		{   
			$dbh = DBI->connect("DBI:mysql:database=$database;host=$host", $user, $password,
					{ RaiseError => 1, AutoCommit => 0, PrintError => 0 }) ||
			die "database connect error.";
		}
		else
		{   
			die "MetagenomeAnalysis: unknown dbms '$dbms'";
		}

	};
	if ($@) {
		warn "Unable to connect to metagenomics database: $@\n";
		return undef;
	}

# create object
	$self = { 
		dbh => $dbh,
	};
	bless $self, $class;


	return $self;

}

=head1 query

Execute an arbitrary SQL query. For example, 

$sims->query('select * from tax_sim_best_by_psc_3650 as t1, (select * from tax_sim_best_by_psc_3650) as t2 where t1.id1=t2.id1 AND t1.dbid=7 and t2.dbid=8;');

=cut

sub query {
	my ($self, $query)=@_;

	my $exc = $self->{dbh}->prepare($query);
	$exc->execute;
	return $exc->fetchall_arrayref();
}

=head1 num_subsystem_hits

Get the number of unique sequences in a database.

usage:
	my $nhits = $mgrastsims->num_subsystem_hits($job, $id);
$job is the job number
$id is a boolean. If true, take the hits from the iden table (best hit sorted by percent identity), otherwise the default is to use the best hit by p-score

=cut

sub num_subsystem_hits {
	my ($self, $job, $id)=@_;
	
	my $table = 'tax_sim_best_by_psc_'.$job;
	if ($id) {$table = 'tax_sim_best_by_iden_'.$job};
	my $q = "select count(distinct id1) from $table where dbid = 7 OR dbid = 9";
	my $ref = $self->query($q);
	return $ref->[0]->[0];
}


=head1 subsystem_hits

Return all the hits for the subsystems database for a job. This is (currently) for SEED subsystems tax 

usage:
	$mgrastsims->subsystem_hits($job, $id);

$job is the job number
$id is a boolean. If true, take the hits from the iden table (best hit sorted by percent identity), otherwise the default is to use the best hit by p-score

The elements of the array are :
dbid; id1; id2; iden; ali_ln; b1; e1; b2; e2; logpsc; bsc; tax_str; tax_group_1; tax_group_2; tax_group_3

0: dbid
1: id1
2: id2
3: iden
4: ali_ln
5: b1
6: e1
7: b2
8: e2
9: logpsc
10: bsc
11: tax_str
12: tax_group_1
13: tax_group_2
14: tax_group_3

=cut

sub subsystem_hits {
	my ($self, $job, $id)=@_;
	my $res = $self->raw_subsystem_hits($job, $id);
	map {
		$_->[9] = $self->log2evalue($_->[9]);
		$_->[11] = $self->tax_string($_->[11]);
		$_->[12] = $self->tax_item($_->[12]);
		$_->[13] = $self->tax_item($_->[13]);
		$_->[14] = $self->tax_item($_->[14]);
	} @$res;

	return $res;
}


=head1 raw_subsystem_hits

This is the same as subsystem_hits, but the columns etc are not expanded

=cut


sub raw_subsystem_hits {
	my ($self, $job, $id)=@_;
	
	my $table = 'tax_sim_best_by_psc_'.$job;
	if ($id) {$table = 'tax_sim_best_by_iden_'.$job};
	my $q = "select * from $table where dbid = 7 OR dbid = 9";
	return $self->query($q);
}


=head1 tax_string

Take a string from the database and return the taxnomy or function that it represents. A tax string is something like

1f:2d:'":3s

=cut

sub tax_string {
	my  ($self, $str)=@_;
	my $tax;
	map {$tax .= $self->tax_item($_). "; "} split /\:/, $str;
	$tax =~ s/\; $//;
	return $tax;
}


=head1 tax_item

Take a sinlge taxonomy/function encoding, and return its user-readable name

=cut

sub tax_item {
	my ($self, $id)=@_;
	#print STDERR "Checking for $id\n";
	my $exc = $self->{dbh}->prepare("select str from tax_item where dbkey = ?");
	$exc->bind_param(1, $id);
	$exc->execute || die $self->{dbh}->errstr;
	return $exc->fetchall_arrayref()->[0]->[0];
}



=head1 evalue2log

return the log of the evalue

=cut

sub evalue2log {
	return 10 * (log($_[1]) / log(10));
}

=head1 log2evalue

return the evalue for a log

=cut

sub log2evalue {
	return 10**($_[1]/10);
}





1;
