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
package CO;

    use strict;
    use ERDB;
    use Tracer;
    use SeedUtils;
    use ServerThing;
    use FC;

=head1 Co-Occurrence Server Function Object

This file contains the functions and utilities used by the Co-Occurrence Server
(B<co_occurs_server.cgi>). The L</Primary Methods> represent function
calls direct to the server. These all have a signature similar to the following.

    my $document = $coObject->function_name($args);

where C<$coObject> is an object created by this module, C<$args> is a parameter
structure, and C<function_name> is the Co-Occurrence Server function name. The
output is a structure, generally a hash reference, but sometimes a string or a
list reference.

=head2 Special Methods

=head3 new

    my $coObject = COserver->new();

Create a new co-occurrence server function object. The server function object
contains a pointer to a L<Sapling> object, and is used to invoke the
server functions.

=cut

#   
# Actually, if you are using CO.pm, you should do CO->new(), not COserver->new()
# That comment above is for the benefit of the pod doc stuff on how to use COserver 
# that is generated from this file.
#

sub new {
    my ($class) = @_;
    # Create the sapling object.
    my $sap = ERDB::GetDatabase('Sapling');
    # Create the server object.
    my $retVal = { db => $sap };
    # Bless and return it.
    bless $retVal, $class;
    return $retVal;
}


=head2 Primary Methods

=head3 methods

    my $document = $coObject->methods();

Return a list of the methods allowed on this object.

=cut

use constant METHODS => [qw(conserved_in_neighborhood
                            pairsets
                            clusters_containing
                            related_clusters
                            co_occurrence_evidence
                            related_figfams
                        )];

sub methods {
    # Get the parameters.
    my ($self) = @_;
    # Return the result.
    return METHODS;
}

=head3 conserved_in_neighborhood

    my $document = $coObject->conserved_in_neighborhood($args);

This method takes a list of feature IDs. For each feature ID, it will
return the set of other features to which it is functionally coupled,
along with the appropriate score.

=over 4

=item args

Either (1) a reference to a hash mapping the key C<-ids> to a list of FIG
feature IDs, or (2) a reference to a list of FIG feature IDs. In case (1),
the additional parameter C<-hash> can be provided. If it has a value of
TRUE, then the output will be a hash of lists instead of a list of lists.

=item RETURN

Returns a reference to a hash or list of sub-lists. Each sub-list corresponds to
a feature in the input list. The sub-list itself is consists 4-tuples, one per
feature functionally coupled to the input feature. Each tuple contains the
coupling score, the FIG ID of the coupled feature, the coupled feature's current
functional assignment, and the ID of the pair set to which the coupling belongs.
If the output is a hash, it maps each incoming feature ID to that feature's
sub-list.

=back

=cut

sub conserved_in_neighborhood {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the sapling database.
    my $sapling = $self->{db};
    # Determine the output format.
    my $hashFormat = $args->{-hash} || 0;
    # Declare the return variable.
    my $retVal = ($hashFormat ? {} : []);
    # Convert a list to a hash.
    if (ref $args ne 'HASH') {
        $args = { -ids => $args };
    }
    # Get the list of feature IDs.
    my $ids = ServerThing::GetIdList(-ids => $args);
    # Loop through the features.
    for my $id (@$ids) {
        # Create a sub-list for this feature.
        my $group = [];
        # Ask for the functional coupling information.
        my @co_occurs = &FC::co_occurs($sapling, $id);
        # Loop through the coupling data found.
        for my $tuple (@co_occurs) {
            # Get the coupled feature's data.
            my($sc, $fid, $pairset) = @$tuple;
            # Add it to the group of tuples for this feature's couplings.
            push(@$group, [$sc, $fid, $sapling->Assignment($fid), $pairset]);
        }
        # Add this feature's couplings to the return value.
        if ($hashFormat) {
            $retVal->{$id} = $group;
        } else {
            push(@$retVal, $group);
        }
    }
    # Return the result.
    return $retVal;
}

