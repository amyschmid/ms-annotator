package CloseStrains;
use SeedEnv;
use strict;
use Data::Dumper;
use File::Copy;
use File::Path 'make_path';
use File::Temp 'tempfile';
use GenomeTypeObject;
use tree_utilities;
use URI::Escape;  # uri_escape
use Carp;
use JSON::XS;
use Biochemistry;

our $have_mousse = 0;
eval {
    require Search::Mousse;
    require Search::Mousse::Writer;
    require Uniq;
    $have_mousse = 1;
};


#===============================================================================

sub RAST2_to_CS_guts {
    my($in_dir,$cs_dir) = @_;

    my @outgroups = ([ 83333.1,'Escherichia'],
		     [ 224308.1,'Bacillus'],
		     [ 1140.7,'Synechococcus'],
		     [ 243274.5,'Thermotoga']);

    open(REPG,">$cs_dir/rep.genomes") || die "could not open rep.genomes";
    open(TYPES,">$cs_dir/genome.types") || die "could not open genome.types";
    open(NAMES,">$cs_dir/genome.names") || die "could not open genome.names";
    foreach my $tuple (@outgroups)
    {
	my($gid,$name) = @$tuple;
	print NAMES join("\t",($gid,$name)),"\n";
	print TYPES  join("\t",($gid,'SEED')),"\n";
        print REPG $gid,"\n";
    }

    opendir(IN,$in_dir) || die "could not open $in_dir";
    my @gids = grep { $_ !~ /^\./ } readdir(IN);
    closedir(IN);

    foreach my $gid (@gids)
    {
	my $gto = GenomeTypeObject->create_from_file("$in_dir/$gid");
	my $name = $gto->{scientific_name};
	print NAMES "$gid\t$name\n";
	print TYPES "$gid\tRAST2";
	print REPG  join("\t",("rast2|$gid",$in_dir)),"\n";
    }
    close(NAMES);
    close(TYPES);
    close(REPG);
    &SeedUtils::run("svr_CS -d $cs_dir");
}

sub get_outgroups_list
{
    my @outgroups = ([ 83333.1,'Escherichia'],
		     [ 224308.1,'Bacillus'],
		     [ 1140.7,'Synechococcus'],
		     [ 243274.5,'Thermotoga']);
    return @outgroups;
}

sub get_closest_genome_set
{
    my($closest, $N) = @_;

    my @closest = @$closest;

    my @set = splice(@closest, 0, 4);
    my $stride = int(@closest / $N);
    for (my $i=0; ($i < @closest); $i += $stride)
    {
	push(@set,$closest[$i]);
    }
    return @set;
}

sub RAST_job_to_CS_directory {
    my($jobID,$csD,$N,$close_genomes) = @_;

    my @outgroups = get_outgroups_list();;

    my $rpD = "/vol/rast-prod/jobs/$jobID/rp";
    opendir(RPD,$rpD) || return undef;
    my @tmp = grep { $_ =~ /^(\d+\.\d+)/ } readdir(RPD);
    closedir(RPD);
    my $gid = $tmp[0] || return undef;
    my $rastD = "$rpD/$gid";
    my @closest = map { ($_ =~ /^(\S+)\t(\S+)/) ? [$1,$2] : () } `cut -f1,3 $rastD/closest.genomes`;
    if (@closest < $N) { return undef }
    my @set = get_closest_genome_set(\@closest, $N);
    push(@set,@outgroups);
    mkdir($csD,0777);
    open(CS,">$csD/rep.genomes") || die "could not open $csD/rep.genomes";
    print CS "rast|$jobID\tRossO\tanno4all\n";
    foreach $_ (@set)
    {
	my $seed_id = $_->[0];
	print CS "$seed_id\n";
    }
    close(CS);
    &SeedUtils::run("svr_CS -d $csD");
}


#===============================================================================
# This code takes a CS directory containing a rep.genomes file as input.
# The rep.genome entries represent pubSEED, CS (i.e., Kbase), and RAST genomes.
# The genome list in rep.genomes is used to construct a directory ($csD/GTOs) of
# typed genome objects.  These GTOs are independent of source, freeing the remainer
# of the code from worrying about where the genomes came from.
#
# The lines in the rep.genomes file can be
#
#       a genome id (implying PubSEED)
#       rast|JOB\tUSERNAME\tPASSWORD  (implying a RAST job)
#       kb|g.\d+ implying a CS genome
#       rast2|genomeID\tRAST2DIR (I am uncertain of what this does; I would guess
#            that is specifies a directory and a GTO in the directory
# 
sub get_genome_objects {
    my($csD) = @_;

    my $gtoD = "$csD/GTOs";
    mkdir($gtoD,0777);
    open(TYPES,">$csD/genome.types") || die "could not open $csD/genome.types";
    foreach $_ (`cat $csD/rep.genomes`)
    {
	if ($_ =~ /^(\d+\.\d+)$/)       # if single field with PubSEED ID
	{
	    my $gid = $1;
	    get_pubseed_genome_object($gtoD, $gid, \*TYPES);
	}
	elsif ($_ =~ /^rast\|(\d+)\t(\S+)\t(\S+)/)   # takes a rast job number
	{
	    my($job_id,$username,$passwd) = ($1,$2,$3);
	    get_rast_genome_object($gtoD, $job_id, $username, $passwd, \*TYPES);
	}
	elsif ($_ =~ /^(kb\|g\.\d+)$/)
	{
	    my $gid = $1;
	    get_cs_genome_object($gtoD, $gid, \*TYPES);
	}
	elsif ($_ =~ /^rast2\|(\S+)\t(\S+)/)
	{
	    my($gid,$rast2_dir) = ($1,$2);
	    use_genome_object_file($gtoD, $gid, "$rast2_dir/$gid", \*TYPES);
	}
    }
    close(TYPES);
}

#
# interface called from RAST web interface for creating GTOs from
# list of rast jobs and list of refs.
#
sub create_set_from_rast
{
    my($csD, $ref_genomes, $rast_genome_objs) = @_;

    open(REPS, ">", "$csD/rep.genomes") or die "Cannot create $csD/rep.genomes: $!";
    my $gtoD = "$csD/GTOs";
    make_path($gtoD);
    open(TYPES, ">", "$csD/genome.types") or die "Cannot create $csD/genome.types: $!";
    for my $ref (@$ref_genomes)
    {
	#
	# We defer this for now as it is time consuming.
	# We invoke svr_CS with a flag that says to fill in any missing
	# non-RAST genomes.
	# get_pubseed_genome_object($gtoD, $ref, \*TYPES);
	print REPS "$ref\n";
    }
    for my $elt (@$rast_genome_objs)
    {
	my($job_id, $obj) = @$elt;
	use_genome_object($gtoD, $obj, "RAST", \*TYPES);
	print REPS "rast|$job_id\n";
    }
    close(REPS);
    close(TYPES);

    set_status($csD, "awaiting computation");
}

sub get_pubseed_genome_object
{
    my($gtoD, $gid, $types_fh) = @_;
    &SeedUtils::run("get_genome_object_from_seed --pretty -o $gtoD/$gid PubSEED $gid");
    print $types_fh join("\t", $gid, 'SEED'),"\n";
}

sub get_rast_genome_object
{
    my($gtoD, $job_id, $username, $passwd, $types_fh) = @_;
    &SeedUtils::run("get_genome_object_from_seed --pretty -o $gtoD/$job_id RAST --username $username --password $passwd $job_id");
    my $gto = GenomeTypeObject->create_from_file("$gtoD/$job_id");
    my $gid = $gto->{id};
    print STDERR "creating GTO $gid from job $job_id\n";
    rename("$gtoD/$job_id", "$gtoD/$gid");
    print $types_fh join("\t",($gid,'RAST',$job_id)),"\n";
}

sub get_cs_genome_object
{
    my($gtoD, $gid, $types_fh) = @_;
    &SeedUtils::run("cs_to_genome -o '$gtoD/$gid' '$gid'");
    print $types_fh join("\t",($gid,'KBase')),"\n";
}

sub use_genome_object_file
{
    my($gtoD, $gid, $gobj_file, $types_fh) = @_;
    copy($gobj_file, "$gtoD/$gid");
    print $types_fh join("\t",($gid,"RAST2")),"\n";
}

sub use_genome_object
{
    my($gtoD, $gobj, $type, $types_fh) = @_;
    my $fh;
    my $gid = $gobj->{id};
    open($fh, ">", "$gtoD/$gid") or die "Cannot write $gtoD/$gid: $!";
    my $json = JSON::XS->new->pretty(1);
    print $fh $json->encode($gobj);
    close($fh);
    print $types_fh join("\t",($gid,$type)),"\n";
}

# We build a genome.names file in the $csD.  This is largely for compatability with
# older versions, since the names are just copied from the GTOs into the genome.names file.

sub get_genome_name {
    my($csD) = @_;
    my $gtoD = "$csD/GTOs";
    open(NAMES,">$csD/genome.names") || die "could not create $csD/genome.names";
    opendir(GTOS,$gtoD) || die "could not open $gtoD";
    my @gids = grep { $_ !~ /^\./ } readdir(GTOS);
    closedir(GTOS);
    foreach my $gid (@gids)
    {
	my $gto = GenomeTypeObject->create_from_file("$gtoD/$gid");
	my $name = $gto->{scientific_name};
	print NAMES "$gid\t$name\n";
    }
    close(NAMES);
}

sub set_status
{
    my($csD, $status) = @_;
    my $sfile = "$csD/STATUS";
    unlink($sfile);
    open(S, ">", $sfile);
    print S "$status\n";
    close(S);
}

sub genome_types {
    my($dataDF) = @_;

    my %types = map {($_ =~ /^(\S+)\t(\S+)/) ? ($1 => $2) : () } `cat $dataDF/genome.types`;
    return \%types;
}

# We make the directory $csD/Seqs contain protein sequences for each of the genomes.
# The genome id is used as the name of the file for each genome's translations

sub get_translations {
    my($csD) = @_;

    my $tranD = "$csD/Seqs";
    if (! -d $tranD) { mkdir($tranD,0777) }
    my $GTOsD = "$csD/GTOs";
    opendir(GTOS,$GTOsD) || die "Failed to open $GTOsD";
    my @genomes = grep { $_ !~ /^\./ } readdir(GTOS);
    closedir(GTOS);
    foreach my $genome (@genomes)
    {
	my $gto = GenomeTypeObject->create_from_file("$GTOsD/$genome");
	$gto->write_protein_translations_to_file("$tranD/$genome",'peg','CDS');
    }
}

