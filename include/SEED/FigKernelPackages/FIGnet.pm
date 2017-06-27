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

package FIGnet;

use Carp;
use Data::Dumper;

use strict;
use FIG;

sub new {
    my($class,$url) = @_;

    if (! $url)
    {
	my $fig = new FIG;
	bless {
	    _fig  => $fig,
	}, $class;
    }
    else
    {
	bless { _url => $url }, $class;
    }
}

sub DESTROY {
    my($self) = @_;
    my($fig);

    if ($fig = $self->{_fig})
    {
	$fig->DESTROY;
    }
}

=pod

=head1 set_remote

usage: $fig->set_remote($url)

Sets the remote version of FIG to the one given by $url.

=cut

sub set_remote_FIG {
    my($self,$url) = @_;

    $self->{_url} = $url;
}


=pod

=head1 current_FIG

usage: $url = $fig->current_FIG

Returns the URL of the current FIG ("" for a local copy).

=cut

sub current_FIG {
    my($self) = @_;

    return $self->{_url} ? $self->{_url} : "";
}


=pod

=head1 genomes

usage: @genome_ids = $fig->genomes;

Genomes are assigned ids of the form X.Y where X is the taxonomic id maintained by
NCBI for the species (not the specific strain), and Y is a sequence digit assigned to
this particular genome (as one of a set with the same genus/species).  Genomes also
have versions, but that is a separate issue.

=cut

sub genomes {
    my($self) = @_;
    my($i);

    if ($self->{_fig})
    {
	return $self->{_fig}->genomes;
    }

    my $url = $self->{_url} . "/kernel.cgi?request=genomes";
    my @out = `wget -O - \'$url\' 2> /dev/null`;
    my @genomes = ();
    for ($i=0; ($i < @out) && ($out[$i] !~ /^<pre>/i); $i++) {}
    if ($i < @out)
    {
	for ($i++; ($i < @out) && ($out[$i] !~ /^</); $i++)
	{
	    if ($out[$i] =~ /^(\d+\.\d+)/)
	    {
		push(@genomes,$1);
	    }
	}
    }
    return @genomes;
}

#############################  KEGG Stuff ####################################


=pod

=head1 all_maps

usage: @maps = $fig->all_maps

Returns a list containing all of the KEGG maps that the system knows about (the
maps need to be periodically updated).

=cut

sub all_maps {
    my($self) = @_;
    my($i);

    if ($self->{_fig})
    {
	return $self->{_fig}->all_maps;
    }

    my $url = $self->{_url} . "/kernel.cgi?request=all_maps";
    my @out = `wget -O - \'$url\' 2> /dev/null`;
    my @maps = ();
    for ($i=0; ($i < @out) && ($out[$i] !~ /^<pre>/i); $i++) {}
    if ($i < @out)
    {
	for ($i++; ($i < @out) && ($out[$i] !~ /^</); $i++)
	{
	    if ($out[$i] =~ /^(\S+)/)
	    {
		push(@maps,$1);
	    }
	}
    }
    return @maps;
}


=pod

=head1 map_to_ecs

usage: @ecs = $fig->map_to_ecs($map)

Returns the set of functional roles (usually ECs)  that are contained in the functionality
depicted by $map.

=cut

sub map_to_ecs {
    my($self,$map) = @_;
    my($i);

    if ($self->{_fig})
    {
	return $self->{_fig}->map_to_ecs($map);
    }

    my $url = $self->{_url} . "/kernel.cgi?request=map_to_ecs($map)";
    my @out = `wget -O - \'$url\' 2> /dev/null`;
    my @ecs = ();
    for ($i=0; ($i < @out) && ($out[$i] !~ /^<pre>/i); $i++) {}
    if ($i < @out)
    {
	for ($i++; ($i < @out) && ($out[$i] !~ /^</); $i++)
	{
	    if ($out[$i] =~ /^(\S+)/)
	    {
		push(@ecs,$1);
	    }
	}
    }
    return @ecs;
}



=pod

=head1 all_compounds

usage: @compounds = $fig->all_compounds

Returns a list containing all of the KEGG compounds.

=cut

