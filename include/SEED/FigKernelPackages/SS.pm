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
package SS;

    use strict;
    use ERDB;
    use Tracer;
    use SeedUtils;
    use ServerThing;

=head1 Subsystem Server Function Object

This file contains the functions and utilities used by the Subsystem Server
(B<subsystem_server_sapling.cgi>). The L</Primary Methods> represent function
calls direct to the server. These all have a signature similar to the following.

    my $document = $ssObject->function_name($args);

where C<$ssObject> is an object created by this module, 
C<$args> is a parameter structure, and C<function_name> is the Subsystem
Server function name. The output is a structure, generally a hash reference, but
sometimes a string or a list reference.

All methods will take a hash reference as the parameter structure. In the
documentation, this will be depicted somewhat like this

    my $document = $ssObject->pegs_in_subsystems({
                        -subsystems => [$subsystemID,...],
                        -genomes => [$genomeID,...]
    });

This indicates that there are two hash keys permitted, the first mapped to a list of
subsystem IDs, and the second to a list of genome IDs.

=head2 Special Methods

=head3 new

    my $ssObject = SSserver->new();

Create a new Subsystem Server function object. The server function object
contains a pointer to a L<Sapling> object, and is used to invoke the
server functions.

=cut

#
# Actually, if you are using SS.pm, you should do SS->new(), not SSserver->new()
# That comment above is for the benefit of the pod doc stuff on how to use SSserver 
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

    my $methodList =        $ssObject->methods();

Return a list of the methods allowed on this object.

=cut

use constant METHODS => [qw(all_subsystems
                            classification_of
                            is_in_subsystem
                            is_in_subsystem_with
                            metabolic_reconstruction
                            pegs_implementing_roles
                            pegs_in_subsystems
                            subsystem_spreadsheet
                        )];

sub methods {
    # Get the parameters.
    my ($self) = @_;
    # Return the result.
    return METHODS;
}

=head3 is_in_subsystem

    my $featureHash =       $ssObject->is_in_subsystem({
                                -ids => [$fid1, $fid2, ...],
                                -unusable => 1
                            });

Return the subsystem and role for each specified feature.

=over 4

=item parameter

The parameter should be a reference to a hash with the following keys.

=over 8

=item -ids

Reference to a list of the FIG feature IDs for the features of interest.

=item -unusable

If TRUE, then results from unusable subsystems will be included. The default
is FALSE, which means only usable subsystems will show up in the results.

=back

For backward compatibility, the parameter may also be a reference to a list
of FIG feature IDs.

=item RETURN

In normal mode, returns a reference to a hash that maps each incoming feature ID
to a list of 2-tuples, each 2-tuple consisting of (0) the ID of a subsystem containing
the feature and (1) the feature's role in that subsystem.

In backward-compatible mode, returns a reference to a list of 3-tuples, each
3-tuple consisting of (0) a subsystem ID, (1) a role ID, and (2) the ID of a
feature from the input list.

=back

=cut

sub is_in_subsystem {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the sapling database.
    my $sapling = $self->{db};
    # This will be set to TRUE if we are in backward-compatible mode.
    my $backwardMode = 0;
    # Convert a list to a hash.
    if (ref $args ne 'HASH') {
        $args = { -ids => $args };
        $backwardMode = 1;
    }
    # Create the filter clause. It contains at least a feature filter.
    my $filter = 'Feature(id) = ?';
    # Unless unusable subsystems are allowed, we restrict to usable ones.
    if (! $args->{-unusable}) {
        $filter .= ' AND Subsystem(usable) = 1';
    }
    # Declare the return variable.
    my $retVal = {};
    # Get the fig IDs from the parameters.
    my $ids = ServerThing::GetIdList(-ids => $args);
    foreach my $fid (@$ids) {
        my @resultRows = $sapling->GetAll("Feature IsContainedIn MachineRole HasRole Role AND " .
                                          "MachineRole IsRoleFor MolecularMachine Implements Variant IsDescribedBy Subsystem", 
                                          $filter, [$fid], [qw(Subsystem(id) Role(id))]);
        $retVal->{$fid} = \@resultRows;
    }
    # If we're in backward-compatible mode, convert the return value to a list.
    if ($backwardMode) {
        my @list;
        for my $fid (@$ids) {
            push @list, map { [@$_, $fid] } @{$retVal->{$fid}};
        }
        $retVal = \@list;
    }
    # Return the result.
    return $retVal;
}

