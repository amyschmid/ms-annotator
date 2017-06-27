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

package SimFC;

use DB_File;

use FIG;
use Data::Dumper;

sub generate_partitions {
    my($fig,$max_sz) = @_;
    my $partitionsF = "$FIG_Config::temp/partitions.$$";
    open(PART,">$partitionsF")  || die "could not open $partitionsF";
    my %prot_hash;
    my %seen_hash;
    &build_hashes($fig,\%prot_hash,\%seen_hash,$max_sz);

    my @all = sort keys(%prot_hash);
    my $n = @all;
    print STDERR "$n proteins to process\n";
    
    my $i;
    for ($i=0; ($i < @all); $i++)
    {
	if (! $seen_hash{$all[$i]})
	{
	    print STDERR "processing $all[$i], $i of $#all\n";
	    &process_one_peg($fig,$all[$i],\%seen_hash,\%prot_hash,$max_sz,\$n,\*PART);
	}
	else
	{
	    print STDERR "seen $all[$i]\n";
	}
    }
    close(PART);
    return $partitionsF;
}

sub process_one_peg {
    my($fig,$prot,$seen,$prot_hash,$max_sz,$nP,$fh) = @_;

    my %in;
    $in{$prot} = 1;
    my %closest;
    $closest{$prot} = 0;

    my $sz = 1;
    my $peg = $prot;
    while (($sz < $max_sz) && defined($peg))
    {
	$$nP--;
	delete $closest{$peg};
	my @sims = $fig->sims($peg,10000,1,'raw');
	foreach my $sim (@sims)
	{
	    my $id2 = $sim->id2;
	    if ($prot_hash->{$id2})
	    {
		if (! $in{$id2})
		{
		    $in{$id2} = 1;
		    $sz++;
		    $closest{$id2} = $sim->bsc;
		}
		elsif (defined($closest{$id2}) && ($closest{$id2} < $sim->bsc))
		{
		    $closest{$id2} = $sim->bsc;
		}
	    }
	}
	$seen->{$peg} = 1;
	print $fh "IN\t$prot\t$peg\n";
	$peg = &the_closest(\%closest,$seen);
    }
    print STDERR "$$nP left\n";
    foreach $_ (sort keys(%in))
    {
	print $fh join("\t",('SET',$prot,$_)),"\n";
    }
}

sub the_closest {
    my($closest,$seen) = @_;

    my($peg,$x,$peg1,$x1);
    while (($peg1,$x1) = each %$closest)
    {
	if ((! $seen->{$peg1}) && ((! defined($peg1)) || ($x1 > $x)))
	{
	    $peg = $peg1;
	    $x = $x1;
	}
    }
    return $peg;
}

sub build_hashes {
    my($fig,$prot_hash,$seen_hash,$sz) = @_;

    my($prot_hash_tie,$seen_hash_tie);
#    $prot_hash_tie = tie %$prot_hash, 'DB_File',"partition_prot_hash_$sz.db",O_RDWR,0666,$DB_BTREE;
#    $seen_hash_tie = tie %$seen_hash, 'DB_File',"seen_hash_$sz.db",O_RDWR,0666,$DB_BTREE;
#    return;

    $prot_hash_tie = tie %$prot_hash, 'DB_File',"partition_prot_hash_$sz.db",O_CREAT,0666,$DB_BTREE;
    $prot_hash_tie || die "tie failed";

    $seen_hash_tie = tie %$seen_hash, 'DB_File',"seen_hash_$sz.db",O_CREAT,0666,$DB_BTREE;
    $seen_hash_tie || die "tie failed";

    open(SYMS,"<$FIG_Config::global/peg.synonyms")
	|| die "could not open peg.synonyms";
    while (defined($_ = <SYMS>))
    {
	chop;
	my($head,$rest) = split(/\t/,$_);
	if ($rest =~ /fig\|/)
	{
	    my @fig = map { ($_ =~ /(fig\|\d+\.\d+\.peg\.\d+)/) ? $1 : () } split(/;/,$rest);
	    @fig = grep { $fig->is_complete(&FIG::genome_of($_)) } @fig;
	    if (@fig > 0)
	    {
		$head =~ s/,\d+$//;
		$prot_hash->{$head} = 1;
		foreach my $peg (@fig)
		{
		    $seen_hash->{$peg} = 1;
		}
	    }
	}
    }
    foreach my $genome ($fig->genomes('complete'))
    {
	foreach my $peg ($fig->all_features($genome,'peg'))
	{
	    if (! $seen_hash->{$peg})
	    {
		$prot_hash->{$peg} = 1;
	    }
	}
    }
}

