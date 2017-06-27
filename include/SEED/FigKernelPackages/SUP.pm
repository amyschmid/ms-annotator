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
package SUP;

    use strict;
    use ERDB;
    use Tracer;
    use SeedUtils;
    use ServerThing;

=head1 Sapling Update Server Function Object

This file contains the functions and utilities used by the Sapling Update Server
(B<sup_server.cgi>). The various methods listed in the sections below represent
function calls direct to the server. These all have a signature similar to the
following.

    my $results = $supObject->function_name($args);

where C<$supObject> is an object created by this module,
C<$args> is a parameter structure, and C<function_name> is the Sapling
Server function name. The output $results is a scalar, generally a success
indication of some type.

=head2 Constructor

Use

    my $supObject = SUPserver->new();

to create a new sapling server function object. The server function object
is used to invoke the L</Primary Methods> listed below. See L<SUPserver> for
more information on how to create this object and the options available.

=cut

#
# Actually, if you are using SUP.pm, you should do SUP->new(), not SUPserver->new()
# That comment above is for the benefit of the pod doc stuff on how to use SAPserver
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

=head3 methods

    my $methodList =        $supObject->methods();

Return a reference to a list of the methods allowed on this object.

=cut

use constant METHODS => [qw(
                         insert_objects
                         update_entity
                         delete
                         disconnect
                        )];

sub methods {
    # Get the parameters.
    my ($self) = @_;
    # Return the result.
    return METHODS;
}

=head1 Primary Methods

=head2 General Updates

=head3 insert_objects

    my $successFlag =   $supObjects->insert_objects({
                            -type => $objectType,
                            -maps => [
                                { $fld1a => $value1a, $fld1b => $value1b, ... },
                                { $fld2a => $value2a, $fld2b => $value2b, ... },
                                ...
                            ]
                        });

Insert one or more objects of a specific entity or relationship type into the database.

=over 4

=item parameter

The parameter should be a reference to a hash with the following keys.

=over 8

=item -type

The entity or relationship type for the objects to be inserted.

=item -maps

Reference to a list of hashes. Each hash maps field names to values for a single object
to be inserted.

=back

=item RETURN

Returns the number of objects successfully inserted.

=back

=cut

sub insert_objects {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the Sapling database.
    my $sap = $self->{db};
    # Get the object type.
    my $type = $args->{-type};
    # Get the list of hash maps.
    my $mapList = ServerThing::GetIdList(-maps => $args);
    # We'll count the inserts in here.
    my $retVal = 0;
    # Loop through the maps, inserting.
    for my $map (@$mapList) {
        # Insert the record for this map.
        $sap->InsertObject($type, %$map);
        # Count it.
        $retVal++;
    }
    # Return the insertion count.
    return $retVal;
}


=head3 update_entity

    my $successFlag =   $supObjects->update_entity({
                            -type => $entityType,
                            -updates => {
                                $id1 => { $fld1a => $value1a, $fld1b => $value1b, ... },
                                $id2 => { $fld2a => $value2a, $fld2b => $value2b, ... },
                                ...
                            ]
                        });

Update one or more objects of a specific entity type.

=over 4

=item parameter

The parameter should be a reference to a hash with the following keys.

=over 8

=item -type

The entity type for the objects to be updated.

=item -maps

Reference to a hash of hashes. The main hash Each hash maps field names to values for a single object
to be inserted.

=back

=item RETURN

Returns the number of objects successfully inserted.

=back

=cut

sub update_entity {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the Sapling database.
    my $sap = $self->{db};
    # Get the object type.
    my $type = $args->{-type};
    # Get the list of hash maps.
    my $mapHash = $args->{-updates};
    Confess("Invalid hash map passed to update_entity.") if ref $mapHash ne 'HASH';
    # We'll count the updates in here.
    my $retVal = 0;
    # Loop through the maps, inserting.
    for my $id (keys %$mapHash) {
        # Update the record for this map.
        $sap->UpdateEntity($type, $id, %{$mapHash->{$id}});
        # Count it.
        $retVal++;
    }
    # Return the insertion count.
    return $retVal;
}


=head3 delete

    my $successFlag =   $supObjects->delete({
                            -type => $entityType,
                            -ids => [$id1, $id2, ...]
                        });

Delete one or more entities and their dependent records.

=over 4

=item parameter

The parameter should be a reference to a hash with the following keys.

=over 8

=item -type

The entity type for the objects to be deleted.

=item -ids

Reference to a list of the IDs for the objects to delete.

=back

=item RETURN

Returns the number of successful deletions.

=back

=cut

sub delete {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the Sapling database.
    my $sap = $self->{db};
    # Get the object type.
    my $type = $args->{-type};
    # Get the list of hash maps.
    my $ids = ServerThing::GetIdList(-ids => $args);
    # We'll count the deletes in here.
    my $retVal = 0;
    # Loop through the ids, deleting.
    for my $id (@$ids) {
        # Delete this record.
        $sap->Delete($type, $id);
        # Count it.
        $retVal++;
    }
    # Return the insertion count.
    return $retVal;
}


=head3 disconnect

    my $successFlag =   $supObjects->disconnect({
                            -type => $relationshipType,
                            -pairs => [[$from1, $to1], [$from2, $to2], ...]
                        });

Disconnect one or more relationships.

=over 4

=item parameter

The parameter should be a reference to a hash with the following keys.

=over 8

=item -type

The entity type for the objects to be deleted.

=item -pairs

Reference to a list of ID pairs. Each contains a from-link and a to-link for a relationship
to disconnect.

=back

=item RETURN

Returns the number of successful disconnects.

=back

=cut

sub disconnect {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the Sapling database.
    my $sap = $self->{db};
    # Get the object type.
    my $type = $args->{-type};
    # Get the list of ID pairs.
    my $ids = $args->{-pairs};
    Confess("Invalid ID pair list for disconnect.") if ref $ids ne 'ARRAY';
    # We'll count the disconnects in here.
    my $retVal = 0;
    # Loop through the ids, deleting.
    for my $pair (@$ids) {
        # Delete this record.
        my ($from, $to) = @$pair;
        $sap->DeleteRow($type, $from, $to);
        # Count it.
        $retVal++;
    }
    # Return the insertion count.
    return $retVal;
}


1;
