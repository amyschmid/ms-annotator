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

package FIGrpc;

use Carp;
use Data::Dumper;

use strict;
use FIG;
use Frontier::Client;

sub new {
    my($class,$url) = @_;

    if (! $url)
    {
	my $fig = new FIG;
	return $fig;
    }
    else
    {
	my($proxy);

	$proxy = Frontier::Client->new(url => $url);

	my $self = {
	    _url => $url,
	    _proxy => $proxy,
	};

	return bless $self, $class;
    }
}

sub DESTROY {
    my($self) = @_;
    my($fig);

    if ($fig = $self->{_fig})
    {
	$fig->DESTROY;
    }
}

=pod

=head1 set_remote

usage: $fig->set_remote($url)

Sets the remote version of FIG to the one given by $url.

=cut

sub set_remote_FIG {
    my($self,$url) = @_;

    $self->{_url} = $url;
}


=pod

=head1 current_FIG

usage: $url = $fig->current_FIG

Returns the URL of the current FIG ("" for a local copy).

=cut

sub current_FIG {
    my($self) = @_;

    return $self->{_url} ? $self->{_url} : "";
}


=pod

=head1 genomes

usage: @genome_ids = $fig->genomes;

Genomes are assigned ids of the form X.Y where X is the taxonomic id maintained by
NCBI for the species (not the specific strain), and Y is a sequence digit assigned to
this particular genome (as one of a set with the same genus/species).  Genomes also
have versions, but that is a separate issue.

=cut

sub get_proxy
{
    my($self) = @_;
  
    return $self->{_proxy};
}

sub genomes {
    my($self) = @_;
    my $gen = $self->get_proxy()->call("genomes");
    return $gen;
}
   
sub genome_counts {
    my($self,$complete) = @_;
    my $counts = $self->get_proxy()->call("genome_counts",$complete);
    return $counts;  
}   

sub  genome_version {
    my($self,$genome) = @_;
    my $version = $self->get_proxy()->call("genome_version",$genome);
    return $version;  
    
}

sub genus_species {
    my($self,$genome) = @_;
    my $gs = $self->get_proxy()->call("genus_species",$genome);
    return $gs;
}

#############################  KEGG Stuff ####################################


=pod

=head1 all_maps

usage: @maps = $fig->all_maps

Returns a list containing all of the KEGG maps that the system knows about (the
maps need to be periodically updated).

=cut

sub all_maps {
    my($self) = @_;
    return my @results = $self->get_proxy()->call("all_maps");
}


=pod

=head1 map_to_ecs

usage: @ecs = $fig->map_to_ecs($map)

Returns the set of functional roles (usually ECs)  that are contained in the functionality
depicted by $map.

=cut

sub map_to_ecs {
    my($self,$map) = @_;
    return my @results = $self->get_proxy()->call("map_to_ecs",$map);
}


=pod

=head1 all_compounds

usage: @compounds = $fig->all_compounds

Returns a list containing all of the KEGG compounds.

=cut

sub all_compounds {
    my($self) = @_;
    return my @results = $self->get_proxy()->call("all_compounds");
}

sub names_of_compound {
    my($self,$cid) = @_;
    return my @results = $self->get_proxy()->call("names_of_compound");
}    

=pod

=head1 comp2react


usage: @rids = $fig->comp2react($cid)

Returns a list containing all of the reaction IDs for reactions that take $cid
as either a substrate or a product.

=cut

sub comp2react {
    my($self,$cid) = @_;
    return my $result = $self->get_proxy()->call("comp2react",$cid);   
}


=pod

=head1 all_reactions

usage: @rids = $fig->all_reactions

Returns a list containing all of the KEGG reaction IDs.

=cut

sub all_reactions {
    my($self) = @_;
    return my @results = $self->get_proxy()->call("all_reactions");
}


=pod

=head1 reversible

usage: $rev = $fig->reversible($rid)

