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

package Kmers2013;

use strict;
use Data::Dumper;
use Carp;
use gjoseqlib;

# typedef tuple<length,frames,otu_data> contig_data;
# typedef tuple<string genus,string species> genus_species;
# typedef tuple<int estimate, comment, int genetic_code, string estimated_taxonomy,seq_set placed> potenital_genome;
# typedef list<potential_genome> potenital_genomes;
# funcdef check_contig_set(seq_set) returns (tuple<potential_genomes,seq_set unplaced>); 

sub check_contig_set {
    my($contigs,$otuH) = @_;

    my $dataD = "/home/overbeek/Ross/KBaseServers/KmerEvaluation/Data";
    if (! $otuH)
    {
	$otuH = &load_otu_index($dataD);
    }
   my %to_seq = map { $_->[0] => $_ } @$contigs;
    my $gs_summary = &load_gs_data($dataD);
    my $kmer_output = &call_dna_with_kmers($contigs,$otuH);
    my %split_by_otu;
    my $unplaced = [];

    foreach my $contig (keys(%$kmer_output))
    {
	my($estimated_otu,$reliable) = &estimate_the_otu($kmer_output->{$contig}->[2]);
	if ($estimated_otu)
	{
	    push(@{$split_by_otu{$estimated_otu}},[$reliable,$contig,$kmer_output->{$contig},$to_seq{$contig}]);
	}
	else
	{
	    push(@$unplaced,[$contig,$kmer_output->{$contig}]);
	}
    }

    my $potential_genomes = [];
    foreach my $estimated_otu (sort keys(%split_by_otu))
    {
	my $potential_genome = &gather_genome_data($estimated_otu,$split_by_otu{$estimated_otu},$gs_summary);
	if ($potential_genome)
	{
	    push(@$potential_genomes,$potential_genome);
	}
    }
    return [$potential_genomes,$unplaced];
}

sub estimate_the_otu {
    my($otu_data) = @_;

    if ((@$otu_data > 0) &&
	($otu_data->[0]->[0] > 10) &&
	((@$otu_data == 1) || ($otu_data->[0]->[0] > (2 * $otu_data->[1]->[0]))))
    {
	my $otu = join(",",map { join(" ",@$_) } @{$otu_data->[0]->[1]});
	my $reliable = ($otu_data->[0]->[0] > 50);
	return ($otu,$reliable);
    }
    return (undef,undef);
}

