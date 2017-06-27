#!/usr/bin/perl -w
use strict;

#
# Copyright (c) 2003-2006 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
#
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License.
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#
package ACH;

    use strict;
    use Tracer;
    use SeedUtils;
    use ServerThing;
    use ERDB;

=head1 ACH Server Function Object

This file contains the functions and utilities used by the Annotation
Clearinghouse Server (B<ach_server.cgi>). The L</Primary Methods> represent
function calls direct to the server. These all have a signature similar to the
following.

    my $document = $achObject->function_name($args);

where C<$achObject> is an object created by this module, 
C<$args> is a parameter structure, and C<function_name> is the Annotation
Clearinghouse Server function name. The output is a structure, generally a hash
reference, but sometimes a string or a list reference.

This server is used to access assertions harvested from the Annotation
Clearinghouse and stored in the Sapling database. At the current time, it
is generally one to two weeks behind the latest server data.

=head2 Special Methods

=head3 new

    my $ffObject = ACHserver->new();

Create a new Annotation Clearinghouse server function object. The server
function object contains a pointer to a L<Sapling> object, and is used to invoke
the server functions.

=cut

#   
# Actually, if you are using ACH.pm, you should do ACH->new(), not ACHserver->new()
# That comment above is for the benefit of the pod doc stuff on how to use ACHserver 
# that is generated from this file.
#

sub new {
    my ($class) = @_;
    # Get the sapling database.
    my $sap = ERDB::GetDatabase('Sapling');
    # Create the server object.
    my $retVal = {
                  db => $sap,
                 };
    # Bless and return it.
    bless $retVal, $class;
    return $retVal;
}

=head2 Primary Methods

=head3 methods

    my $document = $achObject->methods();

Return a list of the methods allowed on this object.

=cut

use constant METHODS => [qw(equiv_sequence
                            equiv_precise
                        )];

sub methods {
    # Get the parameters.
    my ($self) = @_;
    # Return the result.
    return METHODS;
}

=head3 equiv_sequence

    my $document = $achObject->equiv_sequence($args);

Return the assertions for all genes in the database that match the
identified protein sequences. A protein sequence can be identified by a
prefixed MD5 code or any prefixed gene identifier (e.g. C<uni|AYQ44>,
C<gi|85841784>, or C<fig|360108.3.peg.1041>).

=over 4

=item args

Reference to a list of protein identifiers, or reference to a hash
with the key C<-ids> whose value is a reference to a list of identifiers. Each
identifier should be a prefixed gene identifier or the C<md5|>-prefixed MD5 of a
protein sequence. If the parameter is a hash reference, then if the key C<-hash>
is provided, the return value will be in the form of a hash instead of a list.

=item RETURN

Normally, returns a reference to a list of 5-tuples. Each 5-tuple contains an
identifier that is sequence-equivalent to at least one of the input identifiers,
the asserted function of that identifier, the source of the assertion, a
flag that is TRUE if the assertion is by an expert, and the name of the genome
relevant to the identifier (if any). If the C<-hash> flag is specified in the
parameter list, then the return value will be a hash of lists, keyed by incoming
protein identifier, mapping each protein identifier to a list of the relevant
5-tuples.

=back

=cut

sub show_methods {
	my @methods = ("equiv_precise", "equiv_sequence");
	return(\@methods);
}