Returns true iff the reactions had a "main direction" designated as "<=>";

=cut

sub reversible {
    my($self,$rid) = @_;
    return my $result = $self->get_proxy()->call("reversible",$rid);
}


=pod

=head1 catalyzed_by

usage: @ecs = $fig->catalyzed_by($rid)

Returns the ECs that are reputed to catalyze the reaction.  Note that we are currently
just returning the ECs that KEGG gives.  We need to handle the incompletely specified forms
(e.g., 1.1.1.-), but we do not do it yet.

=cut

sub catalyzed_by {
    my($self,$rid) = @_;
    return my @results = $self->get_proxy()->call("catalyzed_by",$rid);
}


=pod

=head1 catalyzes

usage: @ecs = $fig->catalyzes($role)

Returns the rids of the reactions catalyzed by the "role" (normally an EC).

=cut

sub catalyzes {
    my($self,$role) = @_;
    return my @results = $self->get_proxy()->call("catalyzes",$role);
}

sub reaction2comp {
    my($self,$rid,$which) = @_;
    return my @results = $self->get_proxy()->call("reaction2comp",$rid,$which);
}

sub seqs_with_roles_in_genomes {
    my($self,$genomes,$roles,$who) = @_;
    return my @results = $self->get_proxy()->call("seqs_with_roles_in_genome",$genomes,$roles,$who);
}

sub abbrev {
    my($self,$genome_name) = @_;
    return my $result = $self->get_proxy()->call("abbrev",$genome_name);
}

sub fast_coupling {
    my($self,$peg,$bound,$coupling_cutoff) = @_;
    return my @results = $self->get_proxy()->call("fast_coupling",$peg,$bound,$coupling_cutoff);
}


sub family_function {
    my($self,$family) = @_;
    return my $result = $self->get_proxy()->call("family_function",$family);
}

sub feature_annotations {
    my($self,$feature_id) = @_;
    return my @results = $self->get_proxy()->call("feature_annotations",$feature_id);
}

sub dna_seq {
    my($self,$genome,@locations) = @_;
    return my $result = $self->get_proxy()->call("dna_seq",$genome,@locations);
}

sub all_protein_families {
    my($self) = @_;
    return my @results = $self->get_proxy()->call("all_protein_families");
}

sub all_sets {
    my($self,$relation,$set_name) = @_;
    return my @results = $self->get_proxy()->call("all_sets",$relation,$set_name);
}

sub db_handle {
    my($self) = @_;
    return my $result = $self->get_proxy()->call("db_handle");
}

sub all_features {
    my($self,$genome,$type) = @_;
    return my @results = $self->get_proxy()->call("all_features",$genome,$type);    
}
    
sub sz_family {
    my($self,$family) = @_;
    return my $result = $self->get_proxy()->call("sz_family",$family);
}

sub sz_set {
    my($self,$which,$relation,$set_name) = @_;
    return my $result = $self->get_proxy()->call("sz_set",$which,$relation,$set_name);
}

sub cgi_url {
    my($self) = @_;
    return my $result = $self->get_proxy()->call("cgi_url");
}

sub function_of {
    my($self,$id,$user) = @_;
    return my $result = $self->get_proxy()->call("function_of",$id,$user);
}

sub get_translation {
    my($self,$id) = @_;
    return my $result = $self->get_proxy()->call("get_translation",$id);
}

sub org_of {
    my($self,$prot_id) = @_;
    return my $result = $self->get_proxy()->call("org_of",$prot_id);
}

sub by_alias {
    my($self,$alias) = @_;
    return my $result = $self->get_proxy()->call("by_alias",$alias);
}

sub by_fig_id {
    my($self,$a,$b) = @_;
    return my $result = $self->get_proxy()->call("by_fig_id",$a,$b);    
}

sub cas {
    my($self,$cid) = @_;
    return my $result = $self->get_proxy()->call("cas",$cid);    
}