=head3 pairsets

    my $document = $coObject->pairsets($args);

This method takes as input a list of functional-coupling pair set IDs.
For each pair set, it returns the set's score (number of significant
couplings) and a list of the coupled pairs in the set.

=over 4

=item args

Either (1) a reference to a list of functional-coupling pair set IDs, or (2) a reference
to a hash mapping the key C<-ids> to a list of functional-coupling pair set IDs.

=item RETURN

Returns a reference to a list of 2-tuples. Each 2-tuple corresponds to an ID
from the input list. The 2-tuples themselves each contain the pair set's ID
followed by another 2-tuple consisting of the score and a reference to a
list of the pairs in the set. The pairs are represented themselves by
2-tuples. Because the pairings all belong to the same set, all of the first
pegs in the pairings are similar to each other, and all of the second pegs
in the pairings are similar to each other.

=back

=cut

sub pairsets {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the sapling database.
    my $sapling = $self->{db};
    # Declare the return variable.
    my $retVal = [];
    # Convert a list to a hash.
    if (ref $args ne 'HASH') {
        $args = { -ids => $args };
    }
    # Get the list of pairset IDs.
    my $ids = ServerThing::GetIdList(-ids => $args);
    # Loop through the pairsets.
    for my $id (@$ids) {
        push(@$retVal, [$id, [&FC::co_occurrence_set($sapling, $id)]]);
    }
    # Return the result.
    return $retVal;
}

=head3 clusters_containing

    my $document = $coObject->clusters_containing($args);

This method takes as input a list of feature IDs. For each feature, it
returns the IDs and functions of other features in the same cluster.

=over 4

=item args

Either (1) a reference to a list of feature IDs, or (2) a reference to a hash
mapping the key C<-ids> to a list of feature IDs.

=item RETURN

Returns a reference to a list. For each incoming feature, there is a list
entry containing the feature ID, the feature's functional assignment, and
a sub-list of 2-tuples. Each 2-tuple contains the ID of another feature in
the same cluster and its functional assignment.

=back

=cut

sub clusters_containing {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the sapling database.
    my $sapling = $self->{db};
    # Declare the return variable.
    my $retVal = [];
    # Convert a list to a hash.
    if (ref $args ne 'HASH') {
        $args = { -ids => $args };
    }
    # Get the list of feature IDs.
    my $ids = ServerThing::GetIdList(-ids => $args);
    # Loop through the features.
    for my $id (@$ids) {
        # Get this feature's cluster data.
        my $cluster = &FC::in_co_occurrence_cluster($sapling, $id);
        # If we found something, put it into the output list.
        if ($cluster) {
            my $func = scalar $sapling->Assignment($id);
            push @$retVal, [$id, $func, [map { [$_, $sapling->Assignment($_)] } @$cluster]];
        }
    }
    # Return the result.
    return $retVal;
}

=head3 related_clusters

    my $document = $coObject->related_clusters($args);

This method returns the functional-coupling clusters related to the specified
input features. Each cluster contains features on a single genome that are
related by functional coupling. 

=over 4

=item args

Either (1) a reference to a list of FIG feature IDs, or (2) a reference to a hash
mapping the key C<-ids> to a list of FIG feature IDs.

=item RETURN

Returns a reference to a list. For each incoming feature ID, the output list
contains a sub-list of clusters. Each cluster in the sub-list is a 3-tuple
consisting of the ID of a feature similar to the incoming feature, the
similarity P-score, and a reference to a list of 2-tuples for clustered features.
Each feature 2-tuple contains the feature ID followed by the functional
assignment.

=back

=cut

