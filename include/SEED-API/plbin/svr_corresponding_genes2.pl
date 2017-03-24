########################################################################
use SeedEnv;
use gjoseqlib;

use strict;
use Data::Dumper;
use Carp;
use CorrTableEntry;

=head1 svr_corresponding_genes

Attempt to Tabulate Corresponding Genes from Two Complete Genomes

------
Example: svr_corresponding_genes 107806.1 198804.1

would produce a 18-column table that is an attempt to present the
correspondence between the genes in two genomes (in this case
107806.1 and 198804.1, which are two Buchnera genomes).
------

There is no input other than the command-line arguments.  The two genomes
must be specified, and there are two optional arguments that relate to determining
how to determine the "context" of genes.

One important aspect of the tool is that it tries to establish the correspondence,
and then for a corresponding pair of genes Ga and Gb, it attemptes to determine
how many genes in the "context" of Ga map to genes in the "context" of Gb.  This is 
important, since preservation of context increases the confidence of the mapping
between Ga and Gb considerably.  The optional parameters effect the determination
of the genes in the "context".  Using

    -n 5

would indicate that the context of G should include 5 distinct genes 
to the left of G and 5 distinct genes to the right of G.  This notion of distinct
was added due to the existence of numerous splice variants in some eukaryotic
genomes.  Genes are considered to be distinct if the size of the overlap
between the genes is less than a threshhold.  The threshhold can be set using
the -o parameter.  Thus, use of 

    -o 1000

would indicate that two genes are distinct iff the boundaries of the two genes 
overlap by less than 1000 bp.  The default is a very high value, so if you specify
nothing (which is appropriate for prokaryotic genomes), any two genes will be 
considered distinct.

=head2 Command-Line Options

The program is invoked using

    svr_corresponding_genes [-u ServerUrl] [-n HalfSzOfContext] [-o MaxOverlap] GenomeSpec1 GenomeSpec2

=over 4

=item -n HalfSizeOfRegion

This is used to specify how many genes to the left and right you want to
be considered in the context.  The default is 10.

=item -o MaxOverlap

This allows the user the specify a maximum overlap that would result in two genes
being considered "distinct" in the computation of genes to be added to the context.
It defaults to a very large value.

=item -u ServerUrl

This allows the user to specify the URL for the Sapling server. If it is
"localhost", then the Sapling method will be run on the local SEED.

=item GenomeSpec1

=item GenomeSpec2

Specify a source of genome data. Either a genome ID (that is available in the SEED servers),
a SEED genome directory, or a comma-separated triple (protein fasta file, tbl file, 
function-assignment file).
    
=head2 Output Format

The standard output is a 18-column tab-delimited file:

=item Column-1
The ID of a PEG in Genome1.

=item Column-2

The ID of a PEG in Genome2 that is our best estimate of a "corresponding gene".

=item Column-3
Count of the number of pairs of matching genes were found in the context

=item Column-4

Pairs of corresponding genes from the contexts

=item Column-5

The function of the gene in Genome1

=item Column-6

The function of the gene in Genome2

=item Column-7

Aliases of the gene in Genome1 (any protein with an identical sequence
is considered an alias, whether or not it is actually the name of the
same gene in the same genome)

=item Column-8

Aliases of the gene in Genome2 (any protein with an identical sequence
is considered an alias, whether or not it is actually the name of the
same gene in the same genome)

=item Column-9

Bi-directional best hits will contain "<=>" in this column.
Otherwise, an "->" or an "<-" will appear.    

=item Column-10

Percent identity over the region of the detected match

=item Column-11

The P-sc for the detected match

=item Column-12

Beginning match coordinate in the protein encoded by the gene in Genome1.

=item Column-13

Ending  match coordinate in the protein encoded by the gene in Genome1.

=item Column-14

Length of the protein encoded by the gene in Genome1.

=item Column-15

Beginning match coordinate in the protein encoded by the gene in Genome2.

=item Column-16

Ending  match coordinate in the protein encoded by the gene in Genome2

=item Column-17

Length of the protein encoded by the gene in Genome2.

=item Column-18

Bit score for the match.  Divide by the length of the longer PEG to get
what we often refer to as a "normalized bit score".

=item Column-19

Number of pegs in the context that have matching functions.

=back

=cut

use SeedEnv;
use SeedUtils;
use SAPserver;
use ProtSims;
use SeedAware;
use Getopt::Long;

