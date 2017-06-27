package GenomeSetImpl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

=head1 NAME

GenomeSet

=head1 DESCRIPTION



=cut

#BEGIN_HEADER

use Data::Dumper;
use DBI;
use FIG_Config;

#END_HEADER

sub new
{
    my($class, @args) = @_;
    my $self = {
    };
    bless $self, $class;
    #BEGIN_CONSTRUCTOR

    my $dbh;

    if ($FIG_Config::gset_dbms eq 'mysql')
    {
	my $dsn = "DBI:mysql:database=$FIG_Config::gset_db;host=$FIG_Config::gset_dbhost";
	$dbh = DBI->connect($dsn, $FIG_Config::gset_dbuser, $FIG_Config::gset_dbpass);
    }
    else
    {
	die "Unsupported dbms $FIG_Config::gset_dbms";
    }

    $self->{dbh} = $dbh;
    
    #END_CONSTRUCTOR

    if ($self->can('_init_instance'))
    {
	$self->_init_instance();
    }
    return $self;
}

=head1 METHODS



=head2 enumerate_user_sets

  $return = $obj->enumerate_user_sets($username)

=over 4

=item Parameter and return types

=begin html

<pre>
$username is a string
$return is a reference to a list where each element is a reference to a list containing 2 items:
	0: a genome_set_id
	1: a genome_set_name
genome_set_id is a string
genome_set_name is a string

</pre>

=end html

=begin text

$username is a string
$return is a reference to a list where each element is a reference to a list containing 2 items:
	0: a genome_set_id
	1: a genome_set_name
genome_set_id is a string
genome_set_name is a string


=end text



=item Description



=back

=cut

sub enumerate_user_sets
{
    my $self = shift;
    my($username) = @_;

    my @_bad_arguments;
    (!ref($username)) or push(@_bad_arguments, "Invalid type for argument \"username\" (value was \"$username\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to enumerate_user_sets:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'enumerate_user_sets');
    }

    my $ctx = $GenomeSetServer::CallContext;
    my($return);
    #BEGIN enumerate_user_sets

    $self->{dbh}->ping();
    $return = $self->{dbh}->selectall_arrayref(qq(SELECT id, name
						  FROM genome_set
						  WHERE owner = ?), undef, $username);
    #END enumerate_user_sets
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to enumerate_user_sets:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'enumerate_user_sets');
    }
    return($return);
}




=head2 enumerate_system_sets

  $return = $obj->enumerate_system_sets()

=over 4

=item Parameter and return types

=begin html

<pre>
$return is a reference to a list where each element is a reference to a list containing 2 items:
	0: a genome_set_id
	1: a genome_set_name
genome_set_id is a string
genome_set_name is a string

</pre>

=end html

=begin text

$return is a reference to a list where each element is a reference to a list containing 2 items:
	0: a genome_set_id
	1: a genome_set_name
genome_set_id is a string
genome_set_name is a string


=end text



=item Description



=back

=cut

sub enumerate_system_sets
{
    my $self = shift;

    my $ctx = $GenomeSetServer::CallContext;
    my($return);
    #BEGIN enumerate_system_sets
    #END enumerate_system_sets
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to enumerate_system_sets:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'enumerate_system_sets');
    }
    return($return);
}




=head2 set_get

  $return = $obj->set_get($genome_set_id)

=over 4

=item Parameter and return types

=begin html

<pre>
$genome_set_id is a genome_set_id
$return is a GenomeSet
genome_set_id is a string
GenomeSet is a reference to a hash where the following keys are defined:
	id has a value which is a genome_set_id
	name has a value which is a genome_set_name
	owner has a value which is a string
	last_modified_date has a value which is a string
	created_date has a value which is a string
	created_by has a value which is a string
	items has a value which is a reference to a list where each element is a Genome
genome_set_name is a string
Genome is a reference to a hash where the following keys are defined:
	id has a value which is a genome_id
	name has a value which is a string
	rast_job_id has a value which is an int
	taxonomy_id has a value which is an int
	taxonomy_string has a value which is a string
genome_id is a string

</pre>

=end html

=begin text

$genome_set_id is a genome_set_id
$return is a GenomeSet
genome_set_id is a string
GenomeSet is a reference to a hash where the following keys are defined:
	id has a value which is a genome_set_id
	name has a value which is a genome_set_name
	owner has a value which is a string
	last_modified_date has a value which is a string
	created_date has a value which is a string
	created_by has a value which is a string
	items has a value which is a reference to a list where each element is a Genome
genome_set_name is a string
Genome is a reference to a hash where the following keys are defined:
	id has a value which is a genome_id
	name has a value which is a string
	rast_job_id has a value which is an int
	taxonomy_id has a value which is an int
	taxonomy_string has a value which is a string
