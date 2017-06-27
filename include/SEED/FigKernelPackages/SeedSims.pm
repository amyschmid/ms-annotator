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

package SeedSims;

use FIG;
use Data::Dumper;

sub load_seed_sims {

    my $dir = "$FIG_Config::data/SimPart";

    if (! -d "$dir")
    {
	system "$FIG_Config::bin/partition_prots 20000 2> /dev/null | make_sim_part_data $dir";
    }

    ((-s "$dir/SimilarityPartitions") &&
     (-s "$dir/ToSimilarityPartition") &&
     (-d "$dir/Partitions"))
	|| die "$dir did not get built properly";

    my $fig = new FIG;
    my $dbf = $fig->db_handle;

    my @tmp = `tail -n 1 $dir/ToSimilarityPartition`;

    my $rebuild = 1;
    if ($fig->table_exists('ToSimilarityPartition') &&
	(@tmp == 1) && ($tmp[0] =~ /^(\d+)\t(\S+)/))
    {
	my $part = $1;
	my $md5 = $2;
	my $db_loc = $dbf->SQL("SELECT partition FROM ToSimilarityPartition WHERE md5_hash = '$md5'");
	my $x = $db_loc->[0]->[0];
	$rebuild = ($x ne $part);
    }

    if ($rebuild)
    {
	print STDERR "loading similarity partition data\n";

	$dbf->drop_table( tbl => "fc_scores" );
	$dbf->create_table( tbl  => "fc_scores",
			    flds => "partition1 integer, partition2 integer, score integer"
			    );
	$dbf->load_table( tbl => "fc_scores", 
			  file => "$dir/PartitionFC"
			  );
    
	$dbf->create_index( idx  => "fc_scores_peg1_ix",
			    tbl  => "fc_scores",
			    type => "btree",
			    flds => "partition1" );

	$dbf->create_index( idx  => "fc_scores_sc_ix",
			    tbl  => "fc_scores",
			    type => "btree",
			    flds => "score" );

	$dbf->drop_table( tbl => "SimilarityPartitions" );

	$dbf->create_table( tbl  => "SimilarityPartitions",
			    flds => "partition integer, md5_hash varchar(32)"
			    );
	$dbf->load_table( tbl => "SimilarityPartitions", 
			  file => "$dir/SimilarityPartitions"
			  );
    
	$dbf->create_index( idx  => "partition_ix",
			    tbl  => "SimilarityPartitions",
			    type => "btree",
			    flds => "partition" );

	$dbf->create_index( idx  => "hash_ix",
			    tbl  => "SimilarityPartitions",
			    type => "btree",
			    flds => "md5_hash" );


	$dbf->drop_table( tbl => "ToSimilarityPartition" );
	$dbf->create_table( tbl  => "ToSimilarityPartition",
			    flds => "partition integer, md5_hash varchar(32)"
			    );
	$dbf->load_table( tbl => "ToSimilarityPartition", 
			  file => "$dir/ToSimilarityPartition"
			  );
    
	$dbf->create_index( idx  => "partition_ix",
			    tbl  => "ToSimilarityPartition",
			    type => "btree",
			    flds => "partition" );

	$dbf->create_index( idx  => "hash_ix",
			    tbl  => "ToSimilarityPartition",
			    type => "btree",
			    flds => "md5_hash" );

	$dbf->drop_table( tbl => "PartitionReps" );
	$dbf->create_table( tbl  => "PartitionReps",
			    flds => "partition integer, md5_hash1 varchar(32), md5_hash2 varchar(32)"
			    );
	$dbf->load_table( tbl => "PartitionReps", 
			  file => "$dir/representatives"
			  );
    
	$dbf->create_index( idx  => "representatives_partition_ix",
			    tbl  => "PartitionReps",
			    type => "btree",
			    flds => "partition" );

	$dbf->create_index( idx  => "representatives_md5_ix",
			    tbl  => "PartitionReps",
			    type => "btree",
			    flds => "md5_hash1" );

	print STDERR "finished loading similarity partition data\n";
    }
}

