
package ACHserver;

    use strict;
    use base qw(ClientThing);

=head1 Annotation Clearinghouse Server Helper Object

=head2 Description

This module is used to call the Annotation Clearinghouse Server, which is a
special-purpose server for assertion data from the Sapling database. Each
Annotation Clearinghouse Server function corresponds to a method of this object.

This package deliberately uses no internal SEED packages or scripts, only common
PERL modules.

The fields in this object are as follows.

=over 4

=item server_url

The URL used to request data from the subsystem server.

=item ua

The user agent for communication with the server.

=item singleton

Indicates whether or not results are to be returned in singleton mode. In
singleton mode, if the return document is a hash reference with only one
entry, the entry value is returned rather than the hash.

=back

=cut

=head3 new

    my $ss = ACHserver->new(%options);

Construct a new server object. The
following options are supported.

=over 4

=item url

URL for the server. This option is required.

=item singleton (optional)

If TRUE, results from methods will be returned in singleton mode. In singleton
mode, if a single result comes back, it will come back as a scalar rather than
as a hash value accessible via an incoming ID.

=back

=cut

sub new {
    # Get the parameters.
    my ($class, %options) = @_;
    # Compute the URL.
    $options{url} = "http://servers.nmpdr.org/ach/server.cgi" if ! $options{url};
    # Construct the subclass.
    return $class->SUPER::new(ACH => %options);
}

1;