# Similarly, we keep a directory, $csD/PegLocs, used to store pEG locations.

sub get_locations {
    my($csD) = @_;

    my $locD = "$csD/PegLocs";
    if (! -d $locD) { mkdir($locD,0777) }
    my $GTOsD = "$csD/GTOs";
    opendir(GTOS,$GTOsD) || die "Failed to open $GTOsD";
    my @genomes = grep { $_ !~ /^\./ } readdir(GTOS);
    closedir(GTOS);
    foreach my $genome (@genomes)
    {
	my $gto = GenomeTypeObject->create_from_file("$GTOsD/$genome");
	$gto->write_feature_locations_to_file("$locD/$genome",'peg','CDS');
    }
}

# build_tree builds $csD/labeled.tree and $csD/readable.tree.  These are based on
# concatenated alignments of universally occurring traslations.

sub build_tree {
    my($csD) = @_;

    &SeedUtils::run("CS_build_fasta_for_phylogeny -d $csD");
    &SeedUtils::run("pg_build_newick_tree -d $csD");
    my @labels = map { ($_ =~ /^(\S+)\t(\S.*\S)/) ? "$1\t$1: $2" : () } `cat $csD/genome.names`;
    my($labels_fh, $labels_file)  = tempfile();
    foreach $_ (@labels)
    {
	print $labels_fh "$_\n";
    }
    close($labels_fh);
    &SeedUtils::run("svr_reroot_tree -m < $csD/estimated.phylogeny.nwk | label_all_nodes > $csD/labeled.tree");
    &SeedUtils::run("sketch_tree -a -l $labels_file  < $csD/labeled.tree > $csD/readable.tree");
    unlink($labels_file);
}

sub place_families_on_tree {
    my($csD) = @_;
    open(ONTREE,">$csD/tmp.prop.$$")
	|| die "could not open $csD/tmp.prop.$$";
#   my @fams = map { ($_ =~ /^(\d+)\tfig\|(\d+\.\d+)/) ? [$1,$2] : () } `cut -f1,4 $csD/families.all`;
    my @fams = map { ($_ =~ /^(\d+)\t(\S+)/) ? [$1,$2] : () } `cut -f1,4 $csD/families.all`;
    @fams    = map { $_->[1] = &SeedUtils::genome_of($_->[1]); $_ } @fams;  # derive genome from feature  ### Fix for KBase
#   @fams is a list of 2-tuples: [fam,genome]  There may be duplicates

    my %genomes = map { ($_->[1] => 1) } @fams;
    my @genomes = keys(%genomes);
    my $last = shift @fams;
    while ($last)
    {
	my $fam = $last->[0];
	my %has;
	while ($last && ($last->[0] == $fam))
	{
	    $has{$last->[1]} = 1;
	    $last = shift @fams;
	}
	foreach my $g (@genomes)
	{
	    print ONTREE join("\t",($fam,$g,($has{$g} ? 1 : 0))),"\n";
	}
    }
    close(ONTREE);
    &SeedUtils::run("place_properties_on_tree -t $csD/labeled.tree -p $csD/tmp.prop.$$ -e $csD/families.on.tree");
    &SeedUtils::run("where_shifts_occurred  -t $csD/labeled.tree -e $csD/families.on.tree > $csD/where.shifts.occurred");
##
### Now place reactions on tree
##
    my $reaction_occurrences = &reactions_present("$csD/families.all");
    open(ONTREE,">$csD/tmp.prop.$$")
	|| die "could not open $csD/tmp.prop.$$";
    foreach my $reaction (sort keys(%$reaction_occurrences))
    {
	foreach my $g (@genomes)
	{
	    print ONTREE join("\t",($reaction,$g,($reaction_occurrences->{$reaction}->{$g} ? 1 : 0))),"\n";
	}
    }

    close(ONTREE);
    &SeedUtils::run("place_properties_on_tree -t $csD/labeled.tree -p $csD/tmp.prop.$$ -e $csD/reactions.on.tree");
    &SeedUtils::run("where_shifts_occurred  -t $csD/labeled.tree -e $csD/reactions.on.tree > $csD/where.reaction.shifts.occurred");
    unlink("$csD/tmp.prop.$$");

##############
    &SeedUtils::run("cs_adjacency_data -d $csD");
}

sub reactions_present {
    my($familiesF) = @_;

    my %complexes;
    my $roles_used_in_modeling = &Biochemistry::roles_used_in_modeling;
    my %rolesH = map { ($_ => 1) } @$roles_used_in_modeling;

    my %roles_hit;
    foreach $_ (`cat $familiesF`)
    {
	if ($_ =~ /^\S+\t(\S[^\t]*)\t[^\t]*\tfig\|(\d+\.\d+)/)
	{
	    my $function = $1;
	    my $genome   = $2;
	    foreach my $role (&SeedUtils::roles_of_function($function))
	    {
		if ($rolesH{$role})
		{
		    push(@{$roles_hit{$genome}},$role);
		}
	    }
	}
    }

    my %reaction_occurrences;
    foreach my $genome (keys(%roles_hit))
    {
	my $roles_in_genome = $roles_hit{$genome};
	my $reactions = &Biochemistry::roles_to_reactions($roles_in_genome);
	foreach my $r (@$reactions)
	{
	    $reaction_occurrences{$r}->{$genome} = 1;
	}
    }
    return \%reaction_occurrences;
}

##########################################

sub show_options_for_otu {
    my($cgi,$g,$dataDF,$base) = @_;

    my @html;
    push (@html,$cgi->header,
                "<h3>$g<br>Types of Variance</h3>\n",
                "<ol>\n",
                "<li><a target='_blank' href=wc.cgi?request=show_signatures&base=$base&dataD=$g>Families that act as Signatures</a>\n",
	        "<li><a target='_blank' href=wc.cgi?request=show_otu_tree&dataD=$g&base=$base>Gains/losses of Gene Families</a>\n");

    if (-s "$dataDF/reactions.on.tree")
    {
        push (@html,
	      "<li> <a target='_blank' href=wc.cgi?request=show_options_for_reactions&base=$base&dataD=$g>Changes Relating to the Reaction Network</a>\n");
    }
    push (@html,
	        "<li><a target='_blank' href=wc.cgi?request=show_adjacency&dataD=$g&base=$base>Changes in Adjacency</a>\n".
	        "</ol>\n");
    my $txt = <<END;
 <pre><br><hr>
To start, we suggest choosing the first option to explore which families act as
signatures for phylogentic groups.  This will bring you to a page where you select
two sets of genomes and then find the genes that distinguish the two sets.
<br>
The second option allows you to ask which genes appear to be gained or lost on an arc in
the phylogenetic tree.
<br>
The third option allows you to see at what nodes reactions were gained or lost.
<br>
The fourth option allows you to explore "changes in adjacency", which often correspond
to rearrangements.

You also have the option of examining sets of families associated with a function.
To do that, type in a few keywords from the function in the following text field and
see what functions match.  If any look like the one you are interested in, you can
locate the sets with members assigned the function.

END
    push(@html,$txt);
    push(@html,"<br>",
                $cgi->start_form(-action => "./wc.cgi"),
	        $cgi->textfield(-name => 'keywords',-size => 100),
	        $cgi->hidden(-override => 1,-name => 'request',-value => 'show_indexed_funcs'),
	        $cgi->hidden(-override => 1,-name => 'dataD',-value => $g),
	        $cgi->hidden(-override => 1,-name => 'base',-value => $base),
	        $cgi->submit('show functions matching keywords'),$cgi->end_form());
    return \@html;
}

sub show_signatures {
    my($cgi,$parms,$html,$base) = @_;

    my $help_link = &help_signatures_link($cgi);
    my $txt = <<END;
 <pre><br><hr>
If you have not used this tool before, you really
do need to read our little help blurb $help_link
END
    
    push(@$html,$txt);
    my $dataDF = $parms->{dataDF};
    $dataDF =~ /([^\/]+)$/; 
    my $dataD = $1;
    my %types = map { ($_ =~ /^(\S+)\t(\S+)/) ? ($1 => $2) : () } `cat $dataDF/genome.types`;

    my @tree;
    my @tmp = `cat $dataDF/readable.tree`;
    foreach $_ (@tmp)
    {
	if ($_ =~ /^(.*\+ )(n\d+)$/)
	{
	    my $start = $1;
	    my $node  = $2;
	    my $link = $cgi->radio_group(-nolabels => 1,
					 -name => "radio_$node",
					 -override => 1,
					 -values => [1,0,2],
					 -default => 0);
	    push(@tree,"$start$node$link\n");
	}
	elsif ($_  =~ /^(.*\- )(\d+\.\d+)(:.*)$/)
	{
	    my $start = $1;
	    my $node  = $2;
	    my $end = $3;
	    my $link = $cgi->radio_group(-nolabels => 1,
					 -name => "radio_$node",
					 -override => 1,
					 -values => [1,0,2],
					 -default => 0);
	    my $type = ($types{$node} eq 'RAST') ? '*' : '';
	    push(@tree,"$start",$link,$node,$type,"$end\n");
	}
	else
	{
	    push(@tree,$_);
	}
    }
    my $tree = join("",@tree);
    push(@$html,"<br>",
                $cgi->start_form(-action => "./wc.cgi"),
	        $cgi->hidden(-override => 1,-name => 'request',-value => 'compute_sigs'),
	        $cgi->hidden(-override => 1,-name => 'dataD',-value => $dataD),
	        $cgi->hidden(-override => 1,-name => 'base',-value => $base),
	        "<pre>\n$tree\n</pre>\n",
	        $cgi->submit('Compute Gene Signatures'));
}