sub all_compounds {
    my($self) = @_;
    my($i);

    if ($self->{_fig})
    {
	return $self->{_fig}->all_compounds;
    }

    my $url = $self->{_url} . "/kernel.cgi?request=all_compounds";
    my @out = `wget -O - \'$url\' 2> /dev/null`;
    my @compounds = ();
    for ($i=0; ($i < @out) && ($out[$i] !~ /^<pre>/i); $i++) {}
    if ($i < @out)
    {
	for ($i++; ($i < @out) && ($out[$i] !~ /^</); $i++)
	{
	    if ($out[$i] =~ /^(\S+)/)
	    {
		push(@compounds,$1);
	    }
	}
    }
    return @compounds;
}


=pod

=head1 names_of_compounds

usage: @tuples = $fig->names_of_compounds

Returns a list tuples (one per compound).  Each tuple contains

    [$cid,$names]

where $names is a pointer to a list of the names used for this compound.

=cut

sub names_of_compounds {
    my($self) = @_;
    my($cid,$i,@names);
    my(@all) = ();

    if ($self->{_fig})
    {
	foreach $cid ($self->{_fig}->all_compounds)
	{
	    push(@all,[$cid,[$self->{_fig}->names_of_compound($cid)]]);
	}
	return @all;
    }

    my $url = $self->{_url} . "/kernel.cgi?request=names_of_compounds";
    my @out = `wget -O - \'$url\' 2> /dev/null`;
    for ($i=0; ($i < @out) && ($out[$i] !~ /^<pre>/i); $i++) {}
    if ($i < @out)
    {
	for ($i++; ($i < @out) && ($out[$i] !~ /^</); $i++)
	{
	    if ($out[$i] =~ /^(\S.*\S)/)
	    {
		($cid,@names) = split(/\t/,$1);
		push(@all,[$cid,[@names]]);
	    }
	}
    }
    return @all;
}


=pod

=head1 names_of_compound

usage: @names = $fig->names_of_compound

Returns a list containing all of the names assigned to the KEGG compounds.  The list
will be ordered as given by KEGG.

=cut

sub names_of_compound {
    my($self,$cid) = @_;
    my($i);
    my(@names) = ();

    if ($self->{_fig})
    {
	return $self->{_fig}->names_of_compound($cid);
    }

    my $url = $self->{_url} . "/kernel.cgi?request=names_of_compound($cid)";
    my @out = `wget -O - \'$url\' 2> /dev/null`;
    for ($i=0; ($i < @out) && ($out[$i] !~ /^<pre>/i); $i++) {}
    if ($i < @out)
    {
	for ($i++; ($i < @out) && ($out[$i] !~ /^</); $i++)
	{
	    if ($out[$i] =~ /^(\S.*\S)/)
	    {
		push(@names,$1);
	    }
	}
    }
    return @names;
}


=pod

=head1 comp2react


usage: @rids = $fig->comp2react($cid)

Returns a list containing all of the reaction IDs for reactions that take $cid
as either a substrate or a product.

=cut

sub comp2react {
    my($self,$cid) = @_;
    my($i);
    my(@rids) = ();

    if ($self->{_fig})
    {
	return $self->{_fig}->comp2react($cid);
    }

    my $url = $self->{_url} . "/kernel.cgi?request=comp2react($cid)";
    my @out = `wget -O - \'$url\' 2> /dev/null`;
    for ($i=0; ($i < @out) && ($out[$i] !~ /^<pre>/i); $i++) {}
    if ($i < @out)
    {
	for ($i++; ($i < @out) && ($out[$i] !~ /^</); $i++)
	{
	    if ($out[$i] =~ /^(\S.*\S)/)
	    {
		push(@rids,$1);
	    }
	}
    }
    return @rids;
}


=pod

=head1 all_reactions

usage: @rids = $fig->all_reactions

Returns a list containing all of the KEGG reaction IDs.

=cut

sub all_reactions {
    my($self) = @_;
    my($i);

    if ($self->{_fig})
    {
	return $self->{_fig}->all_reactions;
    }

    my $url = $self->{_url} . "/kernel.cgi?request=all_reactions";
    my @out = `wget -O - \'$url\' 2> /dev/null`;
    my @reactions = ();
    for ($i=0; ($i < @out) && ($out[$i] !~ /^<pre>/i); $i++) {}
    if ($i < @out)
    {
	for ($i++; ($i < @out) && ($out[$i] !~ /^</); $i++)
	{
	    if ($out[$i] =~ /^(\S+)/)
	    {
		push(@reactions,$1);
	    }
	}
    }
    return @reactions;
}


=pod