genome_id is a string


=end text



=item Description



=back

=cut

sub set_get
{
    my $self = shift;
    my($genome_set_id) = @_;

    my @_bad_arguments;
    (!ref($genome_set_id)) or push(@_bad_arguments, "Invalid type for argument \"genome_set_id\" (value was \"$genome_set_id\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to set_get:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'set_get');
    }

    my $ctx = $GenomeSetServer::CallContext;
    my($return);
    #BEGIN set_get

    $self->{dbh}->ping();

    my $res = $self->{dbh}->selectall_hashref(qq(SELECT id, name, owner, last_modified_date, created_date, created_by
						  FROM genome_set
						  WHERE id = ?), 'id', undef, $genome_set_id);
    return {} unless $res && $res->{$genome_set_id};
    $return = $res->{$genome_set_id};

    my $items = $self->{dbh}->selectall_arrayref(qq(SELECT genome_id, genome_name, rast_job_id,
						    	   taxonomy_id, taxonomy_string
						    FROM genome_set_entry
						    WHERE genome_set_id = ?), undef, $genome_set_id);
    $return->{items} = [ map { 
    				{   id => $_->[0],
				    name => $_->[1],
				    rast_job_id => $_->[2],
				    taxonomy_id => $_->[3],
				    taxonomy_string => $_->[4]
				}
			    } @$items ];

    #END set_get
    my @_bad_returns;
    (ref($return) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to set_get:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'set_get');
    }
    return($return);
}




=head2 set_create

  $return = $obj->set_create($genome_set_name, $username)

=over 4

=item Parameter and return types

=begin html

<pre>
$genome_set_name is a genome_set_name
$username is a string
$return is a genome_set_id
genome_set_name is a string
genome_set_id is a string

</pre>

=end html

=begin text

$genome_set_name is a genome_set_name
$username is a string
$return is a genome_set_id
genome_set_name is a string
genome_set_id is a string


=end text



=item Description



=back

=cut

sub set_create
{
    my $self = shift;
    my($genome_set_name, $username) = @_;

    my @_bad_arguments;
    (!ref($genome_set_name)) or push(@_bad_arguments, "Invalid type for argument \"genome_set_name\" (value was \"$genome_set_name\")");
    (!ref($username)) or push(@_bad_arguments, "Invalid type for argument \"username\" (value was \"$username\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to set_create:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'set_create');
    }

    my $ctx = $GenomeSetServer::CallContext;
    my($return);
    #BEGIN set_create

    $self->{dbh}->ping();
    my $res = $self->{dbh}->do(qq(INSERT INTO genome_set (name, owner, created_date)
				  VALUES (?, ?, CURRENT_TIMESTAMP)), undef, $genome_set_name, $username);
    #
    # mysql-specific
    #

    $return = $self->{dbh}->{mysql_insertid};

    #END set_create
    my @_bad_returns;
    (!ref($return)) or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to set_create:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'set_create');
    }
    return($return);
}




=head2 set_delete

  $obj->set_delete($genome_set_id)

=over 4

=item Parameter and return types

=begin html

<pre>
$genome_set_id is a genome_set_id
genome_set_id is a string

</pre>

=end html

=begin text

$genome_set_id is a genome_set_id
genome_set_id is a string


=end text



=item Description



=back

=cut

sub set_delete
{
    my $self = shift;
    my($genome_set_id) = @_;

    my @_bad_arguments;
    (!ref($genome_set_id)) or push(@_bad_arguments, "Invalid type for argument \"genome_set_id\" (value was \"$genome_set_id\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to set_delete:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'set_delete');
    }

    my $ctx = $GenomeSetServer::CallContext;
    #BEGIN set_delete

    #
    # check auth? Nah, for now.
    #

    $self->{dbh}->ping();
    
    $self->{dbh}->do(qq(DELETE FROM genome_set_entry
			WHERE genome_set_id = ?), undef, $genome_set_id);
    $self->{dbh}->do(qq(DELETE FROM genome_set
			WHERE id = ?), undef, $genome_set_id);

    #END set_delete
    return();
}




=head2 set_add_genome

  $obj->set_add_genome($id, $genome)

=over 4

=item Parameter and return types

=begin html

<pre>
$id is a genome_set_id
$genome is a Genome
genome_set_id is a string
Genome is a reference to a hash where the following keys are defined:
	id has a value which is a genome_id
	name has a value which is a string
	rast_job_id has a value which is an int
	taxonomy_id has a value which is an int
	taxonomy_string has a value which is a string
genome_id is a string

</pre>

=end html

=begin text