sub show_signatures_reactions {
    my($cgi,$parms,$html,$base) = @_;
    my $help_link = &help_signatures_reactions_link($cgi);
    my $txt = <<END;
 <pre><br><hr>
If you have not used this tool before, you really
do need to read our little help blurb $help_link
END
    
    push(@$html,$txt);
    my $dataDF = $parms->{dataDF};
    $dataDF =~ /([^\/]+)$/; 
    my $dataD = $1;
    my %types = map { ($_ =~ /^(\S+)\t(\S+)/) ? ($1 => $2) : () } `cat $dataDF/genome.types`;

    my @tree;
    my @tmp = `cat $dataDF/readable.tree`;
    foreach $_ (@tmp)
    {
	if ($_ =~ /^(.*\+ )(n\d+)$/)
	{
	    my $start = $1;
	    my $node  = $2;
	    my $link = $cgi->radio_group(-nolabels => 1,
					 -name => "radio_$node",
					 -override => 1,
					 -values => [1,0,2],
					 -default => 0);
	    push(@tree,"$start$node$link\n");
	}
	elsif ($_  =~ /^(.*\- )(\d+\.\d+)(:.*)$/)
	{
	    my $start = $1;
	    my $node  = $2;
	    my $end = $3;
	    my $link = $cgi->radio_group(-nolabels => 1,
					 -name => "radio_$node",
					 -override => 1,
					 -values => [1,0,2],
					 -default => 0);
	    my $type = ($types{$node} eq 'RAST') ? '*' : '';
	    push(@tree,"$start",$link,$node,$type,"$end\n");
	}
	else
	{
	    push(@tree,$_);
	}
    }
    my $tree = join("",@tree);
    push(@$html,"<br>",
	 $cgi->start_form(-action => "./wc.cgi"),
	 $cgi->hidden(-override => 1,-name => 'request',-value => 'compute_signatures_reactions'),
	 $cgi->hidden(-override => 1,-name => 'dataD',-value => $dataD),
	 $cgi->hidden(-override => 1,-name => 'base',-value => $base),
	 "<pre>\n$tree\n</pre>\n",
	 $cgi->submit('Compute Reaction Signatures'));
}

sub show_options_for_reactions {
    my($cgi,$html,$g,$dataDF,$base) = @_;

    my $txt = <<END;
<pre><br><hr>
You have a number of options relating to display of the reaction network:
The most commonly used option is to select two genomes and ask "Which
reactions are supported in one genome, but not the other.  We have generalized this
type of request to one in which a user specifies two sets of genomes: S1 and S2.
The request then becomes "Which reactions tend to occur in one set, but not 
the other?"

A second type of query is more related to the phylogentic tree.  Here we ask
"Which reactions were gained or lost on a specific arc of the phylogentic tree?"

END

    push(@$html,$txt);
    push(@$html,"<ol>\n",
                "<li><a target='_blank' href=wc.cgi?request=show_signatures_reactions&base=$base&dataD=$g>Reactions that act as Signatures)</a>\n",
	        "<li><a target='_blank' href=wc.cgi?request=show_otu_tree_reactions&base=$base&dataD=$g>Gains/losses of reactions on arcs of tree</a>\n",
	        "</ol>\n");
}

sub show_reactions {
    my($cgi,$parms,$html,$base) = @_;

    my $help_link = &help_reactions_link($cgi);
    my $txt = <<END;
<pre><br><hr>
If you have not used this tool before, you really
do need to read our little help blurb 

$help_link
END
	
	push(@$html,$txt);

}

sub show_reaction_genome_data {
    my($cgi,$reaction,$genome,$dataDF,$parms,$html,$base) = @_;
    my $reaction_to_complexes = &Biochemistry::reaction_to_complexes;
    my $complex_to_roles      = &Biochemistry::complex_to_roles;
    my $reaction_to_description = &Biochemistry::reactions_to_descriptions;
    my $complexes = $reaction_to_complexes->{$reaction};
    if (! $complexes)
    {
	push(@$html,$cgi->h2("No complexes implementing $reaction"));
    }
    else
    {
	my $hdrs1 = ['Reaction','Complex','Optional','Role'];
	my $rows1 = [];
	my %roles_to_seek;
	foreach my $complex (@$complexes)
	{
	    my $role_tuples = $complex_to_roles->{$complex};
	    foreach my $tuple (@$role_tuples)
	    {
		my($role,$optional) = @$tuple;
		$roles_to_seek{$role} = 1;
		push(@$rows1,[$reaction,$complex,($optional ? 'optional' : ''),$role]);
	    }
	}
	my $desc = $reaction_to_description->{$reaction};
	push(@$html,&HTML::make_table($hdrs1,$rows1,"Complexes and Roles for $reaction:<br><br> $desc"));
	push(@$html,"<hr><br><br>");

	my $hdrs2 = ['Role','PEG'];
	my $rows2 = [];
	my @relevant = map { (($_ =~ /^([^\t]+)\t(fig\|(\d+\.\d+)\.peg\.\d+)/) && 
                              ($3 eq $genome)
                             ) ? [$1,$2] : () 
                           } `cut -f2,4 $dataDF/families.all`;
        @relevant = grep { &matching_role($_->[0],\%roles_to_seek) } @relevant;
	foreach $_ (sort { ($a->[0] cmp $b->[0]) or (&SeedUtils::by_fig_id($a->[1],$b->[1])) } @relevant)
	{
            my($role,$peg) = @$_;
            my $peg_link = &peg_link($peg,$parms);
            push(@$rows2,[$role,$peg_link]);
#            push(@$rows2,[$role,$peg]);
        }
	push(@$html,&HTML::make_table($hdrs2,$rows2,"Relevant PEGs"));
    }
}

sub matching_role { 
    my($func,$roles_to_seek) = @_;

    my @roles_in_func = &SeedUtils::roles_of_function($func);
    my $i;
    for ($i=0; ($i < @roles_in_func) && (! $roles_to_seek->{$roles_in_func[$i]}); $i++) {}
    return ($i < @roles_in_func);
}
sub compute_signatures {
    my($cgi,$parms,$html,$base) = @_;

    push(@$html,"<br><br>",&help_compute_signatures_link($cgi));
    
    my $dataDF = $parms->{dataDF};
    $dataDF =~ /([^\/]+)$/; 
    my $dataD = $1;


    my @out;
    my @in;
    my @params = grep { $_ =~ /^radio/ } $cgi->param();
    foreach my $param (@params)
    {
	if ($param =~ /^radio_(\S+)/)
	{
	    my $node = $1;
	    if ($cgi->param($param) == 1)
	    {
		push(@out,$node);
	    }
	    elsif ($cgi->param($param) == 2)
	    {
		push(@in,$node);
	    }
	}
    }
    my $families = "$dataDF/families.all";
    my $tree = &tree_utilities::parse_newick_tree(join("",`cat $dataDF/labeled.tree`));
    my $indexP = &tree_utilities::tree_index_tables($tree);
    my $genomes = {};
    &in_set(\@out,$tree,$indexP,1,$genomes);
    &in_set(\@in,$tree,$indexP,2,$genomes);
    my $s1N = grep { $genomes->{$_} == 1 } keys(%$genomes);
    my $s2N = grep { $genomes->{$_} == 2 } keys(%$genomes);

    my %by_family;
    my %fam2func;
    foreach $_ (map { (($_ =~ /^(\S+)\t([^\t]*)\tfig\|(\d+\.\d+)/) && $genomes->{$3}) ? [$1,$2,$3] : () }
		`cut -f1,2,4 $families | sort -u`)
    {
	my($fam,$func,$g) = @$_;
	$by_family{$fam}->{$g} = 1;
	$fam2func{$fam} = $func;
    }

    my @scored_families;
    my %famH;
    foreach my $f (keys(%by_family))
    {
	my $fH = $by_family{$f};
	my @hits = keys(%$fH);
	my $s1Hits = grep { $genomes->{$_} == 1 } @hits;
	my $s2Hits = grep { $genomes->{$_} == 2 } @hits;
	my $counts1 = [$s1Hits,$s1N-$s1Hits];
	my $counts2 = [$s2Hits,$s2N-$s2Hits];
	my($din,$dout)  = &discriminates($counts2,$counts1);
	my $disc = $din+$dout;
	if ($disc > 1.5)
	{
	    $famH{$f} = 1;
	    push(@scored_families,[sprintf("%0.3f",$disc/2),$f]);
	}
    }
    my $coupledH = &coupling_data($dataDF,\%famH,$base);
    my $col_hdrs = ['Score','Tree','Family','Avg Length','Function','Clusters','Coupling'];
    my %mean_len = map { ($_ =~ /^(\S+)\t(\S+)/) ? ($1 => $2) : () } `cut -f1,6 $dataDF/families.all`;
    my $rows = [];
    my $fam_counts = &fam_counts($dataDF);
    foreach my $tuple (sort { $b->[0] <=> $a->[0] } @scored_families)
    {
	my($sc,$fam) = @$tuple;
	my $func = $fam2func{$fam};
	my $count = $fam_counts->{$func};
        my $nf    = ($count == 1) ? "1 family" : "$count families";
	my $func_link = &show_func_link($dataD,$func,$base) . "($nf)";
	my($cluster_link,$coupled_html) = &cluster_link_and_cluster_html($fam,$coupledH,\%fam2func,$dataD,$base);
	push(@$rows,[$sc,
	             &show_fam_links($dataDF,$fam,$base),
                     $mean_len{$fam},
                     $func_link,
	             $cluster_link,
	             $coupled_html
	            ]);
    }
    my $N = @$rows;
    push(@$html,&HTML::make_table($col_hdrs,$rows,"$N Families that Distinguish"));
}

