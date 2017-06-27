package GenomeSetClient;

use JSON::RPC::Client;
use strict;
use Data::Dumper;
use URI;
use Bio::KBase::Exceptions;

# Client version should match Impl version
# This is a Semantic Version number,
# http://semver.org
our $VERSION = "0.1.0";

=head1 NAME

GenomeSetClient

=head1 DESCRIPTION





=cut

sub new
{
    my($class, $url, @args) = @_;
    

    my $self = {
	client => GenomeSetClient::RpcClient->new,
	url => $url,
    };


    my $ua = $self->{client}->ua;	 
    my $timeout = $ENV{CDMI_TIMEOUT} || (30 * 60);	 
    $ua->timeout($timeout);
    bless $self, $class;
    #    $self->_validate_version();
    return $self;
}




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
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function enumerate_user_sets (received $n, expecting 1)");
    }
    {
	my($username) = @args;

	my @_bad_arguments;
        (!ref($username)) or push(@_bad_arguments, "Invalid type for argument 1 \"username\" (value was \"$username\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to enumerate_user_sets:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'enumerate_user_sets');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "GenomeSet.enumerate_user_sets",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'enumerate_user_sets',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method enumerate_user_sets",
					    status_line => $self->{client}->status_line,
					    method_name => 'enumerate_user_sets',
				       );
    }
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
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 0)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function enumerate_system_sets (received $n, expecting 0)");
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "GenomeSet.enumerate_system_sets",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'enumerate_system_sets',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method enumerate_system_sets",
					    status_line => $self->{client}->status_line,
					    method_name => 'enumerate_system_sets',
				       );
    }
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
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function set_get (received $n, expecting 1)");
    }
    {
	my($genome_set_id) = @args;

	my @_bad_arguments;
        (!ref($genome_set_id)) or push(@_bad_arguments, "Invalid type for argument 1 \"genome_set_id\" (value was \"$genome_set_id\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to set_get:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'set_get');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "GenomeSet.set_get",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'set_get',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method set_get",
					    status_line => $self->{client}->status_line,
					    method_name => 'set_get',
				       );
    }
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
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function set_create (received $n, expecting 2)");
    }
    {
	my($genome_set_name, $username) = @args;

	my @_bad_arguments;
        (!ref($genome_set_name)) or push(@_bad_arguments, "Invalid type for argument 1 \"genome_set_name\" (value was \"$genome_set_name\")");
        (!ref($username)) or push(@_bad_arguments, "Invalid type for argument 2 \"username\" (value was \"$username\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to set_create:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'set_create');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "GenomeSet.set_create",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'set_create',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method set_create",
					    status_line => $self->{client}->status_line,
					    method_name => 'set_create',
				       );
    }
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
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function set_delete (received $n, expecting 1)");
    }
    {
	my($genome_set_id) = @args;

	my @_bad_arguments;
        (!ref($genome_set_id)) or push(@_bad_arguments, "Invalid type for argument 1 \"genome_set_id\" (value was \"$genome_set_id\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to set_delete:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'set_delete');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "GenomeSet.set_delete",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'set_delete',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return;
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method set_delete",
					    status_line => $self->{client}->status_line,
					    method_name => 'set_delete',
				       );
    }
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
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function set_add_genome (received $n, expecting 2)");
    }
    {
	my($id, $genome) = @args;

	my @_bad_arguments;
        (!ref($id)) or push(@_bad_arguments, "Invalid type for argument 1 \"id\" (value was \"$id\")");
        (ref($genome) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 2 \"genome\" (value was \"$genome\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to set_add_genome:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'set_add_genome');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "GenomeSet.set_add_genome",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'set_add_genome',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return;
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method set_add_genome",
					    status_line => $self->{client}->status_line,
					    method_name => 'set_add_genome',
				       );
    }
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
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function set_remove_genome (received $n, expecting 2)");
    }
    {
	my($id, $genome) = @args;

	my @_bad_arguments;
        (!ref($id)) or push(@_bad_arguments, "Invalid type for argument 1 \"id\" (value was \"$id\")");
        (!ref($genome)) or push(@_bad_arguments, "Invalid type for argument 2 \"genome\" (value was \"$genome\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to set_remove_genome:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'set_remove_genome');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "GenomeSet.set_remove_genome",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'set_remove_genome',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return;
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method set_remove_genome",
					    status_line => $self->{client}->status_line,
					    method_name => 'set_remove_genome',
				       );
    }
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
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function set_clear (received $n, expecting 1)");
    }
    {
	my($genome_set_id) = @args;

	my @_bad_arguments;
        (!ref($genome_set_id)) or push(@_bad_arguments, "Invalid type for argument 1 \"genome_set_id\" (value was \"$genome_set_id\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to set_clear:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'set_clear');
	}
    }

    my $result = $self->{client}->call($self->{url}, {
	method => "GenomeSet.set_clear",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'set_clear',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return;
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method set_clear",
					    status_line => $self->{client}->status_line,
					    method_name => 'set_clear',
				       );
    }
}