=head3 is_in_subsystem_with

    my $featureHash =       $ssObject->is_in_subsystem_with({
                                -ids => [$fid1, $fid2, ...],
                                -unusable => 1
                            });

For each incoming feature, returns a list of the features in the same genome that
are part of the same subsystem. For each other feature returned, its role,
functional assignment, subsystem variant, and subsystem ID will be returned as
well.

=over 4

=item parameter

The parameter should be a reference to a hash with the following keys.

=over 8

=item -ids

Reference to a list of the FIG feature IDs for the features of interest.

=item -unusable

If TRUE, then results from unusable subsystems will be included. The default
is FALSE, which means only usable subsystems will show up in the results.

=back

For backward compatibility, the parameter may also be a reference to a list
of FIG feature IDs.

=item RETURN

Returns a reference to a hash that maps each incoming feature ID to a list
of 5-tuples relating to features in the same subsystem. Each 5-tuple contains
(0) a subsystem ID, (1) a variant ID, (2) the related feature ID, (3) the
related feature's functional assignment, and (4) the related feature's role
in the subsystem.

In backward-compatibility mode, returns a reference to a list of lists. Each
sub-list contains 6-tuples relating to a single incoming feature ID. Each
6-tuple consists of a subsystem ID, a variant ID, the incoming feature ID, the
other feature ID, the other feature's functional assignment, and the other
feature's role in the subsystem.

=back

=cut

sub is_in_subsystem_with {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the sapling database.
    my $sapling = $self->{db};
    # Declare the return variable.
    my $retVal;
    # This will be set to TRUE if we are in backward-compatible mode.
    my $backwardMode = 0;
    # Convert a list to a hash.
    if (ref $args ne 'HASH') {
        $args = { -ids => $args };
        $backwardMode = 1;
    }
    # Create the filter clause. It contains at least a feature filter.
    my $filter = 'Feature(id) = ?';
    # Unless unusable subsystems are allowed, we restrict to usable ones.
    if (! $args->{-unusable}) {
        $filter .= ' AND Subsystem(usable) = 1';
    }
    # Get the fig IDs from the parameters.
    my $ids = ServerThing::GetIdList(-ids => $args);
    foreach my $fid (@$ids) {
        my @resultRows = $sapling->GetAll("Feature IsContainedIn MachineRole IsRoleFor MolecularMachine Implements Variant IsDescribedBy Subsystem AND MolecularMachine IsMachineOf MachineRole2 Contains Feature2 AND MachineRole2 HasRole Role", 
                                          $filter, [$fid],
                                          [qw(Subsystem(id) Variant(code)
                                              Feature2(id) Feature2(function)
                                              Role(id))]);
        $retVal->{$fid} = \@resultRows;
    }
    # If this is backward-compatability mode, convert the result to a list.
    if ($backwardMode) {
        my @outList;
        for my $fid (@$ids) {
            my $fidList = $retVal->{$fid};
            if (! defined $fidList) {
                push @outList, [];
            } else {
                # Because the incoming feature ID is no longer available as the
                # hash key, we need to put it back into the output tuples. It goes
                # in the third position (offset 2).
                for my $fidTuple (@$fidList) {
                    splice @$fidTuple, 2, 0, $fid;
                }
                push @outList, $fidList;
            }
        }
        $retVal = \@outList;
    }
    # Return the result.
    return $retVal;
}

=head3 all_subsystems

    my $dsubsystemHash =    $ssObject->all_subsystems({
                                -unusable => 1,
                                -exclude => [$type1, $type2, ...],
                            });

Return a list of all subsystems in the system. For each subsystem, this
method will return the ID, curator, the classifications, and roles.

=over 4

=item parameter

The parameter should be a reference to a hash with the following possible
keys, all of which are optional. Because all of the keys are optional,
it is permissible to pass an empty hash or no parameters at all.

=over 8

=item -unusable (optional)

TRUE if unusable subsystems should be included, else FALSE. The default is
FALSE.

=item -exclude (optional)

