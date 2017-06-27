package ServFIGfam;

#
# This file is part of an application created with create-new-page.
# The implementation module is FigKernelPackages/ServFIGfam.pm.
# The SeedViewer page module is SeedViewer/WebPage/SV_ServFIGfam.pm.
# The CGI script is FigWebServices/serv_FIGfam.cgi.
#
# The SeedViewer url is http://yourseed/seedviewer.cgi?page=SV_ServFIGfam
# The CGI url is http://yourseed/serv_FIGfam.cgi
#


use strict;
use HTML;
use Data::Dumper;
use Data::Dumper;
use LinksUI;
use RC;
use URI::Escape;


sub run
{
    my ($env) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj}; 

    my $title = "FIGfam Page";

    my @html = ();

    my @params = $cgi->param;
    push(@html,"<pre>\n");
    foreach $_ (@params)
    {
	push(@html,"$_\t:" . join(",",$cgi->param($_)) . ":\n");
    }
    push(@html,"</pre>\n",$cgi->hr);

    my $ff = $cgi->param('FIGfam');
    if (! $ff)
    {
	push(@html,$cgi->h1('You need to specify a FIGfam id in the URL'));
    }
    if ($cgi->param('show_figfam'))
    {
	push(@html,&RC::show_FIGfam($env,$ff));
    }
    elsif ($cgi->param('show_coupled_figfams'))
    {
	push(@html,&RC::show_fc_FIGfams($env,$ff));
    }
    else
    {
#	my $funcH = $sapO->figfam_function( -ids => [$ff] );
	my $funcH = &RC::protein_families_to_functions($env,[$ff]);
	push(@html,$cgi->h3("$ff: $funcH->{$ff}"),"<br>");
	push(@html,&LinksUI::show_FIGfam_link($env,$ff),"<br>");
	push(@html,&LinksUI::show_fc_FIGfam_link($env,$ff),"<br>");
    }

    my $html_txt = join("", @html);
    return($html_txt, $title);
}    
1;
