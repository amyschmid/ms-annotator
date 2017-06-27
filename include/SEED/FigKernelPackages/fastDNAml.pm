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

package fastDNAml;

use tree_utilities;
use Carp;
require Exporter;
@ISA = (Exporter);
@EXPORT = qw(
	     fastDNAml
);

# Example: 
#   $ans = fastDNAml([["id1","acgtacgt"],["id2","acgt-cgt"]],[[jumble,13],
#                                                             [weights,"01010101"],
#                                                             ["categories","ABCD1234"]],
#
# The answer is a list of [LogLikelihood,Tree] pairs
#

%codes   = (
	    "bootstrap"       => "B",
	    "categories"      => "C",
	    "fast_add"        => "Q",
	    "frequencies"     => "F",
	    "global"          => "G",
	    "jumble"          => "J",
	    "restart"         => "R",
	    "treefile"        => "Y",
	    "transition"      => "T",
	    "userlengths"     => "U",
	    "weights"         => "W",
	    );
    

sub fastDNAml {
    my($id_seqs,$options) = @_;
    my($tmp,$functor,$arity,$opt,$code,$num_seqs,$len_seqs);
    my($n,$rate,$rates,$i,$x,$tree);
   
    $added_n = 1;

    @translated = ();
    foreach $pair (@$id_seqs)
    {
	$id = $pair->[0];
	if ((index($id,"_") >= 0) || (length($id) > 10))
	{
	    $id1 = "ZZadded$added_n";
	    $added_n++;
	    $pair->[0] = $id1;
	    push(@translated,[$id,$id1]);
#	    print STDERR "$id -> $id1\n";
	}
    }

    &fix_options($options);
    mkdir("Tmp$$",0777);
    $num_seqs = @$id_seqs;
    $tmp = $id_seqs->[0]->[1];
    $tmp =~ s/\s//g;
    $len_seqs = length($tmp);
    $tmp = "Tmp$$/tmp$$";

    open(TMP,">$tmp") || die "could not open $tmp";
    print TMP "$num_seqs $len_seqs ";
    foreach $opt (@$options)
    {
	$functor = $opt->[0];
	$arity   = $#{$opt} - 1;
	if (($code = $codes{$functor}) &&
	    (! (($functor eq "frequencies") && ($arity == 4))))
	{
	    print TMP " $code";
	}
    }
    print TMP "\n";

    foreach $opt (@$options)
    {
	$functor = $opt->[0];
	$arity   = $#{$opt};
	if    (($functor eq "bootstrap") && ($arity == 1))
	{
	    print TMP "B $opt->[1]\n";
	}
	elsif (($functor eq "global") && ($arity == 1))
	{
	    print TMP "G $opt->[1]\n";
	}
	elsif (($functor eq "global") && ($arity == 2))
	{
	    print TMP "G $opt->[1] $opt->[2]\n";
	}
	elsif (($functor eq "jumble") && ($arity == 1))
	{
	    print TMP "J $opt->[1]\n";
	}
	elsif (($functor eq "transition") && ($arity == 1))
	{
	    print TMP "T $opt->[1]\n";
	}
	elsif (($functor eq "treefile") && ($arity == 1))
	{
	    print TMP "Y $opt->[1]\n";
	}
	elsif (($functor eq "categories") && ($arity == 2))
	{
	    $n = $#{$opt->[1]} + 1;
	    print TMP "C $n";
	    $rates = $opt->[1];
	    foreach $rate (@$rates)
	    {
		print TMP " $rate";
	    }
	    print TMP "\n";
	    print TMP "Categories  $opt->[2]\n";
	}
	elsif (($functor eq "weights") && ($arity == 1))
	{
	    print TMP "Weights     $opt->[1]\n";
	}
	elsif (($functor eq "frequencies") && ($arity == 4))
	{
	    print TMP "$opt->[1] $opt->[2] $opt->[3] $opt->[4]\n";
	}
    }
    foreach $pair (@$id_seqs)
    {
	($id,$seq) = @$pair;
	$pad = " " x (13 - length($id));
	print TMP "$id$pad$seq\n";
#	print STDERR "seq: $id\n";
    }

    for ($i=0; ($i <= $#{$options}) && ($options->[$i]->[0] ne "usertree"); $i++) {}
    if ($i <= $#{$options})
    {
	$trees = $options->[$i]->[1];
	$n     = $#{$trees} + 1;
	print TMP "$n\n";
	foreach $tree (@$trees)
	{
	    $x = &to_translated_newick($tree);
	    print TMP "$x\n";
	}
    }

    for ($i=0; ($i <= $#{$options}) && ($options->[$i]->[0] ne "restart"); $i++) {}
    if ($i <= $#{$options})
    {
	$tree = $options->[$i]->[1];
	$x = &to_translated_newick($tree);
	print TMP "$x\n";
    }
    close(TMP);
    system "cd Tmp$$; fastDNAml < tmp$$ > output; cd ..";

    @trees = glob("Tmp$$/treefile*");
    if (@trees != 1)
    {
	confess "no tree produced by fastDNAml - look in Tmp$$";
    }
    system "cd Tmp$$; mv treefile.* fastDNAml_tree; cd ..";
    @trees = `cat Tmp$$/fastDNAml_tree`;
    $trees = [];
    foreach $tree (@trees)
    {
	if ($tree =~ /^.*\[.*likelihood\s*=\s*([0-9.,e-]+),.*\]\s*(\S.*\S)\s*$/)
	{
	    $lk = $1; $just_tree = $2;
	    $just_tree =~ s/\'//g;
	    foreach $pair (@translated)
	    {
		$just_tree =~ s/\b$pair->[1]\b/$pair->[0]/g;
	    }
	    $parsed = &parse_newick_tree($just_tree);
	    push(@$trees,[$lk,$parsed]);
	}
    }
    system "/bin/rm -r Tmp$$";
    return $trees;
}
	
sub to_translated_newick {
    my($tree) = @_;
    my($x,$pair,$y);

    $x = &to_newick($tree);
    foreach $pair (@translated)
    {
	$y = quotemeta($pair->[0]);
	$x =~ s/\b$y\b/$pair->[1]/g;
    }
    return $x;
}

sub memberchk {
    my($opt,$options) = @_;
    my($i);

    for ($i=0; ($i <= $#{$options}) && ($options->[$i]->[0] ne $opt); $i++) {}
    return ($i <= $#{$options});
}

sub fix_options {
    my($options) = @_;
    my($i,$x);

    if (! (&memberchk("bootstrap",$options) ||
	   &memberchk("jumble",$options) ||
	   &memberchk("transition",$options) ||
	   &memberchk("weights",$options) ||
	   &memberchk("categories",$options)))
    {
	unshift(@$options,["transition",2.0]);
    }
    
    for ($i=0; ($i <= $#{$options}) && ($options->[$i]->[0] ne "frequencies"); $i++) {}
    if ($i <= $#{$options})
    {
	$x = $options->[$i];
	splice(@$options,$i,1);
	push(@$options,$x);
    }
    else
    {
	push(@$options,["frequencies"]);
    }

    for ($i=0; ($i <= $#{$options}) && ($options->[$i]->[0] ne "global"); $i++) {}
    if ($i <= $#{$options})
    {
	$x = $options->[$i];
	splice(@$options,$i,1);
	unshift(@$options,$x);
    }

    for ($i=0; ($i <= $#{$options}) && ($options->[$i]->[0] ne "treefile"); $i++) {}
    if ($i <= $#{$options})
    {
	$x = $options->[$i];
	splice(@$options,$i,1);
	unshift(@$options,$x);
    }
    else
    {
	unshift(@$options,["treefile"]);
    }
}
	