sub representative_of {
    my($fig,$partition,$md5) = @_;

    my $dbf = $fig->db_handle;
    my $rep = $dbf->SQL("SELECT md5_hash2 FROM ToSimilarityPartition,PartitionReps WHERE 
                         (PartitionReps.md5_hash1 = '$md5') AND 
                         (ToSimilarityPartition.md5_hash = '$md5') AND
                         (ToSimilarityPartition.partition = $partition)");
    
    return ($rep && (@$rep == 1)) ? $rep->[0]->[0] : undef;
}

sub seed_sims {
    my($peg,$parms) = @_;

    &load_seed_sims;
    my $fig = new FIG;
    my $md5 = $fig->md5_of_peg($peg);
#    print STDERR "before md5 sims\n";
    my @simsH = &md5_sims($md5,$parms);
#    print STDERR "after md5 sims\n";
    my $sim;
    my @sims = ();
    foreach $sim (@simsH)
    {
	$sim->[0] = $peg;
	my $md5 = $sim->[1];
	my @pegs = $fig->pegs_with_md5($md5);
	foreach my $peg1 (@pegs)
	{
	    my $sim1 = bless([@$sim],'Sim');
	    if ($peg1 ne $peg)
	    {
		$sim1->[1] = $peg1;
		push(@sims,$sim1);
	    }
	}
    }
    return @sims;
}

sub md5_sims {
    my($md5,$parms) = @_;

    my @sims = ();
    my $fig = new FIG;
    my $dbf = $fig->db_handle;
    if (! $md5)
    {
	print STDERR "MISSING MD5 HASH for $peg\n";
	return ();
    }
    my $seq1 = &seq_with_md5($fig,$md5);
    my @blastout;
    if ($seq1)
    {
	my $ln1 = length($seq1);
	my $tmpF = "$FIG_Config::temp/md5$$.fasta";
	open(TMP,">$tmpF") || die "could not open $tmpF";
	print TMP ">$md5\n$seq1\n";
	close(TMP);

	my $db_loc = $dbf->SQL("SELECT partition FROM ToSimilarityPartition WHERE md5_hash = '$md5'");
	my $x = $db_loc->[0]->[0];
	if ($x)
	{
	    my $dir1 = $x % 1000;
	    my $partF = "$FIG_Config::data/SimPart/Partitions/$dir1/$x";
	    if (! ((-s "$partF.psq") && ((-M $partF) > (-M "$partF.psq"))))
	    {
		system "$FIG_Config::ext_bin/formatdb -i $partF -p T";
	    }

#	    print STDERR "before blast\n";
	    @blastout = map { chop; bless([split(/\s+/,$_),$ln1],'Sim') }
	                   `blastall -i $tmpF -d $partF -p blastp -m 8 -e 0.01 $parms`;
	    my %ln2 = map { $_ =~ /^(\S+)\t(\S+)/; $1 => $2 } `cut -f1,2 $partF.summary`;

	    my $sim;
	    foreach $sim (@blastout)
	    {
		my $ln2 = $ln2{$sim->id2};
		if ($ln2)
		{
		    push(@$sim,$ln2);
		    push(@sims,$sim);
		}
	    }
	}
	unlink $tmpF;
    }
#   return @sims;
    return @blastout;
}

sub seq_with_md5 {
    my($fig,$md5) = @_;

    my @pegs = $fig->pegs_with_md5($md5);

    my($i,$x);
    for ($i=0; ($i < @pegs) && (! ($x = $fig->get_translation($pegs[$i]))); $i++) {}
    if ($i == @pegs)
    {
	return undef;
    }
    $x =~ s/\*$//;
    return $x;
}

sub length_of_seq_with_md5 {
    my($fig,$md5) = @_;

    my @pegs = $fig->pegs_with_md5($md5);

    my($i,$x);
    for ($i=0; ($i < @pegs) && (! ($x = $fig->translation_length($pegs[$i]))); $i++) {}
    if ($i == @pegs)
    {
	return undef;
    }
    return $x;
}

sub md5_to_sim_set {
    my($md5) = @_;

    my $fig = new FIG;
    my $dbf = $fig->db_handle;

    my $db_loc = $dbf->SQL("SELECT partition FROM ToSimilarityPartition WHERE md5_hash = '$md5'");
    my $x = defined($db_loc->[0]->[0]) ? $db_loc->[0]->[0] : undef;
}

sub partition_coupling_evidence {
    my($fig,$ss1,$ss2) = @_;

    if ($ss1 && $ss2)
    {
	my $in1 = &load_locs($ss1);
	my $in2 = &load_locs($ss2);
	my @pairs = ();
	foreach my $genome (sort keys(%$in1))
	{
	    my($xH1,$xH2);
	    if ($xH1 = $in1->{$genome})
	    {
		$xH2 = $in2->{$genome};

		my($contig,$YL1,$YL2);
		foreach $contig (keys(%$xH1))
		{
		    if ($YL2 = $xH2->{$contig})
		    {
			$YL1 = $xH1->{$contig};
			my $i1;
			my $i2;
			for ($i1 =0; ($i1 < @$YL1); $i1++)
			{
			    for ($i2=0; ($i2 < @$YL2); $i2++)
			    {
				if (($YL1->[$i1]->[2] ne $YL2->[$i2]->[2]) && 
				    &close_enough($YL1->[$i1],$YL2->[$i2]))
				{
				    push(@pairs,[$YL1->[$i1],$YL2->[$i2]]);
				}
			    }
			}
		    }
		}
	    }
	}
	# @pairs now contains the relevant pairs of PEGs as evidence of coupling
	my $score = &score_pairs($fig,\@pairs);
	return ($score,\@pairs);
    }
}

sub close_enough {
    my($x,$y) = @_;

    return abs($x->[0] - $y->[0]) < 5000;
}

sub score_pairs {
    my($fig,$pairs) = @_;

    my %md5_vals;
    foreach my $pair (@$pairs)
    {
	my $rep = $pair->[0]->[3];
	if (my $rep1 = &representative_of($fig,$pair->[0]->[4],$rep))
	{
	    $rep = $rep1;
	}
	$md5_vals{$rep}++;
    }
    return scalar keys(%md5_vals);
}

sub load_locs {
    my($ss) = @_;
    
    my $file = &summary_file($ss);
    my $locs = {};
    open(TMP,"cut -f1,3 $file |") || die "could not open $file";
    while (defined($_ = <TMP>))
    {
	if ($_ =~ /^(\S+)\t(\S+)/)
	{
	    my $md5 = $1;
	    my $peg_info = $2;
	    my @peg_locs = split(/;/,$peg_info);
	    foreach my $peg_loc (@peg_locs)
	    {
		if ($peg_loc =~ /^(fig\|(\d+\.\d+)\.peg\.\d+),(\S+)/)
		{
		    my $peg = $1;
		    my $genome = $2;
		    my $loc    = $3;
		    my($contig,$beg,$end) = &FIG::boundaries_of($loc);
		    push(@{$locs->{$genome}->{$contig}},[&FIG::min($beg,$end),&FIG::max($beg,$end),$peg,$md5,$ss]);
		}
	    }
	}
    }
    close(TMP);
    return $locs;
}

sub summary_file {
    my($x) = @_;

    my $dir1 = $x % 1000;
    my $summF = "$FIG_Config::data/SimPart/Partitions/$dir1/$x.summary";
    return (-s $summF) ? $summF : undef;
}

1;