sub compute_signatures_reactions {
    my($cgi,$parms,$html) = @_;

    my $base = $parms->{base};
    push(@$html,"<br><br>",&help_compute_signatures_reactions_link($cgi));
    
    my $dataDF = $parms->{dataDF};
    $dataDF =~ /([^\/]+)$/; 
    my $dataD = $1;
    my @out;
    my @in;
    my @params = grep { $_ =~ /^radio/ } $cgi->param();
    foreach my $param (@params)
    {
	if ($param =~ /^radio_(\S+)/)
	{
	    my $node = $1;
	    if ($cgi->param($param) == 1)
	    {
		push(@out,$node);
	    }
	    elsif ($cgi->param($param) == 2)
	    {
		push(@in,$node);
	    }
	}
    }
    my $reactionsF = "$dataDF/reactions.on.tree";
    my $tree = &tree_utilities::parse_newick_tree(join("",`cat $dataDF/labeled.tree`));
    my $indexP = &tree_utilities::tree_index_tables($tree);
    my $genomes = {};
    &in_set(\@out,$tree,$indexP,1,$genomes);
    &in_set(\@in,$tree,$indexP,2,$genomes);
    my $s1N = grep { $genomes->{$_} == 1 } keys(%$genomes);
    my $s2N = grep { $genomes->{$_} == 2 } keys(%$genomes);

    my %by_reaction;
    foreach $_ (`cat $reactionsF`)
    {
        if ($_ =~ /^(\S+)\t(\S+)\t([01])/)
	{
	    my($reaction,$node,$val) = ($1,$2,$3);
	    if (($val == 1) && ($node !~ /^n\d+/))
            {
                $by_reaction{$reaction}->{$node} = 1;
            }
        }
    }
    my @scored_reactions;
    my %reactionH;
    foreach my $r (keys(%by_reaction))
    {
	my $rH = $by_reaction{$r};
	my @hits = keys(%$rH);
	my $s1Hits = grep { $genomes->{$_} == 1 } @hits;
	my $s2Hits = grep { $genomes->{$_} == 2 } @hits;
	my $counts1 = [$s1Hits,$s1N-$s1Hits];
	my $counts2 = [$s2Hits,$s2N-$s2Hits];
	my($din,$dout)  = &discriminates($counts2,$counts1);
	my $disc = $din+$dout;
	if ($disc > 1.5)
	{
	    $reactionH{$r} = 1;
	    push(@scored_reactions,[sprintf("%0.3f",$disc/2),$r]);
	}
    }

    my $descH = &Biochemistry::reactions_to_descriptions;
    my $col_hdrs = ['Score','Reaction','Description'];
    my @rows = ();
    foreach my $tuple (@scored_reactions)
    {
	my($sc,$r) = @$tuple;
	my $desc   = $descH->{$r};
	push(@rows,[$sc,
                    &reaction_on_tree_link($r,$base,$dataD),
                    $desc]);
    }
    @rows = sort { ($b->[0] <=> $a->[0]) or ($a->[2] cmp $b->[2]) } @rows;
    push(@$html,&HTML::make_table($col_hdrs,\@rows,"Reactions that Distinguish"));
}

sub in_set {
    my($nodes,$tree,$indexP,$which,$genomes) = @_;

    foreach my $x (@$nodes)
    {
	if ($x =~ /^(\d+\.\d+)/)
	{
	    $genomes->{$1} = $which;
	}
	elsif (($x =~ /^(n\d+)/) && (my $node = &tree_utilities::label_to_node($indexP,$1)))
	{
	    my $tips = &tree_utilities::tips_of_tree($node);
	    foreach my $tip (@$tips)
	    {
		$genomes->{$tip} = $which;
	    }
	}
    }
}

sub discriminates {
    my($xin,$xout) = @_;

    my $sx    = &vector_sum($xin);
    my $sy    = &vector_sum($xout);
    my $xy    = &scalar_product($xin,$xout);
    my $xx    = &scalar_product($xin,$xin);
    my $yy    = &scalar_product($xout,$xout);

    my $din   = (($sx != 0) && ($yy != 0)) ? (1 - (($sy * $xy) / ($sx * $yy))) : 0;
    my $dout  = (($sy != 0) && ($xx != 0)) ? (1 - (($sx * $xy) / ($sy * $xx))) : 0;
    return ($din,$dout);
}

sub vector_sum {
    my($v) = @_;

    my $sum = 0;
    foreach $_ (@$v) 
    { 
	$sum += $_;
    }
    return $sum;
}

sub scalar_product {
    my($x,$y) = @_;
    
    if (@$x != @$y)
    {
	print STDERR &Dumper($x,$y);
	die "incompatable";
    }
    my $i;
    my $sum = 0;
    for ($i=0; ($i < @$x); $i++)
    {
	$sum += $x->[$i] * $y->[$i];
    }
    return $sum;
}

sub coupling_data {
    my($dataDF,$famsH,$base) = @_;

    my $coupled = {};
    foreach $_ (`cat $dataDF/coupled.families`)
    {
	if (($_ =~ /(\S+)\t(\S+)\t(\d+)/) && $famsH->{$1} && $famsH->{$2} && ($1 ne $2))
	{
	    push(@{$coupled->{$1}},$2);
	}
    }
    return $coupled;
}

sub show_family_pegs {
    my($cgi,$parms,$html,$families,$base) = @_;

    push(@$html,"<br><br>",&help_display_family_link($cgi));
    my $dataDF = $parms->{dataDF};
    $dataDF =~ /([^\/]+)$/; 
    my $dataD = $1;

    my $func;
    foreach $_ (`cut -f1,2 $dataDF/families.all`)
    {
#	if (($_ =~ /^(\d+)\t(\S[^\t]*\S)/) && ($1 == $families)) { $func = $2 }
	if (($_ =~ /^(\d+)\t(\S[^\t]*\S)/) && &fam_in_set($1,$families)) { $func = $2 }
    }
    my %genome_names = map { ($_ =~ /^(\S+)\t(\S.*\S)/) ? ($1 => $2) : () } `cat $dataDF/genome.names`;
    my $col_hdrs = ['','Genome','Genome Name','Peg'];
    my @tuples   = map { my $tuple = $_; $tuple->[3] = &peg_link($tuple->[3],$parms); $tuple } 
	           sort { $a->[1] cmp $b->[1] } 
	           map { (($_ =~ /^(\d+)\t([^\t]*)\t(fig\|(\d+\.\d+)\.peg\.\d+)/) && &fam_in_set($1,$families)) ? 
			     [$cgi->checkbox(-name => "check.$3",-checked => 1,-label => ''),
			      $4,
			      $genome_names{$4},
			      $3] : () }
	           `cut -f1,2,4 $dataDF/families.all`;
    push(@$html,$cgi->start_form(-action => "./wc.cgi"));
    push(@$html,"<br><br>\n",&HTML::make_table($col_hdrs,\@tuples,"Distribution of Family $families: $func"),$cgi->hr,"\n");
    push(@$html,"<input type=hidden name=dataD value=$dataD>\n");
    push(@$html,"<input type=hidden name=base value=$base>\n");
    push(@$html,"<input type=hidden name=request value=show_ali_or_occurs_tree>\n");
    push(@$html,$cgi->submit('alignment'),
#               $cgi->checkbox(-name => "dna",-checked => 0,-label => 'DNA'),
	        "<br><br>",
	        $cgi->submit('tree'),
                $cgi->end_form());
}

sub fam_in_set {
    my($fam,$set) = @_;

    my @fams = split(/,/,$set);
    my $i;
    for ($i=0; ($i < @fams) && ($fam ne $fams[$i]); $i++) {}
    return ($i < @fams);
}

sub show_func {
    my($cgi,$parms,$html,$function,$base) = @_;

    push(@$html,"<br><br>",&help_display_function_link($cgi));
    my $dataDF = $parms->{dataDF};
    $dataDF =~ /([^\/]+)$/; 
    my $dataD = $1;

    my %counts;
    my %fams = map { my $x; 
		     if (($_ =~ /^(\d+)\t(\S[^\t]*\S)/) && ($2 eq $function)) 
                     {
			 $counts{$1}++;
                         ($1 => 1);
		     }
		     else
		     {
			 () 
		     }
                   } `cat $dataDF/families.all`;
    my $col_hdrs = ['Family','PEGs in Family','Distribution on Tree','Size'];
    my @tab      = map { [$_,
			  &CloseStrains::show_fam_table_link($dataDF,$_,$base),
			  &show_fam_on_tree_link($dataDF,$_,$base),
			  $counts{$_}
                         ] } sort { $a <=> $b } keys(%fams);
    push(@$html,"<h1>$function</h1>", &HTML::make_table($col_hdrs,\@tab,"Families with Function"),"<hr>");

    my @fams = keys(%fams);
    if (@fams > 1)
    {
	push(@$html,"<br>",&show_fam_on_tree_link($dataDF,$fams[0],"union",$base)," with union of families<br><br>");
    }
    push(@$html,"<hr>");
    my @gained = map { (($_ =~ /^(\S+)\t(\S+)\t(\d+)\t0\t1/) && $fams{$3}) ? 
			 [$1,&show_node_link($dataD,$2,'families',$base),&CloseStrains::show_fam_table_link($dataDF,$3,$base)] : () }
               `cat $dataDF/where.shifts.occurred`;
    push(@$html,&HTML::make_table(['Ancestor','Descendant','Family'],\@gained,"Where $function was GAINED"));
    push(@$html,"<hr><br>");
    my @lost = map { (($_ =~ /^(\S+)\t(\S+)\t(\d+)\t1\t0/) && $fams{$3}) ? 
			 [$1,&show_node_link($dataD,$2,'families',$base),&CloseStrains::show_fam_table_link($dataDF,$3,$base)] : () }
               `cat $dataDF/where.shifts.occurred`;
    push(@$html,&HTML::make_table(['Ancestor','Descendant','Family'],\@lost,"Where $function was LOST"));
}

sub show_family_tree {
    my($cgi,$parms,$html,$family,$base) = @_;

    my $dataDF = $parms->{dataDF};
#   if union is specified, you want to treat all families with the same function
#   as "present"
    my $union = $cgi->param('union');
    my $func;   # used only if union is requested
    my @fam_func_peg_tuples = map { chomp; [split(/\t/,$_)] } `cut -f1,2,4 $dataDF/families.all`;
    if ($union) { 
	my @tmp = grep { $_->[0] == $family } @fam_func_peg_tuples; 
	$func = $tmp[0]->[1];
    }
    
    $dataDF =~ /([^\/]+)$/; 
    my $dataD = $1;

    push(@$html,"<br><hr>",&show_fam_table_link($dataDF,$family,$base),"<br><br>");
    my @tuples = grep { $union ? ($_->[1] eq $func) : ($_->[0] == $family) } 
                 @fam_func_peg_tuples;
    my $func   = (@tuples > 0) ? $tuples[0]->[1] : 'hypothetical protein';
    my %has    = map { ($_->[2] =~ /fig\|(\d+\.\d+)/) ? ($1 => 1) : () } @tuples;
    my @tree;
    my %node_vals = map { (($_ =~ /^(\S+)\t(n\d+)\t(\S+)/) && ($family eq $1)) ? ($2 => $3) : () } `cat $dataDF/families.on.tree`;

    my @tmp = `cat $dataDF/readable.tree`;
    foreach $_ (@tmp)
    {
	if ($_  =~ /^(.*\- )(\d+\.\d+)(:.*)$/)
	{
	    my $start   = $1;
	    my $genome  = $2;
	    my $end     = $3;
	    if ($has{$genome})
	    {
		push(@tree,"$start<b>$genome$end</b>\n");
	    }
	    else
	    {
		push(@tree,"$start$genome$end\n");
	    }
	}
	elsif (($_ =~ /^(.*\+ )(n\d+)$/) && (! $union))
	{
	    my $start = $1;
	    my $node  = $2;
	    my $status = $node_vals{$node};
	    my $to_show = $node . ":$status";
	    push(@tree,"$start$to_show\n");
	}
	else
	{
	    push(@tree,$_);
	}
    }
    my $tree = join("",@tree);
    my $func_link = &show_func_link($dataD,$func,$base);
    push(@$html,"<br><h2>$func_link</h2><br><pre>\n$tree\n</pre>\n");
}

