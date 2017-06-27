package ServFeature;

#
# This file is part of an application created with create-new-page.
# The implementation module is FigKernelPackages/ServFeature.pm.
# The SeedViewer page module is SeedViewer/WebPage/SeedViewerServeFeature.pm.
# The CGI script is FigWebServices/serv_feature.cgi.
#
# The SeedViewer url is http://yourseed/seedviewer.cgi?page=SeedViewerServeFeature
# The CGI url is http://yourseed/serv_feature.cgi
#

use strict;
use HTML;
use Data::Dumper;
use LinksUI;
use RC;
use URI::Escape;

sub run
{
    my ($env) = @_;

    my $fig     = $env->{fig};
    my $cgi     = $env->{cgi};
    my $sapO    = $env->{sap};
    my $sapdb   = $env->{sapdb};
    my $user    = $env->{user};
    my $url     = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj}; 
    my $title = "Feature Page";

    my @html = ();

    my @params = $cgi->param;
    push(@html,"<pre>\n");
    foreach $_ (@params)
    {
	push(@html,"$_\t:" . join(",",$cgi->param($_)) . ":\n");
    }
    push(@html,"</pre>\n",$cgi->hr);

    my $fid = $cgi->param('fid');
    if ((! $fid) && 
	(! $cgi->param('Make projections consistent')) &&
	(! $cgi->param('Make identical consistent')))
    {
	push(@html,$cgi->h1('You need to specify a feature id (fid) in the URL'));
    }
    elsif ($cgi->param('assign') && (my $func = $cgi->param('function')))
    {
	push(@html,&RC::assign_function($env,$func,$fid));
    }
    elsif ($cgi->param('Close Sims'))
    {
	push(@html,&RC::similarities_for_fid($env,$fid));
    }
    elsif ($cgi->param('show_regulons'))
    {
	push(@html,&RC::show_regulons_for_fid($env,$fid));
    }
    elsif ($cgi->param('NCBI Blast') && (my $seq = $cgi->param('seq')))
    {
	push(@html,&RC::get_blast_results($env,$seq));
    }
    elsif ($cgi->param('Change Function'))
    {
	my $new_func = $cgi->param('new_function');
	if (! $new_func)
	{
	    push(@html,$cgi->h1('You need to specify a function'));
	}
	else
	{
	    push(@html,&RC::assign_function($env,$new_func,($fid)));
	    push(@html,&show_feature($env, $fid));
	}
    }
    elsif ($cgi->param('Add Pubmed IDs'))
    {
	my $pmid = $cgi->param('pmid');
	if (! $pmid)
	{
	    push(@html,$cgi->h1('You need to specify a PubMed ID'));
	}
	else
	{
	    push(@html,&RC::record_pmid($env,$fid,$pmid));
	    push(@html,&show_feature($env, $fid));
	}
    }
    elsif ($cgi->param('other_annotations'))
    {
	push(@html,&RC::other_annotations_for_fid($env,$fid));
    }
    elsif ($cgi->param('expand_other_annotations'))
    {
	push(@html,&RC::expand_other_annotations_for_fid($env,$fid,
							 $cgi->param('source'),
							 $cgi->param('function')));
    }
    elsif ($cgi->param('inconsistent_annotations'))
    {
	push(@html,&RC::inconsistent_annotations_for_fid($env,$fid));
    }
    elsif ($cgi->param('Make identical consistent'))
    {
	my $to_change = $cgi->param('to_change');
	my $new_func      = $cgi->param('func');
	if ($to_change && $new_func)
	{
	    my @pegs = split(/:/,$to_change);
	    if ($cgi->param('check for duplicates'))
	    {
		@pegs = &RC::check_dups($env,\@pegs,$new_func);
	    }
	    push(@html,&RC::assign_function($env,$new_func,@pegs));
	}
    }
    elsif ($cgi->param('Make projections consistent'))
    {
	my $to_change     = $cgi->param('to_change');
	my $new_func      = $cgi->param('func');
	if ($to_change && $new_func)
	{
	    my @pegs = split(/:/,$to_change);
	    if ($cgi->param('check for duplicates'))
	    {
		@pegs = &RC::check_dups($env,\@pegs,$new_func);
	    }
	    push(@html,&RC::assign_function($env,$new_func,@pegs));
	}
    }
    elsif ($cgi->param('show_comments'))
    {
	push(@html,&RC::comments_for_fid($env,$fid));
    }
    elsif ($cgi->param('show_history_of_assignments'))
    {
	push(@html,&RC::history_of_assignments($env,$fid));
    }
    elsif ($cgi->param('add_comment'))
    {
	push(@html,$cgi->start_form(-action => $url),
	           $cgi->h1("Attach a Comment to $fid"),
	           $cgi->textarea(-name => 'anno', -rows => 20, -cols => 80, -override => 1),'<br><br>',
	           $cgi->submit('Add a Comment'),
	           $hidden_form_var,
	           $cgi->hidden(-name => 'fid', -value => $fid),
	           $cgi->hidden(-name => 'user', -value => $user),
	           $cgi->end_form);
    }
    elsif ($cgi->param('Add a Comment'))
    {
	my $anno = $cgi->param('anno');
	if (! $anno)
	{
	    push(@html,$cgi->h1('You need to supply an annotation to add'));
	}
	else
	{
	    push(@html,&RC::make_annotation($env,$fid,$anno));
	    push(@html,&show_feature($env, $fid));
	}
    }
    elsif ($cgi->param('show_dna_sequence'))
    {
	push(@html,&RC::show_dna_sequence_of_fid($env,$fid));
    }
    elsif ($cgi->param('show_prot_sequence'))
    {
	push(@html,&RC::show_prot_sequence_of_fid($env,$fid));
    }
    elsif ($cgi->param('show_ar'))
    {
	my $ar = $cgi->param('ar');
	if (! $ar)
	{
	    push(@html,$cgi->h2("You need to specify an atomic regulon ID in the 'ar' parameter"));
	}
	else
	{
	    push(@html,&RC::show_ar($env,$ar,$fid));
	}
    }
    else
    {
	push(@html,&show_feature($env, $fid));
    }
    my $html_txt = join("", @html);
    return($html_txt, $title);
}