Reference to a list of special subsystem types that should be excluded from the
result list. The permissible types are C<cluster-based>, C<experimental>, and
C<private>. Normally cluster-based subsystems are included, but experimental and
private subsystems are only included if the C<-unusable> option is turned on.

=back

=item RETURN

Returns a hash mapping each subsystem ID to a 3-tuple consisting of (0) the name of the
curator, (1) a reference to a list of the subsystem classifications, and (2) a reference
to a list of the subsystem's roles.

=back

=cut

sub all_subsystems {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the spaling database.
    my $sapling = $self->{db};
    # Declare the return variable.
    my $retVal = {};
    # Compute the filter based on the parameters.
    my $filter = "";
    ServerThing::AddSubsystemFilter(\$filter, $args);
    # Create a hash for walking up the subsystem class hierarchy.
    my %classMap = map { $_->[0] => $_->[1] } $sapling->GetAll("IsSubclassOf",
                                                               "", [],
                                                               [qw(from-link to-link)]);
    # Read the subsystem role data from the database.
    my @roleData = $sapling->GetAll("Subsystem Includes Role AND Subsystem IsInClass SubsystemClass",
                                    $filter, [], 
                                    [qw(Subsystem(id) Subsystem(curator) 
                                        SubsystemClass(id) Role(id))]);
    # Loop through the subsystems, building the result hash.
    for my $roleDatum (@roleData) {
        my ($subsystem, $curator, $class, $role) = @$roleDatum;
        # Is this subsystem new?
        if (! exists $retVal->{$subsystem}) {
            # Yes. Get its classification data. We trace the classifications from
            # the bottom up, so new ones are shifted onto the front.
            my @classes;
            while ($class) {
                unshift @classes, $class;
                $class = $classMap{$class};
            }
            # Create its hash entry.
            $retVal->{$subsystem} = [$curator, \@classes, []];
        }
        # Now we know an entry exists for this subsystem. Push this role onto it.
        push @{$retVal->{$subsystem}[2]}, $role;
    }
    # Return the result.
    return $retVal;
}

=head3 classification_of

    my $subsystemHash =     $ssObject->classification_of({
                                -ids => [$sub1, $sub2, ...]
                            });

Return the classification for each specified subsystem.

=over 4

=item parameter

Reference to a hash of parameters with the following possible keys.

=over 8

=item -ids

Reference to a list of subsystem IDs.

=back

=item RETURN

Returns a hash mapping each incoming subsystem ID to a list reference. Each
list contains the classification names in order from the largest classification to
the most detailed.

=cut

sub classification_of {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the sapling database.
    my $sap = $self->{db};
    # Declare the return variable.
    my $retVal = {};
    # Get the list of subsystem IDs.
    my $ids = ServerThing::GetIdList(-ids => $args);
    # Loop through the subsystem IDs, getting the classification data.
    for my $id (@$ids) {
        # We'll build the classification list in here.
        my @classes;
        # Get the low-level class.
        my ($class) = $sap->GetFlat("Subsystem IsInClass SubsystemClass",
                                    "Subsystem(id) = ?", [$id], 'SubsystemClass(id)');
        # Loop through the remaining classes. Note that since we're moving up
        # the hierarchy, new classes are added at the beginning.
        while (defined $class) {
            unshift @classes, $class;
            ($class) = $sap->GetFlat("SubsystemClass IsSubclassOf SubsystemClass2",
                                     "SubsystemClass(id) = ?", [$class],
                                     'SubsystemClass2(id)');
        }
        # Store this classification.
        $retVal->{$id} = \@classes;
    }
    # Return the result.
    return $retVal;
}

=head3 subsystem_spreadsheet

    my $subsystemHash =     $ssObject->subsystem_spreadsheet({
                                -ids => [$sub1, $sub2, ...]
                            });

This method takes a list of subsystem IDs, and for each one returns a
list of the features in the subsystem. For each feature, it will include
the feature's functional assignment, the subsystem name and variant
(spreadsheet row), and its role (spreadsheet column).

=over 4

=item parameter

Reference to a hash of parameters with the following possible keys.

=over 8

=item -ids

Reference to a list of subsystem IDs.

=back

For backward compatibility, this method can also accept a reference to a list of
subsystem IDs.

=item RETURN

