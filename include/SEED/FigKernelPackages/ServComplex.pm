package ServComplex;

#
# This file is part of an application created with create-new-page.
# The implementation module is FigKernelPackages/ServComplex.pm.
# The SeedViewer page module is SeedViewer/WebPage/SV_ServComplex.pm.
# The CGI script is FigWebServices/serv_complex.cgi.
#
# The SeedViewer url is http://yourseed/seedviewer.cgi?page=SV_ServComplex
# The CGI url is http://yourseed/serv_complex.cgi
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

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj}; 



    my $title = "Complex Page";

    my @html = ();

    my @params = $cgi->param;
    push(@html,"<pre>\n");
    foreach $_ (@params)
    {
	push(@html,"$_\t:" . join(",",$cgi->param($_)) . ":\n");
    }
    push(@html,"</pre>\n",$cgi->hr);

    my $complex = $cgi->param('complex');
    if (! $complex)
    {
	push(@html,$cgi->h1('You need to specify a complex in the URL'));
    }
    else
    {
	push(@html,&show_complex($env,$complex));
    }
    my $html_txt = join("", @html);
    return($html_txt, $title);
}


sub show_complex {
    my ($env, $complex) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      


    my @html;

#    my $dataH = $sapO->complex_data( -ids => [$complex], -data => ['name','reactions','roles']);
    my $dataH  = &RC::complex_data($env,[$complex]);

    if ($dataH && ($dataH->{$complex}))
    {
	my($name,$roles,$reactions) = @{$dataH->{$complex}};
	$name = $name ? $name : 'unnamed complex';
	push(@html,$cgi->h3("$complex: $name"));
	if (@$roles > 0)
	{
	    push(@html,&RC::roles_in_complex($env,$complex),"<br>");
	}
	if (@$reactions)
	{
	    push(@html,&RC::complex_to_reactions($env,$complex),"<br>");
	}
    }
    else
    {
	push(@html,$cgi->h3("$complex may not be a valid context ID"));
    }
    return @html;
}

###############################################


1;