sub show_feature {
    my ($env, $fid) = @_;

    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};

    my $html        = [];
#    my $dataH       = $sapO->ids_to_data( -ids => [$fid], -data => ['genome-name','function','length','location']);
    my $dataH        = &RC::fids_to_feature_data($env,[$fid]);
    if ($dataH && ($_ = $dataH->{$fid}))
    {
	my $genome_name = $_->{genome_name};
	my $function    = $_->{feature_function};
	my $dna_len     = $_->{feature_length};
	my $loc         = $_->{feature_location};
	my $type_fid    = &RC::type_of_feature($env,$fid);

	my $prot_len    = ($dna_len && ($type_fid eq "peg")) ? int($dna_len/3) : 0;
#	my $ffH         = $sapO->ids_to_figfams( -ids => [$fid] );
	my $ffH         = &RC::fids_to_figfams($env,[$fid]);
	my $ffs  = $ffH->{$fid};
	push(@$html, &layout($env,
			     { fid          => $fid,
			       location     => $loc,
			       user         => $user,
			       genome_name  => $genome_name,
			       function     => $function,
			       dna_len      => $dna_len,
			       prot_len     => $prot_len,
			       figfams      => $ffs
			       })
	     );
    }
    else
    {
	push(@$html,$cgi->h3("$fid does not appear to be real"));
    }
    return @$html;
}

