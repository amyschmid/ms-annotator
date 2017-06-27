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

package Kmers;
no warnings 'redefine';

use strict;
use DB_File;
use FIG;

use Tracer;

use ProtSims;

use Data::Dumper;
use Carp;
use FFs;

our $KmersC_available;
eval {
    require KmersC;
    $KmersC_available++;
};


# This is the constructor.  Presumably, $class is 'Kmers'.  
#

sub new {
    my($class,$KmerDB,$FRIDB,$setIDB) = @_;

    my $figfams = {};
    $figfams->{what} = '';
    $figfams->{blastdb} = "./blastdb";

    my $dir;
    if (defined($KmerDB) && (! defined($FRIDB)))
    {
	$dir = $KmerDB;
	($KmerDB,$FRIDB,$setIDB) = ("$dir/kmer.db","$dir/FRI.db","$dir/setI.db");

	if (open(WHAT,"<$dir/what") && defined($_ = <WHAT>))
	{
	    chomp;
	    $figfams->{what} = $_;
	    close(WHAT);
	}
	$figfams->{blastdb} = "$dir/blastdb";
    }
    else
    {
	$dir = ".";  # look for 'blastdb' and 'what' in current directory
    }
    $figfams->{dir} = $dir;

    if ((! defined($KmerDB)) || (! defined($FRIDB)) || (! defined($setIDB))) { return undef }

    my %fr_hash;
    my %set_hash;
    my %kmer_hash;

    my $fr_hash_tie   = tie %fr_hash,   'DB_File', $FRIDB,  O_RDONLY, 0666, $DB_HASH;
    my $set_hash_tie  = tie %set_hash,  'DB_File', $setIDB,  O_RDONLY, 0666, $DB_HASH;
    my $kmer_hash_tie = tie %kmer_hash, 'DB_File', $KmerDB, O_RDONLY, 0666, $DB_HASH;

    $fr_hash_tie    || die "tie failed for function index $FRIDB";
    $set_hash_tie   || die "tie failed for function index $FRIDB";
    $kmer_hash_tie  || die "tie failed for kmer hash $KmerDB";

    my($motif,undef) = each %kmer_hash;
    $figfams->{size} = length($motif);

    $figfams->{KmerH} = \%kmer_hash;
    $figfams->{friH}  = \%fr_hash;
    $figfams->{setiH} = \%set_hash;

    $figfams->{fig} = new FIG;
    bless $figfams,$class;
    return $figfams;
}

sub new_using_C {
    my($class,$KmerBinaryDB,$FRIDB,$setIDB) = @_;

    if (defined($KmerBinaryDB) && (! defined($FRIDB)))
    {
	my $dir = $KmerBinaryDB;
	($KmerBinaryDB,$FRIDB,$setIDB) = ("$dir/table.binary","$dir/FRI.db","$dir/setI.db");
    }

    my $figfams = {};
    if ((! defined($KmerBinaryDB)) || (! defined($FRIDB)) || (! defined("$setIDB"))) { return undef }


    $KmersC_available or die "KmersC module not available in this perl build";
    
    my %fr_hash;
    my $fr_hash_tie   = tie %fr_hash,   'DB_File', $FRIDB,  O_RDONLY, 0666, $DB_HASH;
    $fr_hash_tie    || die "tie failed for function index $FRIDB";

    my %set_hash;
    my $set_hash_tie  = tie %set_hash,   'DB_File', $setIDB,  O_RDONLY, 0666, $DB_HASH;
    $set_hash_tie   || warn "tie failed for function index $setIDB";

    my $kc = new KmersC;
    $kc->open_data($KmerBinaryDB) or die "cannot load Kmer binary database $KmerBinaryDB";
    
    $figfams->{size} = $kc->get_motif_len();
    $figfams->{KmerC} = $kc;
    $figfams->{friH}  = \%fr_hash;
    $figfams->{setiH} = \%set_hash;
    $figfams->{fig} = new FIG;

    bless $figfams,$class;
    return $figfams;
}

sub DESTROY {
    my ($self) = @_;
    delete $self->{fig};
}

sub match_seq {
    my($self,$seq) = @_;

    if ($self->{KmerC})
    {
	my $matches = [];
	Confess("No sequence specified.") if ! $seq;
	$self->{KmerC}->find_all_hits(uc $seq, $matches);
	return $matches;
    }

    my $kmer_hash = $self->{KmerH};
    my $motif_sz = $self->{size};
    my $matches = [];
    my $ln = length($seq);
    my $i;
    for ($i=0; ($i < ($ln - $motif_sz)); $i++)
    {
	my $oligo = uc substr($seq,$i,$motif_sz);
	my $x = $kmer_hash->{$oligo};
	if (defined($x))
	{
	    push(@$matches,[$i,$oligo,split(/\t/,$x)]);
	}
    }
    return $matches;
}