sub cas_to_cid {
    my($self,$cas) = @_;
    return my $result = $self->get_proxy()->call("cas_to_cid",$cas);  
}

sub close_genes {
    my($self,$fid,$dist) = @_;
    return my @results = $self->get_proxy()->call("close_genes",$fid,$dist); 
}

sub contig_ln {
    my($self,$genome,$contig) = @_;
    return my $result = $self->get_proxy()->call("contig_ln",$genome,$contig); 
}

sub coupling_and_evidence {
    my($self,$fid,$bound,$sim_cutoff,$coup_cutoff) = @_;
    return my @results = $self->get_proxy()->call("coupling_and_evidence",$fid,$bound,$sim_cutoff,$coup_cutoff); 
}  

sub crude_estimate_of_distance {
    my($self,$genome1,$genome2) = @_;
    return my $result = $self->get_proxy()->call("crude_estimate_of_distance",$genome1,$genome2); 
}

sub displayable_reaction {
    my($self,$rid) = @_;
    return my $result = $self->get_proxy()->call("displayable_reaction",$rid); 
}

sub add_annotation {
    my($self,$feature_id,$user,$annotation) = @_;
    return my $result = $self->get_proxy()->call("add_annotation",$feature_id,$user,$annotation); 
}

sub add_chromosomal_clusters {
    my($self,$file) = @_;
    return my $result = $self->get_proxy()->call("add_chromosomal_clusters",$file); 
}

sub add_genome {
    my($self,$genomeF) = @_;
    return my $result = $self->get_proxy()->call("add_genome",$genomeF); 
}   
    
sub add_pch_pins {
    my($self,$file) = @_;
    return my $result = $self->get_proxy()->call("add_pch_pins",$file); 
}      

sub min {
    my($self,@x) = @_;
    return my $result = $self->get_proxy()->call("min",@x); 
}

sub all_roles {   
   my($self) = @_;
   return my @results = $self->get_proxy()->call("all_roles"); 
}

sub assign_function {
    my($self,$peg,$user,$function,$confidence) = @_;
    return my $result = $self->get_proxy()->call("assign_function",$peg,$user,$function,$confidence); 
}

sub assignments_made {
    my($self,$genomes,$who,$date) = @_;
    return my @results = $self->get_proxy()->call("assignments_made",$genomes,$who,$date); 
}

sub auto_assign {
    my($self,$peg,$seq) = @_;
    return my $result = $self->get_proxy()->call("auto_assign",$peg,$seq); 
    
}

sub between {
    my($self,$x,$y,$z) = @_;
    return my $result = $self->get_proxy()->call("between",$x,$y,$z); 
}

sub delete_genomes {
    my($self,$genomes) = @_;
    return my $result = $self->get_proxy()->call("delete_genomes",$genomes); 
}

sub dsims {
    my($self,$id,$seq,$maxN,$maxP,$select) = @_;
    return my @results = $self->get_proxy()->call("dsims",$id,$seq,$maxN,$maxP,$select); 
}

sub ec_to_maps {
    my($self,$ec) = @_;
    return my @results = $self->get_proxy()->call("ec_to_maps",$ec); 
}

sub ec_name {
    my($self,$ec) = @_;
    return my $result = $self->get_proxy()->call("ec_name",$ec); 
}

sub expand_ec {
    my($self,$ec) = @_;
    return my $result = $self->get_proxy()->call("expand_ec",$ec); 
}

sub epoch_to_readable {
    my($epoch) = @_;
    my($sec,$min,$hr,$dd,$mm,$yr) = localtime($epoch);
    $mm++;
    $yr += 1900;
    return "$mm-$dd-$yr:$hr:$min:$sec";
}

sub export_chromosomal_clusters {
    my($self) = @_;
    return my $result = $self->get_proxy()->call("expand_ec"); 
}

sub export_pch_pins {
    my($self) = @_;
    return my $result = $self->get_proxy()->call("export_pch_pins"); 
}