sub gather_genome_data {
    my($estimated_otu,$contig_set,$gs_summary) = @_;
    my $otuS = &summarize_otu($estimated_otu,$gs_summary);
    if (! $otuS) { return undef }
    my $ribo_prot = {};
    my $seq_set = [];

    foreach my $contig_tuple (@$contig_set)
    {
	my($reliable,$contig,$contig_data,$sequence) = @$contig_tuple;
	my($contig_len,$frames,$otu_data) = @$contig_data;
	foreach my $frame (@$frames)
	{
	    my($strand,$off,$hits) = @$frame;
	    foreach my $hit (@$hits)
	    {
		my($b,$e,$fI,$func) = @$hit;
		if ($func =~ /[LS]SU ribosomal protein/)
		{
		    push(@{$ribo_prot->{$func}},[$contig,$strand,$off,$b,$e,$strand,$off]);
		}
	    }
	}
	push(@$seq_set,$sequence);
    }
    my $estimated_rp          = 0;
    my $estimated_frameshifts = 0;
    my $estimated_duplicates  = 0;
    foreach my $func (keys(%$ribo_prot))
    {
	my $rpf      = $ribo_prot->{$func};
	my @hit_func = sort { ($a->[0] cmp $b->[0]) or ($a->[3] <=> $b->[3]) } @$rpf;
	my $i;
	for ($i=0; ($i < @hit_func); $i++)
	{
	    if ($i == 0)
	    {
		$estimated_rp++;
	    }
	    elsif (($i < $#hit_func) && &close_hits($hit_func[$i],$hit_func[$i+1]))
	    {
		if (($hit_func[$i]->[5] != $hit_func[$i+1]->[5])  || # different frame
		    ($hit_func[$i]->[6] != $hit_func[$i+1]->[6]))
		{
		    $estimated_frameshifts++;
		}
	    }
	    else
	    {
		$estimated_duplicates++;
	    }
	}
    }
    my($class,$comment,$gc,$tax) = &estimate_class_and_comment($estimated_rp,
								   $estimated_frameshifts,
								   $estimated_duplicates,
								   $otuS,
								   $contig_set);
    return [$class,$comment,$gc,$tax,$seq_set];
}

sub close_hits {
    my($x,$y) = @_;
    my($c1,$strand1,undef,$beg1,$end1) = @$x;
    my($c2,$strand2,undef,$beg2,$end2) = @$y;
    return (($c1 eq $c2) && ($strand1 == $strand2) && ((abs($beg2-$end1) < 200) || (abs($beg1-$end2) < 200)));
}

sub estimate_class_and_comment {
    my($estimated_rp,$estimated_frameshifts,$estimated_duplicates,$otuS,$contig_set) = @_;
    
    my $dna      = 0;
    my $contigsN = 0;
    my $large_contigs = 0;
    my $reliable_placements = [];
    my($gs_sz,$gs_gc,$gs_domain,$gs_tax,$gs_rp) = @$otuS;
    foreach my $contig_tuple (@$contig_set)
    {
	my($reliable,$contig,$contig_data) = @$contig_tuple;
	if ($reliable) { push(@$reliable_placements,$contig) }
	my($act_sz,$frames,$otu_counts) = @$contig_data;
	$dna += $act_sz;
	$contigsN++;
	if ($act_sz > 5000)
	{
	    $large_contigs++;
	}
    }
    my $avg_contig_sz = int($dna / $contigsN);
    
    my $class;
    if ((abs($gs_rp - $estimated_rp) <= (0.1 * $gs_rp)) &&
	(abs($gs_sz - $dna) <= (0.2 * $gs_sz)))
    {
	$class = 1;   # 1 means OK
    }
    elsif ((abs($gs_rp - $estimated_rp) <= (0.2 * $gs_rp)) &&
	   (abs($gs_sz - $dna) <= (0.3 * $gs_sz)))
    {
	$class = 2;  # 2 means low quality
    }
    elsif (($gs_rp < (0.6 * $estimated_rp)) && ($avg_contig_sz > 500))
    {
	$class = 3;  # 3 means genome with duplicate contigs
    }
    elsif (($avg_contig_sz < 500) && ($dna < (1.5 * $gs_sz)))
    {
	$class = 4;  # 4 means possible metagenome (lots of short contigs)
    }
    else
    {
	$class = 5;  # 5 means clueless
    }
    my $comment = &encode_attributes([['class',$class],
				      ['average dna-size for species',$gs_sz],
				      ['dna-size',$dna],
				      ['avg. contig sz',$avg_contig_sz],
				      ['reliable placements',join(",",@$reliable_placements)],
				      ['ribosomal proteins',$estimated_rp],
				      ['expected ribosomal proteins',$gs_rp],
				      ['frameshifted ribosomal proteins',$estimated_frameshifts],
				      ['duplicate ribosomal proteins',$estimated_duplicates],
				      ['genetic-code',$gs_gc],
				      ['domain',$gs_domain],
				      ['taxonomy',$gs_tax],
				     ]);

    return ($class,$comment,$gs_gc,$gs_tax);
}

sub encode_attributes {
    my($attr) = @_;

    my @lines;
    foreach $_ (@$attr)
    {
	my $line = join("\t",@$_) . "\n";
	push(@lines,$line);
    }
    return join("",@lines);
}

sub summarize_otu {
    my($estimated_otu,$gs_summary) = @_;

    my @base_otus = split(/,/,$estimated_otu);
    my $sz = 0;
    my $gc;
    my $domain;
    my $tax;
    my $rp;
    my $i = 0;
    for ($i=0; ($i < @base_otus); $i++)
    {
	my $otu_est = $gs_summary->{$base_otus[$i]};
	if (! $otu_est) 
	{
	    return [2000000,11,'Bacteria','Bacteria',50]; # just a guess
	}
	my($sz1,$gc1,$domain1,$tax1,$rp1) = @$otu_est;
	$sz     = int((($sz * $i) + $sz1)/($i+1));
	$gc     = ($i == 0) ? $gc1 : $gc;
	$domain = ($i == 0) ? $domain1 : $domain;
	$tax    = ($i == 0) ? $tax1 : &merge_tax($tax1,$tax);
	$rp     = int((($rp * $i) + $rp1)/($i+1));
    }
    return [$sz,$gc,$domain,$tax,$rp];
}

sub merge_tax {
    my($tax1,$tax2) = @_;

    if (length($tax1) < length($tax2)) { ($tax1,$tax2) = ($tax2,$tax1) }
    my @t1 = split(/,/,$tax1);
    my @t2 = split(/,/,$tax2);
    my($i,$j);
    my $got = 0;
    for ($j = $#t2; (! $got) && ($j >= 0); $j--)
    {
	for ($i = $#t1; ($i >= 0) && ($t1[$i] ne $t2[$j]); $i--) {}
	if ($i >= 0)
	{
	    $got = 1;
	    $#t1 = $i;
	}
    }
    return $got ? join(",",@t1) : $t1[0];
}

sub summarize_potential_genome {
    my($otuS,$contig_set,$estimated_rp,$estimated_frameshifts,$estimated_duplicates) = @_;
}

# typedef tuple<id,comment,sequence> seq_triple;
# typedef list<seq_triple> seq_set;
# typedef tuple<string genus,string species> genus_species;
# typedef tuple<genus_species,int genetic_code,string estimated_taxonomy,seq_set> genome_tuple;
# typedef list<genome_tuple> genome_tuples;
# typedef list<genus_species> otu_set;
# typedef tuple<int count,otu_set> otu_set_counts;
# typedef list<otu_set_counts> otu_data;
# typedef tuple<int start_of_first_hit,int end_of_last_hit,int number_hits,function> call;
# typedef list<call> calls;
# typedef tuple<strand,int offset_of_frame,calls> frame;
# typedef list<frame> frames;
# typedef tuple<length,frames,otu_data> contig_data;
# 
# funcdef call_dna_with_kmers(seq_set) returns (mapping<contig, contig_data>);
##########
# processing NZ_ABWC01000001[351849]
# TRANSLATION	NZ_ABWC01000001	351849	+	0
# CALL	0	29	23	18190	Mobile element protein
# OTU-COUNTS	NZ_ABWC01000001[351849]	69752-122	7444-43516	439-65535
# 
sub call_dna_with_kmers {
    my($seq_set,$otuH) = @_;


    my $guts = "/home/overbeek/Ross/KBaseServers/KmerEvaluation/bin/kmer_guts";
    my $dataD = "/home/overbeek/Ross/KBaseServers/KmerEvaluation/Data";
    my $tmpF = "$$.tmp.fasta";
    gjoseqlib::write_fasta($tmpF,$seq_set);
    if (! $otuH) 
    {
	$otuH = &load_otu_index($dataD);
    }
    open(KMER,"$guts -D $dataD < $tmpF |")
	|| die "could not run kmer_guts";
    my $contigH = {};
    my $last;
    while (($last = <KMER>) && ($last =~ /^processing\s+(\S+)\[(\d+)\]$/))
    {
	my $id        = $1;
	my $contig_ln = $2;
	my $frames = [];
	$last = <KMER>;
	while ($last && ($last =~ /^TRANSLATION\t\S+\t\d+\t(\S)\t(\d)/))
	{
	    my $strand = ($1 eq '+') ? 0 : 1;
	    my $offset = $2;
	    push(@$frames,[$strand,$offset,[]]);
	    $last = <KMER>;
	    while ($last && ($last =~ /^CALL\t(\d+)\t(\d+)\t(\d+)\t\d+\t(.*)$/))
	    {
		push(@{$frames->[-1]->[2]},[$1,$2,$3,$4]);
		$last = <KMER>;
	    }
	}
	my $otu_data = [];
	if ($last =~ /^OTU-COUNTS\t\S+\t(\S.*\S)/)
	{
	    my $counts = $1;
	    $otu_data  = [map { my($count,$otu) = split(/-/,$_); [$count,$otuH->{$otu}] } split(/\t/,$counts)];
	}
	$contigH->{$id} = [$contig_ln,$frames,$otu_data];
    }
    close(KMER);
    unlink($tmpF);
    return $contigH;
}

sub call_aa_with_kmers {
    my($seq_set,$otuH) = @_;

    my $guts = "/home/overbeek/Ross/KBaseServers/KmerEvaluation/bin/kmer_guts";
    if (! $otuH)
    {
	my $dataD = "/home/overbeek/Ross/KBaseServers/KmerEvaluation/Data";
	$otuH = &load_otu_index($dataD);
    }
    my $idH = {};
    my $tmpF = "/tmp/$$.tmp.fasta";
    gjoseqlib::write_fasta($tmpF,$seq_set);

    my $dataD = "/home/overbeek/Ross/KBaseServers/KmerEvaluation/Data";
    open(KMER,"$guts -a -D $dataD < $tmpF |")
	|| die "could not run kmer_guts";

#   typedef tuple<string genus,string species> genus_species;
#   typedef list<genus_species> otu_set;
#   typedef tuple<int count,otu_set> otu_set_counts;
#   typedef list<otu_set_counts> otu_data;
#   typedef tuple<int start_of_first_hit,int end_of_last_hit,int number_hits,function> call;
#   typedef list<call> calls;
#   funcdef call_prot_with_kmers(seq_set) returns (mapping<id, tuple<calls, otu_data>>);

# PROTEIN-ID	fig|713603.3.peg.1
# CALL	0	626	557	28090	tRNA uridine 5-carboxymethylaminomethyl modification enzyme GidA
# OTU-COUNTS	fig|713603.3.peg.489[127]	120064-454	4530-356	1674-511716	249-526331	1-50130

    my $last;
    while (($last = <KMER>) && ($last =~ /^PROTEIN-ID\s+(\S+)/))
    {
	my $id = $1;
	my $calls = [];
	while (($last = <KMER>) && ($last =~ /^CALL\t(\d+)\t(\d+)\t(\d+)\t\d+\t(.*)$/))
	{
	    push(@$calls,[$1,$2,$3,$4]);
	}
	my $otu_data = [];
	if ($last =~ /^OTU-COUNTS\t\S+\t(\S.*\S)/)
	{
	    my $counts = $1;
	    $otu_data  = [map { my($count,$otu) = split(/-/,$_); [$count,$otuH->{$otu}] } split(/\t/,$counts)];
	}
	$idH->{$id} = [$calls,$otu_data];
    }
    close(KMER);
    unlink($tmpF);

    return $idH;
}

sub load_gs_data {
    my($dataD) = @_;

    my $idH = {};
    open(GSD,"<","$dataD/gs.data") || die "could not open $dataD/gs.data";
    while (defined($_ = <GSD>))
    {
	chop;
	my($gs,$dna_sz,$genetic_code,$domain,$tax,$rp) = split(/\t/,$_);
	$idH->{$gs} = [$dna_sz,$genetic_code,$domain,$tax,$rp];
    }
    close(GSD);
    return $idH;
}

sub load_otu_index
{
    my($dataD) = @_;

    my $idH = {};
    foreach $_ (`cat $dataD/otu.index`)
    {
	if ($_ =~ /^(\d+)\t(\S+)\s+(\S+)$/)
	{
	    $idH->{$1} = [[$2,$3]];
	}
	elsif ($_ =~ /^(\d+)\t(\S+)$/)
	{
	    my $otu = $1;
	    my $set = $2;
	    my @entries = split(/,/,$set);
	    $idH->{$otu} = [map { $idH->{$_}->[0] } @entries];
	}
    }
    return $idH;
}


1;
