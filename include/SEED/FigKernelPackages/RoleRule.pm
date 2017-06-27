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

package RoleRule;

    use strict;
    use Tracer;
    use SeedUtils;

=head1 Role Rule

This object is the base class for role rules. Role rules take as input a hash
of functional assignments (here rather inaccurately referred to as I<roles>)
taken from a single protein family. If the roles appear similar, one will be
chosen as the normal form and recommended as the correct functional assignment
for the whole family.

The actual rules are all implemented as subclasses of this object. Every role
rule must implement the L</Check> method. The subclass also provides utilities
that multiple role rules may find useful.

This object contains the following fields.

=over 4

=item roleH

Hash of all the roles found in subsystems.

=item stats

L<Stats> object to which statistical information should be written when processing
roles.

=back

This object maintains as a static data structure a hash of all roles found in
subsystems. This static data structure can be used by all subclasses.

=cut

my $RoleH;

=head2 Special Methods

=head3 new

    my $rule = RoleRule->new($sap, $stats);

Create the base-class Role-Rule object. The resulting object can then be used to
examine role sets to see if one particular role should be chosen above all others
according to the rule defined by the subclass's L</Check> function.

=over 4

=item sap

L<Sapling> database object used to find the subsystem roles.

=item stats

L<Stats> object to be updated with statistics during processing of the rules.

=back

=cut

sub new {
    # Get the parameters.
    my ($class, $sap, $stats) = @_;
    # Check to see if we need to create the hash of roles found in subsystems.
    if (! defined $RoleH) {
        # Create the hash. Reading the Includes relationship (which connects roles
        # and subsystems) is the cheapest way to do this.
        my %roleH = map { $_ => 1 } $sap->GetFlat('Includes', "", [], 'to-link');
        $RoleH = \%roleH;
    }
    # Create the role-rule object.
    my $retVal = {
        roleH => $RoleH,
        stats => $stats
    };
    # Bless and return it.
    bless $retVal, $class;
    return $retVal;
}

=head2 Virtual Methods

=head3 Check

    my $roles = $rule->Check(\%roles);

This method takes as input a hash of roles mapped to features in a protein family.
It will return a list of the roles sorted with the preferred role first, or C<undef>
if this role rule does not apply.

=over 4

=item roles

Reference to a hash of roles found in a protein family, mapping each role to a
list of the IDs for the features in which it is contained.

=item RETURN

If all the roles should be normalized to a single functional assignment, returns a reference
to a list of the roles sorted from most preferred to least preferred; otherwise, returns
an undefined value.

=back

=cut

sub Check {
    # This is a pure virtual method.
    die "RoleRule subclass " . __PACKAGE__ . " did not implement Check function.\n";
}


=head2 Subclass Methods

=head3 Sort

    my $sortedRoles = RoleRule::Sort(\%roles);

Sort the roles in order from most common to least common.

=over 4

=item roles

Reference to a hash of roles found in a protein family, mapping each role to a
list of the IDs for the features in which it is contained.

=item RETURN

Returns a reference to a list of the roles, sorted in order from most common to
least common.

=back

=cut

sub Sort {
    # Get the parameters.
    my ($roles) = @_;
    # This is a hash whose values are all list references. If we dereference the lists,
    # it will convert them to list lengths in scalar context, which is the value on
    # which we want to sort. We negate the comparison function to get them sorted
    # from highest length to lowest length.
    my @retVal = sort { -(@{$roles->{$a}} <=> @{$roles->{$b}}) } keys %$roles;
    # Return the result.
    return \@retVal;
}

=head3 SubsysCheck

    my $roleList = $rule->SubsysCheck(\%roles);

If exactly one of the roles in the role hash is from a subsystem, return a
list of the roles with the subsystem-based role first and the others in
order from most common to least common.

The return value from this method is fairly arcane: it recognizes that we have
three separate conditions of interest-- no roles found in subsystems, one role
found in subsystems, and multiple roles found in subsystems.

=over 4

=item roles

Reference to a hash of roles found in a protein family, mapping each role to a
list of the IDs for the features in which it is contained.

=item RETURN

Returns a reference to a list of the roles in priority order if exactly one of them
is in a subsystem, or the number of roles in subsystems otherwise.

=back

=cut

sub SubsysCheck {
    # Get the parameters.
    my ($self, $roles) = @_;
    # Declare the list for the roles in subsystems.
    my @subRoles;
    # This list will contain the remaining roles.
    my @otherRoles;
    # Get the hash of subsystem-based roles.
    my $roleH = $self->{roleH};
    # Loop through the roles in the hash, checking for subsystem membership.
    for my $role (keys %$roles) {
        if ($roleH->{$role}) {
            push @subRoles, $role;
            $self->Add(roleInSubsystem => 1);
        } else {
            push @otherRoles, $role;
        }
    }
    # Declare the return variable. We default to the number of roles found in
    # subsystems.
    my $retVal = scalar @subRoles;
    # If exactly one role was found, we want to return a list reference containing
    # the roles in priority order.
    if ($retVal == 1) {
        # Put the subsystem-based role in the return list.
        $retVal = \@subRoles;
        # Sort the other roles from most common to least common and add them to the
        # end.
        push @$retVal, sort { -(@{$roles->{$a}} <=> @{$roles->{$b}}) } @otherRoles;
    }
    # Return the result.
    return $retVal;
}

=head3 Add

    $rule->Add($name => $value);

Add a value to a statistical count in the statistics object.

=over 4

=item name

Name of the statistic to update.