sub extract_seq {
    my($self,$contigs,$loc) = @_;
    return my $result = $self->get_proxy()->call("extract_seq",$contigs,$loc); 
}

sub all_exchangable_subsystems {
    my($self) = @_; 
    return my @results = $self->get_proxy()->call("all_exchangable_subsystems"); 
}
   
sub feature_aliases {
    my($self,$feature_id) = @_;
    return my @results = $self->get_proxy()->call("feature_aliases",$feature_id); 
}

sub feature_location {
    my($self,$feature_id) = @_;
    return my $result = $self->get_proxy()->call("feature_location",$feature_id); 
} 

sub file2N {
    my($self,$file) = @_;
    return my $result = $self->get_proxy()->call("file2N",$file); 
}   

sub ftype {
    my($self,$feature_id) = @_;
    return my $result = $self->get_proxy()->call("ftype",$feature_id);  
}

sub genes_in_region {
    my($self,$genome,$contig,$beg,$end) = @_;
    return my @results = $self->get_proxy()->call("genes_in_region",$genome,$contig,$beg,$end);  
}

sub blastit {
    my($self,$id,$seq,$db,$maxP) = @_;
    return my @results = $self->get_proxy()->call("blastit",$id,$seq,$db,$maxP);  
}

sub boundaries_of {
    my($self,$location) = (@_ == 1) ? $_[0] : $_[1];
    return my $result = $self->get_proxy()->call("boundaries_of",$location);  
}

sub build_tree_of_complete {
    my($self,$min_for_label) = @_;
    return my @results = $self->get_proxy()->call("build_tree_of_complete",$min_for_label);  
}

sub clean_tmp {
    my($self,$file);
    return my $result = $self->get_proxy()->call("clean_tmp",$file);  
}

sub hypo {
    my $x = (@_ == 1) ? $_[0] : $_[1];

    if (! $x)                             { return 1 }
    if ($x =~ /hypoth/i)                  { return 1 }
    if ($x =~ /conserved protein/i)       { return 1 }
    if ($x =~ /gene product/i)            { return 1 }
    if ($x =~ /interpro/i)                { return 1 }
    if ($x =~ /B[sl][lr]\d/i)             { return 1 }
    if ($x =~ /^U\d/)                     { return 1 }
    if ($x =~ /^orf/i)                    { return 1 }
    if ($x =~ /uncharacterized/i)         { return 1 }
    if ($x =~ /psedogene/i)               { return 1 }
    if ($x =~ /^predicted/i)              { return 1 }
    if ($x =~ /AGR_/)                     { return 1 }
    if ($x =~ /similar to/i)              { return 1 }
    if ($x =~ /similarity/i)              { return 1 }
    if ($x =~ /glimmer/i)                 { return 1 }
    if ($x =~ /unknown/i)                 { return 1 }
    return 0;
}

sub ids_in_family {
    my($self,$family) = @_;
    return my @results = $self->get_proxy()->call("ids_in_family",$family);   
}

sub ids_in_set {
    my($self,$which,$relation,$set_name) = @_;
    return my @results = $self->get_proxy()->call("ids_in_set",$which,$relation,$set_name);
}
 
sub in_cluster_with {
    my($self,$peg) = @_;
    return my @results = $self->get_proxy()->call("in_cluster_with",$peg);
}

sub in_family {
    my($self,$id) = @_;
    return my $result = $self->get_proxy()->call("in_family",$id);
}

sub in_pch_pin_with {
    my($self,$peg) = @_;
    return my @results = $self->get_proxy()->call("in_pch_with",$peg);
}

sub in_sets {
    my($self,$id,$relation,$set_name) = @_;
    return my @results = $self->get_proxy()->call("in_sets",$id,$relation,$set_name);
}

sub is_archaeal {
    my($self,$genome) = @_;
    return my $result = $self->get_proxy()->call("is_archaeal",$genome);
}