my $usage = "usage: svr_corresponding_genes [-u SERVERURL] [-o N1] [-n N2] [-d RASTdirectory] Genome1 Genome2";

my $ignore_ov   = 1000000;
my $sz_context  = 5;
my $url;

my $rc    = GetOptions("o"              => \$ignore_ov,
                       "n=i"            => \$sz_context,
                       "u=s"            => \$url
                      );
if (! $rc) { print STDERR $usage; exit }

my $sapObject = SAPserver->new(url => $url);

my($genome1_name, $genome2_name);
(
 ($genome1_name = shift @ARGV) &&
 ($genome2_name = shift @ARGV) 
)
    || die $usage;


my $genome1 = make_genome_source($genome1_name, $sapObject);
$genome1 or die "Cannot load genome data from $genome1_name\n";

my $genome2 = make_genome_source($genome2_name, $sapObject);
$genome2 or die "Cannot load genome data from $genome2_name\n";

#
# If both arguments are genome ids, see if the SAP server
# has already computed this correspondence.
# 
if ((ref($genome1) eq 'SapGenomeSource') &&
    (ref($genome2) eq 'SapGenomeSource'))
{
    my $corr = $sapObject->gene_correspondence_map(-genome1 => $genome1_name,
						   -genome2 => $genome2_name,
						   -fullOutput => 1,
						   -passive => 1);
    #
    # TODO add column 19
    #
    my $fns;
    
    if (defined($corr))
    {
	foreach my $ent (@$corr)
	{
	    my $corr = bless $ent, 'CorrTableEntry';;
	    if (!defined($corr->num_matching_functions))
	    {
		my $count = 0;

		if (!defined($fns))
		{
		    #
		    # Pull all the functions for the given genomes.
		    #
		    my $fidHash  = $sapObject->all_features(-ids => [$genome1_name, $genome2_name], -type => 'peg');
		    $fns = $sapObject->ids_to_functions(-ids => [map { @$_ } values %$fidHash]);
		}

		for my $pair ($corr->pairs)
		{
		    my($p1, $p2) = @$pair;
		    my $f1 = $fns->{$p1};
		    my $f2 = $fns->{$p2};
		    $count++ if $f1 eq $f2;
		}
		$ent->[18] = $count;
	    }
	    print join("\t", @$ent), "\n";
	}
	exit 0;
    }
}

$genome1->init_data();
$genome2->init_data();


my $tmp_dir = SeedAware::location_of_tmp();

my $formatdb = SeedAware::executable_for("formatdb");

my $tmp1 = "$tmp_dir/tmp1_$$.fasta";
my $tmp2 = "$tmp_dir/tmp2_$$.fasta";

my $lens1 =  $genome1->get_fasta($tmp1);
my $lens2 =  $genome2->get_fasta($tmp2);
# print STDERR "GOT SIMS\n";
system($formatdb, '-i', $tmp2, '-p', 'T');

my($sims1,$sims2) = &get_sims($tmp1,$tmp2,$lens1,$lens2);
unlink($tmp1,$tmp2,"$tmp2.psq","$tmp2.pin","$tmp2.phr");

my $functions = {};
$genome1->get_functions($functions);
$genome2->get_functions($functions);

# print STDERR "GOT Functions\n";

my $aliases = {};
$genome1->get_aliases($aliases);
$genome2->get_aliases($aliases);

# print STDERR "GOT Aliases\n";

my($matching_context, $matching_count) = &matching_neighbors($genome1,$sims1,$genome2,$sims2,$sz_context,$ignore_ov);

# print STDERR "GOT Context\n";

