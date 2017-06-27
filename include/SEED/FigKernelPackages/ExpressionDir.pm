package ExpressionDir;

use FileHandle;
use gjoseqlib;
use Data::Dumper;
use strict;
use SeedAware;
use File::Copy;
use File::Temp 'tempfile';
use File::Spec::Functions;
use base 'Class::Accessor';
use Carp;
use Fcntl ':seek';
use Statistics::Descriptive;
    
__PACKAGE__->mk_accessors(qw(genome_dir expr_dir genome_id));

our @probe_parsers = qw(parse_probe_format_1lq
			parse_probe_format_1
			parse_probe_format_2
			parse_probe_format_3
			parse_probe_format_shew
			parse_probe_format_native);

=head3 new

    my $edir = ExpressionDir->new($expr_dir);

Create a new ExpressionDir object from an existing expression dir.


=cut

sub new
{
    my($class, $expr_dir) = @_;

    my $gfile = catfile($expr_dir, "GENOME_ID");
    open(GF, "<", $gfile) or die "Cannot open $expr_dir/GENOME_ID: $!";
    my $genome_id = <GF>;
    chomp $genome_id;
    close(GF);
    
    my $self = {
	genome_dir => catfile($expr_dir, $genome_id),
	genome_id => $genome_id,
	expr_dir => $expr_dir,
    };
    return bless $self, $class;
}

=head3 create

    my $edir = ExpressionDir->create($expr_dir, $genome_id, $genome_src)

Create a new expression directory from the given genome id and genome data source. 
The data source is either a FIG or FIGV object, or a SAPserver object
that points at a server from which the data can be extracted.

=cut

sub create
{
    my($class, $expr_dir, $genome_id, $genome_src) = @_;

    if (! -d $expr_dir)
    {
	mkdir($expr_dir);
    }
    my $genome_dir = catfile($expr_dir, $genome_id);
    if (! -d $genome_dir)
    {
	mkdir($genome_dir);
    }

    open(GF, ">", catfile($expr_dir, "GENOME_ID"));
    print GF "$genome_id\n";
    close(GF);
    
    my $self = {
	genome_dir => $genome_dir,
	genome_id => $genome_id,
	expr_dir => $expr_dir,
    };
    bless $self, $class;

    if (ref($genome_src) =~ /^FIG/)
    {
	$self->create_from_fig($genome_src);
    }
    elsif (ref($genome_src =~ /^SAP/))
    {
	$self->create_from_sap($genome_src);
    }
    else
    {
	confess "Unknown genome source\n";
    }
    return $self;
}

sub create_from_fig
{
    my($self, $fig) = @_;

    my $gdir = $fig->organism_directory($self->genome_id);

    if (! -d $gdir)
    {
	confess "Genome directory $gdir not found";
    }

    copy(catfile($gdir, "contigs"), catfile($self->genome_dir, "contigs"));
    mkdir(catfile($self->genome_dir, "Features"));
    my @pegs;
    my %locs;
    for my $ftype (qw(peg rna))
    {
	my $ofdir = catfile($gdir, "Features", $ftype);
	my $nfdir = catfile($self->genome_dir, "Features", $ftype);
	
	if (open(OT, "<", "$ofdir/tbl"))
	{
	    mkdir($nfdir);
	    open(NT, ">", "$nfdir/tbl") or confess "Cannot write $nfdir/tbl: $!";
	    while (<OT>)
	    {
		my($id) = /^(\S+)\t(\S+)/;
		if (!$fig->is_deleted_fid($id))
		{
		    print NT $_;
		    if ($ftype eq 'peg')
		    {
			push(@pegs, $id);
			$locs{$id} = $2;
		    }
			
		}
	    }
	    close(OT);
	    close(NT);
	}
	copy("$ofdir/fasta", "$nfdir/fasta");
    }

    my $genome_ss_dir = catfile($gdir, "Subsystems");
    if (-d $genome_ss_dir && -s "$genome_ss_dir/bindings" && -s "$genome_ss_dir/subsystems")
    {
	my $my_ss_dir = $self->genome_dir . "/Subsystems";
	mkdir($my_ss_dir) or die "Cannot mkdir $my_ss_dir: $!";
	for my $f (qw(bindings subsystems))
	{
	    copy("$genome_ss_dir/$f", "$my_ss_dir/$f") or die "Cannot copy $genome_ss_dir/$f to $my_ss_dir/$f: $!";
	}
    }

    open(SS, ">", catfile($self->genome_dir, "subsystem.data"));
    my %phash = $fig->subsystems_for_pegs_complete(\@pegs);
    for my $peg (keys %phash)
    {
	my $list = $phash{$peg};
 	next unless $list;
	
	for my $ent (@$list)
	{
	    print SS join("\t", $peg, @$ent), "\n";
	}
    }
    close(SS);

    open(AF, ">", catfile($self->genome_dir, "assigned_functions"));
    my $fns = $fig->function_of_bulk(\@pegs);
    for my $peg (@pegs)
    {
	print AF join("\t", $peg, $fns->{$peg}), "\n";
    }
    close(AF);

    open(PD, ">", catfile($self->genome_dir, "peg_dna.fasta"));
    for my $peg (@pegs)
    {
	my $dna = $fig->dna_seq($self->genome_id, split(/,/, $locs{$peg}));
	if ($dna eq '')
	{
	    die "no dna for ", $self->genome_id, " $peg $locs{$peg}\n";
	}
	print_alignment_as_fasta(\*PD, [$peg, undef, $dna]);
    }
    close(PD);
}

