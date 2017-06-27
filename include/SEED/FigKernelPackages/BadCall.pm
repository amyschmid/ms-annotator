#!/usr/bin/perl -w
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


package BadCall;

    use strict;
    use Tracer;
    use FIG;
    use BasicLocation;
    use Overlap;

=head1 Bad Call Utilities

=head2 Introduction

This module contains utility methods for finding and analyzing bad gene calls. The
default constructor uses a FIG object; however, any other object that mimics the
FIG object signatures can be used. By convention, all calls to FIG object methods
will use the variable name I<$fig>, so that the FIG methods used can be easily
identified.

Most B<Location> objects manipulated by this package are I<augmented locations>. An
augmented location contains two additional fields-- the feature ID (C<$loc->{fid}>)
and the location's index in the feature's location list (C<$loc->{index}). An
augmented location enables us to relate the location back to the feature of interest.

=cut

#: Constructor BadCall->new();

=head2 Public Methods

=head3 new

    my $bc = BadCall->new($figLikeObject);

Construct a new, blank BadCall object.

=over 4

=item figLikeObject

An object that mimics the FIG object, which will be used to access genetic information.
If no parameter is specified, a vanilla FIG object will be used.

=item RETURN

Returns an object that can be used to locate and analyze bad gene calls.

=back

=cut

sub new {
    # Get the parameters.
    my ($class, $figLikeObject) = @_;
    if (! defined $figLikeObject) {
        $figLikeObject = FIG->new();
    }
    # Create the $bc object.
    my $retVal = {
                  fig => $figLikeObject
                 };
    # Bless and return it.
    bless $retVal, $class;
    return $retVal;
}

=head3 LocationList

    my @locs = $bc->LocationList($genomeID);

Return a sorted list of the augmented locations for the features of the specified genome.

=over 4

=item genomeID

ID of the genome whose features should be put into the list.

=item RETURN

Returns a list of augmented locations for all the feature segments on the genome's contigs,
sorted in the order they appear on the contigs, so that overlapping segments will be next
to each other.

=back

=cut
#: Return Type @%;
sub LocationList {
    # Get the parameters.
    my ($self, $genomeID) = @_;
    my $fig = $self->{fig};
    # Get the genome's features.
    my $featureDataList = $fig->all_features_detailed($genomeID);
    # @featureDataList now contains a list of tuples. Each tuple's first element is a
    # feature ID, and its second element is the feature's location list, comma-separated.
    # We use This information to create a list of augmented locations.
    my @locList = ();
    for my $featureData (@{$featureDataList}) {
        # Get the feature ID and the location strings.
        my $fid = $featureData->[0];
        my @locations = split /\s*,\s*/, $featureData->[1];
        # Loop through the location strings, creating augmented locations.
        for (my $i = 0; $i <= $#locations; $i++) {
            # Create the location object.
            my $loc = BasicLocation->new($locations[$i] . "(fid = $fid, index = $i)");
            # Add it to the list.
            push @locList, $loc;
        }
    }
    # Sort and return the list.
    my @retVal = sort { BasicLocation::Cmp($a, $b) } @locList;
    return @retVal;
}

=head3 Overlaps

    my %overlaps = $bc->Overlaps($genomeID);

Find the overlapping features in a genome.

This method processes the sorted segment list for a genome's features amd produces
a hash describing which features overlap other features. Each feature ID maps to
a list of overlap objects describing the overlaps. Each overlap will appear
in two lists of the hash-- one for each participating feature.

=over 4

=item genomeID

ID of the genome whose overlaps are desired.

=item RETURN

Returns a hash of lists, keyed by feature ID. Each list will contain overlap objects
describing the overlaps involving the specified feature.

=back

=cut
#: Return Type %@;
sub Overlaps {
    # Get the parameters.
    my ($self, $genomeID) = @_;
    my $fig = $self->{fig};
    # Get the genome's location list. The location list is sorted in such a way as to
    # facilitate detection of overlaps. Any two overlapping locations will be adjacent
    # to each other.
    my @locList = $self->LocationList($genomeID);
    # Create the return hash.
    my %retVal = ();
    # Now we run through the locations checking for overlaps. If one is found, we add
    # it to the return hash.
    for (my $i = 0; $i < $#locList; $i++) {
        # Get the current location and feature ID.
        my $loc0 = $locList[$i];
        my $fid0 = $loc0->{fid};
        # We now loop through the locations following the current one, stopping at the
        # first which is not an overlap.
        my $done = 0;
        for (my $j = $i + 1; $j <= $#locList && ! $done; $j++) {
            my $loc1 = $locList[$j];
            # Check for overlap. If an overlap exists, the Overlap constructor will
            # return an overlap object; otherwise it will return an undefined value.
            my $olap;
            if ($olap = Overlap->new($loc0, $loc1)) {
                # Here we have an overlap. We put the overlap object in the hash
                # for both of the participating features.
                my $fid1 = $loc1->{fid};
                Tracer::AddToListMap(\%retVal, $fid0, $olap);
                Tracer::AddToListMap(\%retVal, $fid1, $olap);
            } else {
                $done = 1;
            }
        }
    }
    # Return the result.
    return %retVal;
}

=head3 OverlapStrings

    my %overlaps = $bc->OverlapStrings($genomeID);

Return a hash of all the overlaps in a genome. Unlike L</Overlaps>, which returns a hash
of lists of overlap objects, this method returns a hash of lists of strings. This makes it
easier to format the overlaps for display.

=over 4

=item genomeID

ID of the genome whose overlaps are desired.

=item RETURN

Returns a hash of lists, keyed by feature ID. Each list will contain overlap strings
describing the overlaps involving the specified feature.

=back

=cut
#: Return Type %@;
sub OverlapStrings {
    # Get the parameters.
    my ($self, $genomeID) = @_;
    my $fig = $self->{fig};
    # Get the hash of overlaps.
    my %overlaps = $self->Overlaps($genomeID);
    # Create the return hash.
    my %retVal = ();
    # Loop through the overlap hash.
    for my $fid (keys %overlaps) {
        for my $olap (@{$overlaps{$fid}}) {
            my $olapString = $olap->String;
            push @{$retVal{$fid}}, $olapString;
        }
    }
    # Return the result.
    return %retVal;
}

1;