Returns a hash mapping each incoming subsystem ID to a list of 4-tuples. Each
tuple contains (0) a variant ID, (1) a feature ID, (2) the feature's functional
assignment, and (3) the feature's role in the subsystem.

In backward-compatability mode, returns a list of 5-tuples. Each tuple contains
(0) a subsystem ID, (1) a variant ID, (2) a feature ID, (3) the feature's
functional assignment, and (4) the feature's role in the subsystem.

=back

=cut

sub subsystem_spreadsheet {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the sapling database.
    my $sapling = $self->{db};
    # Declare the return variable.
    my $retVal;
    # Check for the backward-compatible mode.
    my $backwardMode = 0;
    if (ref $args ne 'HASH') {
        $args = { -ids => $args };
        $backwardMode = 1;
    }
    # Get the list of subsystem IDs.
    my $ids = ServerThing::GetIdList(-ids => $args);
    # Loop through the subsystem IDs.
    foreach my $subsysName (@$ids) {
        # Normalize the subsystem ID.
        my $subsysID = $sapling->SubsystemID($subsysName);
        # Get the subsystem's spreadsheet data.
        my @resultRows = $sapling->GetAll("Subsystem Describes Variant IsImplementedBy MolecularMachine IsMachineOf MachineRole Contains Feature AND MachineRole HasRole Role Includes Subsystem", 
                                          'Subsystem(id) = ? ORDER BY Variant(id), Includes(sequence)', 
                                          [$subsysID], [qw(Variant(id)
                                                           Feature(id)
                                                           Feature(function)
                                                           Role(id))]);
        $retVal->{$subsysName} = \@resultRows;
    }
    # In backward-compatible mode, convert the hash to a list.
    if ($backwardMode) {
        # We'll build the list in here.
        my @listForm;
        for my $subsysName (@$ids) {
            # Get this subsystem's spreadsheet and paste in the subsystem ID.
            my $spreadsheet = $retVal->{$subsysName};
            for my $row (@$spreadsheet) {
                unshift @$row, $subsysName;
            }
            # Put it into the output.
            push @listForm, @$spreadsheet;
        }
        # Return the list.
        $retVal = \@listForm;
    }
    # Return the result.
    return $retVal;
}

=head3 pegs_in_subsystems

    my $subsystemHash =     $ssObject->pegs_in_subsystems({
                                -genomes => [$genome1, $genome2, ...],
                                -subsystems => [$sub1, $sub2, ...]
                            });

This method takes a list of genomes and a list of subsystems and returns
a list of the roles represented in each genome/subsystem pair.

=over 4

=item parameter

Reference to a hash of parameter values with the following possible keys.

=over 8

=item -genomes

Reference to a list of genome IDs.

=item -subsystems

Reference to a list of subsystem IDs.

=back

For backward compatibility, the parameter may also be a reference to a 2-tuple,
the first element of which is a list of genome IDs and the second of which is a
list of subsystem IDs.

=item RETURN

Returns a reference to a hash of hashes. The main hash is keyed by subsystem ID.
Each subsystem's hash is keyed by role ID and maps the role to a list of
the feature IDs for that role in the subsystem that belong to the specified
genomes.

In backward-compatibility mode, returns a list of 2-tuples. Each tuple consists
of a subsystem ID and a second 2-tuple that contains a role ID and a reference
to a list of the feature IDs for that role that belong to the specified genomes.

=back

=cut