sub create_from_sap
{
    my($self, $sap) = @_;
    confess "create_from_sap not yet implemented";
}

sub parse_probe_format_1lq
{
    my($self, $in_file, $out_file) = @_;

    my($fh);

    if ($in_file !~ /\.1lq$/)
    {
	return undef;
    }

    open($fh, "<", $in_file) or confess "Cannot open $in_file for reading: $!";

    my $out;
    open($out, ">", $out_file) or confess "Cannot open $out for writing: $!";

    # Skip 3 header lines.
    $_ = <$fh> for 1..3;
    
    while (defined($_ = <$fh>))
    {
	if ($_ =~ /(\d+)\s+(\d+)\s+([ACGT]+)\s+(-?\d+)\s/)
	{
	    if (length($3) < 15)
	    {
		close($fh);
		close($out);
		confess "Bad length at line $. of $in_file";
		return undef;
	    }
	    next if ($4 =~ /\d+3$/); #mismatch probe
	    my($x,$y,$seq) = ($1,$2,$3);
	    $seq = scalar reverse $seq;
	    print $out "$x\_$y\t$seq\n";
	}
	else
	{
	    #
	    # We expect some lines not to match.
	    #
	}
    }
    
    close($fh);
    close($out);
    return 1;
}

sub parse_probe_format_1
{
    my($self, $in_file, $out_file) = @_;

    my($fh);

    open($fh, "<", $in_file) or confess "Cannot open $in_file for reading: $!";
    my $l = <$fh>;
    chomp $l;
    $l =~ s/\r//;
    my @hdrs = split(/\t/, $l);
    my %hdrs;
    $hdrs{$hdrs[$_]} = $_ for 0..$#hdrs;

    my $x_col = $hdrs{"Probe X"};
    my $y_col = $hdrs{"Probe Y"};
    my $seq_col = $hdrs{"Probe Sequence"};
    if (!(defined($x_col) && defined($y_col) && defined($seq_col)))
    {
	close($fh);
	return undef;
    }

    my $out;
    open($out, ">", $out_file) or confess "Cannot open $out for writing: $!";

    while (<$fh>)
    {
	chomp;
	s/\r//g;
	my @flds = split(/\t/,$_);
	my($x,$y,$seq);
	$x = $flds[$x_col];
	$y = $flds[$y_col];
	$seq = $flds[$seq_col];
	my $id = "$x\_$y";
	print $out "$id\t$seq\n";
    }
    close($fh);
    close($out);
    return 1;
}

