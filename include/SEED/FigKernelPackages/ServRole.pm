package ServRole;

#
# This file is part of an application created with create-new-page.
# The implementation module is FigKernelPackages/ServRole.pm.
# The SeedViewer page module is SeedViewer/WebPage/SV_ServRole.pm.
# The CGI script is FigWebServices/serv_role.cgi.
#
# The SeedViewer url is http://yourseed/seedviewer.cgi?page=SV_ServRole
# The CGI url is http://yourseed/serv_role.cgi
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

    my $title = "Role Page";

    my @html = ();

    my @params = $cgi->param;
    push(@html,"<pre>\n");
    foreach $_ (@params)
    {
	push(@html,"$_\t:" . join(",",$cgi->param($_)) . ":\n");
    }
    push(@html,"</pre>\n",$cgi->hr);
    my $role = $cgi->param('role');
    if (! $role)
    {
	push(@html,$cgi->h1('You need to specify a role in the URL'));
    }
    else
    {
	push(@html,&RC::subsystems_containing_role($env,$role));
	push(@html,&RC::role_to_reactions($env,$role));
	push(@html,&RC::role_to_FIGfams($env,$role));
    }
    my $html_txt = join("", @html);
    return($html_txt, $title);
}

    
1;