foreach my $peg1 (keys(%$lens1))
{
    my $peg2 = $sims1->{$peg1}->[0];
    if ($peg2)
    {
	my $context = "";
	my $context_count = 0;
	my $function2 = "";
	my $aliases2 = "";

	my $function1 = $functions->{$peg1} ? $functions->{$peg1} : "";
	my $aliases1  = $aliases->{$peg1}   ? $aliases->{$peg1} : "";
	my $peg3 = $sims2->{$peg2}->[0]; 
	my $bbh  =  ($peg3  && ($peg3 eq $peg1)) ? "<=>" : "->";

	if ($_ = $matching_context->{"$peg1,$peg2"})  
	{ 
	    $context = $_;
	    $context_count = ($context =~ tr/,//) + 1;
	}

	my($iden,$psc,$b1,$e1,$b2,$e2,$ln1,$ln2,$bitsc);
	(undef,$iden,$psc,$bitsc,$b1,$e1,$b2,$e2,$ln1,$ln2) = @{$sims1->{$peg1}};
	if ($functions->{$peg2})  { $function2 = $functions->{$peg2} }
	if ($aliases->{$peg2})    { $aliases2  = $aliases->{$peg2} }
	my $mcount = $matching_count->{"$peg1,$peg2"};
	$mcount = 0 unless defined($mcount);
	print join("\t",($peg1,$peg2,$context_count,$context,$function1,$function2,
			 $aliases1,$aliases2,$bbh,$iden,$psc,
			 $b1,$e1,$ln1,$b2,$e2,$ln2,$bitsc,$mcount)),"\n";
    }
}

foreach my $peg2 (keys(%$lens2))
{
    my $peg1 = $sims2->{$peg2}->[0];
    if ($peg1)
    {
	my $context = "";
	my $context_count = 0;
	my $function1 = "";
	my $aliases1 = "";

	my $function2 = $functions->{$peg2} ? $functions->{$peg2} : "";
	my $aliases2  = $aliases->{$peg2}   ? $aliases->{$peg2} : "";
	my $peg3 = $sims1->{$peg1}->[0]; 
	if ($peg3 ne $peg2)
	{
	    if ($_ = $matching_context->{"$peg1,$peg2"})  
	    { 
		$context = $_;
		$context_count = ($context =~ tr/,//) + 1;
	    }
	    my $mcount = $matching_count->{"$peg1,$peg2"};
	    $mcount = 0 unless defined($mcount);
	    my($iden,$psc,$b1,$e1,$b2,$e2,$ln1,$ln2,$bitsc);
	    (undef,$iden,$psc,$bitsc,$b2,$e2,$b1,$e1,$ln2,$ln1) = @{$sims2->{$peg2}};
	    if ($functions->{$peg1})  { $function1 = $functions->{$peg1} }
	    if ($aliases->{$peg1})    { $aliases1  = $aliases->{$peg1} }
	    print join("\t",($peg1,$peg2,$context_count,$context,$function1,$function2,
			     $aliases1,$aliases2,"<-",$iden,$psc,
			     $b1,$e1,$ln1,$b2,$e2,$ln2,$bitsc,$mcount)),"\n";
	}	
    }
}

unlink($tmp1);
unlink($tmp2);

sub get_sims {
    my($tmp1,$tmp2) = @_;

    my @sims = &ProtSims::blastP($tmp1,$tmp2,1,1);  # this last argument forces the use of blast, bypassing blat
    my $sims1 = {};
    my $sims2 = {};
    my %seen;
    foreach my $sim (@sims)
    {
	my $id1 = $sim->id1;
	my $id2 = $sim->id2;
	my $iden = $sim->iden;
	my $b1 = $sim->b1;
	my $e1 = $sim->e1;
	my $b2 = $sim->b2;
	my $e2 = $sim->e2;
	my $psc = $sim->psc;
	my $bit_sc = $sim->bsc;

	my $x = $sims1->{$id1};
	if ((! $x) || (($x->[0] ne $id2) && ($psc < $x->[2])))
	{
	    $sims1->{$id1} = [$id2,$iden,$psc,$bit_sc,$b1,$e1,$b2,$e2,$lens1->{$id1},$lens2->{$id2}];
	}
	elsif ($x && ($x->[0] eq $id2))
	{
	    ($b1,$e1,$b2,$e2) = &merge($b1,$e1,$b2,$e2,$x->[4],$x->[5],$x->[6],$x->[7]);
	    $x->[4] = $b1;
	    $x->[5] = $e1;
	    $x->[6] = $b2;
	    $x->[7] = $e2;
	}

	$x = $sims2->{$id2};
	if ((! $x) || (($x->[0] ne $id2) && ($psc < $x->[2])))
	{
	    $sims2->{$id2} = [$id1,$iden,$psc,$bit_sc,$b2,$e2,$b1,$e1,$lens2->{$id2},$lens1->{$id1}];
	}
	elsif ($x && ($x->[0] eq $id2))
	{
	    ($b2,$e2,$b1,$e1) = &merge($b2,$e2,$b1,$e1,$x->[4],$x->[5],$x->[6],$x->[7]);
	    $x->[4] = $b2;
	    $x->[5] = $e2;
	    $x->[6] = $b1;
	    $x->[7] = $e1;
	}
    }
    # close(BLAST); # This file apparently no longer exists ??
    return ($sims1,$sims2);
}

sub merge {
    my($b1a,$e1a,$b2a,$e2a,$b1b,$e1b,$b2b,$e2b) = @_;

    if (($b1a < $b1b) && (abs($b1b - $e1a) < 10) &&
	($b2a < $b2b) && (abs($b2b - $e2a) < 10))
    {
	return ($b1a,$e1b,$b2a,$b2b);
    }
    elsif (($b1b < $b1a) && (abs($b1a - $e1b) < 10) &&
	   ($b2b < $b2a) && (abs($b2a - $e2b) < 10))
    {
	return ($b1b,$e1a,$b2b,$b2a);
    }
    else
    {
	return ($b1b,$e1b,$b2b,$e2b);
    }
}


sub matching_neighbors {
    my($genome1,$sims1,$genome2,$sims2,$sz_context,$ignore_ov) = @_;

    my %by_genome;
    my @peg_loc_tuples_in_genome;

    @peg_loc_tuples_in_genome = $genome1->get_peg_loc_tuples();
    $by_genome{$genome1} = &set_neighbors(\@peg_loc_tuples_in_genome, $sz_context, $ignore_ov);

    @peg_loc_tuples_in_genome = $genome2->get_peg_loc_tuples();
    $by_genome{$genome2} = &set_neighbors(\@peg_loc_tuples_in_genome, $sz_context, $ignore_ov);
    
    my %matched_pairs;
    my %matching_count;
    foreach my $peg1 (keys(%$sims1))
    {
	my $peg2   = $sims1->{$peg1}->[0];
	my $neigh1 = $by_genome{$genome1}->{$peg1};
	my $neigh2 = $by_genome{$genome2}->{$peg2};
	my %neigh2H = map { $_ => 1 } @$neigh2;
	my @pairs = ();
	my $matching_count = 0;
	foreach my $n1 (@$neigh1)
	{
	    my $maps_to = $sims1->{$n1}->[0];
	    if ($maps_to && $neigh2H{$maps_to})
	    {
		push(@pairs,"$n1:$maps_to");

		if ($functions->{$n1} eq $functions->{$maps_to})
		{
		    $matching_count++;
		}
	    }
	}
	$matched_pairs{"$peg1,$peg2"} = join(",",@pairs);
	$matching_count{"$peg1,$peg2"} = $matching_count;
    }
    return \%matched_pairs, \%matching_count;
}



sub compare_locs {
    my($loc1,$loc2) = @_;

    my($contig1,$min1,$max1) = &SeedUtils::boundaries_of($loc1);
    my($contig2,$min2,$max2) = &SeedUtils::boundaries_of($loc2);
    return (($contig1 cmp $contig2) or (($min1+$max1) <=> ($min2+$max2)));
}

sub set_neighbors {
    my($peg_loc_tuples,$N,$ignore_ov) = @_;

    my $peg_to_neighbors = {};
    my $i;

    for ($i=0; ($i < @$peg_loc_tuples); $i++)
    {
	my($contigI,$minI,$maxI) = &SeedUtils::boundaries_of($peg_loc_tuples->[$i]->[1]);
	$contigI || confess "BAD";
	my $neighbors = [];
	my $j = $i-1;
	my $to_add = $N;
	while (($j >= 0) && ($to_add > 0) && 
	       &same_contig($peg_loc_tuples->[$j]->[1],$contigI))
	{
	    $j--;
	    if (&distinct($peg_loc_tuples->[$j]->[1],$peg_loc_tuples->[$j+1]->[1],$ignore_ov))
	    {
		$to_add--;
	    }
	}
	$j++;
	while ($j < $i) { push(@$neighbors,$peg_loc_tuples->[$j]->[0]); $j++ }

	$j = $i+1;
	$to_add = $N;
	while (($j < @$peg_loc_tuples) && ($to_add > 0) &&
	       &same_contig($peg_loc_tuples->[$j]->[1],$contigI))
	{
	    push(@$neighbors,$peg_loc_tuples->[$j]->[0]);
	    if (&distinct($peg_loc_tuples->[$j]->[1],$peg_loc_tuples->[$j-1]->[1],$ignore_ov))
	    {
		$to_add--;
	    }
	    $j++;
	}
	$peg_to_neighbors->{$peg_loc_tuples->[$i]->[0]} = $neighbors;
    }
    return $peg_to_neighbors;
}

sub distinct {
    my($x,$y,$ignore_ov) = @_;

    return ($ignore_ov > &overlap($x,$y));
}

sub overlap {
    my($x,$y) = @_;

    my($contig1,$min1,$max1) = &SeedUtils::boundaries_of($x);
    my($contig2,$min2,$max2) = &SeedUtils::boundaries_of($y);
    if ($contig1 ne $contig2) { return 0 }
    if (&SeedUtils::between($min1,$min2,$max1)) { return ($max1 - $min2)+1 }
    if (&SeedUtils::between($min2,$min1,$max2)) { return ($max2 - $min1)+1 }
    return 0;
}

sub same_contig {
    my($entry,$contig) = @_;

    $contig || confess "BAD";
    my($contig1,$minI,$maxI) = &SeedUtils::boundaries_of($entry);
    return ($contig eq $contig1);
}

sub get_functions {
    my($sapObject,$pegs1,$pegs2,$g1dir) = @_;

    if(! $g1dir)
    {
	return $sapObject->ids_to_functions(-ids => [@$pegs1,@$pegs2]);
    }
    else
    {
	my $functions = $sapObject->ids_to_functions(-ids => $pegs2);
	# (-s "$g1dir/assigned_functions") || die "$g1dir/assigned_functions is missing";
	# foreach (`cat $g1dir/assigned_functions`)

	if (open(my $fh, "<", "$g1dir/assigned_functions"))
	{
	    while (<$fh>)
	    {
		if (/^(fig\|\S+)\t(\S.*\S)/)
		{
		    $functions->{$1} = $2;
		}
	    }
	    close($fh);
	}
	return $functions;
    }
}

sub get_aliases {
    my($sapObject,$pegs) = @_;
    
    my $aliases = {};
    my $aliasHash = $sapObject->fids_to_ids(-ids => $pegs);

    foreach my $peg (@$pegs)
    {
	my $typeH = $aliasHash->{$peg} ? $aliasHash->{$peg} : {};
	my @all_aliases = map { @{$typeH->{$_}} } keys(%$typeH);
	my $aliasStr = (@all_aliases > 0) ? join(",",@all_aliases) : "";
	$aliases->{$peg} = $aliasStr;
    }
    return $aliases;
}

sub make_genome_source
{
    my($name, $sap) = @_;

    if ($name =~ /^\d+\.\d+$/)
    {
	return SapGenomeSource->new($name, $sap);
    }
    elsif (-d $name)
    {
	my $fasta = "$name/Features/peg/fasta";
	
	my $tbl = "$name/Features/peg/tbl";

	if (! -f $fasta)
	{
	    die "No fasta found in $fasta\n";
	}
	if (! -f $tbl)
	{
	    die "No tbl file found in $tbl\n";
	}

	#
	# We might have multiple functions files. If there are,
	# collapse into one based on the usual RAST
	# rules (old assigned funcs overwritten by
	# auto-assign funcs overwritten by FIGfams funcs).
	#

	my @files;
	foreach my $file (qw(assigned_functions proposed_non_ff_functions proposed_functions))
	{
	    if (-f "$name/$file")
	    {
		push(@files, "$name/$file")
	    }
	}
	if (@files == 0)
	{
	    die "No functions file found for $name\n";
	}

	return SapFileSource->new($fasta, $tbl, \@files);
    }
    else
    {
	#
	# Must be a comma-sep triple
	#
	my @x = split(/,/, $name);
	if (@x != 3)
	{
	    die "Invalid genome specifier: $name\n";
	}
	my($fasta, $tbl, $func) = @x;
	if (! -f $fasta)
	{
	    die "No fasta found in $fasta\n";
	}
	if (! -f $tbl)
	{
	    die "No tbl file found in $tbl\n";
	}
	if (! -f $func)
	{
	    die "No function file found in $func\n";
	}

	return SapFileSource->new($fasta, $tbl, [$func]);
    }
}

package SapFileSource;
use strict;

sub new
{
    my($class, $fasta, $tbl, $func_files) = @_;

    my $self = {
	fasta => $fasta,
	tbl => $tbl,
	func_files => $func_files,
    };
    bless $self, $class;
    return $self;
}

sub init_data
{
    my($self) = @_;

    open(TBL, "<", $self->{tbl}) or die "Cannot read $self->{tbl}: $!";
    
    while (<TBL>)
    {
        chomp;
	my($id, $loc, @aliases) = split(/\t/);

#	my ($contig, $begin, $end, $strand) = parse_location($loc);

	$self->{loc}->{$id} = $loc;

	$self->{aliases}->{$id} = [@aliases];
    }
    close(TBL);
}

sub get_fasta
{
    my($self, $file) = @_;
    
    my @seqs = &gjoseqlib::read_fasta($self->{fasta});
    
    &gjoseqlib::print_alignment_as_fasta($file,\@seqs);
    my $lens = {};
    foreach $_ (@seqs)  { $lens->{$_->[0]} = length($_->[2]) }
    return $lens;
}

sub get_functions
{
    my($self, $hash) = @_;

    for my $file (@{$self->{func_files}})
    {
	open(FFILE, "<", $file) or die "Cannot read $file: $!";
	while (<FFILE>)
	{
	    chomp;
	    my($id, $fn) = split(/\t/);
	    $hash->{$id} = $fn;
	}
	close(FFILE);
    }
}

sub get_aliases
{
    my($self, $hash) = @_;
    for my $key (keys % {$self->{aliases}})
    {
	$hash->{$key} = join(",", @{$self->{aliases}->{$key}});
    }
}

sub get_peg_loc_tuples
{
    my($self) = @_;

    my @all_fids = keys(%{$self->{loc}});;

    my @peg_loc_tuples_in_genome =
	sort { &main::compare_locs($a->[1],$b->[1]) }
 	    map { [$_, [split(/,/,$self->{loc}->{$_})]] }
	    @all_fids;
    return @peg_loc_tuples_in_genome;
}

package SapGenomeSource;

sub new
{
    my($class, $genome, $sap) = @_;
    my $self = {
	genome => $genome,
	sap => $sap,
    };

    return bless $self, $class;
}

sub init_data
{
    my($self) = @_;
    my $genome = $self->{genome};
    my $sap = $self->{sap};
    
    my $fidHash  = $sap->all_features(-ids => $genome, -type => 'peg');
    $self->{all_fids} = $fidHash->{$genome};

    if (@{$self->{all_fids}} == 0)
    {
	die "Could not load pegs for $genome\n";
    }
    
    my $locHash  = $sap->fid_locations(-ids => $self->{all_fids});
}

sub get_functions
{
    my($self, $hash) = @_;

    my $fns = $self->{sap}->ids_to_functions(-ids => $self->{all_fids});
    $hash->{$_} = $fns->{$_} for keys %$fns;
}

sub get_aliases {
    my($self, $aliases) = @_;
    
    my $aliasHash = $sapObject->fids_to_ids(-ids => $self->{all_fids});

    foreach my $peg (keys %$aliasHash)
    {
	my $typeH = $aliasHash->{$peg} ? $aliasHash->{$peg} : {};
	my @all_aliases = map { @{$typeH->{$_}} } keys(%$typeH);
	my $aliasStr = (@all_aliases > 0) ? join(",",@all_aliases) : "";
	$aliases->{$peg} = $aliasStr;
    }
    return $aliases;
}

sub get_peg_loc_tuples
{
    my($self) = @_;

    my $locHash  = $sapObject->fid_locations(-ids => $self->{all_fids});
    my @peg_loc_tuples_in_genome =
	sort { &main::compare_locs($a->[1],$b->[1]) }
 	    map { [$_,$locHash->{$_}] }
 	    keys(%$locHash);
    return @peg_loc_tuples_in_genome;
}

sub get_fasta {
    my($self, $file) = @_;

    my $lens = {};
    my $fastaHash = $sapObject->ids_to_sequences(-ids => $self->{all_fids},
						 -protein => 1);

    open(FASTA,">$file") || die "could not open $file";
    foreach my $peg (keys(%$fastaHash))
    {
	my $seq = $fastaHash->{$peg};
	if ($seq)
	{
	    print FASTA ">$peg\n$seq\n";
	    $lens->{$peg} = length($seq);
	}
    }
    close(FASTA);
    return $lens;
}
	
