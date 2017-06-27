package LinksUI;


use strict;
use HTML;
use Data::Dumper;
use URI::Escape;
use Carp;

my %link_lookup;
$link_lookup{"feature"}{"seedviewer"} = "seedviewer.cgi?page=SeedViewerServeFeature";
$link_lookup{"feature"}{"cgi"} = "serv_feature.cgi?";
$link_lookup{"genome"}{"seedviewer"} = "seedviewer.cgi?page=SV_ServGenome";
$link_lookup{"genome"}{"cgi"} = "serv_genome.cgi?";
$link_lookup{"role"}{"seedviewer"} = "seedviewer.cgi?page=SV_ServRole";
$link_lookup{"role"}{"cgi"} = "serv_role.cgi?";
$link_lookup{"reaction"}{"seedviewer"} = "seedviewer.cgi?page=SV_ServReaction";
$link_lookup{"reaction"}{"cgi"} = "serv_reaction.cgi?";
$link_lookup{"FIGfam"}{"seedviewer"} = "seedviewer.cgi?page=SV_ServFIGfam";
$link_lookup{"FIGfam"}{"cgi"} = "serv_FIGfam.cgi?";
$link_lookup{"complex"}{"seedviewer"} = "seedviewer.cgi?page=SV_ServComplex";
$link_lookup{"complex"}{"cgi"} = "serv_complex.cgi?";
$link_lookup{"subsysRow"}{"seedviewer"} = "seedviewer.cgi?page=SV_ServSubsysRow";
$link_lookup{"subsysRow"}{"cgi"} = "serv_subsysRow.cgi?";
$link_lookup{"otu"}{"seedviewer"} = "seedviewer.cgi?page=SV_ServOTU";
$link_lookup{"otu"}{"cgi"} = "serv_otu.cgi?";

sub genome_link {
    my ($env, $genome) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    &set_url(\$url,'genome', $seedviewer_page_obj);
    my $link = $url . "&genome=$genome";
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">$genome</a>";
}

sub genome_validate_link {
    my ($env, $genome) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $code = $env->{genetic_code};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
    &set_url(\$url,'genome', $seedviewer_page_obj);
    my $link = $url . "&genome=$genome&validate=1&genetic_code=$code";
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">Validate Translations for $genome</a>";
}

sub otu_link {
    my ($env, $otu_rep) = @_;
    
    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    &set_url(\$url,'otu', $seedviewer_page_obj);
    my $link = $url . "&otu=$otu_rep";
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">$otu_rep</a>";
}

sub subsystems_for_genome_link {
    my ($env, $genome) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    &set_url(\$url,'genome', $seedviewer_page_obj);
    my $link = $url . "&genome=$genome&show_subsys=1";
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">Show Subsystems for $genome</a>";
}

sub id_link {    #### THis needs a bunch of special cases
    my ($env, $id) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    if ($id =~ /^fig\|\d+\.\d+\.peg\.\d+$/) { return &peg_link($env,$id) }
    return $id;
}

sub peg_link {
    my ($env, $peg) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    &set_url(\$url,'feature', $seedviewer_page_obj);
    my $link = $url . "&fid=" . &uri_escape($peg);
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">$peg</a>";
}

sub peg_prot_link {
    my($env,$peg) = @_;

    my $peg_link = &peg_link($env,$peg);
    $peg_link =~ s/\&fid=/&show_prot_sequence=1&fid=/;
    return $peg_link;
}

sub find_gene_link {
    my ($env, $peg, $genome) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    my $link = "http://pubseed.theseed.org/seedviewer.cgi?page=SearchGeneByFeature&template_gene=$peg&organism=$genome&SUBMIT=1";
    return "<a target='_blank' href=\"$link\">Find this gene in an organism</a>";
}
sub peg_links {
    my ($env, $pegs) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    &set_url(\$url,'feature', $seedviewer_page_obj);
    return join("<br>",map { &peg_link($env,$_,) } @$pegs);
}

sub trees_link {
    my ($env, $peg, $n) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    my $link = "http://pubseed.theseed.org/seedviewer.cgi?page=AlignTreeViewer&fid=$peg";
    return "<a target='_blank' href=\"$link\">$n Trees</a>";
}