sub pegs_in_subsystems {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the sapling database.
    my $sapling = $self->{db};
    # Get access to the sapling subsystem object.
    require SaplingSubsys;
    # Declare the return variable.
    my $retVal = {};
    # Check for backward-compatibility mode.
    my $backwardMode = 0;
    if (ref $args ne 'HASH') {
        $args = { -genomes => $args->[0], -subsystems => $args->[1] };
        $backwardMode = 1;
    }
    # Get the list of genome IDs.
    my $genomes = ServerThing::GetIdList(-genomes => $args);
    # Get the list of subsystem IDs.
    my $subs = ServerThing::GetIdList(-subsystems => $args);
    # Loop through the subsystems.
    for my $sub (@{$subs}) {
        # Normalize the subsystem ID.
        my $subID = $sapling->SubsystemID($sub);
        # Get the subsystem spreadsheet in memory.
        my $ss = SaplingSubsys->new($subID, $sapling);
        # Only proceed if we found it.
        if (defined $ss) {
            # We'll build the subsystem's hash in here.
            my $subHash = {};
            # Loop through the genomes, assigning features to the roles.
            foreach my $g (@{$genomes}) {
                # Get role/featureList pairs for this genome.
                my @roleTuples = $ss->get_roles_for_genome($g, 1);
                # Loop through the pairs.
                foreach my $roleTuple (@roleTuples) {
                    # Extract the role ID and the feature list.
                    my ($role, $features) = @$roleTuple;
                    # Attach the features to the role.
                    push @{$subHash->{$role}}, @$features;
                }
            }
            # Attach this hash to this subsystem.
            $retVal->{$sub} = $subHash;
        }
    }
    # In backward-compatible mode, we have to conver the hashes to lists.
    if ($backwardMode) {
        # We'll build the output list in here.
        my @outList;
        # Loop through the subsystems in input order.
        for my $ss (@$subs) {
            my $subHash = $retVal->{$ss};
            if (defined $subHash) {
                # Now we convert the role -> feature map to a list of
                # [sub, [role, feature]] nested pairs.
                for my $role (keys %$subHash) {
                    push @outList, [$ss, [$role, $subHash->{$role}]];
                }
            }
        }
        # Store the output list as the result.
        $retVal = \@outList;
    }
    # Return the result.
    return $retVal;
}

# Synonym for "pegs_in_subsystems" provided for backward compatibility.
sub pegs_in_subsystem {
    return pegs_in_subsystems(@_);
}

=head3 pegs_implementing_roles

    my $document = $ssObject->pegs_implementing_roles($args);

Given a subsystem and a list of roles, return a list of the subsystem's
features for each role.

=over 4

=item args

Reference to either (1) a hash that maps C<-subsystem> to a subsystem ID and
C<-roles> to a list of roles or (2) a 2-tuple containing a subsystem ID followed
by a reference to a list of roles in that subsystem.

=item RETURN

Returns a list of 2-tuples. Each tuple consists of a role and a reference to a
list of the features in that role.

=back

=cut

sub pegs_implementing_roles {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the sapling database.
    my $sapling = $self->{db};
    # Get the sapling subsystem object.
    require SaplingSubsys;
    # Declare the return variable.
    my $retVal;
    # Convert a list to a hash.
    if (ref $args ne 'HASH') {
        $args = { -subsystem => $args->[0], -roles => $args->[1] };
    }
    # Get the subsystem ID.
    my $subsystem = $args->{-subsystem};
    # If there is no subsystem ID, it's an error.
    if (! defined $subsystem) {
        Confess("Subsystem ID not specified.");
    } else {
        # Normalize the subsystem ID.
        my $subsystemID = $sapling->SubsystemID($subsystem);
        # Get the list of roles.
        my $roles = ServerThing::GetIdList(-roles => $args);
        my $ss = SaplingSubsys->new($subsystemID, $sapling);
        foreach my $role (@$roles) {
            my @pegs = $ss->pegs_for_role($role);
            push (@$retVal, [$role, \@pegs]); 
        }
    }
    # Return the result.
    return $retVal;
}


=head3 metabolic_reconstruction

    my $document = $ssObject->metabolic_reconstruction($args);

This method will find for each subsystem, the subsystem variant that contains a
maximal subset of the roles in an incoming list, and output the ID of the
variant and a list of the roles in it.

=over 4

=item args

Reference to (1) a list of role descriptors or (2) a hash mapping the key C<-roles>
to a list of role descriptors. A role descriptor is a 2-tuple consisting of the
role ID followed by an arbitrary ID of the caller's choosing.

=item RETURN

Returns a list of tuples, each containing a variant ID, a role ID, and optionally a
caller-provided ID for the role.

=back

=cut

