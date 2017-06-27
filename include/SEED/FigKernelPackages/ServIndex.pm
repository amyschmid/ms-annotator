package ServIndex;

#
# This file is part of an application created with create-new-page.
# The implementation module is FigKernelPackages/ServIndex.pm.
# The SeedViewer page module is SeedViewer/WebPage/SVServIndex.pm.
# The CGI script is FigWebServices/serv_index.cgi.
#
# The SeedViewer url is http://yourseed/seedviewer.cgi?page=SVServIndex
# The CGI url is http://yourseed/serv_index.cgi
#


use strict;
use HTML;
use Data::Dumper;
use Data::Dumper;
use LinksUI;
use RC;
use URI::Escape;

our %column_order = (Feature   => [qw(kbid function genome_name)],
		     Genome    => [qw(kbid scientific_name source_id)],
		     Role      => [qw(kbid description)],
		     Contig    => [qw(kbid)],
		     Subsystem => [qw(kbid name curator)]);

our %format_kbid = (Feature   => \&LinksUI::peg_link,
		    Genome    => \&LinksUI::genome_link,
#		    Role      => \&
#		    Contig    => \&format_contig_id,
		    Subsystem => \&LinksUI::subsystem_link);

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

    show_search_form($env, \@html);
    if ($cgi->param("do_search"))
    {
	perform_search($env, \@html);
    }

    my $title = "default  title";

    my $html_txt = join("", @html);
    return($html_txt, $title);
}

sub perform_search
{
    my($env, $html) = @_;
    my $cgi     = $env->{cgi};
    my $url     = $env->{url};
    my $kbase   = $env->{kbase};
    my $hidden_form_var = $env->{hidden_form_var};

    my $term = $cgi->param('search_string');
    my $res = $kbase->text_search($term, 0, 40, []);

    for my $entity (keys %$res)
    {
	show_entity_results($env, $html, $entity, $res->{$entity});
    }
}

sub show_entity_results
{
    my($env, $html, $entity, $hits) = @_;
    my $cgi     = $env->{cgi};

    my @keys = @{$column_order{$entity}};
    my @table;
    my $format_id = $format_kbid{$entity};
    for my $hit (@$hits)
    {
	my($weight, $fields) = @$hit;

	if ($format_id)
	{
	    my $id = &$format_id($env, $fields->{kbid});
	    $fields->{kbid} = $id;
	}
	
	push(@table, [@$fields{@keys}]);
    }
    push(@$html, &HTML::make_table(\@keys, \@table, "Hits for $entity"));
}

sub show_search_form
{
    my($env, $html) = @_;
    my $cgi     = $env->{cgi};
    my $url     = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};

    push(@$html, $cgi->start_form(-action => $url),
	 $cgi->hidden(-name => 'kb', -value => 1),
	 $cgi->h1("Search KBase"),
	 $cgi->textfield(-name => 'search_string', -size => 80),
	 '<br>',
	 $cgi->submit(-name => 'do_search', -value => 'Search'),
	 $hidden_form_var,
	 $cgi->end_form);
}

1;