sub compare_regions_link {
    my ($env, $peg) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    my $link = "http://pubseed.theseed.org/seedviewer.cgi?page=Annotation&feature=$peg";
    return "<a target='_blank' href=\"$link\">Compare Regions</a>";
}


sub ec_link {
    my ($env, $ec) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};


    my $link = "http://www.genome.jp/dbget-bin/www_bget?ec:$ec";
    return "<a target='_blank' href=\"$link\">$ec</a>";
}

sub cdd_link {
    my ($env, $fid) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

#   my $seqH = $sapO->ids_to_sequences( -ids => [$fid], -fasta => 0, -protein => 1 );
    my $seqH = &RC::ids_to_sequences($env,[$fid],0,1);

    my $seq = $seqH->{$fid};
    my $plink = &uri_escape(">$fid\n$seq");
    my $structure_link = "<a target='_blank' href='http://www.ncbi.nlm.nih.gov/Structure/cdd/wrpsb.cgi?SEQUENCE=$plink&FULL'>CDD</a>";
    return $structure_link;
}

sub show_dna_link {
    my ($env, $fid, $len) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      

    &set_url(\$url,'feature', $seedviewer_page_obj);
    my $link = $url . "&fid=" . &uri_escape($fid) . '&show_dna_sequence=1';
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">Show DNA sequence ($len bp)</a>";
}

sub show_prot_link {
    my ($env, $fid, $aa) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      

    &set_url(\$url,'feature', $seedviewer_page_obj);
    my $link = $url . "&fid=" . &uri_escape($fid) . '&show_prot_sequence=1';
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">Show protein sequence ($aa aa)</a>";
}

sub add_comment_to_peg_link {
    my ($env, $peg) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      

    &set_url(\$url,'feature', $seedviewer_page_obj);
    my $link = $url . "&fid=" . &uri_escape($peg) . '&add_comment=1';
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">Add comment/annotation to $peg</a>";
}
 
sub show_comments_on_peg_link {
    my ($env, $peg) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      

    &set_url(\$url,'feature', $seedviewer_page_obj);
    my $link = $url . "&fid=" . &uri_escape($peg) . '&show_comments=1';
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">Show comments/annotations attached to $peg</a>";
}
 
sub show_history_of_assignments_link {
    my ($env, $peg, $func) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      

    &set_url(\$url,'feature', $seedviewer_page_obj);
    my $link = $url . "&fid=" . &uri_escape($peg) . '&show_history_of_assignments=1&function=' . &uri_escape($func);
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">Show history of related assignments</a>";
}
 
sub dlit_links {
    my($dlits) = @_;

    if ($dlits && (@$dlits > 0))
    {
	join(",",map { &dlit_link($_)} @$dlits);
    }
    else 
    {
	return '';
    }
}

sub dlit_link {
    my($dlit) = @_;

    my $link = "http://www.ncbi.nlm.nih.gov/pubmed/?term=$dlit";
    return "<a target='_blank' href=\"$link\">$dlit</a>";
}

sub inconsistent_annotations_link {
    my ($env, $fid) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      

    &set_url(\$url,'feature', $seedviewer_page_obj);
    my $link = $url . "&fid=" . &uri_escape($fid) . '&inconsistent_annotations=1';
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">Show inconsistent annotations</a>";
}

sub other_annotations_link {
    my ($env, $fid) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      

    &set_url(\$url,'feature', $seedviewer_page_obj);
    my $link = $url . "&fid=" . &uri_escape($fid) . '&other_annotations=1';
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">Show other annotations</a>";
}

sub expand_links_to_equiv_prots {
    my ($env, $fid, $source, $function) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      
    &set_url(\$url,'feature', $seedviewer_page_obj);
    my $link = $url . "&fid=" . &uri_escape($fid) . 
	       "&expand_other_annotations=1&source=$source&function=" . 
	       &uri_escape($function);
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">$source</a>";
}

