package ServReaction;

#
# This file is part of an application created with create-new-page.
# The implementation module is FigKernelPackages/ServReaction.pm.
# The SeedViewer page module is SeedViewer/WebPage/SV_ServReaction.pm.
# The CGI script is FigWebServices/serv_reaction.cgi.
#
# The SeedViewer url is http://yourseed/seedviewer.cgi?page=SV_ServReaction
# The CGI url is http://yourseed/serv_reaction.cgi
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

    my $title = "Reaction Page";

    my @html = ();

    my @params = $cgi->param;
    push(@html,"<pre>\n");
    foreach $_ (@params)
    {
	push(@html,"$_\t:" . join(",",$cgi->param($_)) . ":\n");
    }
    push(@html,"</pre>\n",$cgi->hr);

    my $reaction = $cgi->param('reaction');
    if (! $reaction)
    {
	push(@html,$cgi->h1('You need to specify a reaction in the URL'));
    }
    else
    {
	push(@html,&show_reaction($env,$reaction));
    }
    my $html_txt = join("", @html);
    return($html_txt, $title);
}


sub show_reaction {
    my ($env, $reaction) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      


    my @html;
#   my $reactH   = $sapO->reaction_strings( -ids => [$reaction], -names => 'only');
    my $reactH   = &RC::reaction_strings($env,[$reaction],'only');

    my $react    = $reactH->{$reaction};
    push(@html,$cgi->h2("reaction: $reaction"),$cgi->h3($react));
    push(@html,&RC::complexes_for_reaction($env,$reaction));
    return @html;
}
1;
