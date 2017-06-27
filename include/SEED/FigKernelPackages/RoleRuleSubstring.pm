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

package RoleRuleSubstring;

    use strict;
    use Tracer;
    use base qw(RoleRule);

=head1 Role Rule: Substring

This object implements one of several role rules used by L<analyze_loose_sets.pl>. If
one role is a substring of all the others (case-insensitive), then the roles
are considered essentially the same and a correct role can be chosen to which
the others should be normalized.

The basic procedure for choosing the correct role is as follows:

=over 4

=item 1

If one of the roles occurs in a subsystem, it gets highest preference. If more
than one role occurs in the subsystem, then the entire operation fails and
no correct role can be chosen.

=item 2

If one of the roles is I<hypothetical protein>, it gets lowest preference.

=item 3

If one of the roles has a gene ID ([A-Z][a-z]{2}[A-Z]), it gets higher preference.

=item 4

The longest role string containing C<transposase> gets a higher preference.

=item 5

Otherwise, the most common role gets a higher preference.

=back


=head2 Special Methods

=head3 new

    my $rule = RoleRuleSubstring->new($sap, $stats);

Create the Substring Role-Rule object. The resulting object can then be used to
examine role sets to see if one particular role should be chosen above all others.

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
    # Create the sub-object. We have no extra fields.
    return RoleRule::new($class, $sap, $stats);
}

=head2 Public Methods

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
    # Get the parameters.
    my ($self, $roles) = @_;
    # Declare the return variable. We assume that the rule will fail to apply.
    # If it does apply, a reference to the return list will be stored in here.
    my $retVal;
    # Sort the roles from shortest to longest and fold them to lower-case.
    my @rolesL = map { lc $_ } sort { length($a) <=> length($b) } keys %$roles;
    # Get the shortest role.
    my $shortestRole = $rolesL[0];
    # Loop through the other roles to see if this one is a substring of all the
    # others.
    my $match = 1;
    for (my $i = 1; $i <= $#rolesL && $match; $i++) {
        if (index($rolesL[$i], $shortestRole) < 0) {
            $match = 0;
        }
    }
    # Do we have a match?
    if ($match) {
        $self->Add(substringMatchRule => 1);
        # Yes. Check for subsystem-based roles.
        my $subRoleList = $self->SubsysCheck($roles);
        # Check the number of subsystem members found.
        if (ref $subRoleList eq 'ARRAY') {
            # Exactly one was found, so we select it.
            $retVal = $subRoleList;
            $self->Add(subsysRoleSelected => 1);
        } elsif ($subRoleList > 1) {
            # More than one means this is a guaranteed manual curation.
            $self->Add(multiSubsysRoles => 1);
        } else {
            # Here no subsystem-based roles are in the list, so we need to check
            # other criteria. There's a standard set of rules in the base class
            # that we'll invoke here.
            $retVal = $self->ChooseBest($roles);
        }
    }
    # Return the result.
    return $retVal;
}

1;