sub parse_probe_format_2
{
    my($self, $in_file, $out_file) = @_;

    my($fh);

    local $/ = "\n>";

    open($fh, "<", $in_file) or confess "Cannot open $in_file for reading: $!";
    my $l = <$fh>;
    chomp $l;
    $l =~ s/\r//;

    if ($l !~ /^>?\S+:(\d+):(\d+);\s+Interrogation_Position=\d+;\s+Antisense;\n([ACGT]+)/s)
    {
	close($fh);
	return undef;
    }
    seek($fh, 0, SEEK_SET);

    my $out;
    open($out, ">", $out_file) or confess "Cannot open $out for writing: $!";

    while (<$fh>)
    {
	chomp;

	if ($_ =~ /^>?\S+:(\d+):(\d+);\s+Interrogation_Position=\d+;\s+Antisense;\n([ACGT]+)/s)
	{
	    if (length($3) < 15)
	    {
		close($fh);
		confess "Bad length at line $. of $in_file";
	    }
	    print $out "$1\_$2\t$3\n";
	}
	else
	{
	    confess "Bad input at line $. of $in_file";
	}
    }
    close($out);
    close($fh);
    return 1;
}

sub parse_probe_format_3
{
    my($self, $in_file, $out_file) = @_;

    my($fh);

    open($fh, "<", $in_file) or confess "Cannot open $in_file for reading: $!";
    my $out;
    open($out, ">", $out_file) or confess "Cannot open $out for writing: $!";
    
    local $/ = "\n>";

    while (defined($_ = <$fh>))
    {
	if ($_ =~ /^>?\S+\s+(\d+)\s+(\d+)[^\n]+\n(\S+)/s)
	{
	    my $x = $1;
	    my $y = $2;
	    my $seq = $3;
	    if ($seq ne "!")
	    {
		if ($seq !~ /^[ACGT]+$/) { die $_ }
		if (length($seq) < 15) { print STDERR "BAD: $_"; die "Failed" }
		print $out "$x\_$y\t$seq\n";
	    }
	}
	else
	{
	    print STDERR "failed to parse: $_";
	    return undef;
	}
    }
    
    close($out);
    close($fh);
    return 1;
}

#
# This one showed up in the shewanella data.
#
sub parse_probe_format_shew
{
    my($self, $in_file, $out_file) = @_;

    my($fh);

    open($fh, "<", $in_file) or confess "Cannot open $in_file for reading: $!";
    my $l = <$fh>;
    chomp $l;
    $l =~ s/\r//;

    if ($l !~ /x\ty\tprobe_type\tsequence/)
    {
	close($fh);
	return undef;
    }

    my $out;
    open($out, ">", $out_file) or confess "Cannot open $out for writing: $!";

    while (<$fh>)
    {
	if ($_ =~ /^(\d+)\t(\d+)\tPM\t+([ACGT]+)/)
	{
	    print $out "$1\_$2\t$3\n";
	}
    }
    close($out);
    close($fh);
    return 1;
}
#
# Our "native" format, used for passing through pre-parsed data.
#
sub parse_probe_format_native
{
    my($self, $in_file, $out_file) = @_;

    my($fh);

    open($fh, "<", $in_file) or confess "Cannot open $in_file for reading: $!";
    my $l = <$fh>;
    chomp $l;
    $l =~ s/\r//;

    if ($l !~ /^\d+_\d+\t[ACGT]+$/)
    {
	close($fh);
	return undef;
    }
    seek($fh, 0, SEEK_SET);

    my $out;
    open($out, ">", $out_file) or confess "Cannot open $out for writing: $!";

    while (<$fh>)
    {
	if ($_ =~ /^\d+_\d+\t[ACGT]+$/)
	{
	    print $out $_;
	}
	else
	{
	    confess "Bad input at line $. of $in_file";
	}
    }
    close($out);
    close($fh);
    return 1;
}