sub assign_function_to_prot {
    my($self,$seq,$blast,$min_hits,$extra_blastdb) = @_;
    $min_hits = 3 unless defined($min_hits);

    my $matches = $self->match_seq($seq);

    my $fr_hash   = $self->{friH};
    my $set_hash  = $self->{setiH};
    
    my(%hitsF,%hitsS);
    foreach my $match (@$matches) 
    {
	my($offset, $oligo, $frI, $setI) = @$match;
	$hitsF{$frI}++; 
	if ($setI)
	{ 
	    $hitsS{$setI}++ ;
	}
    }

    my $FRI = &best_hit(\%hitsF,$min_hits);
    my $setI  = &best_hit(\%hitsS,$min_hits);
    my $blast_results = [];
    if ($fr_hash->{$FRI})
    {
	if ($blast && ($fr_hash->{$FRI} || $set_hash->{$setI}))
	{
	    $blast_results = &blast_data($self,'query',$seq,$fr_hash->{$FRI},$blast,'blastp');
	}
	return [$fr_hash->{$FRI},$set_hash->{$setI}, $blast_results,$hitsF{$FRI}];
    }
    elsif ((-s $extra_blastdb) && 
	   (-s "$extra_blastdb.psq") && 
	   (-M $extra_blastdb >= -M "$extra_blastdb.pdq"))
    {
	my $fig = $self->{fig};

#	my $tmpF = "$FIG_Config::temp/tmpseq.$$.fasta";
#	open(TMP,">$tmpF") || die "could not open $tmpF";
#	print TMP ">query\n$seq\n";
#	close(TMP);

	my $seq_inp = [['query', '', $seq]];
	my @blastout = ProtSims::blastP($seq_inp, $extra_blastdb, 5);

	#my @blastout = `$FIG_Config::ext_bin/blastall -p blastp -FF -m 8 -e 1.0-20 -d $extra_blastdb -i $tmpF`;
	#unlink $tmpF;

#	if (@blastout > 5) { $#blastout = 4 }
#	my %hit_pegs = map { $_ =~ /^\S+\t(\S+)/; $1 => 1 } @blastout;
	my %hit_pegs = map { $_->id2 => 1 } @blastout;
	my @pegs = keys(%hit_pegs);
	if (@pegs == 0)
	{
	    return ['hypothetical protein','',[],0];
	}
	else
	{
	    my %funcs;
	    foreach my $peg (@pegs)
	    {
		my $func = $fig->function_of($peg,1);
		if (! &FIG::hypo($func))
		{
		    $funcs{$func}++;
		}
	    }
	    my @pos = sort { $funcs{$b} <=> $funcs{$a} } keys(%funcs);
	    my $proposed = (@pos > 0) ? $pos[0] : "hypothetical protein";
	    return [$proposed,'',[],0];
	}
    }
    else
    {
	return ['','',[],0];
    }
}