sub is_bacterial {
    my($self,$genome) = @_;
    return my $result = $self->get_proxy()->call("is_bacterial",$genome);
}

sub is_eukaryotic {
    my($self,$genome) = @_;
    return my $result = $self->get_proxy()->call("is_eukaryotic",$genome);
}

sub is_prokaryotic {
    my($self,$genome) = @_;
    return my $result = $self->get_proxy()->call("is_prokayotic",$genome);
}

sub is_exchangable_subsystem {
    my($self,$subsystem) = @_;
    return my $result = $self->get_proxy()->call("is_exchangable_subsystem",$subsystem);
}

sub is_real_feature {
    my($self,$fid) = @_;
    return my $result = $self->get_proxy()->call("is_real_feature",$fid);
}

sub largest_clusters {
    my($self,$roles,$user,$sort_by_unique_functions) = @_;
    return my @results = $self->get_proxy()->call("largest_clusters",$roles,$user,$sort_by_unique_functions);
}

sub load_all {
    my($self) = @_;
    $self->get_proxy()->call("load_all");
}

sub map_name {
    my($self,$map) = @_;
    return my $result = $self->get_proxy()->call("map_name",$map);
}

sub mapped_prot_ids {
    my($self,$id) = @_;
    return my @results = $self->get_proxy()->call("mapped_prot_ids",$id);
}

sub maps_to_id {
    my($self,$id) = @_;
    return my @results = $self->get_proxy()->call("maps_to_id",$id);
}

sub max {
    my($self,@x) = @_;
    return my $result = $self->get_proxy()->call("max",@x);
}

sub merged_related_annotations {
    my($self,$fids) = @_;
    return my @results = $self->get_proxy()->call("merged_related_annotations",$fids);
}

sub neighborhood_of_role {
    my($self,$role) = @_;
    return my @results = $self->get_proxy()->call("neighborhood_of_role",$role);
}

sub pegs_of {
    my($self,$genome) = @_;
    return my @results = $self->get_proxy()->call("pegs_of",$genome);
}

sub possibly_truncated {
    my($self,$feature_id) = @_;
    return my $result = $self->get_proxy()->call("possibly_truncated",$feature_id);
}

sub related_by_func_sim {
    my($self,$peg,$user) = @_;
    return my @results = $self->get_proxy()->call("related_by_func_sim",$peg,$user);
}

sub rnas_of {
    my($self,$genome) = @_;
    return my @results = $self->get_proxy()->call("rnas_of",$genome);
}

sub roles_of_function {
    my($self,$func) = @_;
    return my @results = $self->get_proxy()->call("roles_of_function",$func);
}

sub search_index {
    my($self,$pattern) = @_;
    return my @results = $self->get_proxy()->call("search_index",$pattern);
}

sub seqs_with_role {
    my($self,$role,$who,$genome) = @_;
    return my @results = $self->get_proxy()->call("seqs_with_role",$role,$who,$genome);
}

sub sims {
    my ($self,$id,$maxN,$maxP,$select,$max_expand) = @_;
    return my @results = $self->get_proxy()->call("sims",$id,$maxN,$maxP,$select,$max_expand);
}

sub sort_genomes_by_taxonomy {
    my($self,@genomes) = @_;
    return my @results = $self->get_proxy()->call("sort_genomes_by_taxonomy",@genomes);
}

sub sort_fids_by_taxonomy {
    my($self,@fids) = @_;
    return my @results = $self->get_proxy()->call("sort_fids_by_taxonomy",@fids);
}

sub taxonomic_groups_of_complete {
    my($self,$min_for_labels) = @_;
    return my @results = $self->get_proxy()->call("taxonomic_groups_of_complete",$min_for_labels);
}

sub taxonomy_of {
    my($self,$genome) = @_;
    return my $result = $self->get_proxy()->call("taxonomy_of",$genome);
}

sub translatable {
    my($self,$prot) = @_;
    return my $result = $self->get_proxy()->call("translatable",$prot);
}

