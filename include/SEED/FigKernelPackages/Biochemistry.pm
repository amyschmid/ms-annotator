package Biochemistry;
use strict;
use Data::Dumper;

####################### Biochemistry #####################

sub biochemistry_dir {
    return "/homes/overbeek/Ross/MakeCS.Kbase/Data/Biochemistry";
}

sub reactions_to_descriptions {
    my $biochemD = &biochemistry_dir;

    my %react2desc = map { ($_ =~ /^(\S+)\t(\S.*\S)/) ? ($1 => $2) : () } `cat $biochemD/ReactionDesc.txt`;
    return \%react2desc;
}

sub role_to_complexes {
    my $biochemD = &biochemistry_dir;

    my %role_to_complexes;
    foreach $_ (`cat $biochemD/Role2Complex.txt`)
    {
	if ($_ =~ /^([^\t]+)\t(\S+)(\t(\S+))?/)
        {
	    my($role,$complex,$optional) = ($1,$2,$3);
	    if (! $optional) { $optional = 1 }
	    push(@{$role_to_complexes{$role}},[$complex,$optional]);
        }
    }
    return \%role_to_complexes;
}

sub complex_to_roles {
    my $biochemD = &biochemistry_dir;

    my %complex_to_roles;
    foreach $_ (`cat $biochemD/Role2Complex.txt`)
    {
	if ($_ =~ /^([^\t]+)\t(\S+)(\t(\S+))?/)
        {
	    my($role,$complex,$optional) = ($1,$2,($4 ? 1 : 0));
	    push(@{$complex_to_roles{$complex}},[$role,$optional]);
        }
    }
    return \%complex_to_roles;
}

sub roles_to_complex_info {
    my($roles) = @_;
    my $biochemD = &biochemistry_dir;

    my $role_to_complexes = &role_to_complexes;
    my %reactions;
    my %hits;
    foreach my $role (@$roles)
    {
	my $complexesL = $role_to_complexes->{$role};
	foreach my $tupleC (@$complexesL)
	{
	    my($complex,$optional) = @$tupleC;
	    if (! $hits{$complex}) { $hits{$complex} = [0,0] }
	    if ($optional)
	    {
		$hits{$complex}->[1]++;
	    }
	    else
	    {
		$hits{$complex}->[0]++;
	    }
	}
    }
    return \%hits;
}

sub roles_to_reactions {
    my($roles) = @_;

    my $complex_to_reactions = &complex_to_reactions;
    my $all_roles = &roles_used_in_modeling;
    my $complex_info = &roles_to_complex_info($all_roles);
    my $input_info   = &roles_to_complex_info($roles);
    my %reactions;
    foreach my $complex (keys(%$input_info))
    {
	my $complex_counts = $complex_info->{$complex};
	my $actual_counts  = $input_info->{$complex};
	if (&call_presence($complex_counts,$actual_counts))
	{
	    my $reacL = $complex_to_reactions->{$complex};
	    foreach my $reac (@$reacL)
	    {
		$reactions{$reac} = 1;
	    }
	}
    }
    return [sort keys(%reactions)];
}

sub call_presence {
    my($complex_info,$input_info) = @_;

    return $input_info->[0] >= (0.8 * $complex_info->[0]);
}

sub roles_used_in_modeling {
    my $biochemD = &biochemistry_dir;
    my @roles = map { chomp; $_ } `cut -f1 $biochemD/Role2Complex.txt | sort -u`;
    return \@roles;
}

sub complex_to_reactions {
    my $biochemD = &biochemistry_dir;
    my %complex_to_reactions;
    foreach $_ (`cat $biochemD/Complex2Reaction.txt`)
    {
	if ($_ = /(\S+)\t(\S+)/)
	{
	    push(@{$complex_to_reactions{$1}},$2);
	}
    }
    return \%complex_to_reactions;
}

sub reaction_to_complexes {
    my $biochemD = &biochemistry_dir;
    my %reaction_to_complexes;
    foreach $_ (`cat $biochemD/Complex2Reaction.txt`)
    {
	if ($_ = /(\S+)\t(\S+)/)
	{
	    push(@{$reaction_to_complexes{$2}},$1);
	}
    }
    return \%reaction_to_complexes;
}

1;
