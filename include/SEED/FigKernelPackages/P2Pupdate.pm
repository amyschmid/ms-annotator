#
# Copyright (c) 2003-2008 University of Chicago and Fellowship
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

package P2Pupdate;

use strict;

use Safe;
use FIG_Config;
use FIG;
use Carp;
use Data::Dumper;
use Cwd;

=pod

=head2 Public Methods

=head3 updating code

This routine packages what is needed to upgrade an older system to the 
current code.  Code releases are numered

     p1n1.p2n2.p3n3...

where "." is added at the point the code moved to another branch of
the tree.  FIG, who provided the initial release of the SEED, will
number all of their code releases as 

       FIGn  

where n is an integer. Suppose that between releases 13 and 14 a
second group (which we will term "Idiots" for convenience) took
release 13 and wished to branch the code tree.  At that point, they
would name their first release as

	FIG13.Idiots1

We are, of course, being both cavalier and nasty when we make such a
reference.  We do, however, wish to express the view that it will
benefit everyone to attempt to reconcile differences and maintain a
single code progression as long as possible.  There are often good
reasons to part ways, but we urge people to think carefully before
taking such a step.

Two code releases 

    i1.i2.i3...in
and j1.j2.j3...jm with m <= n

are compatible iff 

    ip == jp  for p < m, and
    jm and im have the same "source" and
    jm <= im

A new code release must have the property that it can bring any
"older" compatible release up to its release.

Note that there is an issue relating to the code to build/install packages.
Since a system may be radically restructured between releases of code, the
code to build a "package" and the code to "install" a package are radically 
separated.  For example, the code in P2Pupdate.pm for building an assignment
package and the code for installing an assignment package both apply to the
release of code current on the system containing P2Pupdate.pm.  In fact, the
code releases may be quite different on two synchronizing systems.

To make things work the following rules must be observed:

    1. a code release is a tar file containing VERSION, Packages,
       bin/ToolTemplates, and CGI/ToolTemplates.  The installing system needs
       to place these at the appropriate spots, and then run bring_system_up_to_date,
       which is supposed to do any required restructuring.

    2. an assignments package is a tar file containing a single directory.  The directory
       contains subdirectories -- one per genome.  Each genome subdirectory contains zero
       or more files.  The name of the file is the "user" and the contents will be the
       assignments made by that user.

    3. an annotations package is a tar file containing a single directory.  The files in 
       the directory are named by genome. They contain the annotations for the genome.

=cut

=pod

=head3 what_code_do_I_have

usage: &what_code_do_I_have($fig_base)

This just returns the current version of the code.

=cut

sub what_code_do_I_have {
    my($fig_base) = @_;

    my $version = &FIG::file_read("$fig_base/VERSION");
    chomp $version;
    return $version;
}

=pod

=head3 updatable_code

usage: &updatable_code_code($v1,$v2)

    This just returns true iff the two versions of code are compatible and $v1
    is "more recent".

=cut

