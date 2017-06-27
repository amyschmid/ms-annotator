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
package Signatures;

    use strict;
    use Tracer;

=head1 Genome Signatures Computation Object

This object is used to support the computation of genome signatures. It
takes as input two genome sets and produces a statistical analysis of the
protein families that distinguish the two sets.

A genome in this context is defined as a genome ID and a list of protein
family IDs. Of course, anything could be used for the genome ID and anything
could be used for the family IDs, so long as it is done consistently.
Nonetheless, to keep the documentation grounded, we will refer to the
elements of discourse as I<genomes> and I<families>.

The basic strategy is to count the number of occurrences of each family in
each set and assign a score ranging from 0 to 2 based on whether the family
tends to occur in both sets or tends to occur in only one set. A score of 1
or more indicates that the family is considered a signature for its
particular set.

The main entry method for this module is the static L</ComputeSignatures>.
This builds the object and runs the computations. The object itself
contains the following fields.

=over 4

=item sets

A 2-tuple containing the hashes for the two genome sets (known as set C<0>
and set C<1>). Each hash is keyed by genome ID and maps each genome in the
set to a list of the IDs of all the families present in the genome.

=item counts

Hash mapping each family ID to a 2-tuple consisting of (0) the number of
genomes in set C<0> that contain the family and (1) the number of genomes
in set C<1> that contain the family.

=back

=head2 Special Methods

=head3 new

    my $sigO = Signatures->new(\%set0, \%set1);

Create a new signature object for the two specified genome sets. The new
object will contain the genome set information, but the family count and
score tables will be empty.

=over 4

=item set0

Reference to a hash mapping the ID of each genome in set 0 to a list of
the families it contains.

=item set1

Reference to a hash mapping the ID of each genome in set 1 to a list of
the families it contains.

=back

=cut

sub new {
    # Get the parameters.
    my ($class, $set0, $set1) = @_;
    # Create the signatures object.
    my $retVal = {
        sets => [$set0, $set1],
        counts => {},
    };
    # Bless and return it.
    bless $retVal, $class;
    return $retVal;
}

=head2 Public Methods

=head3 ComputeSignatures

    my ($families0, $families1) = ComputeSignatures(\%set0, \%set1);

Compute the signature protein families for the two specified genome sets.
Each genome set is specified in the form of a hash that maps the ID of
each genome in the set to a list of the IDs for families represented in the
genome. The output hashes list the families common in each set that are
uncommon in the other set. They map each relevant family ID to a score
ranging from 1 to 2 indicating the degree to which the family can be considered
a signature family.

=over 4

=item set0

Reference to a hash mapping the ID of each genome in set 0 to a list of
the families it contains.

=item set1

Reference to a hash mapping the ID of each genome in set 1 to a list of
the families it contains.

=item RETURN

Returns a list of two hash references, the first (index 0) containing families
that are significant to set 0 and the second (index 1) containing families that
are significant to set 1. Each hash maps family IDs to significance scores
ranging from 1 to 2. The higher the score, the more significant the family
is in distinguishing the indicated set from the other set.

=back

=cut

sub ComputeSignatures {
    # Get the parameters.
    my ($set0, $set1) = @_;
    # Create the signatures object.
    my $sig = Signatures->new($set0, $set1);
    # Count the families.
    $sig->CountFamilies(0);
    $sig->CountFamilies(1);
    # Loop through the families, computing scores.
    my ($families0, $families1) = $sig->ScoreFamilies();
    # Return the result.
    return ($families0, $families1);
}

=head2 Internal Methods

=head3 CountFamilies

    $sig->CountFamilies($idx);

Count the families found in the specified genome set. The counts will be stored
in the C<counts> member of this object.

=over 4

=item idx

Index of the set to be counted: C<0> for set 0 or C<1> for set 1.

=back

=cut

sub CountFamilies {
    # Get the parameters.
    my ($self, $idx) = @_;
    # Get the indicated set.
    my $set = $self->{sets}[$idx];
    # Get the count hash.
    my $counts = $self->{counts};
    # Loop through the genomes in the specified set.
    for my $genomeID (keys %$set) {
        Trace("Processing $genomeID for set $idx.") if T(3);
        # Get the genome's families.
        my $families = $set->{$genomeID};
        # Loop through them.
        for my $family (@$families) {
            # Insure we have a hash entry for this family.
            if (! exists $counts->{$family}) {
                $counts->{$family} = [0,0];
            }
            # Count this family for this set.
            $counts->{$family}[$idx]++;
        }
    }
}

=head3 ScoreFamilies

    my ($families0, $families1) = $sig->ScoreFamilies();

Compute the score for each family and place it in the appropriate output
hash. This method should be called after L</CountFamilies> has been used
to fill in the C<counts> member.

=over 4

=item RETURN

Returns a list of two hash references, the first (index 0) containing families
that are significant to set 0 and the second (index 1) containing families that
are significant to set 1. Each hash maps family IDs to significance scores
ranging from 1 to 2. The higher the score, the more significant the family
is in distinguishing the indicated set from the other set.

=back

=cut

sub ScoreFamilies {
    # Get the parameters.
    my ($self) = @_;
    # Create the return hashes.
    my $families0 = {};
    my $families1 = {};
    # Get the count hash.
    my $counts = $self->{counts};
    # Compute the size of each set.
    my $size0 = scalar keys %{$self->{sets}[0]};
    my $size1 = scalar keys %{$self->{sets}[1]};
    # Loop through the families, computing scores.
    for my $family (keys %$counts) {
        # Get the counts for this family.
        my ($count0, $count1) = @{$counts->{$family}};
        # Compute the occurrence ratios for the two sets.
        my $ratio0 = $count0 / $size0;
        my $ratio1 = $count1 / $size1;
        my $comp0 = 1 - $ratio0;
        my $comp1 = 1 - $ratio1;
        # Get the three variances.
        my $var0 = $ratio0 * $ratio0 + $comp0 * $comp0;
        my $var1 = $ratio1 * $ratio1 + $comp1 * $comp1;
        my $mix = $ratio0 * $ratio1 + $comp0 * $comp1;
        # Compute the score.
        my $score = 2 - $mix / $var0 - $mix / $var1;
        # If we have a score, save this family.
        if ($score > 1) {
            if ($ratio0 > $ratio1) {
                $families0->{$family} = $score;
            } else {
                $families1->{$family} = $score;
            }
        }
        Trace("Family counts for $family are $count0, $count1 with score $score.") if T(3);
    }
    # Return the family hashes.
    return ($families0, $families1);
    
}

1;