sub metabolic_reconstruction {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the sapling database.
    my $sapling = $self->{db};
    # Declare the return variable.
    my $retVal = [];
    # Convert a list to a hash.
    if (ref $args ne 'HASH') {
        $args = { -roles => $args };
    }
    # This counter will be used to generate user IDs for roles without them.
    my $next = 1000;
    # Get the list of roles.
    my $id_roles = ServerThing::GetIdList(-roles => $args);
    my @id_roles1 = map { (ref $_ ? $_ : [$_, "FR" . ++$next]) } @$id_roles;

    my @id_roles = ();
    foreach my $tuple (@id_roles1)
    {
	my($function,$id) = @$tuple;
	foreach my $role (split(/(; )|( [\]\@] )/,$function))
	{
	    push(@id_roles,[$role,$id]);
	}
    }

    my %big;
    my $id_display = 1;
    map {push(@{$big{$_->[0]}}, $_->[1])} @id_roles;
    my @resultRows = $sapling->GetAll("Subsystem Includes Role", 
                            'ORDER BY Subsystem(id), Includes(sequence)', [], 
                            [qw(Subsystem(id) Role(id) Includes(abbreviation))]);
    my %ss_roles;
    foreach my $row (@resultRows) {
        my ($sub, $role, $abbr) = @$row;
        $ss_roles{$sub}->{$role} = $abbr;
    }
    foreach my $sub (keys %ss_roles) {
        my $roles = $ss_roles{$sub};

        my @abbr = map{$roles->{$_}} grep { $big{$_}} keys %$roles;
        my $set =  join(" ",  @abbr);
        if (@abbr > 0) {
            my ($variant, $size) = $self->get_max_subset($sub, $set);
            if ($variant) {
                foreach my $role (keys %$roles) {
                    if ($id_display) {
                        foreach my $id (@{$big{$role}}) {
                            push (@$retVal, [$variant, $role, $id]);
                        }
                    } else {
                        push (@$retVal, [$variant, $role]);
                    }
                }
            }
        }
    }
    # Return the result.
    return $retVal;
}

=head2 Internal Utility Methods

=head3 get_max_subset

    my ($max_variant, $max_size) = $ssObject->get_max_subset($sub, $setA);

Given a subsystem ID and a role rule, return the ID of the variant for
the subsystem that matches the most roles in the rule and the number of
roles matched.

=over 4

=item sub

Name (ID) of the subsystem whose variants are to be examined.

=item setA

A space-delimited list of role abbreviations, lexically ordered. This provides
a unique specification of the roles in the set.

=item RETURN

Returns a 2-element list consisting of the ID of the variant found and the number
of roles matched.

=back

=cut

sub get_max_subset {
    my ($self, $sub, $setA) = @_;
    my $sapling = $self->{db};
    my $max_size = 0;
    my $max_set;
    my $max_variant;
    my %set_hash;
    my $qh = $sapling->Get("Subsystem Describes Variant", 'Subsystem(id) = ? AND Variant(type) = ?', [$sub, 'normal']);
    while (my $resultRow = $qh->Fetch()) {
        my @variantRoleRule = $resultRow->Value('Variant(role-rule)');
        my ($variantCode) = $resultRow->Value('Variant(code)');
        my $variantId = $sub.":".$variantCode;
        foreach my $setB (@variantRoleRule) {
                    my $size = is_A_a_superset_of_B($setA, $setB);
                    if ($size  && $size > $max_size) {
                            $max_size = $size;
                            $max_set = $setB;
                            $max_variant = $variantId;
                    }
        }
    }
    #if ($max_size) {
            #print STDERR "Success $max_variant, $max_set\n";
    #}
    return($max_variant, $max_size);
}


=head3 is_A_a_superset_of_B

    my $size = SS::is_A_a_superset_of_B($a, $b);

This method takes as input two role rules, and returns 0 if the first
role rule is NOT a superset of the second; otherwise, it returns the size
of the second rule. A role rule is a space-delimited list of role
abbreviations in lexical order. This provides a unique identifier for a
set of roles in a subsystem.

=over 4

=item a

First role rule.

=item b

Second role rule.

=item RETURN

Returns 0 if the first rule is NOT a superset of the second and the size of the
second rule if it is. As a result, if the first rule IS a superset, this method
will evaluate to TRUE, and to FALSE otherwise.

=back

=cut

sub is_A_a_superset_of_B {
    my ($a, $b) = @_;
    my @a = split(" ", $a);
    my @b = split(" ", $b);
    if (@b > @a) {
            return(0);
    }
    my %given;
    map { $given{$_} = 1} @a;
    map { if (! $given{$_}) {return 0}} split(" ", $b);
    my $l = scalar(@b);
    return scalar(@b);
}


1;