sub build_partition_directories {
    my($fig,$partitionsF,$dir) = @_;

    if (-d $dir) { die "$dir already exists" }

    mkdir($dir,0777) || die "could not make $dir";

    my $partD = "$dir/Partitions";
    my $simF  = "$dir/SimilarityPartitions";
    my $relF  = "$dir/ToSimilarityPartition";

    my %prot_hash;
    &build_expand_hash($fig,\%prot_hash);

    open(SIMPART,">$simF")
	|| die "could not open $simF";
    open(REL,">$relF")
	|| die "could not open $relF";

    mkdir("$partD",0777) || die "could not make $partD";
    my $n = 1;
    open(PART,"<$partitionsF") || die "could not open $partitionsF";
    my $x = <PART>;
    while (defined($x) && ($x =~ /^IN\t(\S+)\t(\S+)/))
    {
	my $currset = $1;
	my @setI = ();
	while (defined($x) && ($x =~ /^IN\t(\S+)\t(\S+)/) && ($1 eq $currset))
	{
	    push(@setI,$2);
	    $x = <PART>;
	}

	my $bug;
	my @setS = ();
	while (defined($x) && ($x =~ /^SET\t(\S+)\t(\S+)/) && ($1 eq $currset))
	{
#	    if ($1 eq 'fig|314291.3.peg.2784') { $bug = 1 }
	    push(@setS,$2);
	    $x = <PART>;
	}
	&process_set($fig,\*SIMPART,\*REL,$partD,\@setI,\@setS,\$n,\%prot_hash,$bug);
    }
    close(SIMPART);
    close(REL);
    close(PART);

    print STDERR "starting to build representative sets for each partition: using 10 processors\n";
    system "make_partition_reps $dir 10 2> $dir/make_partition_reps.stderr > $dir/make_partition_reps.stdout";
}

sub process_set {
    my($fig,$entity_fh,$rel_fh,$partD,$setI,$setS,$nP,$prot_hash,$bug) = @_;
#    if ($bug) { print STDERR &Dumper($setI,$setS) }

    my @reduced = &reduce($fig,$setS,$prot_hash);
#    if ($bug) { print STDERR &Dumper('reduced1',\@reduced); }
    if (@reduced > 1)
    {
	my $md5;
	foreach $md5 (@reduced)
	{
	    print $entity_fh join("\t",($$nP,$md5)),"\n";
	}
	my @reduced_in = &reduce($fig,$setI,$prot_hash);
#	if ($bug) { print STDERR &Dumper('reduced_in',\@reduced_in); }
	foreach $md5 (@reduced_in)
	{
	    print $rel_fh join("\t",($$nP,$md5)),"\n";
	}
	my $dir1 = $$nP % 1000;
	&FIG::verify_dir("$partD/$dir1");
	my $fasta = "$partD/$dir1/$$nP";
	open(FASTA,">$fasta") || die "could not make $partD/$dir1/$$nP";
	open(SUMMARY,">$fasta.summary") || die "could not open $fasta.summary";
	my %locs;
	my $count = 0;

	foreach $md5 (@reduced)
	{
	    my @pegs = grep { $fig->is_real_feature($_) } $fig->pegs_with_md5($md5);
#	    if ($bug) { print STDERR &Dumper([$md5,\@pegs]); }
	    if (@pegs == 0)
	    {
		print STDERR "could not handle hash=$md5\n";
	    }
	    else
	    {
		my($i,$x);
		for ($i=0; ($i < @pegs) && (! ($x = $fig->get_translation($pegs[$i]))); $i++) {}
		if ($i < @pegs)
		{
		    if (length($x) > 10)
		    {
			$count++;
			print FASTA ">$md5\n$x\n";
		    }
		}
		my $hits = join(";",map { "$_," . $fig->feature_location($_) } @pegs);
		print SUMMARY join("\t",($md5,length($x),$hits)),"\n";
	    }
	}
	close(FASTA);
	close(SUMMARY);
	if ($count)
	{
	    system "formatdb -i $fasta -p T";
	}
	$$nP++;
    }
#   if ($bug) { die "aborted" }
}

sub reduce {
    my($fig,$set,$prot_hash) = @_;

    my @setE = ();
    my $x;
    foreach $x (@$set)
    {
	my $toL;
	if ($toL = $prot_hash->{$x})
	{
	    push(@setE,split(/,/,$toL));
	}
	elsif ($x =~ /^fig\|/)
	{
	    push(@setE,$x);
	}
    }
#    print STDERR &Dumper(['expanded',\@setE]);
    my %reduced = map { $_ => 1 } @setE;
    my @reduced_set = sort { &FIG::by_fig_id($a,$b) } keys(%reduced);
 #   print STDERR &Dumper(\@reduced_set);

    my %md5s;
    foreach my $peg (@reduced_set)
    {
#	print STDERR &Dumper($peg);
	my $md5 = $fig->md5_of_peg($peg);
	if ($md5)
	{
	    push(@{$md5s{$md5}},$peg);
	}
    }
    my @md5_set = sort keys(%md5s);
    return @md5_set;
}

