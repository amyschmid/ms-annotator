# -*- perl -*-
########################################################################
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
########################################################################

package ClosestGenomes;

use strict;
use Data::Dumper;
use Carp;

sub closest_genomes_to_existing_genome {
    my($fig,$genome) = @_;

    my @univ = (
		"Phenylalanyl-tRNA synthetase beta chain (EC 6.1.1.20)",
		"Prolyl-tRNA synthetase (EC 6.1.1.15)",
		"Phenylalanyl-tRNA synthetase alpha chain (EC 6.1.1.20)",
		"Histidyl-tRNA synthetase (EC 6.1.1.21)",
		"Arginyl-tRNA synthetase (EC 6.1.1.19)",
		"Tryptophanyl-tRNA synthetase (EC 6.1.1.2)",
		"Preprotein translocase secY subunit (TC 3.A.5.1.1)",
		"Tyrosyl-tRNA synthetase (EC 6.1.1.1)",
		"Methionyl-tRNA synthetase (EC 6.1.1.10)",
		"Threonyl-tRNA synthetase (EC 6.1.1.3)",
		"Valyl-tRNA synthetase (EC 6.1.1.9)"
	       );

    my($role);

    my $number_hits = 0;
    my $tot_norm_sc = {};
    my $num_norm_sc = {};
    foreach $role (@univ)
    {
        my @pegs = $fig->seqs_with_role($role,'master',$genome);
        if (@pegs == 1)
        {
            my $peg = $pegs[0];
            $number_hits++;

            my($sim,%seen,$norm_sc);
            foreach $sim ($fig->sims($peg,20,1.0e-5,"fig"))
            {
                my $genome2 = &FIG::genome_of($sim->id2);
                if (! $seen{$genome2})
                {
                    $seen{$genome2} = 1;
		    my $len_match = $sim->e2 + 1 - $sim->b2;
                    $norm_sc = $sim->bsc / $len_match;
                    $tot_norm_sc->{$genome2} += $norm_sc;
                    $num_norm_sc->{$genome2}++;
                }
            }
        }
    }
    my @genomes_hit = sort { $b->[1] <=> $a->[1] }
	              map { [$_,sprintf("%0.3f",$tot_norm_sc->{$_} / $num_norm_sc->{$_})] }
                      keys(%$tot_norm_sc);
   
    return @genomes_hit;

}

1;