sub related_clusters {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the sapling database.
    my $sapling = $self->{db};
    # Declare the return variable.
    my $retVal = [];
    # Convert a list to a hash.
    if (ref $args ne 'HASH') {
        $args = { -ids => $args };
    }
    # Get the list of feature IDs.
    my $ids = ServerThing::GetIdList(-ids => $args);
    # Loop through the features.
    for my $id (@$ids) {
        # Create the output list for this feature.
        my $output = [];
        # Loop through the related clusters.
        for my $cluster (FC::largest_co_occurrence_clusters($sapling, $id)) {
            # Get this cluster's data.
            my ($fid, $sc, $other_fids) = @$cluster;
            # Extract the functional roles of the other features in the cluster.
            my $other_tuples = [ map { [$_, $sapling->Assignment($_)] } @$other_fids ];
            # Assemble the result into the output list.
            push @$output, [$fid, $sc, $other_tuples];
        }
        # Push this list of clusters into the master return list.
        push @$retVal, $output;
    }
    # Return the result.
    return $retVal;
}

=head3 co_occurrence_evidence

    my $document = $coObject->co_occurrence_evidence($args);

For each specified pair of genes, this method returns the evidence that
the genes are functionally coupled (if any); that is, it returns a list
of the physically close homologs for the pair.

=over 4

=item args

Reference to a hash containing the parameters.

=item RETURN

Returns a hash mapping each incoming gene pair to a list of 2-tuples. Each 2-tuple
contains a pair of physically close genes, the first of which is similar to the first
gene in the input pair, and the second of which is similar to the second gene in the
input pair. The hash keys will consist of the two gene IDs separated by a colon (e.g.
C<fig|273035.4.peg.1016:fig|273035.4.peg.1018>).

=back

=head4 Parameter Hash Fields

=over 4

=item -pairs

Reference to a list of functionally-coupled pairs. Each pair is represented by two
FIG gene IDs, either in the form of a 2-tuple or as a string with the two gene IDs
separated by a colon.

=back

=cut

sub co_occurrence_evidence {
    # Get the parameters.
    my ($self, $args) = @_;
    # Declare the return variable.
    my $retVal = {};
    # Get the Sapling database.
    my $sap = $self->{db};
    # Get the list of pairs.
    my $pairs = ServerThing::GetIdList(-pairs => $args);
    # Loop through the pairs.
    for my $pair (@$pairs) {
        # Determine the IDs in this pair.
        my ($peg1, $peg2);
        if (ref $pair) {
            ($peg1, $peg2) = @$pair;
        } else {
            ($peg1, $peg2) = split /:/, $pair;
        }
        # Get the evidence and store it in the return hash.
        $retVal->{"$peg1:$peg2"} = FC::co_occurrence_evidence($sap, $peg1, $peg2);
    }
    # Return the result.
    return $retVal;
}



=head3 related_figfams

    my $document = $coObject->related_figfams($args);

This method takes a list of FIGfam IDs. For each FIGfam, it returns a
list of FIGfams related to it by functional coupling.

=over 4

=item args

Either (1) a reference to a list of FIGfam IDs, or (2) a reference to a hash
mapping the key C<-ids> to a list of FIGfam IDs.

=item RETURN

Returns a reference to a list of 2-tuples. Each 2-tuple contains an incoming
FIGfam ID followed by a sub-list of 2-tuples for other FIGfams. The 2-tuples
in the sub-list each consist of a related FIGfam's ID followed by a 2-tuple
containing a coupling score and the related FIGfam's function.

=back

=cut

sub related_figfams {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the sapling database.
    my $sapling = $self->{db};
    # Declare the return variable.
    my $retVal = [];
    # Convert a list to a hash.
    if (ref $args ne 'HASH') {
        $args = { -ids => $args };
    }
    # Get the list of FIGfam IDs.
    my $ids = ServerThing::GetIdList(-ids => $args);
    # Loop through the FIGfams.
    for my $id (@$ids) {
        push(@$retVal, [$id, [&FC::co_occurring_FIGfams($sapling, $id)]]);
    }
    # Return the result.
    return $retVal;
}




1;
