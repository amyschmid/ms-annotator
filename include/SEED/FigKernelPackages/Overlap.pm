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


package Overlap;

    use strict;
    use Tracer;
    use BasicLocation;

=head1 Overlap Descriptor

=head2 Introduction

An overlap descriptor contains information describing two overlapping feature
segments in a genome. To completely describe an overlap, you need the IDs of the
overlapping features, the index in each feature's location list of the overlapping
segments and the locations of the segments themselves. From this information it is
possible to derive the type of overlap (normal, embedded, convergent, or divergent)
and the number of overlapping base pairs.

The string representation of an overlap consists of a single letter describing the
overlap type (B<N>ormal, B<E>mbedded, B<C>onvergent, or B<D>ivergent), a sequence
of digits indicating the number of overlapping bases, a single colon (C<:>), and
then the augmented locations separated by a slash. For example, the following string
describes an overlap between the first segment of feature B<fig|83333.1.peg.1005> and
the second segment of feature B<fig|83333.1.peg.1004>.

    N12:
    NC_000913_1080579+111(fid = fig|83333.1.peg.1005, index = 0)/
    NC_000913_1080677+732(fig = fig|83333.1.peg.1004, index = 1)

This is a single string, even though it's displayed on three lines in order to
increase readability. The purpose of encapsulating all this data in a single
string is to make it easy to pass around in web forms. It is expected that the
normal method of storing overlap information is as an object of this type.

=cut

#: Constructor Overlap->new();

# Table of overlap types.
my %TypeTable = ( n => 'normal', e => 'embedded', c => 'convergent', d => 'divergent' );

=head2 Public Methods

=head3 new

    my $olap = Overlap->new($loc0, $loc1);

Construct an overlap object from two augmented locations.

=over 4

=item loc0, loc1

Augmented location objects describing the two segments. In addition to the
location information, each object should contain the feature ID (C<fid>) and
the index of the segment in the feature's location list (C<index>).

If the locations do not overlap, an undefined value will be returned.

=back

    my $olap = Overlap->new($olapString);

Construct an overlap object from a display string.

=over 4

=item olapString

The string representation of an overlap, consisting of a single letter describing the
overlap type (B<N>ormal, B<E>mbedded, B<C>onvergent, or B<D>ivergent), a sequence
of digits indicating the number of overlapping bases, a single colon (C<:>), and
then the augmented locations separated by a slash.

=back

=cut

sub new {
    # Get the parameters.
    my ($class, @p) = @_;
    # Declare the variables for the object components.
    my ($type, $len, $loc0, $loc1);
    # Declare the return value.
    my $retVal;
    # Check the constructor type.
    if (@p == 1) {
        # Here we're constructing from a string. First, we parse out the pieces.
        my ($loc0String, $loc1String);
        if ($p[0] =~ m![necd](\d+):\s*([^/]+)\s*/\s*(.+)$!i) {
            ($type, $len, $loc0String, $loc1String) = ($1, $2, $3, $4);
        } else {
            Confess("Invalid overlap string \"$p[0]\".");
        }
        # Convert the type character to a type name.
        $type = TypeTable{lc $type};
        # Convert the location strings to locations.
        $loc0 = BasicLocation->new($loc0String);
        $loc1 = BasicLocation->new($loc1String);
    } else {
        # Here we have a pair of augmented locations.
        ($loc0, $loc1) = @p;
        # Determine the type and length of the overlap.
        ($type, $len) = CheckOverlap($loc0, $loc1);
    }
    # If an overlap was found, create and bless the object.
    if ($type) {
        # Get copies of the locations.
        my @locations = (BasicLocation->new($loc0), BasicLocation->new($loc1));
        # Determine which location is the left one and which is the right one. This
        # is very useful for the clients.
        my ($left, $right);
        if ($loc0->Left < $loc1->Left) {
            ($left, $right) = ($locations[0], $locations[1]);
        } else {
            ($left, $right) = ($locations[1], $locations[0]);
        }
        $retVal = {
                    _type => $type,
                    _len => $len,
                    _locs => \@locations,
                    _left => $left,
                    _right => $right
                };
        bless $retVal, $class;
    }
    # Return the result.
    return $retVal;
}

=head3 CheckOverlap

    my ($type, $len) = Overlap::CheckOverlap($loc0, $loc1);

Check for an overlap between two locations.

=over 4

=item loc0, loc1

Location objects representing the locations for which overlap information is desired.
These may be B<BasicLocation>s or B<FullLocation>s.