sub show_ali {
    my($cgi,$parms,$base) = @_;

    my $dataDF = $parms->{dataDF};
    my @checked = map { ($_ =~ s/^check.//) ? $_ : () } $cgi->param();
    if (@checked > 1) 
    {
	my %checked = map { $_ => 1 } @checked;
	my $dataD    = $cgi->param('dataD');

	my $tmp_seqs_in = "$FIG_Config::temp/tmp$$.seqs.in";
	my $tmp_seqs_ali = "$FIG_Config::temp/tmp$$.ali";
	open(SEQS,">$tmp_seqs_in") || die "could not open $tmp_seqs_in";
	my $dna = $cgi->param('dna');
	opendir(GENOMES,"$dataDF/Seqs") || die "could not open $dataDF/Seqs";
	my @genomes = grep { $_ !~ /^\./ } readdir(GENOMES);
	closedir(GENOMES);
	foreach my $g (@genomes)
	{
	    my @seqs;
	    if($dna)
	    {
		@seqs = grep { $checked{$_->[0]} } &gjoseqlib::read_fasta("$dataDF/PegDNA/$g");
	    }
	    else
	    {
		@seqs = grep { $checked{$_->[0]} } &gjoseqlib::read_fasta("$dataDF/Seqs/$g");
	    }
	    foreach my $tuple(@seqs)
	    {
		my($peg,undef,$seq) = @$tuple;
		print SEQS ">$peg\n$seq\n";
	    }
	}
	close(SEQS);
	&SeedUtils::run("svr_align_seqs < $tmp_seqs_in | svr_ali_to_html > $tmp_seqs_ali");
	open(SEQS,"<$tmp_seqs_ali") || die "could not open $tmp_seqs_ali";
	print $cgi->header;
	while (defined($_ = <SEQS>))
	{
	    $_ =~ s/\b(fig\|\d+\.\d+\.peg\.\d+)/<a target='_blank' href=http:\/\/pubseed.theseed.org\/seedviewer.cgi?page=Annotation&feature=$1>$1<\/a>/g;
	    print $_;
	}
	close(SEQS);
	unlink($tmp_seqs_in,$tmp_seqs_ali);
    }
}

sub show_otu_tree {
    my($cgi,$parms,$html,$type,$base) = @_;

    if ($type eq "adjacency") {     push(@$html,"<br><br>",&help_display_adjacency_link($cgi)) }

    my $dataDF = $parms->{dataDF};
    $dataDF =~ /([^\/]+)$/; 
    my $dataD = $1;
    my @tree;
    my @tmp = `cat $dataDF/readable.tree`;
    foreach $_ (@tmp)
    {
	if ($_ =~ /^(.*\+ )(n\d+)$/)
	{
	    my $start = $1;
	    my $node  = $2;
	    my $link  = &show_node_link($dataD,$node,$type,$base);
	    push(@tree,"$start$link\n");
	}
	elsif ($_  =~ /^(.*\- )(\S+)(:.*)$/)
	{
	    my $start = $1;
	    my $node  = $2;
	    my $end = $3;
	    push(@tree,"$start",&show_node_link($dataD,$node,$type,$base),"$end\n");
	}
	else
	{
	    push(@tree,$_);
	}
    }

    my $tree = join("",@tree);
    push(@$html,"<pre>\n$tree\n</pre>\n");
}

sub show_occurs_tree {
    my($cgi,$parms,$html,$base) = @_;

    my $dataDF = $parms->{dataDF};
    my @checked = map { ($_ =~ s/^check.//) ? $_ : () } $cgi->param();
    if (@checked > 3) 
    {
	my %genome_name = 
	    map { ($_ =~ /^(\d+\.\d+)\t(\S.*\S)/) ? ($1 => $2) : () }
	    `cat $dataDF/genome.names`;
	my $tmp_labels = "$FIG_Config::temp/tmp$$.labels";
	open(LABELS,">$tmp_labels") || die "could not open $tmp_labels";
	my %need_g;
	my %need_peg;
	foreach my $peg (@checked) 
	{
	    if ($peg =~ /^fig\|(\d+\.\d+)/)
	    {
		my $g = $genome_name{$1};
		$need_g{$1} = 1;
		$need_peg{$peg} = 1;
		my $link = &CloseStrains::peg_link($peg,$parms);
		print LABELS "$peg\t$link: $g\n";
	    }
	}
	close(LABELS);

	my $tmp_seqs = "$FIG_Config::temp/tmp$$.seqs";
	open(SEQS,"| svr_align_seqs | svr_tree | sketch_tree -m -l $tmp_labels > $tmp_seqs")
	    || die "could not open $tmp_seqs";

	foreach my $gid (keys(%need_g))
	{
	    my @fasta = &gjoseqlib::read_fasta("$dataDF/Seqs/$gid");
	    foreach my $tuple (@fasta)
	    {
		my($id,undef,$seq) = @$tuple;
		if ($need_peg{$id})
		{
		    print SEQS ">$id\n$seq\n";
		}
	    }
	}
	close(SEQS);
	open(SEQS,"<$tmp_seqs") || die "could not open $tmp_seqs";
	push(@$html,"<pre>\n");
	while (defined($_ = <SEQS>))
	{
	    push(@$html,$_);
	}
	push(@$html,"</pre>\n");
	close(SEQS);
	unlink($tmp_seqs,$tmp_labels);
    }
}


sub show_reaction_on_tree {
    my($cgi,$reaction,$parms,$html,$base) = @_;

    my $dataDF = $parms->{dataDF};
    $dataDF =~ /([^\/]+)$/; 
    my $dataD = $1;
    my @tree;
    my @tmp = `cat $dataDF/readable.tree`;
    my %has = map { (($_ =~ /^(\S+)\t(\d+\.\d+)\t1$/) && ($1 eq $reaction)) ? ($2 => 1) : () } `cat $dataDF/reactions.on.tree`;
    foreach $_ (@tmp)
    {
	if ($_  =~ /^(.*\- )(\d+\.\d+)(:.*)$/)
	{
	    my $start   = $1;
	    my $genome  = $2;
	    my $link    = &show_reaction_genome_data_link($reaction,$genome,$dataD,$base);
	    my $end     = $3;
	    if ($has{$genome})
	    {
		push(@tree,"$start<b>$link$end</b>\n");
	    }
	    else
	    {
		push(@tree,"$start$link$end\n");
	    }
	}
	else
	{
	    push(@tree,$_);
	}
    }

    my $tree = join("",@tree);
    my $descH = &Biochemistry::reactions_to_descriptions;
    my $desc = $descH->{$reaction};
    push(@$html,"<h2>Occurrences of reaction $reaction on tree<br><br>$desc</h2>");
    push(@$html,"<br><br>",&help_display_reaction_on_tree_link($cgi));
    push(@$html,"<pre>\n$tree\n</pre>\n");
}

sub show_node {
    my($cgi,$parms,$html,$node,$base) = @_;
    my $dataDF = $parms->{dataDF};
    my $type = $cgi->param('type');
    if ($type eq 'families')
    {
	&show_changes_families($cgi,$parms,$html,$node,$base);
    }
    elsif ($type eq "reaction")
    {
	&show_changes_reactions($cgi,$parms,$html,$node,$base);
    }
    else
    {
	&show_changes_adjacency($cgi,$parms,$html,$node,$base);
    }
}

sub show_changes_reactions {
    my($cgi,$parms,$html,$node,$base) = @_;
    my $dataDF = $parms->{dataDF};
    $dataDF =~ /([^\/]+)$/; 
    my $dataD = $1;
    my $reaction_to_description = &Biochemistry::reactions_to_descriptions;

    my $col_hdrs = ['reaction','description'];
    my @relevant_shifts = map { (($_ =~ /^(n\d+)\t(\S+)\t(\S+)\t(\S+)\t(\S+)/) && 
				 ($2 eq $node) && 
				 (($4 eq '0') || ($4 eq '1')) && 
				 ($4 ne $5)) ? [$3,$4,$5] : () } `cat $dataDF/where.reaction.shifts.occurred`;
#   @relevant_shifts contains [reaction,anc-val,node-val]

    my @tabG = sort { ($a->[1] cmp $b->[1]) }
               map { $_->[2] ? [&reaction_on_tree_link($_->[0],$base,$dataD),$reaction_to_description->{$_->[0]}]
			     : () } @relevant_shifts;
    my @tabL = sort { ($a->[1] cmp $b->[1]) }
               map { $_->[1] ? [&reaction_on_tree_link($_->[0],$base,$dataD),$reaction_to_description->{$_->[0]}]
			     : () } @relevant_shifts;

    push(@$html,"<br><br><a href=#lost>Skip to reactions lost</a>");
    push(@$html,&HTML::make_table($col_hdrs,\@tabG,"Reactions Gained"),$cgi->hr,"\n");
    push(@$html,"<br><br>",$cgi->hr,"<br><a name=lost>Reactions Lost</a>");
    push(@$html,&HTML::make_table($col_hdrs,\@tabL,"Reactions Lost"));
}

sub show_changes_adjacency {
    my($cgi,$parms,$html,$node,$base) = @_;

    my $dataDF = $parms->{dataDF};
    $dataDF =~ /([^\/]+)$/; 
    my $dataD = $1;

    push(@$html,"<br><br>",&help_display_adjacency_link($cgi));


    my $col_hdrs = ['Family','Function','Ancestral','New','Compare'];

    # an event is [anc,current-node,Fam,AdjAnc,AdjCurr]
    my @events = grep { $node eq $_->[1] } 
                 map { ($_ =~ /(\S+)\t(\S+)\t(\d+):\S+\t(\d+):\S+\t(\d+)/) ? [$1,$2,$3,$4,$5] : () }
                 `cat $dataDF/placed.events`;

    # The following hash is Family -> [adj-fam-ancestor,adj-fam-in-current-node]
    my %families = map { ($_->[2] => [$_->[3],$_->[4]])} @events;
    
    # The following generates a hash with keys of families for which pegs are needed
    my %pegs_needed  = map { (($_->[2] => 1), ($_->[3] => 1),($_->[4] => 1)) } @events;

    # This builds a hash: "Fam,AdjFam" => Peg  [for fams in shift]
    my %fam_peg  = map { my $x; 
			 (($_ =~ /^(\d+)\t\S+\t(\d+)\t\S+\t\S+\t(\S+)\t(\S+)/) && 
		          ($x = $families{$1}) && (($x->[0] eq $2) || ($x->[1] eq $2))) ? ("$1,$2" => "$3,$4") : () }
                   `cat $dataDF/adjacency.of.unique`;
    my %peg_to_func = map { (($_ =~ /^([^t]+)\t([^\t]*)\t(\S+)/) && $pegs_needed{$1}) ? ($3 => $2) : () } `cut -f1,2,4 $dataDF/families.all`;
    my @rows;
    my $ancestor;
    foreach my $event (@events)
    {
	my($anc,$node,$fam,$fam1,$fam2) = @$event;
	$ancestor = $anc;
	my $pegs1 = $fam_peg{"$fam,$fam1"};
	my $peg1  = $pegs1; $peg1 =~ s/,.*$//;
        my $peg1b = $pegs1; $peg1b =~ s/^.*,//;
	my $pegs2 = $fam_peg{"$fam,$fam2"};
	my $peg2  = $pegs2; $peg2 =~ s/,.*$//;
	my $peg2b = $pegs2; $peg2b =~ s/^.*,//;

	my $func = $peg_to_func{$peg1};
	if ($peg1 && $peg2 && $func)
	{
	    my $peg_links1 = &CloseStrains::peg_link($peg1,$parms) . "," .
		             &CloseStrains::peg_link($peg1b,$parms);
	    my $peg_links2 = &CloseStrains::peg_link($peg2,$parms) . "," .
		             &CloseStrains::peg_link($peg2b,$parms);
	    push(@rows,[&CloseStrains::show_fam_table_link($dataDF,$fam,$base),
			$func,
			$peg_links1,
			$peg_links2,
	                &compare_link([$peg1,$peg2],$parms)]);
	}
    }
    push(@$html,&HTML::make_table($col_hdrs,\@rows,"Changes in Adjacency from $ancestor"));
}


sub show_changes_families {
    my($cgi,$parms,$html,$node,$base) = @_;
   
    my $dataDF = $parms->{dataDF};
    $dataDF =~ /([^\/]+)$/; 
    my $dataD = $1;

    my %func = map { ($_ =~ /^(\d+)\t(\S[^\t]*\S)/) ? ($1 => $2) : () } `cut -f1,2 $dataDF/families.all`;
    my $col_hdrs = ['Show Where','Show PEGs','Family','Function (# Families)','Clusters','Coupling'];
    my @tmp = grep { (($_ =~ /^\S+\t(\S+)/) && ($1 eq $node)) } 
    `cat /$dataDF/where.shifts.occurred`;
    my @tabG  = sort { ($a->[4] cmp $b->[4]) or ($a->[3] <=> $b->[3]) }
    map { ($_ =~ /^(\S+)\t\S+\t(\S+)\t0\t1/) ? [&CloseStrains::show_fam_links($dataDF,$2,$base),$1,$2,$func{$2}] : () } 
    @tmp;
    # tabG entries are [linkT,linkP,ancestor,fam,func]

    # try to pick up the ancestor node from the first entry in @tabG
    # If you cannot get it, try to take it from @tabL
    my $anc = (@tabG > 0) ? $tabG[0]->[-3] : undef;
    foreach $_ (@tabG) { splice(@$_,2,1) }   ### get rid of ancestor
    ## tabG entries are [linkT,linkP,fam,func]

    my @tabL  = sort { ($a->[4] cmp $b->[4]) or ($a->[3] <=> $b->[3]) }
    map { ($_ =~ /^(\S+)\t\S+\t(\S+)\t1\t0/) ? [&CloseStrains::show_fam_links($dataDF,$2,$base),$1,$2,$func{$2}] : () } 
    @tmp;
    if (! $anc)
    {
	$anc = (@tabL > 0) ? $tabL[0]->[-3] : '';
    }
    foreach $_ (@tabL) { splice(@$_,2,1) }   ### get rid of ancestor

## @tabG and @tabL are of the form [link-to-tree,link-to-peg-display,family,function]]
## we now add coupling data.

    my $with_couplingL = &build_table(\@tabL,$dataDF,$base);
    my $with_couplingG = &build_table(\@tabG,$dataDF,$base);
    
    push(@$html,"<br><br><a href=#lost>Skip to families lost</a>");
    my $nG = @$with_couplingG;
    my $nL = @$with_couplingL;
    push(@$html,&HTML::make_table($col_hdrs,$with_couplingG,"$nG Families Gained from Ancestor $anc"),$cgi->hr,"\n");
#   push(@$html,"<a name=lost>Lost Families</a>");
    push(@$html,&HTML::make_table($col_hdrs,$with_couplingL,"<a name=lost>$nL Families Lost from Ancestor $anc</a>"),$cgi->hr,"\n");
}

sub fam_counts {
    my($dataDF) = @_;

    my %fam2func;
    my %fam_counts;
    
    foreach $_ (map { ($_ =~ /^\S+\t(\S.*\S)/) ? $1 : () }
		`cut -f1,2 $dataDF/families.all | sort -u`)
    {
        $fam_counts{$_}++;
    }
    return \%fam_counts;
}

sub build_table {
    my($tab,$dataDF,$base) = @_;
    $dataDF =~ /([^\/]+)$/; 
    my $dataD = $1;

    my $fam_counts = &fam_counts($dataDF);
    my %famH = map { ($_->[-2] => 1) } @$tab;
    my %fam_to_func = map { ($_->[2] => $_->[3]) } @$tab;
    my $coupledH = &CloseStrains::coupling_data($dataDF,\%famH,$base);
    my @with_coupling;
    foreach my $tuple (@$tab)
    {
	my($link1,$link2,$family,$function) = @$tuple;
	my $count = $fam_counts->{$function};
        my $nf    = ($count == 1) ? "1 family" : "$count families";
	$tuple->[3] = &CloseStrains::show_func_link($dataD,$function,$base) . " ($nf)";

	my($cluster_link,$coupled_html) = &CloseStrains::cluster_link_and_cluster_html($family,$coupledH,\%fam_to_func,$dataD,$base);
	$tuple->[4] = $cluster_link;
	$tuple->[5] = $coupled_html; 
	push(@with_coupling,$tuple);
    }
    return \@with_coupling;
}

sub show_clusters {
    my($cgi,$parms,$html,$base) = @_;

    my $dataDF = $parms->{dataDF};
    my $families = $cgi->param('families');
    my @families = split(/,/,$families);
    my %families = map { $_ => 1 } @families;
    my %genome_names = map { ($_ =~ /^(\S+)\t(\S.*\S)/) ? ($1 => $2) : () } `cat $dataDF/genome.names`;
    my @genome_pegN_fam_func = sort { ($a->[0] <=> $b->[0]) or ($a->[1] <=> $b->[1]) }
    map { (($_ =~ /^(\S+)\t([^\t]*)\t[^\t]*\tfig\|(\d+\.\d+)\.peg\.(\d+)/) && $families{$1}) ?
	      [$3,$4,$1,$2] : () 
    } `cat $dataDF/families.all`;
    push(@$html,$cgi->h1('Relevant Clusters'));
    my $col_hdrs = ['Family','Function','PEG'];
    my $last = shift @genome_pegN_fam_func;
    while ($last)
    {
	my $last_g    = $last->[0];
	my $last_pegN = $last->[1];
	my @set;
	while ($last && ($last_g == $last->[0]) && &close($last_pegN,$last->[1]))
	{
	    $last_pegN = $last->[1];
	    push(@set,[$last->[2],$last->[3],&CloseStrains::peg_link("fig|" . $last_g . ".peg." . $last_pegN,$parms)]);
	    $last = shift @genome_pegN_fam_func;
	}
	if (@set > 1)
	{
	    push(@$html,&HTML::make_table($col_hdrs,\@set,"Cluster for $last_g: $genome_names{$last_g}"));
	    push(@$html,"<hr><br><br>\n");
	}
    }
}

sub close {
    my($pegN1,$pegN2) = @_;

    return abs($pegN2 - $pegN1) <= 7;
}

sub show_virulence_functions {
    my($cgi,$parms,$html,$base) = @_;

    my $dataDF = $parms->{dataDF};
    $dataDF =~ /([^\/]+)$/; 
    my $dataD = $1;

    my $functions_in_fams = &functions_in_at_least_one_family($dataDF);
    my @virulence_functions = map { chomp; $functions_in_fams->{$_} ? $_ : () } `cat $dataDF/virulence.functions`;
    my @links = map { [&CloseStrains::show_func_link($dataD,$_,$base)] } sort @virulence_functions;
    push(@$html,&HTML::make_table(['Function Sometimes Associated with Virulence'],
				  \@links,
				  'Functions Known to Be Associated with Virulence in Some Organisms'));
}

sub show_indexed_funcs {
    my($cgi,$parms,$html,$keywords,$base) = @_;

    my $dataDF = $parms->{dataDF};
    $dataDF =~ /([^\/]+)$/; 
    my $dataD = $1;

    my $functions_in_fams = &functions_in_at_least_one_family($dataDF);
#    $keywords = "$dataD " . $keywords; ### tell the user to add it,if necessary

    my %funcs_to_show;

    #
    # If we have a search index built here, use that.
    #

    my $idx_dir = "$dataDF/Index";
    if (-s "$idx_dir/search_index_key_to_id.cdb")
    {
	print STDERR "Using search index\n";
	my @res = search_index($dataDF, $keywords);
	for my $feat (@res)
	{
	    my $func = $feat->{function};
	    $func =~ s/\s*\#.*$//;
	    if ($functions_in_fams->{$func})
	    {
		$funcs_to_show{$func}++;
	    }
	}
    }
    else
    {
	print STDERR "using svr_sphinx $idx_dir\n";
	foreach my $func (`svr_sphinx_indexing -k \'$keywords\' | cut -f1 | svr_function_of | cut -f2`)
	{
	    chomp $func;
	    $func =~ s/\s*\#.*$//;
	    if ($functions_in_fams->{$func})
	    {
		$funcs_to_show{$func}++;
	    }
	}
    }
    my @funcs = sort { $funcs_to_show{$b} <=> $funcs_to_show{$a} } keys(%funcs_to_show);
    if (@funcs == 0)
    {
	push(@$html,"<h1>Sorry, no functions matched</h1>\n");
    }
    else
    {
	my @links = map { [&CloseStrains::show_func_link($dataD,$_,$base)] } @funcs;
	push(@$html,&HTML::make_table(['Possible Functions'],\@links,"Possible functions - Select to find nodes where shifts occurred"));
    }
}

sub functions_in_at_least_one_family {
    my($dataDF) = @_;

    my %functions_in_fams = map { chomp; ($_ => 1) }  `cut -f2 $dataDF/families.all`;
    return \%functions_in_fams;
}
############################### HELP ##########################
sub help_sig_reactions { 

    my $txt = <<END;
    <h2> Getting Started Finding Reactions that Act as "Signatures"</h2>
	<pre>
        When we speak of a "reaction" as a "signature",
	what we are saying is that the reaction occurs in one set of genomes,
        but not in a second specified set.  Thus, we might discuss
        the reactions that act as "signatures" for Strep pneumonia versus Strep pyogenes.

	The basic idea behind the use of signatures is as follows:

	1.  You select two sets of genomes -- call them S1 and S2.

	2.  Then you request the program to find reactions that
	    distinguish S1 and S2 (by clicking on the button at the end of the page).

Let us work up to the full power in 4 simple steps.  First, let's pick two
genomes and ask <i>What reactions occur in one genome, but not the other.</i>
To do this you need to

     a.  Go to the radio button for the node representing the first genome and click on
         the left option.  This sets S1 to be the selected genome.

     b.  Now go to a second genome and click on the right option.
         This makes S2 contain just the selected genome.

     c.  Finally, go to the bottom of the page and ask to compute the reactions
         that distinguish S2 from S1.

--------

Now let's pick one set to include a subtree of genomes, and the second
set to be a single genome.  

     a.  Go to the radio button for the node representing the subtree
         of genomes and click on the left option.  This sets S1 to be
         the selected subtree.

     b.  Now go to a second genome and click on the right option.
         This makes S2 contain just the selected genome.  If S2 is
         embedded in S1, the program will interpret your request as
         looking for signatures that distinguish S2 from the other
         members of S1.

     c.  Finally, go to the bottom of the page and ask to compute the signatures
         that distinguish S2 from the genomes in S1.  You should do this just to
         see what is produced as reactions that tend to distinguish genomes in S1
         from the single genome in S2.
----------------

The next step up in complexity corresponds to choosing S1 as a set (just as you did
before) and choosing S2 to be a disjoint subset of genomes.  This allows you to
compute signatures that separate the genomes in the two disjoint sets.

--------
The third option is one in which you choose S1 as a subtree, and then pick S2 as
a subtree embedded in S1.  In this case S1 would become all genomes in the selected
subtree other than those chosen to be in S2.
--------

Finally, it should be noted that you can build up subsets as unions by hitting the
first or third options for more than single nodes (but, perhaps, it is best to try
that only after experimenting a bit).
</pre>
END
    return $txt;
}

sub help_sig { 

    my $txt = <<END;
    <h2> Getting Started Finding Families that Act as "Signatures"</h2>
	<pre>
	When we speak of a "family" we mean a set of genes.  The genes are believed
	to all implement the same function.  So when we speak of a "family" as a "signature",
	what we are saying is that the genes occuring in the family represent a function
	that occurs in one set of genomes, but not in some other specified set.

	The basic idea behind the use of signatures is as follows:

	1.  You select two sets of genomes -- call them S1 and S2.

	2.  Then you request the program to find families that
	    distinguish S1 and S2 (by clicking on the button at the end of the page).

Let us work up to the full power in 4 simple steps.  First, let's pick two
genomes and ask <i>What families occur in one genome, but not the other.</i>
To do this you need to

     a.  Go to the radio button for the node representing the first genome and click on
         the left option.  This sets S1 to be the selected genome.

     b.  Now go to a second genome and click on the right option.
         This makes S2 contain just the selected genome.

     c.  Finally, go to the bottom of the page and ask to compute the signatures
         that distinguish S2 from S1.

--------

Now let's pick one set to include a subtree of genomes, and the second
set to be a single genome.  

     a.  Go to the radio button for the node representing the subtree
         of genomes and click on the left option.  This sets S1 to be
         the selected subtree.

     b.  Now go to a second genome and click on the right option.
         This makes S2 contain just the selected genome.  If S2 is
         embedded in S1, the program will interpret your request as
         looking for signatures that distinguish S2 from the other
         members of S1.

     c.  Finally, go to the bottom of the page and ask to compute the signatures
         that distinguish S2 from the genomes in S1.  You should do this just to
         see what is produced as families that tend to distinguish genomes in S1
         from the single genome in S2.
----------------

The next step up in complexity corresponds to choosing S1 as a set (just as you did
before) and choosing S2 to be a disjoint subset of genomes.  This allows you to
compute signatures that separate the genomes in the two disjoint sets.

--------
The third option is one in which you choose S1 as a subtree, and then pick S2 as
a subtree embedded in S1.  In this case S1 would become all genomes in the selected
subtree other than those chosen to be in S2.
--------

Finally, it should be noted that you can build up subsets as unions by hitting the
first or third options for more than single nodes (but, perhaps, it is best to try
that only after experimenting a bit).
</pre>
END
    return $txt;
}

sub help_sig_output { 

    my $txt = <<END;
<h2> Interpreting the Signature Output</h2>
 <pre>
Each row in the output relates to a single family that tends to discriminate between
the sets S1 and S2 that you selected.  That is, the family tends to occur in S1, but 
not S2, or vice versa.  To see which, you can click on the link in the second column,
which will produce a tree in which the genomes containing the family are displayed in
bold. 

The first column gives a score which is usually in the range 0.75 to 1.0.  A score
of 1.0 indicates perfect discrimination, and lower values indicate some anomalies.

The third column gives the family ID (a numeric value) and a link that allows you
to see what protein-encoding genes (PEGs) are in the family, to construct an 
alignment of the protein sequences in the family, and to construct a tree from
those protein sequences (when this disagrees with the main tree, it suggests
horizontal transfer).  You can go from the PEGs to the standard SEED displays
for PEGs in genomes from PubSEED or RAST.

The fourth column just gives the average length of protein sequences in the family.

The fifth column contains our best estimate of the function implemented by members of
the family.  If you take the link, you can see all families that have been 
assigned the same function.

The sixth and seventh columns relate to conserved contiguity on the chromosome.
The seventh column contains functions of families that tend to occur close
to the family described by the row.  The fifth column contains just the row
family id linked to a display of chromosomal clusters reflecting the functions
described in the seventh column.

</pre>
END
    return $txt;
}

sub help_adjacency_output { 

    my $txt = <<END;
<h2> Locating Shifts in Adjacency</h2>
 <pre>
We try to suggest points where chromosomal rearrangements have occurred.
The key to this effort is a set of comprehensive protein families that we 
compute for the proteins encoded by genes in the genomes.

For each genome, we think of the genome as a sequence of protein families.
For our purposes relating to adjacency, we remove from each list families
that include more than one protein from a single genome.
Then, for each genome we generate asserions of the form

        "family X occurs adjacent to family Y in genome Z, and
         the occurrances of the pair of families is less than
         5000 bp apart"

Once we have generated these assertions, we have assertions of adjacency
for all genomes in the set we have included in building the underlying
phylogenetic tree.  We estimate with of these pairs of families are believed
to occur close to one another in the ancestral nodes based on a parsimony 
estimate (we attempt to minimize the number of shifts that must have occurred).

Once we have estimates of which genes were adjacent in all of the nodes
in the tree, we can estimate where shifts occurred and use these to locate
potential rearrangements.
</pre>
END
    return $txt;
}

sub help_sig_output_reactions {

    my $txt = <<END;
<h2> Help interpreting a the Table of Reactions that Distinguish Sets of Genomes</h2>

This table is computed by looking for reactions that distinguish genomes from two sets.
That is, the reactions will tend to occur in one of the sets, but not the other.
The <b>score</b>, which is the first column of the table, indicates how well the reaction
distinguishes the sets of genomes.  A score of 1.0 is perfect.  Lower scores indicate that
some exeptions seem to exist (remember, these often reflect nothing more than sequencing or
annotation errors).  The second column contains reaction IDs.  If you click on one, you
should see a tree that shows which genomes contain the genes needed to support the reaction.

The third column is a summary of the reaction.


</pre>
END
    return $txt;
}

sub help_reaction_on_tree {

    my $txt = <<END;
<h2> Help interpreting a reaction mapped onto the phylogentic tree</h2>
 <pre>
The page will show the phylogentic tree with some genomes shown in bold font.  Those
are the genomes believed to contain genes capable of supporting the designated
reaction. 

If you click on a genome, you should get back two tables: the first shows 
which <i>complexes</i> can support the reaction, as well as the roles that
make up each complex.  The second table will show the protein-encoding genes (PEGs)
that implement the relevant roles in the genome


</pre>
END
    return $txt;
}
    
sub help_family_output { 

    my $txt = <<END;
<h2> Interpreting the Family Output</h2>
 <pre>
The page displaying a family includes a table of the protein-encoding
genes (PEGs) that makeup the family.  You can ask for an alignment or
tree to be built from the sequences.  If you wish only a subset of the
sequences for an alignment of tree, use the checkboxes to ignore those you
want left out.

Note that the tree is built from the checked sequences and may differ from
the overall tree we display elsewhere.


</pre>
END
    return $txt;
}

sub help_function_output { 

    my $txt = <<END;
<h2> Interpreting the Output for a Function</h2>
 <pre>
The output we display for a function is more complex than you
might imagine.  First, note that there can be numerous families
that have the same function (e.g., <i>hypothetical protein</i> may well
have a considerable number).  It is important to understand that there
are a number of reasons why there might be multiple families:

    1.  It is often the case that the selected outgroup organisms 
        are quite distant from the cluster focused on your organisms
        of interest.  The families are produced using an algorithm
        that expects the genomes to be very closely related, so distant
        genomes frequently have genes in extremely small families, but
        the correct function.

    2.  Apparent frameshifts often exist, leading to versions of 
        the same protein that differ substantially in length.  These 
	often produce distinct families.

    3.  There are often paralagous genes that encode very similar
        proteins.  The algorithm that constructs the protein families
        attempts to handle these properly, but it is often not clear whether
        or not a protein belongs in the "main" family or represents a 
	newly-derived function.

Note that you can see where the function occurs in the tree by clicking
the link that requests painting all of the members of the families with the function
simultaneously ("Family on Tree with union of families").

Finally, you get two tables.  The first shows you points in the tree where
specific families with the function were gained (i.e., the ancestor
of the mentioned node apparently does not contain a member of the family,
but the mentioned node does).  The second table shows the arcs in which 
the families were dropped (i.e., the ancestor apparently doed contain
an instance, but the mentioned node does not).  If you were to click on
the mentioned node, it will display a table showing all of the families
that were gained or lost on the designated arc.

</pre>
END
    return $txt;
}


# ==================================== LINKS ======

sub help_display_reaction_on_tree_link {
    my($cgi) = @_;

    return "<a target='_blank' href=wc.cgi?request=show_help&type=reaction_on_tree>Help for a reaction mapped to the tree</a>"
} 

sub help_reactions_link {
    my($cgi) = @_;

    return "<a target='_blank' href='wc.cgi?request=show_help&type=reaction'>show help for displaying changes in the reaction netwrok</a>"
} 

sub help_display_family_link {
    my($cgi) = @_;

    return "<a target='_blank' href='wc.cgi?request=show_help&type=family'>show help for family display</a>"
} 

sub help_display_function_link {
    my($cgi) = @_;

    return "<a target='_blank' href='wc.cgi?request=show_help&type=function'>show help for function display</a>"
} 

sub help_display_adjacency_link {
    my($cgi) = @_;

    return "<a target='_blank' href='wc.cgi?request=show_help&type=adjacency'>show help for adjacency display</a>"
} 

sub help_signatures_link {
    my($cgi) = @_;

    return "<a target='_blank' href='wc.cgi?request=show_help&type=signatures'>show help relating to signatures</a>"
} 

sub help_compute_signatures_link {
    my($cgi) = @_;

    return "<a target='_blank' href='wc.cgi?request=show_help&type=compute_signatures'>Show help relating to output of signatures</a>"
} 

sub help_signatures_reactions_link {
    my($cgi) = @_;

    return "<a target='_blank' href='wc.cgi?request=show_help&type=signatures_reactions'>show help relating to reactions that act as signatures</a>"
} 

sub help_compute_signatures_reactions_link {
    my($cgi) = @_;

    return "<a target='_blank' href='wc.cgi?request=show_help&type=compute_signatures_reactions'>Show help relating to output of reaction signatures</a>"
} 

sub show_reaction_genome_data_link {
    my($reaction,$genome,$dataD,$base) = @_;
    my $link =  "<a target='_blank' href='wc.cgi?request=show_reaction_genome_data&base=$base&dataD=$dataD&reaction=$reaction&genome=$genome'>$genome</a>";
    return $link;
}

sub show_func_link {
    my($dataD,$function,$base) = @_;

    if (! $function) { return '' }
    my $functionQ = uri_escape($function);
    return "<a target='_blank' href='wc.cgi?request=show_func&function=$functionQ&base=$base&dataD=$dataD'>$function</a>"
}

sub cluster_link_and_cluster_html {
    my($family,$coupledH,$fam_to_func,$dataD,$base) = @_;

    my $cluster_link = '';
    my $coupled = $coupledH->{$family};
    my $coupled_html = "";
    if ($coupled && (@$coupled > 0))
    {
	$cluster_link = &show_clusters_link($dataD,$family,$coupled,$base);
	$coupled_html = join("<br>",map { &show_fam_table_link($dataD,$_,$base) . '(' .
					  &show_func_link($dataD,$fam_to_func->{$_},$base) . ')'
				        } @$coupled);
    }
    return ($cluster_link,$coupled_html);
}

sub show_clusters_link {
    my($dataD,$family,$coupled,$base) = @_;
    my %tmp = map { $_ => 1 } ($family,@$coupled);
    my $families = join(",",sort { $a <=> $b} keys(%tmp));
    return "<a target='_blank' href=\"wc.cgi?request=show_clusters&base=$base&dataD=$dataD&families=$families\">$family</a>";
}

sub show_fam_table_link {
    my($dataDF,$fam,$base) = @_;

    $dataDF =~ /([^\/]+)$/; 
    my $dataD = $1;

    return "<a target='_blank' href='wc.cgi?family=$fam&pegs=1&request=show_family_pegs&base=$base&dataD=$dataD'>$fam: PEGs</a>";
}

sub show_fam_links {
    my($dataDF,$fam,$base) = @_;

    $dataDF =~ /([^\/]+)$/; 
    my $dataD = $1;

    return ("<a target='_blank' href='wc.cgi?request=show_family_tree&family=$fam&base=$base&dataD=$dataD'>tree</a>",
	    "<a target='_blank' href='wc.cgi?request=show_family_pegs&family=$fam&pegs=1&base=$base&dataD=$dataD'>PEGs:$fam</a>");
}

sub peg_link {
    my($peg,$parms) = @_;

    my $gid = &SeedUtils::genome_of($peg);
    my $type = $parms->{genome_types}->{$gid};
    if ($type eq "SEED")
    {
	return "<a target='_blank' href='http://pubseed.theseed.org/seedviewer.cgi?page=Annotation&feature=$peg'>$peg</a>";
    }
    elsif ($type eq "RAST")
    {
	return "<a target='_blank' href='http://rast.nmpdr.org/seedviewer.cgi?page=Annotation&feature=$peg'>$peg</a>";
    }
    else
    {
	return $peg;
    }
}

sub show_fam_on_tree_link {
    my($dataDF,$fam,$union) = @_;

    $union = defined($union) ? $union : 0;
    if ($dataDF =~ /([^\/]+)$/)
    {
	my $dataDQ = uri_escape($1);
	return "<a target='_blank' href='wc.cgi?family=$fam&union=$union&dataD=$dataDQ&request=show_family_tree'>Family on Tree</a>";
    }
    return '';
}

sub reaction_on_tree_link
{
    my($r,$base,$dataD) = @_;
    my $link="<a target='_blank' href='wc.cgi?request=show_reaction_on_tree&base=$base&dataD=$dataD&reaction=$r'>$r</a>";
    return $link;
}

sub show_node_link {
    my($dataD,$node,$type,$base) = @_;
    if ($type eq "families")
    {
	return "<a target='_blank' href='wc.cgi?request=show_node&base=$base&dataD=$dataD&node=$node&type=families'>$node</a>";
    }
    elsif ($type eq "reaction")
    {
	return "<a target='_blank' href='wc.cgi?request=show_node&base=$base&dataD=$dataD&node=$node&type=reaction'>$node</a>";
    }
    else
    {
	return "<a target='_blank' href='wc.cgi?request=show_node&base=$base&dataD=$dataD&node=$node&type=adjacency'>$node</a>";
    }
}

# RAST:    http://rast.nmpdr.org/seedviewer.cgi?page=Annotation&feature=fig|1639.345.peg.1 
# pubSEED  http://pubseed.theseed.org/seedviewer.cgi?page=Annotation&feature=fig|394.7.peg.6356
#
sub compare_link {
    my($pegs,$parms) = @_;
    my $types = $parms->{genome_types};
    my %seed_genomes = map { ($types->{$_} eq "SEED") ? ($1 => 1) : () } keys(%$types);

    my @genomes = map { (($_ =~ /^fig\|(\d+\.\d+)/) && $seed_genomes{$1}) ? $1 : () } @$pegs;
    if (@genomes < 1) 
    {
	return " ";
    }
    my $args = join("&",map { "show_genome=$_" } @genomes);
    return "<a target='_blank' href='http://pubseed.theseed.org/seedviewer.cgi?page=Annotation&feature=" .
	     $pegs->[0] . "&$args'>Compare Regions</a>";
}

sub search_index
{
    my($csD, $term) = @_;
    my $idir = "$csD/Index";
    my $mousse = Search::Mousse->new(directory => $idir,
				     name => "search_index",
				     stemmer => \&search_stemmer,);
    $mousse->and(1);
    return $mousse->search($term);
}

sub create_inverted_index
{
    my($csD) = @_;

    if (!$have_mousse)
    {
	print STDERR "Not creating index: Search::Mousse not available\n";
	return;
    }

    my $idir = "$csD/Index";
    my $tmpdir = "$csD/tmp";
    make_path($idir);
    make_path($tmpdir);

    local $ENV{TMPDIR} = $tmpdir;
    print STDERR "initializing index creation with idir=$idir tmpdir=$tmpdir\n";
    my $mousse = Search::Mousse::Writer->new(directory => $idir,
					     name => "search_index",
					     stemmer => \&search_stemmer,);
    for my $gto (<$csD/GTOs/*>)
    {
	my $gobj = GenomeTypeObject->create_from_file($gto);
	print STDERR "Writing index for $gto\n";
	for my $feature ($gobj->features())
	{
	    my $id = $feature->{id};
	    my $func = $feature->{function};
	    $mousse->add($id, $feature, "$func $gobj->{scientific_name}"); 
	}
    }
    print STDERR "Writing index\n";
    $mousse->write();
    print STDERR "Writing done\n";
}

sub search_stemmer
{
    my $words = lc shift;
    return Uniq::uniq(split /[-\s:;]/, $words);
}

1;