sub translate_function {
    my($self,$function) = @_;
    return my $result = $self->get_proxy()->call("translate_function",$function);
}

sub translated_function_of {
    my($self,$id,$user) = @_;
    return my $result = $self->get_proxy()->call("translated_function_of",$id,$user);
}

sub translation_length {
    my($self,$fid) = @_;
    return my $result = $self->get_proxy()->call("translation_length",$fid);
}

sub unique_functions {
    my($self,$pegs,$user) = @_;
    return my @results = $self->get_proxy()->call("unique_functions",$pegs,$user);
}

sub verify_dir {
    my($self,$dir) = @_;
    return my $result = $self->get_proxy()->call("verify_dir",$dir);
}

sub reverse_comp {
    my($self,$seq) = @_;
    return my $result = $self->get_proxy()->call("reverse_comp",$seq);
}

sub rev_comp {
    my($self, $seqP ) = @_;
    return my $result = $self->get_proxy()->call("rev_comp",$seqP);
}

sub display_id_and_seq {
    my($self,$id, $seq, $fh ) = @_;
    return my $result = $self->get_proxy()->call("display_id_and_seq",$id,$seq,$fh);
}    

sub standard_genetic_code {
    
    my($self) = @_;
    
    my $code = {};

    $code->{"AAA"} = "K";
    $code->{"AAC"} = "N";
    $code->{"AAG"} = "K";
    $code->{"AAT"} = "N";
    $code->{"ACA"} = "T";
    $code->{"ACC"} = "T";
    $code->{"ACG"} = "T";
    $code->{"ACT"} = "T";
    $code->{"AGA"} = "R";
    $code->{"AGC"} = "S";
    $code->{"AGG"} = "R";
    $code->{"AGT"} = "S";
    $code->{"ATA"} = "I";
    $code->{"ATC"} = "I";
    $code->{"ATG"} = "M";
    $code->{"ATT"} = "I";
    $code->{"CAA"} = "Q";
    $code->{"CAC"} = "H";
    $code->{"CAG"} = "Q";
    $code->{"CAT"} = "H";
    $code->{"CCA"} = "P";
    $code->{"CCC"} = "P";
    $code->{"CCG"} = "P";
    $code->{"CCT"} = "P";
    $code->{"CGA"} = "R";
    $code->{"CGC"} = "R";
    $code->{"CGG"} = "R";
    $code->{"CGT"} = "R";
    $code->{"CTA"} = "L";
    $code->{"CTC"} = "L";
    $code->{"CTG"} = "L";
    $code->{"CTT"} = "L";
    $code->{"GAA"} = "E";
    $code->{"GAC"} = "D";
    $code->{"GAG"} = "E";
    $code->{"GAT"} = "D";
    $code->{"GCA"} = "A";
    $code->{"GCC"} = "A";
    $code->{"GCG"} = "A";
    $code->{"GCT"} = "A";
    $code->{"GGA"} = "G";
    $code->{"GGC"} = "G";
    $code->{"GGG"} = "G";
    $code->{"GGT"} = "G";
    $code->{"GTA"} = "V";
    $code->{"GTC"} = "V";
    $code->{"GTG"} = "V";
    $code->{"GTT"} = "V";
    $code->{"TAA"} = "*";
    $code->{"TAC"} = "Y";
    $code->{"TAG"} = "*";
    $code->{"TAT"} = "Y";
    $code->{"TCA"} = "S";
    $code->{"TCC"} = "S";
    $code->{"TCG"} = "S";
    $code->{"TCT"} = "S";
    $code->{"TGA"} = "*";
    $code->{"TGC"} = "C";
    $code->{"TGG"} = "W";
    $code->{"TGT"} = "C";
    $code->{"TTA"} = "L";
    $code->{"TTC"} = "F";
    $code->{"TTG"} = "L";
    $code->{"TTT"} = "F";
    
    return $code;
}
 
1
