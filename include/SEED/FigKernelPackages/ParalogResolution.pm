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

package ParalogResolution;

use strict;
use FIG;

use Data::Dumper;
use Carp;
use gjoalignment;

sub context_tags {
    my($pegs,$dist) = @_;

    my $fig = new FIG;
    my($i,%before,%after,%funcs);
    foreach my $peg (@$pegs)
    {
	my $loc = $fig->feature_location($peg);
	if ($loc)
	{
	    my($contig,$beg,$end) = $fig->boundaries_of($loc);
	    if ($contig && $beg && $end)
	    {
		my $min = &FIG::min($beg,$end) - $dist;
		my $max = &FIG::max($beg,$end) + $dist;
		my $feat;
		($feat,undef,undef) = $fig->genes_in_region(&FIG::genome_of($peg),$contig,$min,$max);
		my(@before,@after,$seen_peg);
		for ($i=0; ($i < @$feat); $i++)
		{
		    my $fid = $feat->[$i];
		    if (&FIG::ftype($fid) eq 'peg')
		    {
			if ($fid eq $peg) 
			{
			    $seen_peg = 1;
			    next;
			}
			my $func = $fig->function_of($fid,"",1);
			$funcs{$func}++;

			if ((($beg < $end) && (! $seen_peg)) || 
			    (($beg > $end) && $seen_peg))
			{
			    push(@before,[$fid,$func]);
			}
			else
			{
			    push(@after,[$fid,$func]);
			}
		    }
		}
		$before{$peg} = [($beg < $end) ? @before : reverse @before];
		$after{$peg}  = [($beg < $end) ? @after  : reverse @after];
	    }
	}
    }
    my @hits = sort { $funcs{$b} <=> $funcs{$a} } 
               grep { $funcs{$_} > 1 } 
               keys(%funcs);

    my %val;
    my %val2func;
    for ($i=0; ($i < @hits); $i++)
    {
	$val{$hits[$i]} = $i+1;
	$val2func{$i+1} = $hits[$i];
    }
    my $tags = {};
    foreach my $peg (@$pegs)
    {
	my $left   = &process_neigh($peg,\%before,\%val);
	my $right  = &process_neigh($peg,\%after,\%val);
	$tags->{$peg} = $left . "::" . $right;
    }
    return ($tags,[map { [$_,$val2func{$_}] } sort { $a <=> $b } keys(%val2func)]);
}

sub process_neigh {
    my($peg,$neigh,$val) = @_;

    my @pieces = ();
    my $tuples = $neigh->{$peg};
    foreach my $tuple (@$tuples)
    {
	my($peg1,$func1) = @$tuple;
	my $x = $val->{$func1};
	if ($x)
	{
	    push(@pieces,$x);
	}
    }
    return join(" ",@pieces);
}


sub reference_set_for_paralogs {
    my( $fig, $genomes, $roles, $parms ) = @_;
    $fig ||= new FIG;

    $parms ||= {};

    my $keep_multifunctional = $parms->{'keep_multifunctional'};
    $keep_multifunctional    = 1 if ! defined($keep_multifunctional);

    my $max_sc    = $parms->{'max_sc'}    || 1.0e-5;
    my $min_cov   = $parms->{'min_cov'}   || 0.7;
    my $min_ident = $parms->{'min_ident'} || 0.25;
    $min_ident *= 100;   #  make it a percentage

    my %ref_genomes = map { $_ => 1 } @$genomes;
    my %ref_roles   = map { $_ => 1 } @$roles;
    my %pegs;
    foreach my $role ( @$roles )
    {
	foreach my $peg ($fig->prots_for_role($role))
	{
	    if ( $ref_genomes{ &FIG::genome_of( $peg ) } && ( ! $fig->screwed_up( $peg ) ) )
	    {
		my $func = $fig->function_of($peg,"",1);
                my $funcF = $func;
                $funcF =~ s/ ##? .*$//;
                $pegs{ $peg } = $func if ! ( $funcF =~ / \/ / );
            }
        }
    }
    my @seqs = map { my $peg = $_; 
		     my $gs = $fig->genus_species(&FIG::genome_of($peg));
		     my $func_of_peg = $pegs{$peg};
		     [$peg,"$func_of_peg \[$gs\]",$fig->get_translation($peg)] 
		   } 
                   keys(%pegs);

#   Now add paralogs from given genomes

    my @to_add = ();
    foreach my $genome ( @$genomes )
    {
        #  Verify the blast db
        my $fasta = "$FIG_Config::organisms/$genome/Features/peg/fasta";
        if ( ! -s "$fasta.psq" )
        {
            next if ! -s $fasta;
            system( "$FIG_Config::ext_bin/formatdb", '-p', 'T', '-i', $fasta );
            next if ! -s "$fasta.psq";
        }

        my $gs = $fig->genus_species( $genome );
        my %seq_done;
        foreach my $tuple ( @seqs )
        {
            my( $peg, $comment, $seq ) = @$tuple;
            next if $seq_done{ $seq }++;
            foreach my $sim ( &FIG::blastitP( $peg, $seq, $fasta, $max_sc, "-F F -a 2" ) )
            {
                my $id2 = $sim->id2;
                if ( ( ! $pegs{ $id2 } )
                  && $fig->is_real_feature( $id2 )
                  && ( ( ( $sim->e2 + 1 - $sim->b2 ) / $sim->ln2 ) >= $min_cov )
                  && ( $sim->iden >= $min_ident )
                   )
                {
                    $pegs{ $id2 } = $fig->function_of( $id2 ) || 'undefined';
                    push( @to_add, [ $id2, "$pegs{$id2} \[$gs\]", $fig->get_translation($id2) ] );
                }
            }
        }
    }
    push( @seqs, @to_add );

    ( @seqs > 1 ) ? &gjoalignment::align_with_muscle( \@seqs )  # align, or align & tree
                  : wantarray ? () : undef;
}


sub role_in {
    my($func,$role) = @_;
    
    my @roles_of_function = &FIG::roles_of_function($func);
    my $i;
    for ($i=0; ($i < @roles_of_function) && ($role ne $roles_of_function[$i]); $i++) {}
    return ($i < @roles_of_function);
}

1;