=head1 reversible

usage: $rev = $fig->reversible($rid)

Returns true iff the reactions had a "main direction" designated as "<=>";

=cut

sub reversible {
    my($self,$rid) = @_;
    my($i);

    if ($self->{_fig})
    {
	return $self->{_fig}->reversible($rid);
    }

    my $url = $self->{_url} . "/kernel.cgi?request=reversible($rid)";
    my @out = `wget -O - \'$url\' 2> /dev/null`;
    for ($i=0; ($i < @out) && ($out[$i] !~ /^<pre>/i); $i++) {}
    if ($i < @out)
    {
	if ($out[$i+1] =~ /^([01])/)
	{
	    return $1;
	}
    }
    return 0;
}


=pod

=head1 catalyzed_by

usage: @ecs = $fig->catalyzed_by($rid)

Returns the ECs that are reputed to catalyze the reaction.  Note that we are currently
just returning the ECs that KEGG gives.  We need to handle the incompletely specified forms
(e.g., 1.1.1.-), but we do not do it yet.

=cut

sub catalyzed_by {
    my($self,$rid) = @_;
    my($i);

    if ($self->{_fig})
    {
	return $self->{_fig}->catalyzed_by($rid);
    }

    my @tuples = ();
    my $url = $self->{_url} . "/kernel.cgi?request=catalyzed_by($rid)";
    my @out = `wget -O - \'$url\' 2> /dev/null`;
    for ($i=0; ($i < @out) && ($out[$i] !~ /^<pre>/i); $i++) {}
    if ($i < @out)
    {
	for ($i++; ($i < @out) && ($out[$i] !~ /^</); $i++)
	{
	    if ($out[$i] =~ /^(\S.*\S)/)
	    {
		push(@tuples,$1);
	    }
	}
    }
    return @tuples;
}


=pod

=head1 catalyzes

usage: @ecs = $fig->catalyzes($role)

Returns the rids of the reactions catalyzed by the "role" (normally an EC).

=cut

sub catalyzes {
    my($self,$role) = @_;
    my($i);

    if ($self->{_fig})
    {
	return $self->{_fig}->catalyzes($role);
    }

    my @rids = ();
    my $url = $self->{_url} . "/kernel.cgi?request=catalyzes($role)";
    my @out = `wget -O - \'$url\' 2> /dev/null`;
    for ($i=0; ($i < @out) && ($out[$i] !~ /^<pre>/i); $i++) {}
    if ($i < @out)
    {
	for ($i++; ($i < @out) && ($out[$i] !~ /^</); $i++)
	{
	    if ($out[$i] =~ /^(R\d+)/)
	    {
		push(@rids,$1);
	    }
	}
    }
    return @rids;
}

sub reaction2comp {
    my($self,$rid,$which) = @_;
    my($i);
    my(@tuples) = ();

    if ($self->{_fig})
    {
	return $self->{_fig}->reaction2comp($rid,$which);
    }

    my $url = $self->{_url} . "/kernel.cgi?request=reaction2comp($rid,$which)";
    my @out = `wget -O - \'$url\' 2> /dev/null`;
    for ($i=0; ($i < @out) && ($out[$i] !~ /^<pre>/i); $i++) {}
    if ($i < @out)
    {
	for ($i++; ($i < @out) && ($out[$i] !~ /^</); $i++)
	{
	    if ($out[$i] =~ /^(\S.*\S)/)
	    {
		push(@tuples,[split(/\t/,$1)]);
	    }
	}
    }
    return @tuples;
}

sub seqs_with_roles_in_genomes {
    my($self,$genomes,$roles,$who) = @_;
    my($line,$genome,$role,$peg,$func);

    my $result = {};
    if ($self->{_fig})
    {
	return $self->{_fig}->seqs_with_roles_in_genomes($genomes,$roles,$who);
    }

    my $genomesL = join(",",@$genomes);
    my $rolesL   = join(",",@$roles);
    my $url = $self->{_url} . "/kernel.cgi?request=seqs_with_roles_in_genomes([$genomesL],[$rolesL],$who)";
    my @out = `wget -O - \'$url\' 2> /dev/null`;
    foreach $line (@out)
    {
	chop $line;
	($genome,$role,$peg,$func) = split(/\t/,$line);
	push(@{$result->{$genome}->{$role}},[$peg,$func]);
    }
    return $result;
}

1