=item value

Value to add to the statistical counter.

=back

=cut

sub Add {
    # Get the parameters.
    my ($self, $name, $value) = @_;
    # Update the statistic.
    $self->{stats}->Add($name, $value);
}


=head3 ChooseBest

    my $sortedList = $rule->ChooseBest(\%roles);

This method is called when all of the functional assignments seem equally valid, but it is
believed they should be the same. It will apply various criteria to rank them from most
preferable to least preferable.

The basic algorithm is to sort the assignments from most common to least common and then
apply stable sorts to rank them according to other criteria. The order in which the
stable sorts are applied ranges from the least important to the most important, so that
criteria of increasing importance have a greater effect.

=over 4

=item roles

Reference to a hash of roles, mapping each role to a list of the features to which
the role has been assigned.

=item RETURN

Returns a reference to a list of the roles sorted from most preferable to least preferable.

=back

=cut

sub ChooseBest {
    # Get the parameters.
    my ($self, $roles) = @_;
    # Sort the roles from most common to least common.
    my $retVal = Sort($roles);
    # Push hypotheticals to the end.
    $retVal = SortForSureness($retVal);
    # Give preference to gene names.
    $retVal = SortForGenes($retVal);
    # Try to get transposase roles.
    $retVal = SortForTransposase($retVal);
    # Return the result.
    return $retVal;
}


=head2 Stable Sorts

These methods take a sorted list, divide it into two groups without changing the order
of the items in the group, and place the preferred group at the front. This kind of sort is
called I<stable> because it does not change the order of items that compare as equivalent.
The process of choosing the best function involves sorting the roles from most common to
least common and then applying these stable sorts in a particular order.

=head3 SortForGenes

    my $sortedRoles = RoleRule::SortForGenes(\@unsortedRoles);

Perform a stable sort of the roles in the incoming list that favors roles containing gene
names. A gene name is a four-letter word with capital letters on each lend and small letters
in the middle.

=over 4

=item unsortedRoles

Reference to a list of roles to be sorted.

=item RETURN

Returns a reference to a list of the same roles in which all the roles containing gene names
have been put first.

=back

=cut

sub SortForGenes {
    # Get the parameters.
    my ($unsortedRoles) = @_;
    # The two lists of roles will be put in here.
    my (@goodRoles, @otherRoles);
    # Loop through the incoming roles in order.
    for my $role (@$unsortedRoles) {
        # Does this role contain a gene?
        if ($role =~ /\b[A-Z][a-z]{2}[A-Z]\b/) {
            # Yes. Put it in the good list.
            push @goodRoles, $role;
        } else {
            # No. Put it in the other list.
            push @otherRoles, $role;
        }
    }
    # Return the two lists together.
    return [@goodRoles, @otherRoles];
}

=head3 SortForSureness

    my $sortedRoles = RoleRule::SortForSureness(\@unsortedRoles);

Perform a stable sort of the roles in the incoming list that favors role which are NOT
hypothetical (that is, roles that have I<more sureness>).

=over 4

=item unsortedRoles

Reference to a list of roles to be sorted.

=item RETURN

Returns a reference to a list of the same roles in which all the roles that are hypothetical
have been put at the end.

=back

=cut

sub SortForSureness {
    # Get the parameters.
    my ($unsortedRoles) = @_;
    # The two lists of roles will be put in here.
    my (@goodRoles, @otherRoles);
    # Loop through the incoming roles in order.
    for my $role (@$unsortedRoles) {
        # Is this role hypothetical?
        if (! SeedUtils::hypo($role)) {
            # No. Put it in the good list.
            push @goodRoles, $role;
        } else {
            # Yes. Put it in the other list.
            push @otherRoles, $role;
        }
    }
    # Return the two lists together.
    return [@goodRoles, @otherRoles];
}

=head3 SortForTransposase

    my $sortedRoles = RoleRule::SortForTransposase(\@unsortedRoles);

Perform a stable sort of the roles in the incoming list that favors the longest roles
which contain the word I<transposase>.

=over 4

=item unsortedRoles

Reference to a list of roles to be sorted.

=item RETURN

Returns a reference to a list of the same roles in which the longest roles containing
I<transposase> have been put at the front.

=back

=cut

sub SortForTransposase {
    # Get the parameters.
    my ($unsortedRoles) = @_;
    # This hash will contain the best transposase roles.
    my %transpoRoles;
    # This variable will contain the length of the role found.
    my $transpoLen = 0;
    for my $role1 (@$unsortedRoles) {
        if ($role1 =~ /transposase/i) {
            # Here we have a transposase role.
            my $newTranspoLen = length $role1;
            if ($newTranspoLen > $transpoLen) {
                # This is better than all the roles we have now, so make it the only one.
                %transpoRoles = ($role1 => 1);
                $transpoLen = $newTranspoLen;
            } elsif ($newTranspoLen == $transpoLen) {
                # This role matches the ones we have now, so keep it.
                $transpoRoles{$role1} = 1;
            }
        }
    }
    # The two lists of roles will be put in here.
    my (@goodRoles, @otherRoles);
    # Loop through the incoming roles in order.
    for my $role (@$unsortedRoles) {
        # Is this role one of the best transposases?
        if ($transpoRoles{$role}) {
            # No. Put it in the good list.
            push @goodRoles, $role;
        } else {
            # Yes. Put it in the other list.
            push @otherRoles, $role;
        }
    }
    # Return the two lists together.
    return [@goodRoles, @otherRoles];
}

1;