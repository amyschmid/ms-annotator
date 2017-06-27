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
package Cmd2HTML;

use strict;
use Carp;
use Data::Dumper;

sub process_string {
    my($req,$state) = @_;

    my $aliases = $state->{aliases};
    my $kb_dcg  = $state->{prolog};
    my $html;

    $req =~ s/[.?]$//;
    my @words;
    while ($req)
    {
	my($word,$rest);
	if ($req =~ /^\'([^\']*)\'(.*)$/)
	{
	    ($word,$rest) = ($1,$2);
	}
	elsif ($req =~ /^(\d+)(k?bp|basepair)(.*)$/)
	{
	    ($word,$rest) = ($2,$3);
	    push(@words,$1);
	}
	elsif ($req =~ /^([^\s]*)(.*)$/)
	{
	    ($word,$rest) = (lc $1,$2);
	}
	if ($req)
	{
	    $rest =~ s/^\s+//;
	    $req = $rest;
	    push(@words,$word);
	}
    }
    @words = map { $aliases->{$_} ? split(/\s+/,$aliases->{$_}) : $_ } 
             map { ($_ =~ /^([^\?\!]+)([\?,\!,\.])$/) ? $1 : $_ } @words;
    @words = map { ($_ =~ /^\'.*\'$/) ? $_ : ("'$_'") } @words;
    my $pstr = "parse_sentence([" . join(",",@words) . "],Reply).\n";
    print STDERR "to prolog: $pstr\n";

    my $tmpF = "tmp.$$";
    open(PROLOG,"| $kb_dcg > tmp.$$") || die "could not open prolog pipe";
    print PROLOG $pstr;
    print PROLOG "a\nhalt.\n";
    close(PROLOG);
    my @tmp_back = `cat $tmpF`;
    print &Dumper(['prolog out: ',\@tmp_back]);
    my @tmp = map { ($_ =~ /Reply = (\S+(\'[^\']*\')*\S+)\s\?\s*$/) ? $1 : () } `cat $tmpF`;
    print &Dumper(['back,',\@tmp]);
    unlink($tmpF);

    if (@tmp == 1)
    {
	print STDERR "Parsed Command: $tmp[0]\n";
	$html = &Cmd2HTML::process_parsed_query($tmp[0],$state);
    print STDERR "HTML\n";
    print STDERR Dumper $html;
	return $html;
    }
    else
    {
	return ["table", {error => "<h3>I don't understand that command. $req</h3>\n"}];
    }
}


sub get_args {
    my($x) = @_;

    my @arguments;
    while ($x)
    {
	$x =~ s/^,//;
	if ($x =~ s/^(\[[^\]]*\])//)
	{
	    push(@arguments,$1);
	}
	elsif ($x =~ s/^\'([^\']*)\'//)
	{
	    push(@arguments,$1);
	}
	elsif ($x =~ s/^([a-zA-Z0-9]*)(,|$)//)
	{
	    push(@arguments,$1);
	}
	elsif ($x =~ /^([a-zA-Z0-9]*\()/)
	{
	    my $i = length($1);
	    my $end;
	    my $left = 1;
	    while ((! $end) && ($i < length($x)))
	    {
		my $c = substr($x,$i,1);
		if ($c eq "(")
		{
		    $left++;
		}
		elsif ($c eq ")")
		{
		    $left--;
		    if ($left == 0)
		    {
			$end = $i+1;
		    }
		}
		$i++;
	    }

	    if ($end)
	    {
		push(@arguments,substr($x,0,$end));
		$x = substr($x,$end);
	    }
	}
	else
	{
	    print STDERR &Dumper($x,\@arguments);  die "BAD";
	}
    }
    return @arguments;
}

sub process_parsed_query {
    my($query,$state) = @_;
    if ($query =~ /^([^\(]+)\((.*)\)$/)
    {
	my($functor,$args) = ($1,$2);
	my @arguments;
	while($args =~ /((\[[^\]]*\])|(\'([^\']*)\')|(^|[\(,])([^\(,\'\)]*)([\),]|$))/g)
	{
	    if    ($6)  { push(@arguments,$6) }
	    elsif ($4)  { push(@arguments,$4) }
	    elsif ($1)  { push(@arguments,$1) }
#	    print &Dumper([$1,$2,$3,$4,$5,$6]);
	}
	no strict;
#       print &Dumper(["perl:", $functor, \@arguments]);
	return &{$functor}($state,@arguments);
	use strict;
    }
    elsif ($query =~ /^([^\(]+)$/)
    {
	my $functor = $1;
	no strict;
	return &{$functor}($state);
	use strict;
    }
    else
    { 
	return undef ;
    }
}

sub fc {
    my($state,$fid) = @_;
    my $ret;

    my @tmp = `echo '$fid' | fids_to_co_occurring_fids`;
    if (@tmp < 1)
    {
        $ret->{error} = "<h3>$fid is either an invalid id, or no function has been assigned yet</h3>";
    }
    else
    {
        my $hdr = ['feature id','number OTUs','co-occurring fid'];
        my @tab = map { chop; [split(/\t/,$_)] } @tmp;
        $ret->{header} = $hdr;
        $ret->{data} = \@tab;
    }
	return ["table", $ret];
}

sub compound_to_reactions {
    my($state,$compound) = @_;

    return &implement_with_kb(['Compound Id', 'Compound'],
			      "echo '$compound' | get_relationship_ParticipatesAs -to id | get_relationship_IsInvolvedIn -to id,name  | cut -f 3,4 | sort -u");
}

sub compounds_in_model {
    my($state,$model) = @_;

    return &implement_with_kb(['Model', 'Location Instance','Location','Localized Compound', 'Compound'],
			      #"echo 'kb|fm.0.bio.0' | get_relationship_IsDividedInto -to id  get_relationship_IsInstanceOf -to id  | get_relationship_IsParticipatingAt -to id | get_relationship_IsParticipationOf -to id");
			      "echo '$model' | get_relationship_IsDividedInto -to id |  get_relationship_IsInstanceOf -to id  | get_relationship_IsParticipatingAt -to id | get_relationship_IsParticipationOf -to id");
}

sub genomes_with_models {
    my($state) = @_;

    return &implement_with_kb(['Model ID','Genome ID','Scientific Name'],
		              "all_entities_Model | get_relationship_Models -to id,scientific_name");
}

sub genes_in_region {
    my($state,$contig,$beg,$end) = @_;

    my $ret;
    my $csO = Bio::KBase::CDMI::CDMIClient->new_for_script();
    my $strand = ($beg < $end) ? '+' : '-';
    my $ln = abs($end-$beg)+1;
    my $fids = $csO->region_to_fids([$contig,$beg,$strand,$ln]);
    my $funcH = $csO->fids_to_functions($fids);
    my $locH   = $csO->fids_to_locations($fids);
    my $hdr = ['Feature','Location','Function'];
    my @tab;
    foreach my $fid (@$fids)
    {
	my $func = $funcH->{$fid};
	my $loc  = join(",",map { ($_->[0] . '_' . $_->[1] . $_->[2] . $_->[3]) } @{$locH->{$fid}});
	push(@tab,[$fid,$loc,$func]);
    }
    @tab = sort { $a->[1] =~ /^\S+_(\d+)[+-]/; my $ab = $1;
		  $b->[1] =~ /^\S+_(\d+)[+-]/; my $bb = $1;
		  ($ab <=> $bb) } @tab;
    $ret->{header} = $hdr;
    $ret->{data} = \@tab;
	return ["table", $ret];
}
sub models_for_genome {
    my($state,$g) = @_;

    return &implement_with_kb(['Genome ID','Scientific Name','Model ID'],
			      "echo '$g' | get_relationship_IsModeledBy -from scientific_name -to id");
}

sub genome_to_reactions {
    my($state,$genome) = @_;

    return &implement_with_kb(['Genome ID', 'Model ID', 'Reaction Instance ID', 'Reaction ID'],
			      "echo '$genome' | get_relationship_IsModeledBy -to id | get_relationship_HasRequirementOf -to id | get_relationship_IsExecutionOf -to id");
}


sub model_to_reactions {
    my($state,$model) = @_;

    return &implement_with_kb(['Model ID', 'Reaction Instance ID', 'Reaction ID'],
			      "echo '$model' | get_relationship_HasRequirementOf -to id | get_relationship_IsExecutionOf -to id");
}

sub role_to_reactions {
    my($state,$r) = @_;

    return &implement_with_kb([ 'Role', 'Complex', 'Reaction'],
			      "echo '$r' | get_relationship_Triggers -to id | get_relationship_HasStep -to id");
}

sub reaction_to_complexes {
    my($state,$r) = @_;

    return &implement_with_kb([ 'Reaction', 'Complex'],
			      "echo '$r' | get_relationship_IsStepOf -to id ");
}

sub complex_to_reactions {
    my($state,$c) = @_;

    return &implement_with_kb([ 'Complex','Reaction'],
			      "echo '$c' | get_relationship_HasStep -to id ");
}

sub compounds_in_biomass {
    my($state,$biomass) = @_;

    return &implement_with_kb(['Biomass ID','Compound Instance ID', 'Localized Compound ID','Compound ID','Label'],
			      "echo '$biomass' | get_relationship_IsComprisedOf -to id | get_relationship_IsUsageOf -to id | get_relationship_IsParticipationOf -to id,label");
}

sub known_media {
    my($state) = @_;
    
    return &implement_with_kb(['Media ID', 'Is Minimal', 'Name', 'Source ID', 'Type'],
			      "all_entities_Media -f 'is_minimal,name,source_id,type'");
}

sub compounds_in_media {
    my($state,$media) = @_;

    return &implement_with_kb(['Media ID','Compound ID','Label of Compound'],
			      "echo '$media' | get_relationship_HasPresenceOf -to id,label");
}

sub count_of_otus {
    my($state) = @_;

    return &implement_with_kb(['Number of OTUs'],"all_entities_OTU | wc -l");
}

sub existing_otus {
    my($state) = @_;

    return &implement_with_kb(['OTU ID','Representative ID','Organism'],
			      "all_entities_OTU | sort -n | otus_to_representatives | get_entity_Genome -f 'scientific_name'");
}

sub genome_to_otu {
    my($state,$genome) = @_;

    return &implement_with_kb(['Genome ID','OTU ID','Representative Genome', 'Representative Name'],
			      "echo '$genome' | get_relationship_IsCollectedInto -to id | otus_to_representatives | get_entity_Genome -f scientific_name");
}

sub genomes_in_otu {
    my($state,$otu) = @_;

    return &implement_with_kb(['OTU ID','Genome ID', 'Organism'],
			      "echo '$otu' | get_relationship_IsCollectionOf -to 'id,scientific_name'");
}

sub taxonomy_of_genome {
    my($state,$g) = @_;

    return &implement_with_kb(['Genome ID', 'Taxonomy'],
			      "echo '$g' | genomes_to_taxonomies");
}

sub taxonomy_id_of_group {
    my($state,$group) = @_;

    &implement_with_kb(['Taxonomy ID','Group'],
		       "query_entity_TaxonomicGrouping -is 'scientific_name,$group' -f scientific_name");
}

sub genomes_in_taxonomic_group {
    my($state,$group) = @_;
    
    &implement_with_kb(['Genome ID','Taxonomy'],
		       "all_entities_Genome | genomes_to_taxonomies 2> /dev/null | grep ' $group:'");
}
sub fid_to_protein_sequence {
    my($state,$fid) = @_;

    return &implement_with_kb(['Feature ID','Protein Sequence ID', 'Protein Sequence'],
			      "echo '$fid' | get_relationship_Produces -to id | fids_to_protein_sequences -c 1 -fasta 0");
}

sub annotations_of_sequence {
    my($state,$md5) = @_;

    return &implement_with_kb(['Protein Sequence ID','Source','External ID','GI Number','Function'],
			      "echo '$md5' | get_relationship_HasAssertedFunctionFrom -to id -rel 'external_id,gi_number,function'");
}

sub sequence_to_alignments {
    my($state,$md5) = @_;

    return &implement_with_kb(['Protein Sequence ID','Alignment ID'],
			      "echo '$md5' | get_relationship_IsAlignedProteinComponentOf -to id");
}



use POSIX;

sub biomass_reaction {
    my($state,$model) = @_;

    my @out = map { $_->[2] = asctime(localtime($_->[2])); chomp $_->[2]; $_ }
              map { chop; [split(/\t/,$_)] } `echo '$model' | get_relationship_Manages -to id | get_entity_Biomass -a`;

    my $retH = {};
    $retH->{header} = ['Model ID',
		       'Biomass ID', 
		       'last modification date of the biomass data',
		       'descriptive name',
		       'portion of a gram of this biomass (expressed as a fraction of 1.0) that is DNA',
		       'portion of a gram of this biomass (expressed as a fraction of 1.0) that is protein',
		       'portion of a gram of this biomass (expressed as a fraction of 1.0) that is cell wall',
		       'portion of a gram of this biomass (expressed as a fraction of 1.0) that is lipid but is not part of the cell wall',
		       'portion of a gram of this biomass (expressed as a fraction of 1.0) that function as cofactors',
		       'number of ATP molecules hydrolized per gram of this biomass'];
    $retH->{data} = \@out;
    return ["table",$retH];
}
sub reaction_to_roles {
    my($state,$r) = @_;

    return &implement_with_kb([ 'Reaction', 'Complex', 'Role'],
			      "echo '$r' | get_relationship_IsStepOf -to id | get_relationship_IsTriggeredBy -to id");
}


sub intergenic_regions {
    my($state,$genome) = @_;

    return &implement_with_kb_fasta("genome_to_intergenic_regions -g '$genome'");
}

use Bio::KBase::CDMI::CDMIClient;
use Bio::KBase::Utilities::ScriptThing;

sub dna_sequence_of_region {
    my($state,$contig,$beg,$end) = @_;

    my $strand = ($beg < $end) ? '+' : '-';
    my $len = abs($beg -$end) + 1;
    my $loc = "$contig\_$beg" . $strand . $len;
    return &implement_with_kb(['Location','DNA'],
			      "echo '$loc' | locations_to_dna_sequences");

}

sub dna_sequence_of_upstream {
    my($state,$fid,$n) = @_;
    my $ret;

    if ($n =~ /^dist\(\'?(\d+)\'?,(\S+)\)/)
    {
	my($d,$unit) = ($1,$2);
	$n = ($unit eq 'kbp') ? ($d * 1000) : $d;
    }
    my @tmp = `echo '$fid' | fids_to_locations`;
    if ((@tmp > 0) && ($tmp[0] =~ /^\S+\t(\S+)_(\d+)([+-])(\d+)/))
    {
	my($contig,$beg,$strand,$ln) = ($1,$2,$3,$4);
	if ($strand eq '+')
	{
	    $beg = ($beg > $n) ? ($beg - $n) : 1;
	}
	else
	{
	    $beg = $beg+$n;
	}
	my $loc = "$contig\_$beg" . $strand . $n;
	return &implement_with_kb(['Location','DNA'],
				  "echo '$loc' | locations_to_dna_sequences");
    }
    $ret->{error} = "<h3>Could not get location of $fid</h3>";
    return ["table", $ret];
}

sub dna_sequence_of_downstream {
    my($state,$fid,$n) = @_;
    my $ret;

    if ($n =~ /^dist\(\'?(\d+)\'?,(\S+)\)/)
    {
	my($d,$unit) = ($1,$2);
	$n = ($unit eq 'kbp') ? ($d * 1000) : $d;
    }
    my @tmp = `echo '$fid' | fids_to_locations`;
    if ((@tmp > 0) && ($tmp[0] =~ /^\S+\t(\S+)_(\d+)([+-])(\d+)/))
    {
	my($contig,$beg,$strand,$ln) = ($1,$2,$3,$4);
	if ($strand eq '+')
	{
	    $beg = $beg+$ln;
	}
	else
	{
	    $beg = $beg-$n;
	}
	my $loc = "$contig\_$beg" . $strand . $n;
	return &implement_with_kb(['Location','DNA'],
				  "echo '$loc' | locations_to_dna_sequences");
    }
    $ret->{error} = "<h3>Could not get location of $fid</h3>";
    return ["table", $ret];
}

sub point_is {
    my($n,$units,$loc,$dir) = @_;

#   print &Dumper($n,$units,$loc,$dir); die "HERE";
}

sub genomes_in_subsystem {
    my($state,$subsys) = @_;

    return &implement_with_kb(['Subsystem','Variant Code','Genome','Scientific Name'],
			      "echo '$subsys' | subsystems_to_genomes | get_entity_Genome -f scientific_name");
}

sub subsystems_for_genome {
    my($state,$g) = @_;

    return &implement_with_kb(['Genome','Subsystem'],
			      "echo '$g' | genomes_to_subsystems");
}

sub features_implement_role {
    my($state,$g,$role) = @_;

    return &implement_with_kb(['Feature','Function'],
			      "echo '$g' | get_relationship_IsOwnerOf -to id,function | grep '$role' | cut -f2,3");
}

sub families_implement_role {
    my($state,$role) = @_;

    return &implement_with_kb(['Family','Function'],
			      "echo '$role' | get_relationship_DeterminesFunctionOf -to id");
}

sub roles_in_subsystem {
    my($state,$subsys) = @_;

    return &implement_with_kb(['Role'],
			      "echo '$subsys' | get_relationship_Includes -to id | cut -f 2");
}

sub kbase_id_of_genome {
    my($state,$source,$source_id) = @_;

    return &implement_with_kb(['KBase id'],
			      "query_entity_Genome -is 'source_id,$source_id' | get_relationship_WasSubmittedBy -to id | grep -i '$source' | cut -f1");
}

sub fids_with_publications {
    my($state,$genome) = @_;

    return &implement_with_kb(['feature','pubmed','URL','title'],"echo '$genome' | genomes_to_fids | fids_to_literature | cut -f2,3,4,5");
}

sub families_of_fid {
    my($state,$fid) = @_;

    return &implement_with_kb(['Feature','Protein Family','Family Function'],
			      "echo '$fid' | fids_to_protein_families | get_entity_Family -f family_function");
}

sub fids_in_family {
    my($state,$family) = @_;
    $family = uc($family);  #### CHECK THIS ###

    return &implement_with_kb(['Family','Feature','Feature Function'],
			      "echo '$family' | protein_families_to_fids | fids_to_functions");
}

sub protein_sequences_in_family {
    my($state,$fam) = @_;

    return &implement_with_kb(['Family','MD5','Sequence'],
			      "echo '$fam' | protein_families_to_proteins | proteins_to_sequences -fasta=0");
}

sub fasta_sequences_in_family {
    my($state,$fam) = @_;

    return &implement_with_kb_fasta("echo '$fam' | protein_families_to_proteins | proteins_to_sequences -fasta=1");
}


sub protein_sequence_of_fid {
    my($state,$fid) = @_;
    
    return &implement_with_kb(['Feature','Protein Sequence'],
			      "echo '$fid' | fids_to_protein_sequences -fasta=0");
}

sub dna_sequence_of_fid {
    my($state,$fid) = @_;

    return &implement_with_kb(['Feature','DNA Sequence'],
			      "echo '$fid' | fids_to_dna_sequences -fasta=0");
}

sub atomic_regulon_containing {
    my($state,$fid) = @_;

    return &implement_with_kb(['Feature','Atomic Regulon'],
			      "echo '$fid' | get_relationship_IsFormedInto -to id");
}

sub family_type {
    my($state,$fam) = @_;

    $fam = uc($fam);
    return &implement_with_kb(['Family','Type'],
			      "echo '$fam' | get_entity_Family -f type");
}

sub family_function {
    my($state,$fam) = @_;
    $fam = uc($fam);

    return &implement_with_kb(['Family','Family Function'],
			      "echo '$fam' | get_entity_Family -f family_function");
}

sub publications_of_fid {
    my($state,$fid) = @_;

    return &implement_with_kb(['feature','pubmed','URL','title'],"echo '$fid' | fids_to_literature");
}

sub kbase_id_of_feature {
    my($state,$source,$source_id) = @_;

    return &implement_with_kb(['KBase id'],
			      "query_entity_Feature -is 'source_id,$source_id' | get_relationship_IsOwnedBy -to id | get_relationship_WasSubmittedBy -to id | grep -i '$source' | cut -f1");
}

sub correlated_expression {
    my($state,$fid) = @_;

    return &implement_with_kb(['feature id','Pearson Correlation Coefficient','coexpressed fid'],
			      "echo '$fid' | fids_to_coexpressed_fids");
}

sub function_of_fid {
    my($state,$fid) = @_;

    return &implement_with_kb(['feature id','function'],
			      "echo '$fid' | get_entity_Feature -f function");
}

sub location_of_fid {
    my($state,$fid) = @_;

    return &implement_with_kb(['feature id','location'],
                  "echo '$fid' | fids_to_locations");
}

sub source_of_genome {
    my($state,$g) = @_;

    return &implement_with_kb(['genome id','source','source id'],
			      "echo '$g' | get_relationship_WasSubmittedBy -from source_id -to id");
}

sub close_genomes {
    my($state,$g,$n) = @_;

    return &implement_with_kb(['genome ID', 'average percent identity between proteins implementing core functionality', 'close genome'],
			      "echo '$g' | close_genomes -n $n");
}

sub size_genome {
    my($state,$g) = @_;

    return &implement_with_kb(['genome id','DNA size'],
			      "echo '$g' | get_entity_Genome -f dna_size");
}

sub name_of_genome {
    my($state,$g) = @_;

    return &implement_with_kb(['genome id','scientific name'],
			      "echo '$g' | get_entity_Genome -f scientific_name");
}

sub contigs_in_genome {
    my($state,$g) = @_;

    return &implement_with_kb(['genome id','contig id'],
			      "echo '$g' | genomes_to_contigs");
}

sub subsystems_containing_role {
    my($state,$role) = @_;
    
    return &implement_with_kb(['Role', 'Subsystem Containing Role'],
			      "echo '$role' | get_relationship_IsIncludedIn -to id | sort -u");
}

sub roles_used_in_subsystems {
    my($state) = @_;

    return &implement_with_kb(['role'],
			      "all_entities_Subsystem | get_relationship_Includes -to id | cut -f2 | sort -u");
}

sub roles_used_in_models {
    my($state) = @_;

    return &implement_with_kb(['role'],
			      "all_roles_used_in_models");
}

 
sub show_genome {
    my($state,$g) = @_;
    my $ret;

    if ($g !~ /^kb\|g\.\d+$/)
    {
        $ret->{error} = "<h3>$g does not look like a KBase genome</h3>\n";
    }
    else
    {   
        my @tmp = `echo '$g' | get_entity_Genome -a`;
        if (@tmp != 1)
        {
            $ret->{error} = "<h3>$g does not appear to be in KBase</h3>\n";
        }
        else
        {
            chop $tmp[0];
            my @fields = split(/\t/,$tmp[0]);
            my $hdr = ['id','CDSs','rnas','scientific_name','complete','prokaryotic','size (bp)','contigs','domain','genetic_code','GC','source_id'];
            $fields[10] = sprintf("%0.3f",$fields[10]);
            splice(@fields,11,2);
            $ret->{header} = $hdr;
            $ret->{data} = [\@fields];
        }
    }
    return ["table", $ret];
}

sub implement_with_kb {
    my($hdr,$kb_pipe) = @_;
    my $ret;

    my @tmp = `$kb_pipe`;
    if (@tmp < 1)
    {
	    $ret->{error} = "Undefined"; 
    } else {
        my @tab = map { chop; [split(/\t/,$_)] } @tmp;
        $ret->{header} = $hdr;
        $ret->{data} = \@tab;
    }
    return ["table", $ret];
}

sub implement_with_kb_fasta {
    my($kb_pipe) = @_;
    my $ret;

    my @tmp = `$kb_pipe`;
    if (@tmp < 1)
    {
	    $ret->{error} = "Undefined"; 
    } else {
        $ret->{data} =  join("",@tmp);    
    }
    return ['Fasta File',$ret];
}

sub num_contigs_in_genome {
    my($state,$g) = @_;
    my $ret;

    if ($g !~ /^kb\|g\.\d+$/)
    {
	    $ret->{error} = "<h3>$g does not look like a KBase genome</h3>\n";
    } else {
        my @tmp = `echo '$g' | genomes_to_contigs`;

        if (@tmp == 0)
        {
            $ret->{error}  = "<h3>$g does not appear to be in KBase</h3>\n";
        }
        else
        {
            my $hdr = ['genome id','number contigs'];
            my @tab = ([$g,scalar @tmp]);

            $ret->{header} = $hdr;
            $ret->{data} = \@tab;
        }
    }
    return ["table", $ret];
}

sub number_genes_in_genome {
    my($state,$g,$type) = @_;
    my $ret;

    if ($g !~ /^kb\|g\.\d+$/)
    {
	    $ret->{error} = "<h3>$g does not look like a KBase genome</h3>\n";
    }
    my @tmp = `echo '$g' | genomes_to_fids`;
    if (@tmp == 0)
    {
        $ret->{error}  = "<h3>$g does not appear to be in KBase</h3>\n";
    }
    else
    {
	my $hdr = ['genome id','number features'];
	my $n = 0;
	foreach $_ (@tmp)
	{
	    if ($_ =~ /^\S+\t(kb\|g\.\d+\.([^.]+)\.\d+)/) 
	    {
		my $type_fid = $2;
		if ($type =~ /all/i)
		{
		    $n++;
		}
		elsif (lc $type eq lc $type_fid)
		{
		    $n++;
		}
		elsif (($type =~ /^(peg)|(cds)/i) &&
		       ($type_fid =~ /^(peg)|(cds)/i))
		{
		    $n++;
		}
	    }
	}
	my @tab = ([$g,$n]);
    $ret->{header} = $hdr;
    $ret->{data} = [\@tab];
    }
    return ["table", $ret];
}

sub genes_in_genome {
    my($state,$g,$type) = @_;
    my $ret;

    if ($g !~ /^kb\|g\.\d+$/)
    {
	    $ret->{error} = "<h3>$g does not look like a KBase genome</h3>\n";
    } else {
        my @tmp = `echo '$g' | get_relationship_IsOwnerOf -to id,function`;
        if (@tmp == 0)
        {
            $ret->{error}  = "<h3>$g does not appear to be in KBase</h3>\n";
        }
        else
        {
            my $hdr = ['genome id','feature','function'];
            my $n = 0;
            my @tab;
            foreach $_ (@tmp)
            {
                if ($_ =~ /^\S+\t(kb\|g\.\d+\.([^.]+)\.\d+)\t(.*)$/) 
                {
                my $fid = $1;
                my $type_fid = $2;
                my $function = $3 ? $3 : '';
                if ($type =~ /all/i)
                {
                    push(@tab,[$g,$fid,$function]);
                }
                elsif (lc $type eq lc $type_fid)
                {
                    push(@tab,[$g,$fid,$function]);
                }
                elsif (($type =~ /^(peg)|(cds)/i) &&
                       ($type_fid =~ /^(peg)|(cds)/i))
                {
                    push(@tab,[$g,$fid,$function]);
                }
                }
            }
            $ret->{header} = $hdr;
            $ret->{data} = \@tab;
        }
    }
    return ["table", $ret];
}

sub help {
    my($state,$entity) = @_;
    my $ret;
    my $help;

    my $helpD = "$state->{helpD}/Entities";
    opendir(HELP,$helpD) || die "could not open $helpD";
    my @entities = grep { $_ =~ /^[A-Z]/ } readdir(HELP);
    closedir(HELP);
    my %to_entity;

    if ($entity eq "pipes") {
        foreach $_ (@entities) {
           if (-s "$helpD/$_/pipes")
            {
                $help .= `cat $helpD/$_/pipes`;
            }
       }
       my @lines = split("\n", $help);
       my @tab;
       foreach my $line (@lines) {
            $line =~ s/KB-PIPE: //;
            my @pair = split("\t", $line);
            push (@tab, [@pair]);
        }
       my $hdr = ['Query','Pipe'];
       $ret->{header} = $hdr;
       $ret->{data} = \@tab;
       return ["table", $ret]; 
    } else {
        if ($entity eq "all") {
            foreach $_ (@entities) {
               if (-s "$helpD/$_/help.html")
                {
                    $help .= `cat $helpD/$_/help.html`;
                }
                $ret->{data} = $help;
           }

        } else {
            foreach $_ (@entities)
            {
                $to_entity{lc $_} = $_;
            }
            my $actual_entity = $to_entity{$entity};
           if (-s "$helpD/$actual_entity/help.html")
            {
                $ret->{data} = `cat $helpD/$actual_entity/help.html`;
            }
            else
            {
                $ret->{error} = "<h3>no help for entity: $entity ($actual_entity)</h3>\n";
            }
        }
    }
    return ["html", $ret];
}


sub tab_to_html {
    my($hdr,$rows) = @_;

    my @html = ("<table border=1>\n");
    push(@html,"<tr>",map { "<th>$_</th>" } @$hdr,"</tr>\n");
    foreach my $row(@$rows)
    {
	push(@html,"<tr>",map { "<td>$_</td>" } @$row,"</tr>\n");
    }
    push(@html,"</table>\n");
    return join('',@html);
}

sub set_alias {
    my($state,$new_alias,$real) = @_;
    my $aliases = $state->{aliases};
    $aliases->{$new_alias} = $real;
    return "<h3>Set alias: $new_alias means $real</h3>";
}
	
sub forget_alias {
    my($state,$alias) = @_;
    my $aliases = $state->{aliases};
    return "<h3>Deleted alias: $alias</h3>";
}

sub dequote {
    my($x) = @_;

    $x =~ s/^\'(.*)\'$/$1/;
    return $x;
}

	
sub use_aliases {
    my($state,$file) = @_;

    $file = &dequote($file);
    my $aliases = $state->{aliases};
    my $userD   = $state->{userD};
    my $cwd = $state->{cwd};
    my $invoc = $state->{invoc};
    my $session = $state->{session};
    my $file = $invoc->get_file($session, $file, $cwd);
    my $n = 0;
    foreach my $line (split(/\n/,$file)) {
	    chop $line;
	    my($real,@aliases) = split(/\t/,$line);
	    if (@aliases > 0)
	    {
		foreach my $alias (@aliases)
		{
		    $aliases->{lc $alias} = $real;
		    $n++;
		}
	    }
	    else
	    {
		return "<h3>Something wrong here: $_</h3>\n";
	    }
	}
	return "<h3>Set $n aliases</h3>\n";
}

sub which_entities {
    my($state) = @_;
    
    my $helpD = "$state->{helpD}/Entities";
    opendir(HELP,$helpD) || die "could not open $helpD";
    my @entities = grep { $_ !~ /^\./ } readdir(HELP);
    closedir(HELP);
    my $hdr   = "<table border=1>\n<tr><th>Entitity</th><th>Description</th></tr>";
    my $trail = "</table>\n";
    my @body;
    foreach my $entity (sort @entities)
    {
	my $desc = join("",`cat $helpD/$entity/description`);
	my $entry = "<tr><td>$entity</td><td>$desc</td></tr>\n";
	push(@body,$entry);
    }
    return $hdr . join("",@body) . $trail;
}

sub genomes_like {
    my($state,$pat) = @_;

    my @pat;
    if ($pat !~ /^\[(.*)\]$/)
    { 
	$pat[0] = $pat;
    }
    else
    {
	@pat = split(/,/,$1);
    }

    my @genomes = map { chop; [split(/\t/,$_)] } `all_entities_Genome -f scientific_name`;
    foreach my $str (@pat)
    {
	@genomes = grep { index(lc $_->[1],lc $str) >= 0 } @genomes;
    }
    return &format_genomes(\@genomes);
}

sub format_genomes {
    my($genomes) = @_;
    my $ret;

    my $hdr = ['ID','Name'];
    $ret->{header} = $hdr;
    $ret->{data} = $genomes;
    return ["table", $ret]; 
}

1;