$id is a genome_set_id
$genome is a Genome
genome_set_id is a string
Genome is a reference to a hash where the following keys are defined:
	id has a value which is a genome_id
	name has a value which is a string
	rast_job_id has a value which is an int
	taxonomy_id has a value which is an int
	taxonomy_string has a value which is a string
genome_id is a string


=end text



=item Description



=back

=cut

sub set_add_genome
{
    my $self = shift;
    my($id, $genome) = @_;

    my @_bad_arguments;
    (!ref($id)) or push(@_bad_arguments, "Invalid type for argument \"id\" (value was \"$id\")");
    (ref($genome) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"genome\" (value was \"$genome\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to set_add_genome:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'set_add_genome');
    }

    my $ctx = $GenomeSetServer::CallContext;
    #BEGIN set_add_genome

    $self->{dbh}->ping();
    $self->{dbh}->do(qq(INSERT INTO genome_set_entry (genome_id, genome_name, rast_job_id, taxonomy_id, taxonomy_string,
						      genome_set_id)
			VALUES (?, ?, ?, ?, ?, ?)), undef,
		     $genome->{id}, $genome->{name}, $genome->{rast_job_id},
		     $genome->{taxonomy_id}, $genome->{taxonomy_string},
		     $id);
    
    #END set_add_genome
    return();
}




=head2 set_remove_genome

  $obj->set_remove_genome($id, $genome)

=over 4

=item Parameter and return types

=begin html

<pre>
$id is a genome_set_id
$genome is a genome_id
genome_set_id is a string
genome_id is a string

</pre>

=end html

=begin text

$id is a genome_set_id
$genome is a genome_id
genome_set_id is a string
genome_id is a string


=end text



=item Description



=back

=cut

sub set_remove_genome
{
    my $self = shift;
    my($id, $genome) = @_;

    my @_bad_arguments;
    (!ref($id)) or push(@_bad_arguments, "Invalid type for argument \"id\" (value was \"$id\")");
    (!ref($genome)) or push(@_bad_arguments, "Invalid type for argument \"genome\" (value was \"$genome\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to set_remove_genome:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'set_remove_genome');
    }

    my $ctx = $GenomeSetServer::CallContext;
    #BEGIN set_remove_genome

    $self->{dbh}->ping();
    $self->{dbh}->do(qq(DELETE FROM genome_set_entry
			WHERE genome_set_id = ? AND genome_id = ?), undef,
		     $id, $genome);

    #END set_remove_genome
    return();
}




=head2 set_clear

  $obj->set_clear($genome_set_id)

=over 4

=item Parameter and return types

=begin html

<pre>
$genome_set_id is a genome_set_id
genome_set_id is a string

</pre>

=end html

=begin text

$genome_set_id is a genome_set_id
genome_set_id is a string


=end text



=item Description



=back

=cut

sub set_clear
{
    my $self = shift;
    my($genome_set_id) = @_;

    my @_bad_arguments;
    (!ref($genome_set_id)) or push(@_bad_arguments, "Invalid type for argument \"genome_set_id\" (value was \"$genome_set_id\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to set_clear:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'set_clear');
    }

    my $ctx = $GenomeSetServer::CallContext;
    #BEGIN set_clear
    $self->{dbh}->ping();
    $self->{dbh}->do(qq(DELETE FROM genome_set_entry
			WHERE genome_set_id = ?), undef,
		     $genome_set_id);

    #END set_clear
    return();
}




=head2 version 

  $return = $obj->version()

=over 4

=item Parameter and return types

=begin html

<pre>
$return is a string
</pre>

=end html

=begin text

$return is a string

=end text

=item Description

Return the module version. This is a Semantic Versioning number.

=back

=cut

sub version {
    return $VERSION;
}

=head1 TYPES



=head2 genome_id

=over 4



=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 Genome

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a genome_id
name has a value which is a string
rast_job_id has a value which is an int
taxonomy_id has a value which is an int
taxonomy_string has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a genome_id
name has a value which is a string
rast_job_id has a value which is an int
taxonomy_id has a value which is an int
taxonomy_string has a value which is a string


=end text

=back



=head2 genome_set_id

=over 4



=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 genome_set_name

=over 4



=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 GenomeSet

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a genome_set_id
name has a value which is a genome_set_name
owner has a value which is a string
last_modified_date has a value which is a string
created_date has a value which is a string
created_by has a value which is a string
items has a value which is a reference to a list where each element is a Genome

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a genome_set_id
name has a value which is a genome_set_name
owner has a value which is a string
last_modified_date has a value which is a string
created_date has a value which is a string
created_by has a value which is a string
items has a value which is a reference to a list where each element is a Genome


=end text

=back



=cut

1;