sub assign_functions_to_prot_set {
    my($self,$seq_set,$blast,$min_hits,$extra_blastdb) = @_;
    $min_hits = 3 unless defined($min_hits);

    my %match_set = map { my($id, $com, $seq) = @$_;  $id => [$self->match_seq($seq), $seq] } @$seq_set;

    my $fr_hash   = $self->{friH};
    my $set_hash  = $self->{setiH};

    my $fig = $self->{fig};

    my @missing;
    while (my($id, $ent) = each %match_set)
    {
	my($matches, $seq) = @$ent;
	
	my(%hitsF,%hitsS);
	foreach my $match (@$matches) 
	{
	    my($offset, $oligo, $frI, $setI) = @$match;
	    $hitsF{$frI}++; 
	    if ($setI)
	    { 
		$hitsS{$setI}++ ;
	    }
	}
	
	my $FRI = &best_hit(\%hitsF,$min_hits);
	my $setI  = &best_hit(\%hitsS,$min_hits);
	push(@$ent, $FRI, $setI, \%hitsF);

	if (!$fr_hash->{$FRI})
	{
	    push(@missing, [$id, undef, $seq]);
	}
    }

    #
    # @missing now has the list of sequences that had no Kmer hits. If we have a
    # blast db, blast 'em.

    my @all_blastout;
    if (@missing && -s $extra_blastdb)
    {
	#print Dumper(\@missing);
	@all_blastout = ProtSims::blastP(\@missing, $extra_blastdb, 5);
	#print Dumper(\@all_blastout);
    }

    #
    # We now have Kmers output and blast output. Go through the original data and
    # create the output.
    #

    my @out;
    
    for my $ent (@$seq_set)
    {
	my $id = $ent->[0];
	my ($matches, $seq, $FRI, $setI, $hitsF)  = @{$match_set{$id}};

	my $blast_results = [];
	if ($fr_hash->{$FRI})
	{
	    if ($blast && ($fr_hash->{$FRI} || $set_hash->{$setI}))
	    {
		$blast_results = &blast_data($self,$id,$seq,$fr_hash->{$FRI},$blast,'blastp');
	    }

	    push(@out, [$id, $fr_hash->{$FRI},$set_hash->{$setI}, $blast_results,$hitsF->{$FRI}]);
	}
	else
	{
	    my @blastout = grep { $_->id1 eq $id } @all_blastout;

	    if (@blastout > 5) { $#blastout = 4 }
	    
	    my %hit_pegs = map { $_->id2 => 1 } @blastout;
	    my @pegs = keys(%hit_pegs);
	    if (@pegs == 0)
	    {
		push(@out, [$id,'hypothetical protein','',[],0]);
	    }
	    else
	    {
		my %funcs;
		foreach my $peg (@pegs)
		{
		    my $func = $fig->function_of($peg,1);
		    if (! &FIG::hypo($func))
		    {
			$funcs{$func}++;
		    }
		}
		my @pos = sort { $funcs{$b} <=> $funcs{$a} } keys(%funcs);
		my $proposed = (@pos > 0) ? $pos[0] : "hypothetical protein";
		push(@out, [$id, $proposed,'',[],0]);
	    }
	}
    }
    return @out;
}

sub best_hit {
    my($hits,$min_hits) = @_;
    my @poss = sort { $hits->{$b} <=> $hits->{$a} } keys(%$hits);

    my $val;
    if ((@poss > 0) && ($hits->{$poss[0]} >= $min_hits))
    {
	$val = $poss[0];
    }
    return $val;
}

sub best_hit_in_group
{
    my($group) = @_;

    my %hash;
    for my $tuple (@$group)
    {
    	my($off,$oligo,$frI,$setI) = @$tuple;
	if ($setI > 0)
	{
	    $hash{$setI}++;
	}
    }
    my @sorted = sort { $hash{$b} <=> $hash{$a} } keys %hash;
    my $max = $sorted[0];
    return $max;
}

sub assign_functions_to_DNA_features {
    my($self,$seq,$min_hits,$max_gap,$blast) = @_;

    $min_hits = 3 unless defined($min_hits);
    $max_gap  = 200 unless defined($max_gap);

    my $fr_hash   = $self->{friH};
    my $set_hash  = $self->{setiH};
    my $motif_sz = $self->{size};

    my %hits;
    my @ans;
    my $matches = $self->process_dna_seq($seq);

    push(@ans,&process_hits($self,$matches,1,length($seq),$motif_sz, $min_hits, $max_gap,$blast,$seq));
    undef %hits;

    $matches = $self->process_dna_seq(&FIG::reverse_comp($seq));
    push(@ans,&process_hits($self,$matches,length($seq),1,$motif_sz, $min_hits, $max_gap,$blast,$seq));
    return \@ans;
}

sub process_dna_seq {
    my($self, $seq,$hits) = @_;

    my $matches = $self->match_seq($seq);
    return $matches;
}


sub process_hits {
    my($self,$matches,$beg,$end,$sz_of_match, $min_hits, $max_gap,$blast,$seq) = @_;

    my $fr_hash   = $self->{friH};
    my $set_hash  = $self->{setiH};
    my $motif_sz = $self->{size};

    my $hits;
    my %sets;
    foreach my $tuple (@$matches)
    {
	my($off,$oligo,$frI,$setI) = @$tuple;
	push(@{$hits->{$frI}},$tuple);
    }

    my @got = ();
    my @poss = sort { (@{$hits->{$b}} <=> @{$hits->{$a}}) } keys(%$hits);
    if (@poss != 0)
    {
	foreach my $frI (@poss)
	{
	    my $hit_list = $hits->{$frI};
	    my @grouped = &group_hits($hit_list, $max_gap);
	    foreach my $group_ent (@grouped)
	    {
		my($group, $group_hits) = @$group_ent;
		my $N = @$group;
		if ($N >= $min_hits)   # consider only runs containing 3 or more hits
		{
		    my $b1 = $group->[0];
		    my $e1 = $group->[-1] + ($sz_of_match-1);

		    my $loc;
		    if ($beg < $end)
		    {
			$loc = [$beg+$b1,$beg+$e1];
		    }
		    else
		    {
			$loc = [$beg-$b1,$beg-$e1];
		    }
		    my $func = $fr_hash->{$frI};

		    my $set = &best_hit_in_group($group_hits);
		    $set = $set_hash->{$set};

		    my $blast_output = [];
		    if ($blast)
		    {
			$blast_output = &blast_data($self,join("_",@$loc),$seq,$func,$blast,
						    ($motif_sz == $sz_of_match) ? 'blastn' : 'blastx');
		    }
		    
		    my $tuple = [$N,@$loc,$func,$set,$blast_output];
		    
		    push(@got,$tuple);
		}
	    }
	}
    }
    return @got;
}

sub group_hits {
    my($hits, $max_gap) = @_;

    my @sorted = sort { $a->[0] <=> $b->[0] } @$hits;
    my @groups = ();
    my $position;
    while (defined(my $hit = shift @sorted))
    {
	my($position,$oligo,$frI,$setI) = @$hit;

	my $group = [$position];
	my $ghits = [$hit];
	while ((@sorted > 0) && (($sorted[0]->[0] - $position) < $max_gap))
	{
	    $hit = shift @sorted;
	    ($position,$oligo,$frI,$setI) = @$hit;
	    push(@$group,$position+1);
	    push(@$ghits, $hit);
	}

	push(@groups,[$group, $ghits]);
    }
    return @groups;
}

sub assign_functions_to_PEGs_in_DNA {
    my($self,$seq,$min_hits,$max_gap,$blast) = @_;

    $blast = 0 unless defined($blast);
    $min_hits = 3 unless defined($min_hits);
    $max_gap  = 200 unless defined($max_gap);

    my $fr_hash   = $self->{friH};
    my $set_hash  = $self->{setiH};
    my $motif_sz = $self->{size};

    my %hits;
    my @ans;
    my $matches = $self->process_prot_seq($seq);
    push(@ans,&process_hits($self,$matches,1,length($seq),3 * $motif_sz, $min_hits, $max_gap,$blast,$seq));
    undef %hits;
    $matches = $self->process_prot_seq(&FIG::reverse_comp($seq));
    push(@ans,&process_hits($self,$matches,length($seq),1,3 * $motif_sz, $min_hits, $max_gap,$blast,$seq));
    return \@ans;
}    

sub process_prot_seq {
    my($self, $seq) = @_;

    my $ans = [];
    my $ln = length($seq);
    my($i,$off);
    for ($off=0; ($off < 3); $off++)
    {
	my $ln_tran = int(($ln - $off)/3) * 3;
	my $tran = uc &FIG::translate(substr($seq,$off,$ln_tran));


	my $matches = $self->match_seq($tran);
	
	push(@$ans, map { $_->[0] = ((3 * $_->[0]) + $off); $_ } @$matches);
    }
    return $ans;
}

use Sim;

sub blast_data {
    my($self,$id,$seq,$func,$blast,$tool) = @_;

    if ($tool eq "blastp")   
    { 
	return &blast_data1($self,$id,$seq,$func,$blast,$tool);
    }

    if ($id =~ /^(\d+)_(\d+)$/)
    {
	my($b,$e) = ($1 < $2) ? ($1,$2) : ($2,$1);
	my $b_adj = (($b - 5000) > 0) ? $b-5000 : 1;
	my $e_adj = (($b + 5000) <= length($seq)) ? $b+5000 : length($seq);
	my $seq1 = substr($seq,$b_adj-1, ($e_adj - $b_adj)+1);
	my $blast_out = &blast_data1($self,$id,$seq1,$func,$blast,$tool);
	foreach $_ (@$blast_out)
	{
	    $_->[2] += $b_adj - 1;
	    $_->[3] += $b_adj - 1;
	    $_->[8] = length($seq);
	}
	return $blast_out;
    }
    else
    {
	return &blast_data1($self,$id,$seq,$func,$blast,$tool);
    }
}

sub blast_data1 {
    my($self,$id,$seq,$func,$blast,$tool) = @_;


    if (! $tool) { $tool = 'blastx' }
    my $fig = $self->{fig};

    my @blastout = ();
    if ($tool ne 'blastn')
    {
	my $ffs = new FFs($FIG_Config::FigfamsData);
	my @fams = $ffs->families_implementing_role($func);
	foreach my $fam (@fams)
	{
	    my $subD = substr($fam,-3);
	    my $pegs_in_fam = "$FIG_Config::FigfamsData/FIGFAMS/$subD/$fam/PEGs.fasta";
	    push(@blastout,map { [$_->id2,$_->iden,$_->b1,$_->e1,$_->b2,$_->e2,$_->psc,$_->bsc,$_->ln1,$_->ln2,$fam] } 
		 $fig->blast($id,$seq,$pegs_in_fam,0.1,"-FF -p $tool -b $blast"));
	}
    }
    else
    {
	push(@blastout,map { [$_->id2,$_->iden,$_->b1,$_->e1,$_->b2,$_->e2,$_->psc,$_->bsc,$_->ln1,$_->ln2,$self->{what}] } 
	     $fig->blast($id,$seq,$self->{blastdb},0.1,"-FF -p $tool -b $blast"));
    }
    @blastout = sort { $b->[7] <=> $a->[7] }  @blastout;
    if (@blastout > $blast) { $#blastout = $blast-1 }
    return \@blastout;
}

1;
