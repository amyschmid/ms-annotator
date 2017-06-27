# -*- perl -*-
########################################################################
# Copyright (c) 2003-2011 University of Chicago and Fellowship
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
########################################################################

package GenerateClusters;

use strict;
no warnings 'redefine';  ## prevents spurious warnings due to use recursion
use SeedUtils;
use SAPserver;
use Data::Dumper;

sub generate_clusters {
    my($ref,$genomes,$min_iden) = @_;

    if (! $min_iden) { $min_iden = 50 }
    my $sapO = SAPserver->new();

    my %neighH;
    foreach my $g (($ref,@$genomes))
    {
	my $pegH = $sapO->all_features( -ids => [$g], -type => ['peg'] );
	my $pegs = $pegH->{$g};
	my $locH = $sapO->fid_locations( -ids => $pegs, -boundaries => 1);
	$neighH{$g} = &neighbors($locH);
	print STDERR "$g done\n";
    }
    my $bbhsH   = &bbhs($ref,$genomes,$sapO,$min_iden);
    my @connected;

    foreach my $peg (sort {&SeedUtils::by_fig_id($a,$b) } keys(%{$neighH{$ref}}))
    {
	my @neigh = keys(%{$neighH{$ref}->{$peg}});
	foreach my $peg2 (sort { &SeedUtils::by_fig_id($a,$b) } @neigh)
	{
	    my $preserved = 0;
	    my $not_preserved = 0;

	    foreach my $g (@$genomes)
	    {
		
		my $bbh_peg = $bbhsH->{$g}->{$peg};
		my $bbh_neigh = $bbhsH->{$g}->{$peg2};
		if ($bbh_peg && $bbh_neigh)
		{
		    if ($neighH{$g}->{$bbh_peg}->{$bbh_neigh})
		    {
			$preserved++;
		    }
		    else
		    {
			$not_preserved++;
		    }
		}
	    }
	    push(@connected,[$peg,$peg2,$preserved,$not_preserved]);
	}
    }
    return \@connected;
}

sub ok_coverage {
    my($b1,$e1,$ln1,$b2,$e2,$ln2) = @_;

    my $ln = ($ln1 > $ln2) ? $ln1 : $ln2;
    return ((($ln - $ln1) / $ln) < 0.2) && ((($ln - $ln2) / $ln) < 0.2);
}

sub bbhs {
    my($ref,$genomes,$sapO,$min_iden) = @_;

    my $corrH = {};
    foreach my $g (@$genomes)
    {
#	open(CORR,"<Corr/$g") || die "could not open correspondence for $g";
#	while (defined($_ = <CORR>))
#	{
#	    chop;
#	    my @x = split(/\t/,$_);
#	    if ($x[8] eq "<=>")
#	    {
#		$corrH->{$g}->{$x[0]} = $x[1];
#	    }
#	}
#	close(CORR);
	print STDERR "bbhs for $ref and $g\n";
#	$corrH->{$g} = $sapO->gene_correspondence_map( -genome1 => $ref, -genome2 => $g );
	my $map = $sapO->gene_correspondence_map( -genome1 => $ref, -genome2 => $g,-fullOutput => 1 );
	foreach my $tuple (@$map)
	{
	    if (($tuple->[8] eq "<=>") && 
		&ok_coverage($tuple->[11],$tuple->[12],$tuple->[13],$tuple->[14],$tuple->[15],$tuple->[16]) &&
		($min_iden <= $tuple->[9]))
	    {
		$corrH->{$g}->{$tuple->[0]} = $tuple->[1];
	    }
	}
    }
    return $corrH;
}

sub neighbors {
    my($locH) = @_;

    my @locs;
    foreach my $peg (keys(%$locH))
    {
	my $loc = $locH->{$peg};
	if ($loc && ($loc =~ /^.*:(\S+)_(\d+)[+-](\d+)$/))
	{
	    my($contig,$beg,$strand,$len) = ($1,$2,$3,$4);
	    my $mid = ($strand eq '+') ? ($beg + ($len/2)) : ($beg - ($len/2));		
	    push(@locs,[$peg,$contig,$mid]);
	}
    }
    @locs = sort { ($a->[1] cmp $b->[1]) or ($a->[2] <=> $b->[2]) } @locs;
    my $neighH = {};
    my($i,$j);
    for ($i=0; ($i < @locs); $i++)
    {
	$j = ($i >= 5) ? ($i - 5) : 0;
	while ($j < $i)
	{
	    if ($locs[$j]->[1] eq $locs[$i]->[1])
	    {
		$neighH->{$locs[$i]->[0]}->{$locs[$j]->[0]} = 1
#		push(@$neigh,$locs[$j]->[0]);
	    }
	    $j++;
	}
	$j = $i+1;
	while (($j < @locs) && ($j <= $i+5))
	{
	    if ($locs[$j]->[1] eq $locs[$i]->[1])
	    {
		$neighH->{$locs[$i]->[0]}->{$locs[$j]->[0]} = 1
#		push(@$neigh,$locs[$j]->[0]);
	    }
	    $j++;
	}
#	$neighH->{$locs[$i]->[0]} = $neigh;
    }
    return $neighH;
}

1;