=item RETURN

Returns a two-element list. The first element is a string describing the type of overlap--
C<embedded>, C<normal>, C<convergent>, or C<divergent>. The second element is the number of
overlapping base pairs. If the locations do not overlap, the first element will be undefined
and the second will be 0.

=back

=cut
#: Return Type @;
sub CheckOverlap {
    # Get the parameters.
    my ($loc0, $loc1) = @_;
    # Declare the return variables.
    my ($type, $len) = (undef, 0);
    # If these are full locations, get the bounds.
    if ($loc0->isa('FullLocation')) {
        ($loc0, undef, undef) = $loc0->GetBounds();
    }
    if ($loc1->isa('FullLocation')) {
        ($loc1, undef, undef) = $loc1->GetBounds();
    }
    # Both locations must belong to the same contig.
    if ($loc0->Contig eq $loc1->Contig) {
        # Sort the locations.
        if (BasicLocation::Cmp($loc0, $loc1) > 0) {
            ($loc0, $loc1) = ($loc1, $loc0);
        }
        # There is overlap if the right endpoint of the location 1 is past the
        # left endpoint of location 2. This test is simple because we've sorted
        # the locations by their left endpoint.
        if ($loc0->Right >= $loc1->Left) {
            # Now we check for the different kinds of overlap.
            if ($loc0->Right >= $loc1->Right) {
                # Here the entire second location is inside the first.
                $type = "embedded";
                $len = $loc1->Length;
            } else {
                # Here we have a normal overlap. The overlap extends from the left point
                # of the second location to the right point of the first location.
                $len = $loc0->Right + 1 - $loc0->Left;
                # The overlap type depends on the directions.
                if ($loc0->Dir eq $loc1->Dir) {
                    $type = "normal";
                } elsif ($loc0->Dir eq '+') {
                    $type = "convergent";
                } else {
                    $type = "divergent";
                }
            }
        }
    }
    # Return the result.
    return ($type, $len);
}

=head3 Type

    my $type = $olap->Type;

Return the type of this overlap.

=cut
#: Return Type $;
sub Type {
    # Get this instance.
    my ($self) = @_;
    # Return the overlap type.
    return $self->{_type};
}

=head3 Length

    my $len = $olap->Length;

Return the number of overlapping base pairs.

=cut
#: Return Type $;
sub Length {
    # Get this instance.
    my ($self) = @_;
    # Return the overlap type.
    return $self->{_len};
}

=head3 Loc

    my $loc = $olap->Loc($name);

Return the named location. The location returned will be a location object augmented with the
relevant feature ID (C<fid>) and segment index (C<index>).

=over 4

=item name

Name of the desired location. If C<left> is specified, the leftmost of the two overlapping
locations will be returned. If C<right> is specified, the rightmost of the two overlapping
locations will be returned. Otherwise, the name is presumed to be an index into the list
of locations passed into the constructor. C<0> specifies the first such location and C<1>
the second.

=item RETURN

Returns the named location object.

=back

=cut
#: Return Type %;
sub Loc {
    # Get the parameters.
    my ($self, $name) = @_;
    # Declare the return variable.
    my $retVal;
    # Choose the named location.
    if ($name eq 'left') {
        $retVal = $self->{'_left'};
    } elsif ($name eq 'right') {
        $retVal = $self->{'_right'};
    } else {
        $retVal = $self->{'_locs'}->[$name];
    }
    # Return the result.
    return $retVal;
}

=head3 String

    my $olapString = $olap->String;

Return a string representation of this overlap.

The string returned can be used in the constructor to re-create a copy of the overlap.

=cut
#: Return Type $;
sub String {
    # Get this instance.
    my ($self) = @_;
    # Assemble the string representation.
    my $retVal = (uc substr($self->Type,0,1)) . $self->Length . ": ";
    my @locs = map { $_->AugmentString } @{$self->{'_locs'}};
    $retVal .= join " / ", @locs;
    # Return the result.
    return $retVal;
}

=head3 Matches

    my $flag = Overlap::Matches($olapA, $olapB);

Return TRUE if the two overlaps contain the same data, else FALSE.

=over 4

TODO: items

=back

=cut
#: Return Type $;
sub Matches {
    # Get the parameters.
    my ($self, $olapA, $olapB) = @_;
    # Declare the return variable.
    my $retVal;
    # TODO: code
    # Return the result.
    return $retVal;
}

1;

