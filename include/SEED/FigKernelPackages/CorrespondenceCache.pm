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
package CorrespondenceCache;

    use strict;
    use Tracer;
    use SeedUtils;
    use ServerThing;

=head1 Genome Correspondence Cache Object

This is a helper object for Sapling Server methods that must manage large
numbers of gene correspondences. It maintains a hash of genome correspondences
so that they can be used over and over without recomputation. When the hash
gets too big, it will be cleared and restarted. Hopefully, that will not be
an issue.

The object has the following fields.

=over 4

=item map

Reference to a hash keyed on a pair of genome IDs separated by a slash. The
first genome ID is the source and the second is the target; the value in
the hash is a sub-hash that contains the gene correspondences from the source
to the target.

=item count

Number of hashes in the map. When this exceeds the maximum, the hash is
cleared and we start over.

=back

=cut

# Maximum number of maps to keep in memory.
use constant MAX_MAPS => 500;

=head2 Special Methods

=head3 new

    my $corrCache = CorrespondenceCache->new();

Construct a new, blank correspondence cache.

=cut

sub new {
    # Get the parameters.
    my ($class) = @_;
    # Create the object.
    my $retVal = {
        map => {},
        count => 0
    };
    # Bless and return it.
    bless $retVal, $class;
    return $retVal;
}


=head2 Public Methods

=head3 get_correspondent

    my $fid2 = $corrCache->get_correspondent($fid1, $genome2);

Return the FIG ID of the gene in a specified genome that corresponds to the
specified incoming gene.

=over 4

=item fid1

FIG ID of the gene for which a corresponding gene is desired.

=item genome2

Target genome in which the corresponding gene should be found.

=item RETURN

Returns the FIG ID of the corresponding gene in the target genome, or
an undefined value if one cannot be found.

=back

=cut

sub get_correspondent {
    # Get the parameters.
    my ($self, $fid1, $genome2) = @_;
    # Declare the return variable. If we don't find a correspondent, it will
    # remain undefined.
    my $retVal;
    # Get the ID of the source gene's genome.
    my $genome1 = genome_of($fid1);
    # Is it the same as the target genome?
    if ($genome1 eq $genome2) {
        # Yes, so simply return the input gene.
        $retVal = $fid1;
    } else {
    # No, we have to work for it. Look for a correspondence table.
        my $corrHash = $self->get_correspondence_map($genome1, $genome2);
        # Only continue if we found one.
        if (defined $corrHash) {
            # Get the corresponding gene from the hash.
            $retVal = $corrHash->{$fid1};
        }
    }
    # Return the result.
    return $retVal;
}

=head3 get_correspondence_map

    my $corrHash = $corrCache->get_correspondence_map($genome1, $genome2);

Return the hash mapping genes in the specified source genome
(I<$genome1>) to corresponding genes in the specified target genome
(I<$genome2>).

This method will actually build the correspondence in both directions at
the same time and cache the one that is not requested. If the desired
correspondence is already cached, it will be returned without preamble.
If the map is already full, it will be cleared before the new correspondences
are put in.

=over 4

=item genome1

Source genome for the correspondence map.

=item genome2

Target genome for the correspondence map.

=item RETURN

Returns a reference to a hash that maps genes in the source genome to corresponding genes
in the target genome, or C<undef> if no correspondence could be created. (This is commonly
because one of the genomes is incomplete.)

=back

=cut

sub get_correspondence_map {
    # Get the parameters.
    my ($self, $genome1, $genome2) = @_;
    # Check for a map already in the cache.
    my $mapKey = "$genome1/$genome2";
    my $retVal = $self->{map}{$mapKey};
    if (! defined $retVal) {
        # We need to create the map. Insure there's room.
        if ($self->{count} + 2 > MAX_MAPS) {
            Trace("Clearing correspondence cache.") if T(Corr => 2);
            $self->{map} = {};
            $self->{count} = 0;
        }
        Trace("Finding correspondence from $genome1 to $genome2.") if T(Corr => 3);
        # Compute the name of the converse map.
        my $converseKey = "$genome2/$genome1";
        # Get the correspondence data from the source to the target. We insist that both
        # directions be represented so we can cache the converse map at this time.
        my $corrList = ServerThing::GetCorrespondenceData($genome1, $genome2, 0, 1);
        # The maps will go in here.
        my (%map, %converse);
        # Loop through the correspondence data, building the maps.
        for my $listRow (@$corrList) {
            # Get the corresponding genes.
            my ($fid1, $fid2) = @$listRow;
            # Get the directional indicator.
            my $dir = $listRow->[8];
            # Update the maps.
            if ($dir ne '<-') {
                $map{$fid1} = $fid2;
            }
            if ($dir ne '->') {
                $converse{$fid2} = $fid1;
            }
        }
        # Store the maps in the cache.
        $self->{map}{$mapKey} = \%map;
        $self->{map}{$converseKey} = \%converse;
        # Update the map count.
        $self->{count} += 2;
        # Return the main map.
        $retVal = \%map;
    }
    # Return the result.
    return $retVal;
}


1;