sub layout {
    my($env,$args) = @_;
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $sapdb = $env->{sapdb};
    my $url = $env->{url};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj}; 
    my $hidden_form_var = $env->{hidden_form_var};
    my $html     = [];
    my $fid      = $args->{fid};
    my $location = $args->{location};
    my $type_fid = &RC::type_of_feature($env,$fid);
    my $func     = $args->{function};
    my $ffs      = $args->{figfams};
    my $user     = $args->{user};
    my $g        = $args->{genome_name};
    my $func_with_links = &RC::set_ec_links($env,$func);
    push(@$html,$cgi->h3("$fid: $func_with_links"));
    my $glink = &LinksUI::genome_link($env,&RC::genome_of($env,$fid));
    push(@$html,$cgi->h3("$glink: $g"));
    push(@$html,$cgi->h3("location: $location"));
    
    if ($sapdb) {
	push(@$html,$cgi->start_form(-action => $url),
	            $cgi->submit('Change Function'),
	            $cgi->textfield(-name => 'new_function', -size => 80, -override => 1),
	            '<br>',
	            $cgi->hidden(-name => 'fid', -value => $fid),
	            $cgi->hidden(-name => 'user', -value => $user),
	            $hidden_form_var,
	            $cgi->end_form);
    }

#     my $dlitH = $sapO->dlits_for_ids( -ids => [$fid] );
    my $dlitH   = &RC::dlits_for_ids($env,[$fid]);
    my $dlits = $dlitH->{$fid};
    if ($dlits) 
    {
	push(@$html,(@$dlits == 1) ? "Dlit: " : "Dlits: ");
	push(@$html,&LinksUI::dlit_links($dlits, $seedviewer_page_obj),"<br>");
    }
    
    if ($sapdb) {
	push(@$html,$cgi->start_form(-action => $url),
	            $cgi->submit('Add Pubmed IDs'),$cgi->textfield(-name => 'pmid', -size => 30, -override => 1),'<br>',
	            $hidden_form_var,
	            $cgi->hidden(-name => 'fid', -value => $fid),
	            $cgi->hidden(-name => 'user', -value => $user),
	            $cgi->end_form);
    }

    if (! $env->{kbase})
    {
	push(@$html,&LinksUI::find_gene_link($env,$fid, &SeedUtils::genome_of($fid)),"<br>");
	push(@$html,&LinksUI::compare_regions_link($env,$fid),"<br>");
	if ($_ = &RC::trees_exist($fid))
	{
	    push(@$html,&LinksUI::trees_link($env,$fid,$_),"<br>");
	}
    }
    my $prot_len = $args->{prot_len};

    if ($prot_len)
    {
	my $ar = &RC::in_atomic_regulon($env,$fid);
	if ($ar)
	{
	    push(@$html,&LinksUI::show_ar_link($env,$fid,$ar,"Show atomic regulon of size $ar->[1]"),"<br>");
	}
	my $regulons = &RC::in_regulons($env,$fid);

	if ($regulons)
	{
	    my $n = @$regulons;
	    push(@$html,&LinksUI::show_regulons_link($env,$fid,"Show $n regulon(s) containing"),"<br>");
	}

	push(@$html,&LinksUI::show_prot_link($env,$fid,$prot_len),"<br>");
	push(@$html,&LinksUI::cdd_link($env,$fid),"<br>");
	if ($ffs) 
	{
	    push(@$html,(@$ffs == 1) ? "FIGfam: " : "FIGfams: ");
	    push(@$html,&LinksUI::figfams_link($env,$ffs),"<br>");
	}
	push(@$html,&LinksUI::other_annotations_link($env,$fid),"<br>");
	push(@$html,&LinksUI::inconsistent_annotations_link($env,$fid),"<br>");
    }
    push(@$html,&LinksUI::show_dna_link($env,$fid,$args->{dna_len}),"<br>");

    if ($sapdb) {
	push(@$html,&LinksUI::add_comment_to_peg_link($env,$fid),"<br>");
    }
    push(@$html,&LinksUI::show_comments_on_peg_link($env,$fid),"<br>");
    push(@$html,&LinksUI::show_history_of_assignments_link($env,$fid,$func),"<br><br>");
    if ($prot_len)
    {
	push(@$html,&RC::show_subsys_for_fid($env,$fid),"<br>");
	push(@$html,&RC::show_fc_for_fid($env,$fid),"<br>","<br>");
    }
    return @$html;
}
###########################

1;