sub build_expand_hash {
    my($fig,$prot_hash) = @_;

#    my $prot_hash_tie = tie %$prot_hash, 'DB_File','make_sim_part_prot_hash.db',O_RDWR,0666,$DB_BTREE; return;
    my $prot_hash_tie = tie %$prot_hash, 'DB_File','make_sim_part_prot_hash.db',O_CREAT,0666,$DB_BTREE;
    $prot_hash_tie || die "tie failed";

    open(SYMS,"<$FIG_Config::global/peg.synonyms")
	|| die "could not open peg.synonyms";
    while (defined($_ = <SYMS>))
    {
	chop;
	my($head,$rest) = split(/\t/,$_);
	if ($rest =~ /fig\|/)
	{
	    my @fig = map { ($_ =~ /(fig\|\d+\.\d+\.peg\.\d+)/) ? $1 : () } split(/;/,$rest);
	    @fig = grep { $fig->is_complete(&FIG::genome_of($_)) } @fig;
	    if (@fig > 0)
	    {
		$head =~ s/,\d+$//;
		if ($head =~ /^fig\|/) { push(@fig,$head) }
		$prot_hash->{$head} = join(",",@fig);
	    }
	}
    }
    close(SYMS);
#    print STDERR "prot_hash has been constructed\n";
}

sub make_fc_data {
    my($fig,$dir,$min_occur,$max_dist) = @_;

    my %to_part_hash;
    &load_to_part($dir,\%to_part_hash);

    my %pairs_hash;
    my $pairs_hash_tie = tie %pairs_hash, 'DB_File',"pairs_hash.$$.db",O_CREAT,0666,$DB_BTREE;
    ($pairs_hash_tie) || die "tieing hash failed";


    &count_co_occurrences($fig,\%to_part_hash,\%pairs_hash,$max_dist);
    open(FC,"| sort -k 1,2 -n >$dir/PartitionFC") || die "could not open $dir/PartitionFC";
    while (my($pair,$n) = each(%pairs_hash))
    {
	if ($n >= $min_occur)
	{
	    my($k1,$k2) = split(/\t/,$pair);
	    print FC join("\t",($k1,$k2,$n)),"\n";
	    print FC join("\t",($k2,$k1,$n)),"\n";
	}
    }
    close(FC);
    untie %pairs_hash;
    untie %to_part_hash;
    unlink("to_part_hash.$$.db","pairs_hash.$$.db");
}

sub load_to_part {
    my($dir,$to_part_hash) = @_;

    $to_part_hash_tie = tie %$to_part_hash, 'DB_File',"to_part_hash.28042.db",O_RDWR,0666,$DB_BTREE;
    return;

    my $to_part_hash_tie = tie %$to_part_hash, 'DB_File',"to_part_hash.$$.db",O_CREAT,0666,$DB_BTREE;
    ($to_part_hash_tie) || die "tieing hash failed";

    open(PARTS,"<$dir/ToSimilarityPartition")
	|| die "could not open $dir/ToSimilarityPartition";
    while (defined($_ = <PARTS>))
    {
	if ($_ =~ /^(\d+)\t(\S+)/)
	{
	    $to_part_hash->{$2} = $1;
	}
    }
    close(PARTS);
}



sub count_co_occurrences {
    my($fig,$to_part_hash,$pairs_hash,$max_dist) = @_;

    my $genome;
    foreach $genome (grep { $fig->is_prokaryotic($_) } $fig->genomes('complete'))
    {
	my @loc_md5_pairs;
	foreach my $peg ($fig->all_features($genome,"peg"))
	{
	    my $loc = $fig->feature_location($peg);
	    my($contig,$beg,$end) = &FIG::boundaries_of($loc);
	    my $md5 = $fig->md5_of_peg($peg);
	    my $p1;
	    if ($md5 && $contig && ($p1 = $to_part_hash->{$md5}))
	    {
		push(@loc_md5_pairs,[$contig,&FIG::min($beg,$end),&FIG::max($beg,$end),$p1,$peg]);
	    }
	}
	@loc_md5_pairs = sort { ($a->[0] cmp $b->[0]) or ($a->[1] <=> $b->[1]) or ($a->[2] <=> $b->[2]) }
	                 @loc_md5_pairs;

	my($i,$j);
	for ($i=0; ($i < (@loc_md5_pairs - 1)); $i++)
	{
	    for ($j = $i+1; ($j < @loc_md5_pairs) && 
		            ($loc_md5_pairs[$j]->[0] eq $loc_md5_pairs[$i]->[0]) &&
		            (($loc_md5_pairs[$j]->[1] - $loc_md5_pairs[$i]->[2]) <= $max_dist);
		 $j++)
	    {
		if ($loc_md5_pairs[$i]->[3] ne $loc_md5_pairs[$j]->[3])
		{
		    my $pair = ($loc_md5_pairs[$i]->[3] lt $loc_md5_pairs[$j]->[3]) ?
			       "$loc_md5_pairs[$i]->[3]\t$loc_md5_pairs[$j]->[3]" :
			       "$loc_md5_pairs[$j]->[3]\t$loc_md5_pairs[$i]->[3]";
		    $pairs_hash->{$pair}++;
		}
	    }
	}
    }
}

1;