sub version {
    my ($self) = @_;
    my $result = $self->{client}->call($self->{url}, {
        method => "GenomeSet.version",
        params => [],
    });
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(
                error => $result->error_message,
                code => $result->content->{code},
                method_name => 'set_clear',
            );
        } else {
            return wantarray ? @{$result->result} : $result->result->[0];
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(
            error => "Error invoking method set_clear",
            status_line => $self->{client}->status_line,
            method_name => 'set_clear',
        );
    }
}

sub _validate_version {
    my ($self) = @_;
    my $svr_version = $self->version();
    my $client_version = $VERSION;
    my ($cMajor, $cMinor) = split(/\./, $client_version);
    my ($sMajor, $sMinor) = split(/\./, $svr_version);
    if ($sMajor != $cMajor) {
        Bio::KBase::Exceptions::ClientServerIncompatible->throw(
            error => "Major version numbers differ.",
            server_version => $svr_version,
            client_version => $client_version
        );
    }
    if ($sMinor < $cMinor) {
        Bio::KBase::Exceptions::ClientServerIncompatible->throw(
            error => "Client minor version greater than Server minor version.",
            server_version => $svr_version,
            client_version => $client_version
        );
    }
    if ($sMinor > $cMinor) {
        warn "New client version available for GenomeSetClient\n";
    }
    if ($sMajor == 0) {
        warn "GenomeSetClient version is $svr_version. API subject to change.\n";
    }
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

package GenomeSetClient::RpcClient;
use base 'JSON::RPC::Client';

#
# Override JSON::RPC::Client::call because it doesn't handle error returns properly.
#

sub call {
    my ($self, $uri, $obj) = @_;
    my $result;

    if ($uri =~ /\?/) {
       $result = $self->_get($uri);
    }
    else {
        Carp::croak "not hashref." unless (ref $obj eq 'HASH');
        $result = $self->_post($uri, $obj);
    }

    my $service = $obj->{method} =~ /^system\./ if ( $obj );

    $self->status_line($result->status_line);

    if ($result->is_success) {

        return unless($result->content); # notification?

        if ($service) {
            return JSON::RPC::ServiceObject->new($result, $self->json);
        }

        return JSON::RPC::ReturnObject->new($result, $self->json);
    }
    elsif ($result->content_type eq 'application/json')
    {
        return JSON::RPC::ReturnObject->new($result, $self->json);
    }
    else {
        return;
    }
}


sub _post {
    my ($self, $uri, $obj) = @_;
    my $json = $self->json;

    $obj->{version} ||= $self->{version} || '1.1';

    if ($obj->{version} eq '1.0') {
        delete $obj->{version};
        if (exists $obj->{id}) {
            $self->id($obj->{id}) if ($obj->{id}); # if undef, it is notification.
        }
        else {
            $obj->{id} = $self->id || ($self->id('JSON::RPC::Client'));
        }
    }
    else {
        # $obj->{id} = $self->id if (defined $self->id);
	# Assign a random number to the id if one hasn't been set
	$obj->{id} = (defined $self->id) ? $self->id : substr(rand(),2);
    }

    my $content = $json->encode($obj);

    $self->ua->post(
        $uri,
        Content_Type   => $self->{content_type},
        Content        => $content,
        Accept         => 'application/json',
	($self->{token} ? (Authorization => $self->{token}) : ()),
    );
}



1;
