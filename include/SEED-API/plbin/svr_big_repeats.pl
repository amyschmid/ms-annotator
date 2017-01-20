########################################################################
use strict;
use Data::Dumper;
use Carp;

#
# This is a SAS Component
#


=head1 svr_big_repeats [-i MinIdentity] [-l MinLength] [-g Genome] [-f FastaContigs] [-t Features] > repeats

Find regions that appear to be big repeats (at the DNA level).

------
=head2 Command-Line Options

If neither the -g or the -f option are specified, contigs will be read from STDIN.

=over 4

=item -i MinIdentity

To be considered a repeat, the blast must show identity values greater than this parameter. (defaults to 95).

=item -l MinLength

This is the minimum length of an identified region of similarity (default is 100)

=item -g Genome

Run the program on contigs from this genome

=item -f FastaContigs

A file containing the contigs for a genome in fasta format.

=item -t Features

If this is specified it names a file that contains feature IDs and
locations.  The right way to get such a file is to concatenate the tbl files
from a RAST/myRAST/SEED directory.

=back

=head2 Output Format

The output is a 6-column table of the form

    [LengthOfRepeat,Identity,Contig1,Beg1,End1,Contig2,Beg2,End2]

If the -t option is specied, you will get extra lines listing the 
features (and their locations) that occur in the similar regions.

=cut

use SeedEnv;
use SAPserver;
use Getopt::Long;

my $usage = "usage: svr_big_repeats [-i MinIdentity] [-l MinLength] [-g Genome] [-f FastaContigs] [-t MergedTbls > repeats";

my $min_iden = 95;
my $min_len  = 100;
my $genome;
my $fastaF;
my $tbl;

my $rc  = GetOptions('i=i' => \$min_iden,
		     'l=i' => \$min_len,
		     'g=s' => \$genome,
		     't=s' => \$tbl,
		     'f=s' => \$fastaF);

if (! $rc) { print STDERR $usage; exit }
my $tmp = "tmp.$$.fasta";
&get_contigs($genome,$fastaF,$tmp);
&get_repeats($tmp,$tbl);
unlink($tmp,"$tmp.nsq","$tmp.nin","$tmp.nhr");

sub get_contigs {
    my($genome,$fastaF,$tmp) = @_;

    if ($genome)
    {
	my $sapO = SAPserver->new;
	my $gH = $sapO->genome_contigs( -ids => [$genome] );
	my $contigs = $gH->{$genome};
	($contigs && (@$contigs > 0))
	    || die "could not get the contigs for $genome";
	my $contigH = $sapO->contig_sequences( -ids => $contigs );
	open(TMP,">",$tmp) || die "could not open $tmp";
	foreach my $contig (@$contigs)
	{
	    my $seq = $contigH->{$contig};
	    $contig =~ s/^.*://;
	    print TMP ">$contig\n$seq\n";
	}
	close(TMP);
    }
    elsif ($fastaF && (-s $fastaF))
    {
	open(TMP,">",$tmp) || die "could not open $tmp";
	open(FASTA,"<",$fastaF) || die "could not open $fastaF";
	while (defined($_ = <FASTA>))
	{
	    print TMP $_;
	}
	close(FASTA);
	close(TMP);
    }
    else
    {
	open(TMP,">",$tmp) || die "could not open $tmp";
	while (defined($_ = <STDIN>))
	{
	    print TMP $_;
	}
	close(TMP);
    }
}

sub get_repeats {
    my($tmp,$tbl) = @_;

    my %fid_locs;
    if ($tbl && open(TBL,"<",$tbl))
    {
	while (defined($_ = <TBL>))
	{
	    if ($_ =~ /^(\S+)\t(\S+)/)
	    {
		my $fid = $1;
		my($contig,$min,$max) = &SeedUtils::boundaries_of($2);
		push(@{$fid_locs{$contig}},[$fid,$min,$max]);
	    }
	}
    }

    &SeedUtils::run("formatdb -i $tmp -p F");
    open(BLAST,"blastall -d $tmp -i $tmp -FF -m8 -p blastn -e 1.0e-100 |")
	|| die "could not run blastall -d $tmp -i $tmp -FF -m8 -p blastn -e 1.0e-100";
    my %seen;
    while (defined($_ = <BLAST>))
    {
	chop;
	my @flds = split(/\s+/,$_);
	my($id1,$id2,$ident,undef,undef,undef,$b1,$e1,$b2,$e2,$psc,$bsc) = @flds;
	if ($id1 gt $id2)                  { ($id1,$id2,$b1,$e1,$b2,$e2) = ($id2,$id1,$b2,$e2,$b1,$e1) }
	if (($id1 eq $id2) && ($b1 > $b2)) { ($id1,$id2,$b1,$e1,$b2,$e2) = ($id2,$id1,$b2,$e2,$b1,$e1) }
	if ($b1 > $e1)     { ($b1,$e1,$b2,$e2) = ($e1,$b1,$e2,$b2) }
	if ((($id1 ne $id2) || (! &overlaps($b1,$e1,$b2,$e2))) &&
	    ($ident >= $min_iden) && ($min_len <= (abs($e1-$b1)+1)))
	{
	    my $out = join("\t",($id1,$b1,$e1,$id2,$b2,$e2));
	    if (! $seen{$out})
	    {
		$seen{$out} = 1;
		print abs($e1+1-$b1),"\t$ident\t$out";
		if ($tbl)
		{
		    my $overlapping1 = &get_overlapping_fids(\%fid_locs,$id1,$b1,$e1);
		    my $overlapping2 = &get_overlapping_fids(\%fid_locs,$id2,$b2,$e2);
		    print "\t$overlapping1\t$overlapping2";
		}
		print "\n";
	    }
	}
    }
    close(BLAST);
}

sub get_overlapping_fids {
    my($fid_locs,$contig,$b,$e) = @_;

    my $fids_on_contig = $fid_locs->{$contig};
    if ($fids_on_contig)
    {
	my @matches = sort { &SeedUtils::by_fig_id($a,$b) }
	              map { &overlaps($b,$e,$_->[1],$_->[2]) ? $_->[0] : () } 
	              @$fids_on_contig;
	return join(",",@matches);
    }
    return "";
}

sub overlaps {
    my($b1,$e1,$b2,$e2) = @_;

    return &SeedUtils::between($b1,$b2,$e1) || &SeedUtils::between($b2,$b1,$e2);
}