sub compute_probe_to_peg
{
    my($self, $probes) = @_;

    my($probe_suffix) = $probes =~ m,(\.[^/.]+)$,;

    my $my_probes = catfile($self->expr_dir, "probes.in$probe_suffix");
    
    copy($probes, $my_probes) or confess "Cannot copy $probes to $my_probes: $!";

    my $probes_fasta = catfile($self->expr_dir, "probes");

    #
    # Attempt to translate probe file.
    #
    my $success;
    for my $meth (@probe_parsers)
    {
	if ($self->$meth($my_probes, $probes_fasta))
	{
	    print STDERR "Translated $probes to $probes_fasta using $meth\n";
	    $success = 1;
	    last;
	}
	else
	{
	    print STDERR "Failed to translate $probes to $probes_fasta using $meth\n";
	}
    }
    if (!$success)
    {
	confess "Could not translate $probes\n";
    }

    my $peg_probe_table = catfile($self->expr_dir, 'peg.probe.table');
    my $probe_occ_table = catfile($self->expr_dir, 'probe.occ.table');

    my $feature_dir = catfile($self->genome_dir, "Features");
    my @tbls;
    for my $ftype (qw(peg rna))
    {
	my $tfile = catfile($feature_dir, $ftype, 'tbl');
	if (-f $tfile)
	{
	    push(@tbls, $tfile);
	}
    }
    if (@tbls == 0)
    {
	confess "Could not find any tbl files in $feature_dir";
    }

    $self->run([executable_for("make_probes_to_genes"),
		$probes_fasta,
		catfile($self->genome_dir, 'contigs'),
		$tbls[0],
		$peg_probe_table,
		$probe_occ_table,
		@tbls[1..$#tbls],
		],
	   { stderr => catfile($self->expr_dir, 'problems') });
			 

    $self->run([executable_for("remove_multiple_occurring_probes"),
		$peg_probe_table,
		],
	   { stdout => catfile($self->expr_dir, 'peg.probe.table.no.multiple') } );

    $self->make_missing_probes($peg_probe_table, $probes_fasta,
			       catfile($self->expr_dir, 'probe.no.match'));
    $self->make_missing_probes(catfile($self->expr_dir, 'peg.probe.table.no.multiple'), $probes_fasta,
			       catfile($self->expr_dir, 'probe.no.multiple.no.match'));
}

sub make_missing_probes
{
    my($self, $probe_table, $probes, $output) = @_;
    open(MATCH,"<", $probe_table) or die "Cannot open $probe_table: $!";
    open(PROBES,"<", $probes) or die "Cannot open $probes: $!";
    open(OUTPUT, ">", $output) or die "Cannot open $output: $!";
    my %locations;
    while(<MATCH>)
    {
	chomp;
	my($peg,$loc)=split "\t";
	$locations{$loc} = $peg;
    }
    
    while(<PROBES>)
    {
	chomp;
	my($loc,$seq) = split "\t";
	print OUTPUT $loc, "\n" if ! exists $locations{$loc};
    }
    close(MATCH);
    close(PROBES);
    close(OUTPUT);
}

#
# we don't copy the experiment files in here because
# they may be very large. This may change.
#
# We do copy the cdf.
#
sub compute_rma_normalized
{
    my($self, $cdf_file, $expt_dir) = @_;

    my $my_cdf = catfile($self->expr_dir, "expr.cdf");
    copy($cdf_file, $my_cdf) or confess "Cannot copy $cdf_file to $my_cdf: $!";

    #
    # We need to build the R library for this cdf.
    #
    my($fh, $tempfile) = tempfile();
#m = make.cdf.package("S_aureus.cdf", cdf.path="..",packagename="foo",package.path="/tmp")

    my $cdf_path = $self->expr_dir;
    my $libdir = catfile($self->expr_dir, "r_lib");
    -d $libdir or mkdir $libdir;
    my $pkgdir = catfile($self->expr_dir, "r_pkg");
    -d $pkgdir or mkdir $pkgdir;

    print $fh "library(makecdfenv);\n";
    print $fh qq(make.cdf.package("expr.cdf", cdf.path="$cdf_path", packagename="datacdf", package.path="$pkgdir", species="genome name");\n);
    close($fh);
    system("Rscript", $tempfile);
    system("R", "CMD", "INSTALL", "-l", $libdir, "$pkgdir/datacdf");

    local($ENV{R_LIBS}) = $libdir;
    $self->run([executable_for("RunRMA"),
		"data",
		catfile($self->expr_dir, "peg.probe.table.no.multiple"),
		catfile($self->expr_dir, "probe.no.multiple.no.match"),
		$expt_dir,
		$self->expr_dir]);
	       
    my $output = catfile($self->expr_dir, "rma_normalized.tab");
    if (! -f $output)
    {
	confess("Output file $output was not generated");
    }
}

sub compute_rma_normalized_from_sif
{
    my($self, $cdf_file, $sif_file, $expt_dir) = @_;

    my $my_cdf = catfile($self->expr_dir, "expr.cdf");
    copy($cdf_file, $my_cdf) or confess "Cannot copy $cdf_file to $my_cdf: $!";

    my $my_sif = catfile($self->expr_dir, "expr.sif");
    copy($sif_file, $my_sif) or confess "Cannot copy $sif_file to $my_sif: $!";

    #
    # Create the sif2peg mapping.
    #

    my $sif2peg = catfile($self->expr_dir, "sif2peg");
    if (! -f $sif2peg)
    {
	$self->run([executable_for('map_sif_to_pegs'),
		    $my_sif,
		    catfile($self->genome_dir, "peg_dna.fasta")],
	       { stdout => $sif2peg });
    }
    
    $self->compute_rma_normalized_using_sif2peg($sif2peg, $expt_dir);
}

sub compute_rma_normalized_from_locus_tags
{
    my($self, $cdf_file, $tag_file, $expt_dir) = @_;

    my $my_cdf = catfile($self->expr_dir, "expr.cdf");
    copy($cdf_file, $my_cdf) or confess "Cannot copy $cdf_file to $my_cdf: $!";

    my $my_tags = catfile($self->expr_dir, "expr.tags");
    copy($tag_file, $my_tags) or confess "Cannot copy $tag_file to $my_tags: $!";

    #
    # Create the sif2peg mapping.
    #

    my $sif2peg = catfile($self->expr_dir, "sif2peg");

    {
	my %tags;
	#
	# Read the tbl file for the organism and create map from locus tag -> peg.
	#
	my $tbl = catfile($self->genome_dir, "Features", "peg", "tbl");
	if (my $fh = FileHandle->new($tbl, "<"))
	{
	    while (<$fh>)
	    {
		chomp;
		my($fid, $loc, @aliases) = split(/\t/);
		for my $a (@aliases)
		{
		    $tags{$a} = $fid;
		    if ($a =~ /^(\S+)\|(.*)/)
		    {
			$tags{$2} = $fid;
		    }
		}
	    }
	    close($fh);
	}
	else
	{
	    confess "Could not open tbl file $tbl: $!";
	}

	my $out = FileHandle->new($sif2peg, ">") or confess "Cannot open $sif2peg for writing: $!";
	my $in = FileHandle->new($my_tags, "<") or confess "Cannot open $my_tags: $!";

	# Per Matt DeJongh: Note that in some cases multiple chip ids
	# map to the same locus tag; in this case ignore the chip id
	# that has "_s_" in it.

	my %locus_map;
	while (<$in>)
	{
	    chomp;
	    my($chip_id, $tag) = split(/\t/);
	    next if $tag eq '';
	    
	    if (exists($locus_map{$tag}))
	    {
		print "Dup: chip_id=$chip_id tag=$tag  old=$locus_map{$tag}\n";
		next if $chip_id =~ /_s_/ ;
		next if $chip_id =~ /^Rick/ && $self->genome_id eq '452659.3';
	    }
	    $locus_map{$tag} = $chip_id;
	}
	close($in);

	for my $locus_tag (sort keys %locus_map)
	{
	    my $chip_id = $locus_map{$locus_tag};
	    my $peg = $tags{$locus_tag};
	    if ($peg ne '')
	    {
		print $out "$chip_id\t$peg\n";
	    }
	}
	close($out);
    }

    if (! -s $sif2peg)
    {
	confess "No probe to peg mappings were found\n";
    }

    $self->compute_rma_normalized_using_sif2peg($sif2peg, $expt_dir);
}

sub compute_rma_normalized_from_pegidcorr
{
    my($self, $cdf_file, $corr_file, $expt_dir) = @_;

    my $my_cdf = catfile($self->expr_dir, "expr.cdf");
    copy($cdf_file, $my_cdf) or confess "Cannot copy $cdf_file to $my_cdf: $!";

    my $my_corr = catfile($self->expr_dir, "peg.id.corr");
    copy($corr_file, $my_corr) or confess "Cannot copy $corr_file to $my_corr: $!";
    my $sif2peg = catfile($self->expr_dir, "sif2peg");
    #
    # Create the sif2peg mapping.
    #

    my $sif2peg = catfile($self->expr_dir, "sif2peg");

    #
    # The peg.id.corr table is of the form peg \t chip-id \t something-else
    # Just rewrite into chip-id \t peg.
    #

    my $out = FileHandle->new($sif2peg, ">") or confess "Cannot open $sif2peg for writing: $!";
    my $in = FileHandle->new($my_corr, "<") or confess "Cannot open $my_corr: $!";
    while (<$in>)
    {
	chomp;
	my($peg, $chip_id, undef) = split(/\t/);
	    
	print $out "$chip_id\t$peg\n";
    }
    close($in);
    close($out);

    if (! -s $sif2peg)
    {
	confess "No probe to peg mappings were found\n";
    }
    $self->compute_rma_normalized_using_sif2peg($sif2peg, $expt_dir);
}

sub compute_rma_normalized_using_sif2peg
{
    my($self, $sif2peg, $expt_dir) = @_;
    
    #
    # We need to build the R library for this cdf.
    #
    my($fh, $tempfile) = tempfile();
#m = make.cdf.package("S_aureus.cdf", cdf.path="..",packagename="foo",package.path="/tmp")

    my $cdf_path = $self->expr_dir;
    my $libdir = catfile($self->expr_dir, "r_lib");
    -d $libdir or mkdir $libdir;
    my $pkgdir = catfile($self->expr_dir, "r_pkg");
    -d $pkgdir or mkdir $pkgdir;

    print $fh "library(makecdfenv);\n";
    print $fh qq(make.cdf.package("expr.cdf", cdf.path="$cdf_path", packagename="datacdf", package.path="$pkgdir", species="genome name");\n);
    close($fh);
    system("Rscript", $tempfile);
    system("R", "CMD", "INSTALL", "-l", $libdir, "$pkgdir/datacdf");

    local($ENV{R_LIBS}) = $libdir;
    $self->run([executable_for("RunRMA_SIF_format"),
		"data",
		$expt_dir,
		$self->expr_dir]);
	       
    my $output = catfile($self->expr_dir, "rma_normalized.tab");
    if (! -f $output)
    {
	confess("Output file $output was not generated");
    }
}

sub compute_atomic_regulons
{
    my($self, $pearson_cutoff) = @_;

    $pearson_cutoff ||= 0.7;

    my $coreg_clusters = catfile($self->expr_dir, "coregulated.clusters");
    my $coreg_subsys = catfile($self->expr_dir, "coregulated.subsys");
    my $merged_clusters = catfile($self->expr_dir, "merged.clusters");
    my $probes_always_on = catfile($self->expr_dir, "probes.always.on");
    my $pegs_always_on = catfile($self->expr_dir, "pegs.always.on");


    $self->run([executable_for("call_coregulated_clusters_on_chromosome"), $self->expr_dir],
	   { stdout => $coreg_clusters });

    my $genome_ss_dir = $self->genome_dir . "/Subsystems";
    $self->run([executable_for("make_coreg_conjectures_based_on_subsys"), 
		$self->expr_dir,
		(-d $genome_ss_dir ? $genome_ss_dir : ()),
		],
	   { stdout => $coreg_subsys });

    $self->run([executable_for("filter_and_merge_gene_sets"), $self->expr_dir, $coreg_clusters, $coreg_subsys],
	   { stdout => $merged_clusters });
    $self->run([executable_for("get_ON_probes"), $self->expr_dir, $probes_always_on, $pegs_always_on]);

    if (-s $pegs_always_on == 0)
    {
	confess "No always-on pegs were found";
    }

    $self->run([executable_for("Pipeline"), $pegs_always_on, $merged_clusters, $self->expr_dir],
	   { stdout => catfile($self->expr_dir, "comments.by.Pipeline.R") });

    $self->run([executable_for("SplitGeneSets"), $merged_clusters, $pearson_cutoff, $self->expr_dir],
	   { stdout => catfile($self->expr_dir, "split.clusters") });
    
    $self->run([executable_for("compute_atomic_regulons_for_dir"), $self->expr_dir]);
}

sub run
{
    my($self, $cmd, $redirect) = @_;

    print "Run @$cmd\n";
    my $rc = system_with_redirect($cmd, $redirect);
    if ($rc != 0)
    {
	confess "Command failed: @$cmd\n";
    }
}

sub get_experiment_names
{
    my($self) = @_;
    my $f = catfile($self->expr_dir, "experiment.names");
    my $fh;
    open($fh, "<", $f) or confess "Could not open $f: $!";
    my @out = map { chomp; my($num, $name) = split(/\t/); $name } <$fh>;
    close($fh);
    return @out;
}

sub get_experiment_on_off_calls
{
    my($self, $expt) = @_;

    my $f= catfile($self->expr_dir, "final_on_off_calls.txt");
    my $fh;
    open($fh, "<", $f) or confess "Could not open $f: $!";
    my $names = <$fh>;
    chomp $names;
    my @names = split(/\t/, $names);
    my $idx = 0;
    my $expt_idx;
    foreach my $n (@names)
    {
	if ($n eq $expt)
	{
	    $expt_idx = $idx;
	    last;
	}
	$idx++;
    }
    if (!defined($expt_idx))
    {
	confess("Could not find experiment $expt in $f");
    }

    my $calls = {};
    while (<$fh>)
    {
	chomp;
	my($peg, @calls) = split(/\t/);
	#
	# +1 because the row[0] element is the peg, and our index is
	# zero-based.
	#
	$calls->{$peg} = $calls[$expt_idx + 1];
    }

    close($fh);
    return($calls);
	
}

=head3 save_model_gene_activity

    $e->save_model_gene_activity($data)

Save the results of a modeling run for a given experiment.

$data is of the form { experiment_id => $data_hash }

=cut

sub save_model_gene_activity
{
    my($self, $data) = @_;
}

sub all_features
{
    my($self, $type) = @_;

    my @ftypes;
    my $fdir = catfile($self->genome_dir, "Features");
    if (defined($type))
    {
	@ftypes = ($type);
    }
    else
    {
	opendir(D, $fdir);
	@ftypes = grep { -f catfile($fdir, $_) && /^\./ } readdir(D);
	closedir(D);
    }
    my @out;
    for my $ftype (@ftypes)
    {
	if (open(TBL, "<", catfile($fdir, $ftype, "tbl")))
	{
	    push(@out, map { /^(\S+)/; $1 } <TBL>);
	    close(TBL);
	}
    }
    return @out;
}

sub fid_locations
{
    my($self, $fids) = @_;

    my %fids;
    $fids{$_}++ for @$fids;

    my $genome_id = $self->genome_id;

    my $fdir = catfile($self->genome_dir, "Features");
    opendir(D, $fdir);
    my @ftypes = grep { -d catfile($fdir, $_) && ! /^\./ } readdir(D);
    closedir(D);
    
    my $out = {};
    for my $ftype (@ftypes)
    {
	if (open(TBL, "<", catfile($fdir, $ftype, "tbl")))
	{
	    while (<TBL>)
	    {
		my($id, $locs) = /^(\S+)\t(\S+)\t/;
		
		if ($fids{$id})
		{
		    $out->{$id} = "$genome_id:" . SeedUtils::boundary_loc($locs);
		}
	    }
	    close(TBL);
	}
    }
    return $out;
}

sub ids_in_subsystems
{
    my($self) = @_;

    my $dir = $self->genome_dir;
    my $fh;
    if (!open($fh, "<", "$dir/Subsystems/bindings"))
    {
	warn "No bindings file, falling back to old method\n";
	return $self->ids_in_subsystems_old();
    }

    my $res;
    while (<$fh>)
    {
	chomp;
	my($ss, $role, $fid) = split(/\t/);
	$ss =~ s/\s+/_/g;
	push(@{$res->{$ss}->{$role}}, $fid);
    }
    close($fh);
    return $res;
}

sub ids_to_subsystems
{
    my($self, $ids) = @_;

    my $dir = $self->genome_dir;
    my $fh;
    if (!open($fh, "<", "$dir/Subsystems/bindings"))
    {
	warn "No bindings file, falling back to old method\n";
	return $self->ids_to_subsystems_old($ids);
    }

    my %ids;
    $ids{$_} = 1 for @$ids;

    my $res = {};
    while (<$fh>)
    {
	chomp;
	my($ss, $role, $fid) = split(/\t/);
	if ($ids{$fid})
	{
	    push(@{$res->{$fid}}, $ss);
	}
    }
    close(SS);

    return $res;
}

sub ids_in_subsystems_old
{
    my($self) = @_;

    open(SS, "<", catfile($self->genome_dir, "subsystem.data"));
    my $res = {};
    while (<SS>)
    {
	chomp;
	my($peg, $ss, $role, $variant) = split(/\t/);
	$ss =~ s/\s+/_/g;
	push(@{$res->{$ss}->{$role}}, $peg);
    }
    close(SS);
    return $res;
}

sub ids_to_subsystems_old
{
    my($self, $ids) = @_;

    my %ids;
    $ids{$_} = 1 for @$ids;

    open(SS, "<", catfile($self->genome_dir, "subsystem.data"));
    my $res = {};
    while (<SS>)
    {
	chomp;
	my($peg, $ss, $role, $variant) = split(/\t/);
	if ($ids{$peg})
	{
	    push(@{$res->{$peg}}, $ss);
	}
    }
    close(SS);
    return $res;
}

sub ids_to_functions
{
    my($self, $ids) = @_;
    open(AF, "<", catfile($self->genome_dir, "assigned_functions"));
    my %ids;
    $ids{$_} = 1 for @$ids;
    my $res = {};

    while (<AF>)
    {
	chomp;
	my($id, $fn) = split(/\t/);
	$res->{$id} = $fn if $ids{$id};
    }
    close(AF);
    return $res;
}

sub compute_pearson_corr
{
    my($self, $peg1, $peg2) = @_;

    my $h = $self->get_pc_hash_strip([$peg1], [$peg2]);
    return $h->{$peg1}->{$peg2};
}

sub best_pearson_corr {
    my($self,$pegs1,$cutoff) = @_;

    my @pegs2 = $self->all_features('peg');
    my $handle = $self->get_pc_hash_strip($pegs1,\@pegs2);
    
    my %ok;
    my $i;
    for ($i=0; ($i < @$pegs1); $i++)
    {
	foreach my $peg2 ( @pegs2 )
	{
	    my $pc = &pearson_corr($handle,$pegs1->[$i],$peg2); 
	    if (abs($pc >= $cutoff))
	    {
		$ok{$pegs1->[$i]} -> {$peg2} = $pc;
	    }
	}
    }
    return \%ok;
}

sub pearson_corr {
    my($hash,$peg1,$peg2) = @_;
    my $v = $hash->{$peg1}->{$peg2};
    return defined($v) ? sprintf("%0.3f",$v) : " ";
}

sub get_pc_hash_strip {
    my($self,$pegs1,$pegs2) = @_;
    my $corrH = $self->get_corr;
    my $hash  = &compute_pc_strip($pegs1,$pegs2,$corrH);
    return $hash;
}

sub get_corr {
    my($self) = @_;

    my $dir           = $self->expr_dir;
    my $rawF          = "$dir/rma_normalized.tab";
    my %gene_to_values;
    open(RAW,"<$rawF") || die "could not open $rawF";
    while (<RAW>)
    {
	chomp;
	my ($gene_id, @gxp_values) = split("\t");
	$gene_to_values{$gene_id} = \@gxp_values;
    }
    close(RAW);
    return \%gene_to_values;
}
    
sub compute_pc_strip {
    my ($pegs1,$pegs2, $gxp_hash) = @_;
    my %values = ();

    for (my $i = 0; $i < @$pegs1; $i++)
    {
	my $stat = Statistics::Descriptive::Full->new();
	$stat->add_data(@{$gxp_hash->{$pegs1->[$i]}});

	foreach my $peg2 (@$pegs2)
	{
	    if ($pegs1->[$i] ne $peg2)
	    {
		my ($q, $m, $r, $err) = $stat->least_squares_fit(@{$gxp_hash->{$peg2}});
		$values{$pegs1->[$i]}->{$peg2} = $r;
	    }
	}
    }
    
    return \%values;
}


1;

