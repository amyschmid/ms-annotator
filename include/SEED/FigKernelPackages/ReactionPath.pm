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
package ReactionPath;

    use strict;

=head1 Reaction Path Descriptor

The reaction path descriptor is used to compute a reaction path through a set of
roles. The path-computation algorithm is a breadth-first graph search that will
work with potentially hundreds of simultaneous paths as it searches for the
best one.

The descriptor is a hash with the following fields.

=over 4

=item roleH

Reference to a hash of the desired roles. Each role maps to the number of
reactions in the path that belong to it.

=item path

Reference to a list that represents the current reaction path, in order.

=item missing

Count of the number of roles that do not yet have reactions in this path.

=back

=head2 Special Methods

=head3 new

    my $pathObject = ReactionPath->new($rxn1, \@foundRoles, \@missingRoles);

Construct a new path starting with a single reaction and specify the roles that
should be covered by the eventual path.

or

    my $pathObject = ReactionPath->new($oldPath);

Construct a new path formed by copying the old path.

=over 4

=item rxn1

ID of the first reaction in the path.

=item foundRoles

Reference to a list of the roles associated with the first reaction.

=item missingRoles

Reference to a list of the roles that are not yet represented in the reaction path.

=item oldPath

An existing L<ReactionPath> object to copy.

=back

=cut

sub new {
    # Get the parameters.
    my ($class, $rxn1, $foundRoles, $missingRoles) = @_;
    # Declare the component variables.
    my (%roleH, $missing, @path);
    # Determine the type of constructor. Is this a new path or a copy of an old one?
    if (ref $rxn1 eq 'ReactionPath') {
        # Here we're copying an existing path. Get the old role hash.
        my $oldRoleH = $rxn1->{roleH};
        # Create a copy of it.
        %roleH = map { $_ => $oldRoleH->{$_} } keys %$oldRoleH;
        # Copy the old path.
        push @path, @{$rxn1->{path}};
        # Copy the old missing-roles values.
        $missing = $rxn1->{missing};
    } else {
        # Create the role hash, primed with the missing roles.
        %roleH = map { $_ => 0 } @$missingRoles;
        # Add the found roles.
        for my $role (@$foundRoles) {
            $roleH{$role} = 1;
        }
        # Count the number of missing roles.
        $missing = scalar @$missingRoles;
        # Create the initial path.
        @path = $rxn1;
    }
    # Build the object and return it.
    my $retVal = bless {
        roleH => \%roleH,
        path => \@path,
        missing => $missing
                      }, $class;
    return $retVal;
}


=head2 Query Methods

=head3 length

    my $length = $pathObject->length();

Return the number of reactions in this path.

=cut

sub length {
    # Get the parameters.
    my ($self) = @_;
    # Return the result.
    return scalar @{$self->{path}};
}

=head3 missing

    my $missing = $pathObject->missing();

Return the number of unrepresented roles in this path.

=cut

sub missing {
    # Get the parameters.
    my ($self) = @_;
    # Return the result.
    return $self->{missing};
}

=head3 lastReaction

    my $rxn = $pathObject->lastReaction();

Return the last reaction in this path.

=cut

sub lastReaction {
    # Get the parameters.
    my ($self) = @_;
    # Extract the current reaction path.
    my $path = $self->{path};
    # Compute the last reaction in the path.
    my $last = scalar(@$path) - 1;
    my $retVal = $path->[$last];
    # Return the result.
    return $retVal;
}

=head3 path

    my @pathList = $pathObject->path();

Return the list of reactions in this path.

=cut

sub path {
    # Get the parameters.
    my ($self) = @_;
    # Return the path.
    return @{$self->{path}};
}


=head2 Update Methods

=head3 AddReaction

    my $newPath = $pathObject->AddReaction($rxn, \@roles);

Add the specified reaction to the path. Return a new path if it is added successfully, C<undef> if the
reaction is already present in the path.

=over 4

=item rxn

ID of the new reaction to add.

=item roles

Reference to a list of the roles represented by the new reaction.

=item RETURN

Returns a new reaction path object if successful, and C<undef> if the reaction is already in this path.

=back

=cut

sub AddReaction {
    # Get the parameters.
    my ($self, $rxn, $roles) = @_;
    # Assume that we've failed until we determine otherwise.
    my $retVal;
    # Get the reaction path.
    my $path = $self->{path};
    # Check to see if this reaction is already in the path.
    my $found = grep { $_ eq $rxn } @$path;
    # Only proceed if this reaction is new.
    if (! $found) {
        # Create the new reaction path.
        $retVal = ReactionPath->new($self);
        # Add the reaction to the path.
        push @{$retVal->{path}}, $rxn;
        # Update the role counts.
        my $roleH = $retVal->{roleH};
        for my $role (@$roles) {
            # Only proceed if the role is one we care about.
            if (exists $roleH->{$role}) {
                # If this is the first time the role has been found, decrease the missing-role
                # count.
                if (! $roleH->{$role}) {
                    $retVal->{missing}--;
                }
                # Update the role count.
                $roleH->{$role}++;
            }
        }
    }
    # Return the result.
    return $retVal;
}

1;