sub updatable_code {
    my($v1,$v2) = @_;
    my($i,$v1p,$v1n,$v2p,$v2n);

    my @v1 = split(/\./,$v1);
    my @v2 = split(/\./,$v2);
    if (@v1 < @v2) { return 0 }

    for ($i=0; ($i < $#v2) && ($v1[$i] eq $v2[$i]); $i++) {}
    if ($i == $#v2)
    {
	$v1[$i] =~ /^(.*[^\d])(\d+)$/;
	$v1p = $1;
	$v1n = $2;

	$v2[$i] =~ /^(.*[^\d])(\d+)$/;
	$v2p = $1;
	$v2n = $2;

	return (($v2p eq $v1p) && ($v2n < $v1n));
    }
    return 0;
}

=pod

=head3 package_code

usage: &package_code($fig_disk,$file)

$fig_base must be an absolute filename (begins with "/") giving the FIG from which
   the updated code release will be taken.

$file must be an absolute filename where the "code package" will be built.

=cut

sub package_code {
    my($fig_disk,$file) = @_;

    &force_absolute($fig_disk);
    &force_absolute($file);
    my @tmp = &FIG::file_head("$fig_disk/CURRENT_RELEASE", 1);
    my $current_release = $tmp[0];
    chomp $current_release;

    &FIG::run("cd $fig_disk/dist/releases; tar czf $file $current_release");
}

sub force_absolute {
    my($file) = @_;

    if (substr($file,0,1) ne "/")
    {
	print "Error: Please use absolute file names (i.e., /Users/fig/... or /home/fig/...)\n";
	exit;
    }
}

=pod

=head3 install_code

usage: &install_code($fig_disk,$package)

$fig_disk must be an absolute filename (begins with "/") giving the FIG to be updated.

$package must be an absolute filename where the "code package" from which to make
    the update exists.

Note that this routine does not check that the updated code is compatible, or even less
current.  It is assumed that upper level logic is doing that.

=cut

sub install_code {
    my($fig_disk,$package) = @_;
    my $fig_base = "$fig_disk/FIG";
    &force_absolute($fig_base);
    &force_absolute($package);

    if (getcwd() !~ /FIGdisk$/) { print die "Sorry, you must run this while in $FIG_Config::fig_disk" }
	
    
    (! -d "$fig_disk/BackupCode") || &FIG::run("rm -rf $fig_disk/BackupCode");
    mkdir("$fig_disk/BackupCode",0777) || die "Could not make the BackupCode directory";
    (! -d "$fig_disk/BackupEnv") || &FIG::run("rm -rf $fig_disk/BackupEnv");
    mkdir("$fig_disk/BackupEnv",0777) || die "Could not make the BackupEnv directory";

    my $version = &what_code_do_I_have($fig_base);
    &FIG::run("cd $fig_disk; mv README install lib man env src $fig_disk/BackupEnv");
    &FIG::run("cd $fig_base; mv VERSION Packages CGI $fig_disk/BackupCode");
    print STDERR "made backups\n";

    &FIG::run("cd $fig_disk; tar xzf $package");
    print STDERR "untarred new code\n";

    &fix_config("$fig_base/Packages/FIG_Config.pm","$fig_disk/BackupCode/Packages/FIG_Config.pm");
    &FIG::run("cd $fig_base/bin; touch ToolTemplates/*/*; make all");
    &FIG::run("cd $fig_base/CGI; touch ToolTemplates/*/*; make all");
    print STDERR "installed new bin and CGI\n";

    &FIG::run("bring_system_up_to_date $version");
}

=pod

=head3 package_lightweight_code

usage: &package_lightweight_code($fig_disk,$file)

$fig_base must be an absolute filename (begins with "/") giving the FIG from which
   the updated code release will be taken.

$file must be an absolute filename where the "code package" will be built.

=cut

sub package_lightweight_code {
    my($fig_disk,$file) = @_;

    &force_absolute($fig_disk);
    &force_absolute($file);
    my @tmp = &FIG::file_head("$fig_disk/CURRENT_RELEASE", 1);
    my $current_release = $tmp[0];
    chomp $current_release;

    &FIG::run("cd $fig_disk/dist/releases; tar czf $file $current_release");
}

=pod

=head3 install_lightweight_code

usage: &install_lightweight_code($fig_disk,$package)

$fig_disk must be an absolute filename (begins with "/") giving the FIG to be updated.

$package must be an absolute filename where the "code package" from which to make
    the update exists.

Note that this routine does not check that the updated code is compatible, or even less
current.  It is assumed that upper level logic is doing that.

=cut

sub install_lightweight_code {
    my($fig_disk,$package) = @_;
    my $fig_base = "$fig_disk/FIG";
    &force_absolute($fig_base);
    &force_absolute($package);

    if (! mkdir("$fig_disk/Tmp$$",0777))
    {
	print "Error: could not make $fig_disk/Tmp$$\n";
	exit;
    }

    &FIG::run("cd $fig_disk/Tmp$$; tar xzf $package");
    if (! opendir(TMP,"$fig_disk/Tmp$$"))
    {
	print "Error: could not open $fig_disk/Tmp$$\n";
	exit;
    }

    my @rels = grep { $_ !~ /^\./ } readdir(TMP);
    closedir(TMP);
    if (@rels != 1)
    {
	print "Error: Bad code package: $package\n";
	exit;
    }

    my $new_release = $rels[0];
    if (-d "$fig_disk/dist/releases/$new_release")
    {
	print "Error: $new_release already exists; we are doing nothing\n";
	exit;
    }

    &FIG::run("mv $fig_disk/Tmp$$/$new_release $fig_disk/dist/releases");
    &FIG::run("rm -rf $fig_disk/Tmp$$");

    #
    # Ugh. For now, find the arch in the fig config file $fig_disk/config/fig-user-env.sh"
    #

    my $arch;
    open(FH, "<$fig_disk/config/fig-user-env.sh");
    while (<FH>)
    {
	if (/RTARCH="(.*)"/)
	{
	    $arch = $1;
	    last;
	}
    }
    close(FH);

    if ($arch eq "")
    {
	die "Couldn't determine SEED install architecture, not switching to release.";
    }
    
    $ENV{RTARCH} = $arch;

    #
    # Need to put the ext_bin in the path.
    #

    $ENV{PATH} .= ":$FIG_Config::ext_bin";
	
    &FIG::run("$FIG_Config::bin/switch_to_release $new_release");
}

    
sub fix_config {
    my($new,$old) = @_;
    my($line,$i);

    my @new = &FIG::file_read($new);
    foreach $line (&FIG::file_read($old))
    {
	if ($line =~ /^(\S+)\s+\=/)
	{
	    my $var = $1;
	    my $varQ = quotemeta $var;

	    for ($i=0; ($i < $#new) && ($new[$i] !~ /^$varQ\s+\=/); $i++) {}
	    if ($i == $#new)
	    {
		splice(@new,$i,0,$line);
	    }
	    else
	    {
		splice(@new,$i,1,$line);
	    }
	}
    }
    open(NEW,">$new") || confess "could not overwrite $new";
    foreach $line (@new)
    {
	print NEW $line;
    }
    close(NEW);
}

=pod

=head3 what_genomes_will_I_sync 

usage: &what_genomes_will_I_sync($fig_base,$who)

This routine returns the list of genome IDs that you are willing to sync with $who.

=cut

sub what_genomes_will_I_sync {
    my($fig_base,$who) = @_;

# This is the promiscuous version - it will sync all genomes with anyone.

    opendir(GENOMES,"$fig_base/Data/Organisms") || die "could not open $fig_base/Data/Organisms";
    my @genomes = grep { $_ =~ /^\d+\.\d+$/ } readdir(GENOMES);
    closedir(GENOMES);
    return @genomes;
}

=pod

=head3 package_annotations

usage: &package_annotations($fig,$genomes,$file)

$genomes is a pointer to a list of genome IDs that will be exchanged.

$file must be an absolute filename where the "annotation package" will be built.

=cut

sub package_annotations {
    my($fig,$who,$date,$genomes,$file, %options) = @_;
    my $fig_base = "$FIG_Config::fig_disk/FIG";

    if (!open(ANNOTATIONS,">$file"))
    {
	die "Cannot open annotations file $file for writing: $!";
    }

    
    my $annos = $fig->annotations_made_fast($genomes, $date, undef, $who);

    #
    # $annos is a list of pairs [$genome, $genomeannos]
    # $genomeannos is a hash keyed on peg. value is a list of lists [$peg, $time, $who, $anno].
    #

    my @annos = sort { &FIG::by_genome_id($a->[0], $b->[0]) } @$annos;

    for my $gent (@annos)
    {
	my($genome, $alist) = @$gent;

	for my $peg (sort { &FIG::by_fig_id($a, $b) } keys %$alist)
	{
	    for my $aent (@{$alist->{$peg}})
	    {
		print ANNOTATIONS $aent->as_text() . "\n///\n";
	    }
	}
	
    }

    print ANNOTATIONS "//\n";

    if (!$options{skip_aliases})
    {
	for my $gent (@annos)
	{
	    my($genome, $alist) = @$gent;
	    my $gs = $fig->genus_species($genome);
	    
	    for my $peg (sort { &FIG::by_fig_id($a, $b) } keys %$alist)
	    {
		my @aliases = grep { $_ =~ /^(sp\||gi\||pirnr\||kegg\||N[PGZ]_)/ } $fig->feature_aliases($peg);
		print ANNOTATIONS join("\t",($peg,join(",",@aliases),$gs,scalar $fig->function_of($peg))) . "\n";
	    }
	}
    }
	
    print ANNOTATIONS "//\n";
    if (!$options{skip_sequences})
    {
	for my $gent (@annos)
	{
	    my($genome, $alist) = @$gent;
	    
	    for my $peg (sort { &FIG::by_fig_id($a, $b) } keys %$alist)
	    {
		my $seq = $fig->get_translation($peg);
		&FIG::display_id_and_seq($peg,\$seq,\*ANNOTATIONS);
	    }
	    
	}
    }
    
    close(ANNOTATIONS);
}

#
# This was the original version.
#
sub package_annotations2 {
    my($fig,$who,$date,$genomes,$file) = @_;
    my $fig_base = "$FIG_Config::fig_disk/FIG";

    if (open(ANNOTATIONS,">$file"))
    {
	my @annotations = sort { $a->[0] cmp $b->[0] } $fig->annotations_made($genomes,$who,$date);
	foreach my $x (@annotations)
	{
            my $ann = join("\n",@$x);
            if (($ann =~ /^fig\|\d+\.\d+\.peg\.\d+\n\d+\n/s) && ($ann !~ /\n\/\/\n/s))
            {
                print ANNOTATIONS join("\n",@$x),"\n///\n";
            }
	}
	print ANNOTATIONS "//\n";

	foreach my $x (@annotations)
	{
	    my $peg = $x->[0];
	    my @aliases = grep { $_ =~ /^(sp\||gi\||pirnr\||kegg\||N[PGZ]_)/ } $fig->feature_aliases($peg);
	    print ANNOTATIONS join("\t",($peg,join(",",@aliases),$fig->genus_species($fig->genome_of($peg)),scalar $fig->function_of($peg))) . "\n";
	}
	print ANNOTATIONS "//\n";

	foreach my $x (@annotations)
	{
	    my $peg;
	    ($peg,undef) = @$x;
	    my $seq = $fig->get_translation($peg);
	    &FIG::display_id_and_seq($peg,\$seq,\*ANNOTATIONS);
	}
	close(ANNOTATIONS);
    }
}


=pod

=head3 install_annotations

usage: &install_annotations($fig_disk,$package)

$fig_disk must be an absolute filename (begins with "/") giving the FIG to be updated.

$package must be an absolute filename where the "annotations package" from which to make
    the update exists.

=cut

sub install_annotations {
    my($fig,$package) = @_;
    my($user,$who,$date,$userR,@assignments,$peg,$aliases,$org,$func);
    my(%pegs,%seq_of,@seq,$peg_to,$trans_pegs,$seq,$line,@ann,$ann);
    my($genome);

    my $fig_disk = $FIG_Config::fig_disk;
    open(IN,"<$package") || die "could not open $package";
    $/ = "\n//\n";
    if (defined($line = <IN>))
    {
	my(@annotations);
	
	$line =~ s/\n\/\/\n/\n/s;
	@ann = split(/\n\/\/\/\n/,$line);
	foreach $ann (@ann)
	{
	    if ($ann =~ /^(fig\|\d+\.\d+\.peg\.\d+)\n(\d+)\n(\S+)\n(.*)/s)
	    {
		push(@annotations,[$1,$2,$3,$4]);
	    }
	}
	$/ = "\n";
	while ($line && defined($line = <IN>) && ($line !~ /^\/\//))
	{
	    chomp $line;
	    ($peg,$aliases,$org,$func) = split(/\t/,$line);
	    $pegs{$peg} = [$aliases,$org,$func];
	}
    
	if ($line) { $line = <IN> }
	while (defined($line) && ($line !~ /^\/\//))
	{
	    if ($line =~ /^>(\S+)/)
	    {
		$peg = $1;
		@seq = ();
		$line = <IN>;
		while ($line && ($line !~ /^[>\/]/) && ($line !~ /^\/\//))
		{
		    push(@seq,$line);
		    $line = <IN>;
		}
		$seq = join("",@seq);
		$seq =~ s/[ \n\t]//gs;
		$seq_of{$peg} = uc $seq;
	    }
	    else
	    {
		$line = <IN>;
	    }
	}
	close(IN);
	$trans_pegs = $fig->translate_pegs(\%pegs,\%seq_of);
	@annotations = sort { ($a->[0] cmp $b->[0]) or ($a->[1] <=> $b->[1]) }
                       map { ($peg = $trans_pegs->{$_->[0]}) ? [$peg,$_->[1],$_->[2],$_->[3]] : () }
	               @annotations;

	if (-d "$fig_disk/BackupAnnotations") { system "rm -rf $fig_disk/BackupAnnotations" }
	mkdir("$fig_disk/BackupAnnotations",0777);
	mkdir("$fig_disk/BackupAnnotations/New",0777);
	my $i;
	for ($i=0; ($i < @annotations); $i++)
	{
	    if (($i == 0) || ($fig->genome_of($annotations[$i]->[0]) ne $fig->genome_of($annotations[$i-1]->[0])))
	    {
		if ($i != 0)
		{
		    close(OUT);
		}
		$genome = $fig->genome_of($annotations[$i]->[0]);
		open(OUT,">$fig_disk/BackupAnnotations/New/$genome")
		    || die "could not open $fig_disk/BackupAnnotations/New/$genome";
	    }
	    print OUT join("\n",@{$annotations[$i]}),"\n//\n";
	}
	if ($i > 0) { close(OUT) }
    }

    opendir(TMP,"$fig_disk/BackupAnnotations/New") || die "could not open $fig_disk/BackupAnnotations/New";
    my @genomes = grep { $_ =~ /^\d+\.\d+$/ } readdir(TMP);
    closedir(TMP);
    foreach $genome (@genomes)
    {
	next if (! -d "$fig_disk/FIG/Data/Organisms/$genome");

	print STDERR "installing $fig_disk/FIG/Data/Organisms/$genome/annotations\n";
	if (-s "$fig_disk/FIG/Data/Organisms/$genome/annotations")
	{
	    &FIG::run("cp -p $fig_disk/FIG/Data/Organisms/$genome/annotations $fig_disk/BackupAnnotations/$genome");
	    &FIG::run("$FIG_Config::bin/merge_annotations $fig_disk/BackupAnnotations/$genome $fig_disk/BackupAnnotations/New/$genome > $fig_disk/FIG/Data/Organisms/$genome/annotations");
	}
	else
	{
	    &FIG::run("cp $fig_disk/BackupAnnotations/New/$genome $fig_disk/FIG/Data/Organisms/$genome/annotations");
	}
	chmod 0777,"$fig_disk/FIG/Data/Organisms/$genome/annotations";
    }
    &FIG::run("$FIG_Config::bin/index_annotations");
}
 

=pod

=head3 install_annotations_gff

Install a set of annotations contained in a GFF3 file package.

We parse using the FigGFF::GFFParser GFF parser. This returns a GFFFile object
that contains the parsed contents of the file. 

=cut

sub install_annotations_gff
{
    my($fig, $gff_file) = @_;

    my $db = $fig->db_handle;

    my $parser = new GFFParser($fig);

    my $fobj = $parser->parse($gff_file);

    #
    # We assume that we only have one genome per GFF file, but we 
    # get the list of genomes and checksums via a general accessor anyway.
    #

    for my $ent (@{$fobj->genome_checksums()})
    {
	my($genome, $checksum) = @$ent;

	#
	# Determine if we have the same version of this genome.
	#

	my $local_genome = $fig->genome_with_md5sum($checksum);
	print "Local genome=$local_genome cksum=$checksum\n";

	#
	# Walk the features, looking for matching features in the local SEED,
	# and install the annotations if possible.
	#

	my @annos;

	print "Walking $genome\n";
	for my $feature (@{$fobj->features_for_genome($genome)})
	{
	    my($local_id);

	    my @local_ids = $feature->find_local_feature($local_genome);

	    print "Mapped to @local_ids\n";
	}
    }
}


=pod

=head3 restore_annotations

usage: &restore_annotations($fig_disk);

$fig_disk must be an absolute filename (begins with "/") giving the FIG to be updated.

=cut

sub restore_annotations {
    my($fig_disk) = @_;

    &force_absolute($fig_disk);
    (-d "$fig_disk/BackupAnnotations") || die "could not find an active backup";
    opendir(TMP,"$fig_disk/BackupAnnotations") || die "could not open $fig_disk/BackupAnnotations";
    my @genomes = grep { $_ =~ /^\d+\.\d+$/ } readdir(TMP);
    closedir(TMP);
    foreach my $genome (@genomes)
    {
	unlink("$fig_disk/FIG/Data/Organisms/$genome/annotations");
	&FIG::run("cp $fig_disk/BackupAnnotations/$genome $fig_disk/FIG/Data/Organisms/$genome/annotations");
	system "chmod 777 $fig_disk/FIG/Data/Organisms/$genome/annotations";
    }
    &FIG::run("$FIG_Config::bin/index_annotations");
}

=pod

=head3 package_aassignments

usage: package_assignments($fig,$user,$who,$date,$genomes,$file)

$user designates the user wishing to get the assignments

$who designates whose assignments you want (defaults to "master")

$date if given indicates a point in time (get assignments after that point)

$genomes is a pointer to a list of genome IDs that will be exchanged.

$file must be an absolute filename where the "assignment package" will be built.

=cut

sub package_assignments {
    my($fig,$user,$who,$date,$genomes,$file) = @_;
    my($genome,$x,$org,$curr,$peg);
    $who   = $who ? $who : "master";
    $date  = $date ? $date : 0;

    if (open(ASSIGNMENTS,">$file"))
    {
	print ASSIGNMENTS "$user\t$who\t$date\n";
	my @assignments = sort { $a->[0] cmp $b->[0] } $fig->assignments_made_full($genomes,$who,$date);
	my @curr_assignments = ();
	foreach $x (@assignments)
	{
	    my($peg, $function, undef, undef) = @$x;
	    if ($function eq $fig->function_of($peg,$who))
	    {
		print ASSIGNMENTS join("\t", $peg, $function),"\n";
		push(@curr_assignments,$x);
	    }
	}
	print ASSIGNMENTS "//\n";

	foreach $x (@curr_assignments)
	{
	    ($peg,undef) = @$x;
	    my @aliases = grep { $_ =~ /^(sp\||gi\||pirnr\||kegg\||N[PGZ]_)/ } $fig->feature_aliases($peg);

	    my $alias_txt = join(",",@aliases);
	    my $gs_txt = $fig->genus_species($fig->genome_of($peg));
	    my $func_txt = scalar $fig->function_of($peg);
	    
	    print ASSIGNMENTS join("\t",($peg,
					 $alias_txt,
					 $gs_txt,
					 $func_txt)) . "\n";
	}
	print ASSIGNMENTS "//\n";

	foreach $x (@curr_assignments)
	{
	    ($peg,undef) = @$x;
	    my $seq = $fig->get_translation($peg);
	    &FIG::display_id_and_seq($peg,\$seq,\*ASSIGNMENTS);
	}
	close(ASSIGNMENTS);
    }
}

=pod

=head3 install_assignments

usage: &install_assignments($package)

$package must be a filename where the "assignments package" from which to make
    the assignment set exists

=cut

sub install_assignments {
    my($fig,$package,$make_assignments) = @_;
    my($user,$who,$date,$userR,@assignments,$peg,$aliases,$org,$func);
    my(%pegs,%seq_of,@seq,$peg_to,$trans_pegs,$seq);

    open(IN,"<$package") || die "could not open $package";
    my $line = <IN>;
    chomp $line;
    ($user,$who,$date) = split(/\t/,$line);
    $userR = $user;
    $userR =~ s/^master://;

    while (defined($line = <IN>) && ($line !~ /^\/\//))
    {
	if ($line =~ /^(fig\|\d+\.\d+\.peg\.\d+)\t(\S.*\S)/)
	{
	    push(@assignments,[$1,$2]);
	}
    }
    while ($line && defined($line = <IN>) && ($line !~ /^\/\//))
    {
	chomp $line;
	($peg,$aliases,$org,$func) = split(/\t/,$line);
	$pegs{$peg} = [$aliases,$org,$func];
    }
    
    if ($line) { $line = <IN> }
    while (defined($line) && ($line !~ /^\/\//))
    {
	if ($line =~ /^>(\S+)/)
	{
	    $peg = $1;
	    @seq = ();
	    $line = <IN>;
	    while ($line && ($line !~ /^[>\/]/) && ($line !~ /^\/\//))
	    {
		push(@seq,$line);
		$line = <IN>;
	    }
	    $seq = join("",@seq);
	    $seq =~ s/[ \n\t]//gs;
	    $seq_of{$peg} = uc $seq;
	}
	else
	{
	    $line = <IN>;
	}
    }
    close(IN);
    $trans_pegs = $fig->translate_pegs(\%pegs,\%seq_of);

    &FIG::verify_dir("$FIG_Config::data/Assignments/$userR");
    my $file = &FIG::epoch_to_readable($date) . ":$who:imported";
    $file =~ s/\//-/g;

    if (! $make_assignments)
    {
	open(OUT,">$FIG_Config::data/Assignments/$userR/$file") 
	    || die "could not open $FIG_Config::data/Assignments/$userR/$file";
    }

    foreach $peg (keys(%$trans_pegs))
    {
	$peg_to = $trans_pegs->{$peg};
	$func   = $pegs{$peg}->[2];
	if ($fig->function_of($peg_to) ne $func)
	{
	    if ($make_assignments)
	    {
		if ($user =~ /master:(.*)/)
		{
		    $userR = $1;
		    $fig->assign_function($peg_to,"master",$func,"");
		    #  Now in assign_function
		    # if ($userR ne "none")
		    # {
		    #     $fig->add_annotation($peg_to,$userR,"Set master function to\n$func\n");
		    # }
		}
		else
		{
		    $fig->assign_function($peg_to,$user,$func,"");
		    #  Now in assign_function
		    # if ($user ne "none")
		    # {
		    #   $fig->add_annotation($peg_to,$user,"Set function to\n$func\n");
		    # }
		}
	    }
	    else
	    {
		print OUT "$peg_to\t$func\n";
	    }
	}
    }
    if (! $make_assignments)
    {
	close(OUT);
	if (! -s "$FIG_Config::data/Assignments/$userR/$file") { unlink("$FIG_Config::data/Assignments/$userR/$file") }
    }
}

=pod

=head3 package_translation_rules

usage: &package_translation_rules($fig_base,$file)

$fig_base must be an absolute filename (begins with "/") giving the FIG from which
   the updated code release will be taken.

$file must be an absolute filename where the "translation_rules package" will be built.

=cut

sub package_translation_rules {
    my($fig_base,$file) = @_;

    &FIG::run("cp $fig_base/Data/Global/function.synonyms $file");
}

=pod

=head3 install_translation_rules

usage: &install_translation_rules($fig_disk,$from,$package)

$fig_disk must be an absolute filename (begins with "/") giving the FIG to be updated.

$package must be an absolute filename where the "translation_rules package" from which to make
    the update exists.

=cut

sub install_translation_rules {
    my($fig_disk,$from,$package) = @_;

    my $file = "$fig_disk/FIG/Data/Global/function.synonyms";
    &force_absolute($fig_disk);
    if (-d "$fig_disk/BackupTranslation_Rules") { system "rm -rf $fig_disk/BackupTranslation_Rules" }
    mkdir("$fig_disk/BackupTranslation_Rules",0777);
    chmod 02777,"$fig_disk/BackupTranslation_Rules";
    if (-s $file)
    {
	&FIG::run("cp $file $fig_disk/BackupTranslation_Rules");
    }
    &FIG::run("$FIG_Config::bin/merge_translation_rules $fig_disk/BackupTranslation_Rules/function.synonyms $package $from > $file");
    chmod 02777,$file;
}

=pod

=head3 restore_translation_rules

usage: &restore_translation_rules($fig_disk);

$fig_disk must be an absolute filename (begins with "/") giving the FIG to be updated.

=cut

sub restore_translation_rules {
    my($fig_disk) = @_;

    &force_absolute($fig_disk);

    my $file = "$fig_disk/FIG/Data/Global/function.synonyms";
    (-s "$fig_disk/BackupTranslation_Rules/function.synonyms") || die "could not find an active backup";
    if (-s "$fig_disk/BackupTranslation_Rules/function.synonyms")
    {
	&FIG::run("cp $fig_disk/BackupTranslation_Rules/function.synonyms $file");
	chmod 0777, $file;
    }
}

sub package_subsystems {
    my($fig,$file,$just_exchangable,$just_these) = @_;
    my($ssa,@exchangable);

    if (@$just_these > 0)
    {
	@exchangable = @$just_these;
    }
    else
    {
	$just_exchangable = defined($just_exchangable) ? $just_exchangable : 1;
	@exchangable = grep { (! $just_exchangable) || $fig->is_exchangable_subsystem($_) }
	               $fig->all_subsystems;
    }
    my $fig = new FIG;
    if ((@exchangable > 0) && open(SUB,">$file"))
    {
	foreach $ssa (@exchangable)
	{
#	    print STDERR "writing $ssa to $file\n";
	    my($spreadsheet,$notes) = $fig->exportable_subsystem($ssa);
	    print SUB join("",@$spreadsheet),join("",@$notes),"########################\n";
	}
	close(SUB);
    }
    else
    {
#	print STDERR &Dumper(\@exchangable,$file);
    }
}

sub install_subsystems {
    my($fig,$package) = @_;

    &FIG::run("$FIG_Config::bin/import_subsystems master last_release < $package");
}


=pod

=head2 unpack_packaged_subsystem

Unpack a packaged subsystem (from the clearinghouse or a p2p transfer)
into a directory; this will create a directory named as the subsystem
and formatted like the standard subsystem directories, as well as a
file of assignments and a file of sequences in fasta format.

Returns the name of the subsystem.

=cut

sub unpack_packaged_subsystem
{
    my($fig, $file, $target_dir) = @_;

    my $user = $fig->get_user();

    &FIG::verify_dir($target_dir);

    my $fh;

    if (!open($fh, "<$file"))
    {
	warn "unpack_packaged_subsystem: cannot open $file: $!";
	return undef;
    }

    #
    # We scan the file, breaking it up into sections and writing
    # to the appropriate places.
    #
    # First the header.
    #

    local $/ = "\n//\n";

    my $header = <$fh>;
    chomp $header;

    my ($name, $version, $exchangable, $curation) = split(/\n/, $header);

    print "Importing name=$name version=$version exch=$exchangable curation='$curation'\n";

    #
    # Pull in roles, subsets, and spreadsheet. These will be written to the new
    # spreadsheet file.
    #

    my $roles = <$fh>;
    chomp $roles;
    
    my $subsets = <$fh>;
    chomp $subsets;

    my $spreadsheet = <$fh>;
    chomp $spreadsheet;


    #
    # Pull the assignments and sequences. These go to their own files.
    #

    my $assignments = <$fh>;
    chomp $assignments;

    my $sequences = <$fh>;
    chomp $sequences;

    #
    # And the notes; these will be written to the subsystem dir.
    #

    my $notes = <$fh>;
    chomp $notes;

    close($fh);
    
    #
    # Everything is read. Now to write it all back out again.
    #

    #
    # First the subsystem.
    #

    my $ss_path = "$target_dir/subsystem";
    &FIG::verify_dir($ss_path);

    open($fh, ">$ss_path/EXCHANGABLE");
    print $fh "$exchangable\n";
    close($fh);

    open($fh, ">$ss_path/VERSION");
    print $fh "$version\n";
    close($fh);

    open($fh, ">$ss_path/curation.log");
    print $fh "$curation\n";
    my $now = time;
    print $fh "$now\t$user\timported\n";
    close($fh);

    open($fh, ">$ss_path/notes");
    print $fh "$notes\n";
    close($fh);
    
    open($fh, ">$ss_path/spreadsheet");
    print $fh "$roles\n";
    print $fh "//\n";
    print $fh "$subsets\n";
    print $fh "//\n";
    print $fh "$spreadsheet\n";
    close($fh);

    open($fh, ">$target_dir/subsystem_name");
    print $fh "$name\n";
    close($fh);

    open($fh, ">$target_dir/assignments");
    print $fh "$assignments\n";
    close($fh);

    open($fh, ">$target_dir/seqs.fasta");
    print $fh "$sequences\n";
    close($fh);

    return $name;
}

package SubsystemFile;

use Data::Dumper;
use strict;
use Carp;
use MIME::Base64;
    
sub new
{
    my($class, $qdir, $file, $fig) = @_;
    my(@info);

    my $use_cache = defined($qdir);

    @info = FIG::file_head($file, 4);
    if (!@info)
    {
	warn "Cannot open $file\n";
	return undef;
    }

    chomp(@info);

    my $name = $info[0];
    my $version = $info[1];
    my $exc = $info[2];

    my @c = split(/\t/, $info[3]);

    my $curator = $c[1];

    my $self = {
	qdir => $qdir,
	use_cache => $use_cache,
	file => $file,
	name => $name,
	version => $version,
	exchangable => $exc,
	curator => $curator,
	curation_log => $info[3],
	fig => $fig,
    };

    return bless($self, $class);
		  
}

#
# Load the export file into internal data structures.
#
# It's structured as
#
# name
# version
# exchangable
# creation date <tab> curator <tab> "started"
# //
# roles
# //
# subsets
# //
# spreadsheet
# //
# assignments
# //
# sequences
# //
# notes
# //
# reactions
#
# Subsections:
#
# roles:
#
#    abbr <tab> role-name
#
# subsets has meaning to the acutal subsystems, but we'll use it as a string.
#
# spreadsheet:
#
#    genome <tab> variant <tab> items
#
# Where items is tab-separated columns, each of which is comma-separated peg number in the genome
#
# assignments:
#
#  fid <tab> aliases <tab> organism <tab> function
#
# sequences:
#
#  list of fasta's
#
# notes:
#
#  plain text
#
sub load
{
    my($self) = @_;

    my $fig = $self->{fig};

    my($fh);

    open($fh, "<$self->{file}") or die "Cannot open $self->{file}: $!\n";

    #
    # Skip intro section - we already read this information in the constructor.
    #

    while (<$fh>)
    {
	chomp;
	last if m,^//,;
    }

    #
    # Read the roles.
    #


    my $nroles;
    
    while (<$fh>)
    {
	last if m,^//,;
	
	$self->{role_text} .= $_;
	chomp $_;

	my($abbr, $role) = split(/\t/);

	warn "Have role $role\n";
	
	push(@{$self->{roles}}, $role);
	push(@{$self->{abbrs}}, $abbr);

	$nroles++;
    }

    #
    # Read in subsets as a string.
    #

    while (<$fh>)
    {
	last if m,^//,;

	$self->{subsets_text} .= $_;
    }

    #
    # Read the spreadsheet.
    #

    while (<$fh>)
    {
	last if m,^//,;

	$self->{spreadsheet_text} .= $_;

	chomp;

	my($genome, $variant, @items) = split(/\t/, $_, $nroles + 2);

	push(@{$self->{genomes}}, $genome);

	my $gobj = GenomeObj->new($self, $fig, $genome, $variant, [@items]);

	$self->{genome_objs}->{$genome} = $gobj;
    }

    #
    # Read PEG info
    #

    while (<$fh>)
    {
	last if m,^//,;

	chomp;

	my ($peg, $aliases, $org, $func) = split(/\t/);

	push(@{$self->{pegs}}, [$peg, $aliases, $org, $func]);
    }

    #
    # Read sequence info
    #

    my($cur, $cur_peg);

    while (<$fh>)
    {
	if (/^>(fig\|\d+\.\d+\.peg\.\d+)/)
	{
	    if ($cur)
	    {
		$cur =~ s/\s+//gs;
		$self->{peg_seq}->{$cur_peg} = $cur;
	    }
	    $cur_peg = $1;
	    $cur = '';
	}
	elsif (m,^//,)
	{
	    $cur =~ s/\s+//gs;
	    $self->{peg_seq}->{$cur_peg} = $cur;
	    last;
	}
	else
	{
	    $cur .= $_;
	}
    }

    #
    # Read notes as a string
    #

    while (<$fh>)
    {
	last if m,^//,;

	$self->{notes_txt} .= $_;
    }

    #
    # Anything left here is reaction data.
    #

    my $reactions;

    while (<$fh>)
    {
	last if m,^//,;

	if (/^([^\t]+)\t([^\t]+)/)
	{
	    $reactions .= $_;
	}
    }

    $self->{reactions} = $reactions if $reactions ne "";
	    
    #
    # Additional sections. If $_ is //<something>, go ahead and process the blocks.
    #
    #

    my @blocks = ();
    
    if (m,^//(.*)$,)
    {
	chomp;
	my $cur_block;
	my $cur_tag = $1;
	while (<$fh>)
	{
	    if (m,^//end$,)
	    {
		push(@blocks, [$cur_tag, $cur_block]);
	    }
	    elsif (m,^//(.*)$,)
	    {
		chomp;
		$cur_block = [];
		$cur_tag = $1;
	    }
	    else
	    {
		push(@$cur_block, $_);
	    }
	}
    }
    $self->{blocks} = \@blocks;
}

#
# Compute or load from cache the PEG translations for this subsystem.
#
sub ensure_peg_translations
{
    my($self) = @_;
    
    #
    # First we map the PEGs in this subsystem to PEGs in the
    # local SEED.
    #
    # translate_pegs requires a hash of peg->[aliases] as the first argument,
    # and a hash of peg->sequence as the second argument.
    #

    my $fig = $self->{fig};
    
    my %pegs;
    my %seqs_of;

    for my $pegent (@{$self->{pegs}})
    {
	my($peg, $aliases, $org, $func) = @$pegent;
	$pegs{$peg} = [$aliases, $org, $func];
	$seqs_of{$peg} = $self->{peg_seq}->{$peg};
    }

    sub show_cb
    {
	print "$_[0]<p>\n";
    }

    my $cached_translation_file = "$self->{qdir}/peg_translation";

    my $tran_peg;

    if ($self->{use_cache} and -f $cached_translation_file and -s $cached_translation_file > 0)
    {
	#
	# Read the cached translations.
	#
	
	if (open(my $fh, "<$cached_translation_file"))
	{
	    warn "Reading cached peg translations\n";
	    $tran_peg = {};
	    while (<$fh>)
	    {
		chomp;
		my($k, $v) = split(/\t/);
		$tran_peg->{$k} = $v;
	    }
	    close($fh);
	}
    }

    if (!$tran_peg)
    {
	$tran_peg = $fig->translate_pegs(\%pegs, \%seqs_of, \&show_cb);

	#
	# tran_peg is now a hash from subsystem_peg->local_peg
	#

	#
	# Write the translations out to a file in the queue directory
	# for use during installation.
	#

	if ($self->{use_cache} and open(my $fh, ">$self->{qdir}/peg_translation"))
	{
	    for my $p (keys(%$tran_peg))
	    {
		my $tp = $tran_peg->{$p};
		print $fh "$p\t$tp\n";
	    }
	    close($fh);
	}
    }
    $self->{tran_peg} = $tran_peg;
    return $tran_peg;
}

#
# Analyze this subsystem for compatibility with this SEED install.
#
# Returns three lists:
#
# A major conflict list, consisting of tuples
# [$ss_peg, $ss_func, $loc_peg, $loc_func, $subs] where $ss_peg
# is the peg in the subsystem being analyzied, and $ss_func is
# its assigned function in that subsystem. $loc_peg is the peg
# in the local SEED, and $loc_func its local assignment. $subs is
# the list of pairs [$subsystem_name, $role] denoting the subsystem(s)
# that $loc_peg particpates in.
#
# A conflict is flagged if the local function is different than
# the one being imported, and if the local peg is in a subsystem.
#
# A minor conflict list, consisting of tuples [$ss_peg, $ss_func, $loc_peg, $loc_func].
#
#
# The second list is a list of subsystem pegs that do not have
# a local equivalent. Each entry is a triple
# [peg, orgname, function].
#

sub analyze
{
    my($self) = @_;
    my $fig = $self->{fig};

    my $tran_peg = $self->ensure_peg_translations();
    
    #
    # Now we walk the PEGs, determining a) which are missing
    # in the local SEED, and b) which have a conflicting assignment.
    #
    #
    # We also need to determine if this assignment will cause
    # pegs to be filled into subsystem roles that were not
    # otherwise going to be added.
    #
    # To enable this, we determine from the subsystem index
    # the list all roles that are present in subsystems on
    # this SEED. 
    #

    my $sub_name = $self->name();
    my $subsystem_roles = $fig->subsystem_roles();
    
    my(@conflict, $minor_conflict, $missing);

    #
    # Hashes for accumulating aggregate counts of conflicts.
    #

    my(%subs_in, %subs_out, %roles_in, %roles_out);

    $missing = [];

    print "Determining conflicts...<p>\n";

    for my $pegent (@{$self->{pegs}})
    {
	my($ss_peg, undef, $ss_org, $ss_func) = @$pegent;

	#
	# If this peg has a local translation, determine if
	# the associated assignment conflicts with a local assignment.
	#
	# One type of conflict occurs when the new assignment would cause
	# the peg to be removed from a subsystem. This occurs when the
	# new functional assignment is different from the current
	# assignment, and the peg is already in a subsystem.
	#
	# Another type of conflict occurs when the new assignment
	# for a peg matches a role that exists in a locally-installed
	# subsystem. This will cause the peg to be added to a
	# subsystem upon refill of that subsystem.
	#
	# It is possible for both the above conditions to hold,
	# in which case a peg would be moved out of one
	# subsystem into another.
	#
	# We denote these cases in the generated conflict list by
	# annotating the entry with the list of subsystems from which
	# the peg would be removed if the assignment were to be
	# accepted, and the list of subsystems to which the
	# peg would be added.
	#

	if (my $loc_peg = $tran_peg->{$ss_peg})
	{
	    my $subs_removed = [];
	    my $subs_added = [];
	    
	    #
	    # Determine what our locally-assigned function is, and what
	    # subsystem this peg appears in.
	    #
	    
	    my $loc_func = $fig->function_of($loc_peg);

	    #
	    # If the functions don't match, it's a conflict.
	    # If the local function is in a subsystem, it's a major
	    # conflict. If it's not, it's a minor conflict.
	    #
	    # We actually let the major/minor determination be done by
	    # the analysis display code, since the difference is only in whether
	    # there are subsystems.
	    #
	    
	    if ($loc_func ne $ss_func)
	    {

		#
		# If the function defined in the new subsystem is different than
		# the current function, we mark a conflict. Along with the conflict
		# we include a list of the subsystems in which the local peg
		# is included.
		#
		# We use the subsystems_for_peg method to determine local subsystems
		# associated with a peg. It returns a list of pairs [subsystem, rolename].
		#
		
		#
		# What if we are loading a new version of an existing subsystem, and
		# a role name has changed?
		#
		# In this case, $loc_func ne $ss_func, $loc_peg will appear in the local copy of
		# the subsystem we are loading, and hence as a candidate for removal from that subsystem.
		# This may be thought of as a spurious message, and leads me to want to remove
		# such warnings (if I'm updating a subsystem, I can expect that the pegs in that
		# subsystem will change).
		#
		# subsystems_for_peg returns a list of pairs [subsystem, role].
		#
		# There might be somethign of a discrepancy here. This only
		# measures the subsystems the peg is actually currently part of, not
		# the number of subsystems that have a role corresponding to the peg's
		# current assignment.
		#

		my @removed = $fig->subsystems_for_peg($loc_peg);

		for my $r (@removed)
		{
		    my($rsub, $rrole) = @$r;

		    #
		    # Skip the numbers for an existing subsystem.
		    #
		    next if $rsub eq $sub_name;

		    $roles_out{$rrole}++;
		    $subs_out{$rsub}++;

		    push(@$subs_removed, $r);
		}

		#
		# We also check to see if the new function is present
		# as a role in any local subsystem. If it is, then when that subsystem
		# is refilled, this peg will appear in it.
		#
		# $subsystem_roles is a hash keyed on role name with each value
		# a list of subsystem names.
		#

		if (my $loc_ss = $subsystem_roles->{$ss_func})
		{
		    #
		    # $loc_ss is the set of subsystems that have the new
		    # function assignment as a role name.
		    #
		    my @subs = grep { $_ ne $sub_name} @$loc_ss;

		    if (@subs)
		    {
			push(@$subs_added, @subs);

			map { $subs_in{$_}++ } @subs;
			$roles_in{$ss_func}++;
		    }
		}

		push(@conflict, [$ss_peg, $ss_func, $loc_peg, $loc_func, $subs_removed, $subs_added]);
	    }
	    
	}
	else
	{
	    push(@$missing, [$ss_peg, $ss_org, $ss_func]);
	}
    }

    my $conflict = [sort { @{$b->[4]} + @{$b->[5]} <=> @{$a->[4]} + @{$a->[5]}  } @conflict];

    my $aggreg = {
	roles_in => [keys(%roles_in)],
	roles_out => [keys(%roles_out)],
	subs_in => [keys(%subs_in)],
	subs_out => [keys(%subs_out)],
    };

    return ($conflict, $missing, $aggreg);
}

sub read_cached_analysis
{
    my($self) = @_;

    my $cfile = "$self->{qdir}/conflicts";
    my $mfile = "$self->{qdir}/missing";

    my($conflict, $missing);
    $conflict = [];
    $missing = [];

    if (open(my $fh, "<$cfile"))
    {

	while (<$fh>)
	{
	    chomp;

	    my($ss_peg, $ss_func, $loc_peg, $loc_func) = split(/\t/);

	    my $subs_removed = <$fh>;
	    my $subs_added = <$fh>;

	    chomp($subs_removed);
	    chomp($subs_added);

	    my @subs_removed_raw = split(/\t/, $subs_removed);
	    my $subs_added_list = [split(/\t/, $subs_added)];

	    my $subs_removed_list = [];

	    while (@subs_removed_raw)
	    {
		my($v1, $v2, @rest) = @subs_removed_raw;
		@subs_removed_raw = @rest;
		push(@$subs_removed_list, [$v1, $v2]);
	    }
	    
	    push(@$conflict, [$ss_peg, $ss_func, $loc_peg, $loc_func, $subs_removed_list, $subs_added_list]);
	}
    }

    if (open(my $fh, "<$mfile"))
    {

	while (<$fh>)
	{
	    chomp;

	    my(@a) = split(/\t/);
	    push(@$missing, [@a]);
	}
    }

    return($conflict, $missing);
}

#
# Install this subsystem.
#
# $dont_assign is a list of subsytem PEGs that should not have their assignments overwritten.
#
# We return a list of for-the-installer messages that will be presented when the install completes.
#
# If $assignments_file is set, assignments will be written to that file
# instead of being installed. 
#
sub install
{
    my($self, $dont_assign, $imported_from, $assignments_file) = @_;

    my @messages;

    my $fig = $self->{fig};
    my $subsystems_dir = "$FIG_Config::data/Subsystems";

    my $sub_name = $self->name();
    $sub_name =~ s/ /_/g;
    my $sub_dir = "$subsystems_dir/$sub_name";
    my $ver = $self->version();
    
    #
    # First check to see if we already have this subsystem installed.
    #

    if (-d $sub_dir and (my $cur_ver = $fig->subsystem_version($sub_name)) >= $ver)
    {
	warn "Not importing $sub_name: current version $cur_ver >= imported version $ver";
	push(@messages, "Not importing $sub_name: current version $cur_ver >= imported version $ver\n");
	return @messages;
    }

    warn "Importing $sub_name version $ver\n";
    push(@messages, "Importing $sub_name version $ver\n");

    if (! -d $sub_dir)
    {
	mkdir($sub_dir, 0777) or die "Cannot mkdir $sub_dir: $!";
    }

    #
    # Write the header/meta information.
    #

    my $fh;
    $imported_from = "???" unless $imported_from ne '';

    open($fh, ">$sub_dir/VERSION") or die "Cannot open $sub_dir/VERSION for writing: $!";
    print $fh "$ver\n";
    close($fh);
    chmod(0666, "$sub_dir/VERSION");

    open($fh, ">$sub_dir/EXCHANGABLE") or die "Cannot open $sub_dir/EXCHANGABLE for writing: $!";
    print $fh $self->exchangable() . "\n";
    close($fh);
    chmod(0666, "$sub_dir/EXCHANGABLE");
       
    open($fh, ">$sub_dir/curation.log") or die "Cannot open $sub_dir/curation.logt for writing: $!";
    print $fh "$self->{curation_log}\n";
    my $time = time;
    print $fh "$time\t$imported_from\timported_from\n";
    close($fh);
    chmod(0666, "$sub_dir/curation.log");

    open($fh, ">$sub_dir/notes") or die "Cannot open $sub_dir/notes for writing: $!";
    print $fh $self->{notes_txt} . "\n";
    close($fh);
    chmod(0666, "$sub_dir/notes");

    if ($self->{reactions})
    {
	open($fh, ">$sub_dir/reactions") or die "Cannot open $sub_dir/reactions for writing: $!";
	print $fh $self->{reactions} . "\n";
	close($fh);
	chmod(0666, "$sub_dir/reactions");
    }
       
    my $tran_peg = $self->ensure_peg_translations();

    #
    # We can start writing the spreadsheet.
    #

    my $ssa_fh;
    open($ssa_fh, ">$sub_dir/spreadsheet") or die "Cannot open $sub_dir/spreadsheet for writing: $!";
    
    #
    # Start with the roles and subsets.
    #
    
    print $ssa_fh $self->{role_text};
    print $ssa_fh "//\n";

    print $ssa_fh $self->{subsets_text};
    print $ssa_fh "//\n";

    for my $g (@{$self->{genomes}})
    {
	my $gobj = $self->{genome_objs}->{$g};
	my ($trans_genome, @row) = $gobj->translate($tran_peg);

	if ($trans_genome)
	{
	    print $ssa_fh join("\t", $trans_genome, $gobj->{variant}, @row), "\n";
	}
    }

    close($ssa_fh);

    #
    # The subsystem itself is now in place. Depending on how we were
    # invoked, write the assignments to a file, or install them on
    # the system.
    #
    # If dont_assign is not a list but is true, save no assignments at all.
    #
    if (!ref($dont_assign) and $dont_assign)
    {
	# Skip assignments
    }
    elsif (defined($assignments_file))
    {
	$self->write_assignments_to_file(\@messages, $tran_peg, $assignments_file);
    }
    else
    {
	$self->install_assignments(\@messages, $tran_peg, $dont_assign);
    }

    $self->install_blocks(\@messages, $sub_dir);

    #
    #  Index, and mark the subsystem cache as dirty.
    #

    my $figss = $fig->get_subsystem($sub_name);
    $figss->db_sync();
    $fig->mark_subsystems_modified();

    return @messages;
}

#
# Install any other block-data code that's in the package. Right now this is just
# the diagrams.
#
# We also store the OWNER file in a block.
#
sub install_blocks
{
    my($self, $messages, $sub_dir) = @_;
    my $fig = $self->{fig};

    #
    # At this point, the rest of the subsystem is written to disk. We can
    # use the Subsys.pm mechanism to write this stuff out.
    #

    my $sub = $fig->get_subsystem($self->name());

    for my $block (@{$self->{blocks}})
    {
	my($block_hdr, $block_data) = @$block;

	if ($block_hdr =~ /^OWNER:(\S+)$/)
	{
	    $sub->set_curator($1);
	}
	elsif ($block_hdr =~ /^diagram:([^:]+):name\t(\S+)/)
	{
	    #
	    # The diagram output format ensures this is the first block, so just
	    # create the diagram.
	    #
	    
	    my $diagram_id = $1;
	    my $diagram_name = $2;

	    $sub->create_new_diagram(undef, undef, $diagram_name, $diagram_id, 1);
	}
	elsif ($block_hdr =~ m,^diagram:([^:]+):diagram=([^\s/]+)\t(\d+),)
	{
	    my $diagram_id = $1;
	    my $img_file = $2;
	    my $size = $3;

	    my $ddir = "$sub_dir/diagrams/$diagram_id";

	    if (! -d $ddir)
	    {
		push(@$messages, "Invalid diagrams: diagram directory for $diagram_id did not exist while parsing diagram file\n");
		next;
	    }

	    if (!open(FH, ">$ddir/$img_file"))
	    {
		push(@$messages, "Cannot open image file $ddir/$img_file for writing: $!\n");
		next;
	    }

	    for my $line (@$block_data)
	    {
		$line =~ s/^B://;
		my $dec = decode_base64($line); 
		print FH $dec;
	    }
	    close(FH);

	    my $fsize = -s "$ddir/$img_file";
	    if ($fsize != $size)
	    {
		push(@$messages, "Diagram image $img_file size $fsize does not match declared size $size\n");
		warn "Diagram image $img_file size $fsize does not match declared size $size";
	    }
	}
    }
}
    
   

sub write_assignments_to_file
{
    my($self, $messages, $tran_peg, $filename) = @_;
    my $fig = $self->{fig};

    my $fh;

    for my $pegent (@{$self->{pegs}})
    {
	my($peg, $aliases, $org, $func) = @$pegent;
	my $tpeg = $tran_peg->{$peg};

	if (!$tpeg)
	{
	    warn "Couldn't translate $peg (from $org)\n";
	    push(@$messages, "Couldn't translate $peg (from $org)");
	    next;
	}

	my $old = $fig->function_of($tpeg);

	if ($old ne $func)
	{
	    #
	    # Only open the file if we have assignments to write.
	    #
	    
	    if (!defined($fh))
	    {
		open($fh, ">$filename") or confess "Error opening $filename for writing: $!";
	    }
	    print $fh "$tpeg\t$func\n";
	}
    }
    if (defined($fh))
    {
	close($fh);
    }
}


sub install_assignments
{
    my($self, $messages, $tran_peg, $dont_assign) = @_;
    my $fig = $self->{fig};
    
    #
    # Enter the new assignments, saving the old assignments in the  spool dir.
    #

    my $now = time;

    my $old_funcs_fh;
    open($old_funcs_fh, ">>$self->{qdir}/old_assignments.$now");

    my $curator = $self->curator();

    my %dont_assign;

    map { $dont_assign{$_}++ } @$dont_assign;

    for my $pegent (@{$self->{pegs}})
    {
	my($peg, $aliases, $org, $func) = @$pegent;
	my $tpeg = $tran_peg->{$peg};

	if (!$tpeg)
	{
	    warn "Couldn't translate $peg (from $org)\n";
	    push(@$messages, "Couldn't translate $peg (from $org)");
	    next;
	}

	if ($dont_assign{$peg})
	{
	    warn "Skipping assignment of $peg ($tpeg locally)\n";
	    next;
	}

	my $old = $fig->function_of($tpeg);

	if ($old ne $func)
	{
	    print $old_funcs_fh "$tpeg\t$old\t$curator\t$func\n";
	    $fig->add_annotation($tpeg, $curator,
				 "Assigning function $func based on installation of subsystem $self->{name}");

	    #  Everyone is now master, and assign_function adds annotation
	    #
	    # if ($curator =~ /master:(.*)/)
	    # {
	    #     my $user = $1;
	    #     $fig->assign_function($tpeg, "master", $func, "");
	    #     $fig->add_annotation($tpeg, $user, "Set master function to\n$func\n");
	    # }
	    # else
	    # {

	    $fig->assign_function($tpeg, $curator, $func, "");

	    #     $fig->add_annotation($tpeg, $curator, "Set function to\n$func\n");
	    # }
	}
	else
	{
	    # print "$tpeg already has assignment $func\n";
	}
    }
    close($old_funcs_fh);
}

#
# Read the aggregate analysis results.
#

sub aggregate_analysis
{
    my($self) = @_;

    if (open(my $fh, "<$self->{qdir}/aggregate"))
    {
	local($/);
	my $txt = <$fh>;
	close($fh);

	my $VAR1;		# For the Dumper'd data.

	my $compartment = new Safe;
	my $aggr = $compartment->reval($txt);
	if ($@)
	{
	    warn "aggregate_analysis: error parsing saved data: $@";
	    return undef;
	}
	return $aggr;
    }
    else
    {
	return undef;
    }
}

sub name
{
    my($self) = @_;
    return $self->{name};
}


sub version
{
    my($self) = @_;
    return $self->{version};
}

sub exchangable
{
    my($self) = @_;
    return $self->{exchangable};
}

sub curator
{
    my($self) = @_;
    return $self->{curator};
}

sub analysis_complete
{
    my($self) = @_;

    return -f "$self->{qdir}/analysis_complete";
}

sub analysis_jobid
{
    my($self) = @_;

    my $jid_file = "$self->{qdir}/analysis_jobid";

    return &FIG::file_head($jid_file, 1);
}

package GenomeObj;

use strict;
use Data::Dumper;

#
# A genomeobj is a small datatype that holds the data in a row of a
# spreadsheet file.
#

sub new
{
    my($class, $subfile, $fig, $genome, $variant, $items) = @_;

    my $self = {
	fig => $fig,
	subfile => $subfile, 
	genome => $genome,
	variant => $variant,
	items => $items,
    };
    return bless($self, $class);
	
}

#
# Translate this row to a new context.
#
# $trans_peg is a hash mapping from spreadsheet PEG to local PEG
#
sub translate
{
    my($self, $trans_peg) = @_;
    my $fig = $self->{fig};

    my $genome = $self->{genome};

    my $parsed_items = [];
    $self->{parsed_items} = $parsed_items;
    my $trans_items = [];
    $self->{trans_items} = $trans_items;

    #
    # Hash of genomes seen in this row.
    my %genomes;

    for my $item (@{$self->{items}})
    {
        my $l = [];
        for my $fid (split(/,/, $item))
	{
	    if ($fid =~ /^\d+$/)
	    {
		push(@$l, "fig|$genome.peg.$fid");
	    }
	    else
	    {
		push(@$l, "fig|$genome.$fid");
	    }
	}
	
	my $t = [ map { $trans_peg->{$_} } @$l ];

	push(@$parsed_items, $l);
	push(@$trans_items, $t);

	#
	# Count the genomes that are seen in the translated pegs.
	#

	for my $tpeg (@$t)
	{
	    my $tg = $fig->genome_of($tpeg);
	    $genomes{$tg}++ if $tg ne "";
	}

    }

    #
    # Now determine the dominant organism for this translated row.
    #

    my @orgs = sort { $genomes{$b} <=> $genomes{$a} } keys(%genomes);

    # print "@{$self->{items}}\n";
    # print join(" ", map { "$_: $genomes{$_} " } @orgs ), "\n";

    unless (@orgs == 1		# Single organism
	or
	(@orgs > 1 and $genomes{$orgs[0]} > (2 * $genomes{$orgs[1]})) # First org has > 2x the second org
	)
    {
	warn "Could not determine translation for $genome\n";
	return undef;
    }
    
    #
    # The dominant organism is the first in the list.
    #

    my $dom = $orgs[0];

    #
    # Run through the translated pegs, and remove the ones that are
    # not in the dominant organism.
    #

    my @res;
    for my $i (0..@$trans_items - 1)
    {
	my $t = $trans_items->[$i];

	my @nt;
	for my $peg (@$t)
	{
	    if ($peg =~ /^fig\|(\d+\.\d+)\.peg\.(\d+)$/)
	    {
		if ($1 eq $dom)
		{
		    push(@nt, $2);
		}
	    }
            elsif ($peg =~ /^fig\|(\d+\.\d+)\.([^.]+\.\d+)$/)
	    {
		if ($1 eq $dom)
		{
		    push(@nt, $2);
		}
	    }
	}
	push(@res, join(",", @nt));
    }
    return $dom, @res;
}
1