sub figfams_link {
    my ($env, $ffs) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      

    if ($ffs && (@$ffs > 0))
    {
	return join(",",map { &ff_link($env,$_)} @$ffs);
    }
    else 
    {
	return '';
    }
}

sub ff_link {
    my ($env, $ff) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      
    &set_url(\$url,'FIGfam', $seedviewer_page_obj);
    my $link = $url . "&FIGfam=$ff";
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">$ff</a>";
}

sub show_FIGfam_link {
    my ($env, $ff) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      
    &set_url(\$url,'FIGfam', $seedviewer_page_obj);
    my $link = $url . "&FIGfam=$ff&show_figfam=1";
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">PEGs in FIGfam</a>";
}

sub show_fc_FIGfam_link {
    my ($env, $ff) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      
    &set_url(\$url,'FIGfam', $seedviewer_page_obj);
    my $link = $url . "&FIGfam=$ff&show_coupled_figfams=1";
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">Functionally-coupled FIGfams</a>";
}

sub show_ar_link {
    my ($env, $fid, $ar, $title) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      
    &set_url(\$url,'feature', $seedviewer_page_obj);
    my($ar_id,$sz) = @$ar;
    my $link = $url . "&fid=" . &uri_escape($fid) . '&show_ar=1&ar=' . &uri_escape($ar_id);
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">Show Atomic Regulon of size $sz</a>";
}

sub reaction_links {
    my ($env, $reactions) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      

    if (@$reactions > 0)
    {
	return join(",",map { &reaction_link($env,$_)} @$reactions);
    }
    else 
    {
	return '';
    }
}

sub reaction_link {
    my ($env, $reaction) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      
    &set_url(\$url,'reaction', $seedviewer_page_obj);
    my $link = $url . "&reaction=$reaction";
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">$reaction</a>";
}


sub complex_link {
    my ($env, $complex) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      
    &set_url(\$url,'complex', $seedviewer_page_obj);
    my $link = $url . "&complex=$complex";
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">$complex</a>";
}

sub subsys_row_link {
    my ($env, $g, $ss) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      
    &set_url(\$url,'subsysRow', $seedviewer_page_obj);
    $ss =~ s/ /_/g;
    my $link = $url . "&genome=" . &uri_escape($g) . '&ss=' . &uri_escape($ss);
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">$ss</a>";
}

sub show_regulons_link {
    my($env,$fid,$text) = @_;
    my $url = $env->{url};
    my $link = $url . "&fid=" . &uri_escape($fid) . '&show_regulons=1';
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">$text</a>";
}

sub role_link {
    my ($env, $role) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      
    &set_url(\$url,'role', $seedviewer_page_obj);
    my $link = $url . "&role=" . &uri_escape($role);
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">$role</a>";
}

#
sub find_candidates_for_role_link {
    my ($env, $g, $other_peg) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      


    my $link = "http://pubseed.theseed.org/seedviewer.cgi?page=SearchGeneByFeature&template_gene=$other_peg&organism=$g&SUBMIT=1";
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">find candidates</a>";
}
    
sub subsystem_link {
    my ($env, $ss) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      

    $ss =~ s/_/ /g;
    my $link = "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowSubsystem&subsystem=" . &uri_escape($ss);
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">$ss</a>";
}

sub set_url {
    my($urlP,$entity, $seedviewer_page_obj) = @_;
    my $svi = $seedviewer_page_obj ? "seedviewer":"cgi"; 
    if ($link_lookup{$entity}{$svi}) {
	    $$urlP  = $link_lookup{$entity}{$svi};
    } 
    else 
    {
	$$urlP =~ s/_([^_]*)\.cgi/_$entity.cgi/;
    }
}

sub assign_link {
    my ($env, $func,$peg) = @_;

    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    my $user = $env->{'user'};
    if (! $user) { return "" }
    &set_url(\$url,'feature', $seedviewer_page_obj);
    my $link = $url . "&user=$user&fid=" . uri_escape($peg) . "&assign=1&function=" . uri_escape($func);
    $link .= "&kb=1" if $env->{kbase};
    return "<a target='_blank' href=\"$link\">assign</a>";
}

1;