sub equiv_sequence {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the Sapling database.
    my $sap = $self->{db};
    # Convert a list to a hash.
    if (ref $args ne 'HASH') {
        $args = { -ids => $args };
    }
    # Find out if we're returning a hash.
    my $hashFlag = $args->{-hash} || 0;
    # Declare the return variable.
    my $retVal = ($hashFlag ? {} : []);
    # Get the list of IDs.
    my $ids = ServerThing::GetIdList(-ids => $args);
    # Loop through the IDs in the list.
    for my $id (@$ids) {
        # This hash will contain a list of the relevant protein sequence IDs.
        my %prots;
        # We'll put our assertions found in here.
        my @results;
        # Determine the ID type.
        if ($id =~ /^md5\|(.+)/) {
            # Here we have a protein sequence MD5 ID. In this case, we just
            # strip the prefix to get a Sapling protein sequence ID.
            $prots{$1} = 1;
        } else {
            # Here we have a gene ID. Start by asking for all of the
            # protein sequences it identifies directly.
            my @prots = $sap->GetFlat("Identifier Names ProteinSequence", 
                                      'Identifier(id) = ?', [$id],
                                      'ProteinSequence(id)');
            # Add the ones it identifies through a feature.
            push @prots, $sap->GetFlat("Identifier Identifies Feature Produces ProteinSequence", 
                                       'Identifier(id) = ?', [$id],
                                       'ProteinSequence(id)');
            # Put all the proteins found in the hash.
            for my $prot (@prots) {
                $prots{$prot} = 1;
            }
        }
        # Loop through the protein sequences, finding assertions. For each
        # protein, we make two queries. Note that we expect the number of
        # protein sequences to be small, despite the large amount of work
        # performed above.
        for my $prot (sort keys %prots) {
            # Get the assertions on the protein's identifiers.
            @results = $sap->GetAll("ProteinSequence IsNamedBy Identifier HasAssertionFrom Source",
                                    "ProteinSequence(id) = ?", [$prot],
                                    [qw(Identifier(id) HasAssertionFrom(function)
                                        Source(id) HasAssertionFrom(expert))]);
            # Add the assertions on the identifiers for the protein's features.
            push @results, $sap->GetAll("ProteinSequence IsProteinFor Feature IsIdentifiedBy Identifier HasAssertionFrom Source AND Feature IsOwnedBy Genome",
                                        "ProteinSequence(id) = ?", [$prot],
                                        [qw(Identifier(id) HasAssertionFrom(function)
                                           Source(id) HasAssertionFrom(expert)
                                           Genome(scientific-name))]);
        }
        # If we found results, put them in the return object.
        Trace(scalar(@results) . " results found for $id.") if T(3);
        if (@results) {
            if ($hashFlag) {
                $retVal->{$id} = \@results;
            } else {
                push @$retVal, @results;
            }
        }
    }
    # Return the result.
    return $retVal;
}

=head3 equiv_precise

    my $document = $achObject->equiv_precise($args);

Return the assertions for all genes in the database that match the
identified gene. The gene can be specified by any prefixed gene
identifier (e.g. C<uni|AYQ44>, C<gi|85841784>, or
C<fig|360108.3.peg.1041>).

=over 4

=item args

Reference to a list of gene identifiers, or reference to a hash
with the key C<-ids> whose value is a reference to a list of
identifiers. Each identifier should be a prefixed gene identifier.
or the C<md5|>-prefixed MD5 of a protein sequence. If the parameter
is a hash reference, then if the key C<-hash> is provided, the return value will
be in the form of a hash instead of a list.

=item RETURN

Normally, returns a reference to a list of 2-tuples. Each 2-tuple consists
of an input identifier followed by a reference to a list of 4-tuples.
Each 4-tuple contains an identifier that is equivalent to the input identifier,
the asserted function of that identifier, the source of the assertion, and a
flag that is TRUE if the assertion is by an expert.

=back

=cut

sub equiv_precise {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the Sapling database.
    my $sap = $self->{db};
    # Declare the return variable.
    my $retVal = [];
    # Convert a list to a hash.
    if (ref $args ne 'HASH') {
        $args = { -ids => $args };
    }
    # Get the list of IDs.
    my $ids = ServerThing::GetIdList(-ids => $args);
    foreach my $id (@$ids) {
        my @resultRows = $sap->GetAll("Identifier HasAssertionFrom Source", 
                                      'Identifier(id) = ? ', 
                                      [$id], [qw(Identifier(id) 
                                                 HasAssertionFrom(function) 
                                                 Source(id) 
                                                 HasAssertionFrom(expert))]);
        push @$retVal, [$id, \@resultRows];
    }
    # Return the result.
    return $retVal;
}





1;
