package ServSubsysRow;

#
# This file is part of an application created with create-new-page.
# The implementation module is FigKernelPackages/ServSubsysRow.pm.
# The SeedViewer page module is SeedViewer/WebPage/SV_ServSubsysRow.pm.
# The CGI script is FigWebServices/serv_subsysRow.cgi.
#
# The SeedViewer url is http://yourseed/seedviewer.cgi?page=SV_ServSubsysRow
# The CGI url is http://yourseed/serv_subsysRow.cgi
#


use strict;
use HTML;
use Data::Dumper;
use Data::Dumper;
use LinksUI;
use RC;
use URI::Escape;


my($fig, $cgi, $sapO, $user, $url, $hidden_form_var, $seedviewer_page_obj);

sub run
{
#    ($fig, $cgi, $sapO, $user, $url, $hidden_form_var, $seedviewer_page_obj) = @_;
    my ($env) = @_;

    $fig = $env->{fig};
    $cgi = $env->{cgi};
    $sapO = $env->{sap};
    $user = $env->{user};
    $url = $env->{url};
    $hidden_form_var = $env->{hidden_form_var};
    $seedviewer_page_obj = $env->{seedviewer_page_obj}; 

    my $title = "Subsystem Row Page";

    my @html = ();

    my @params = $cgi->param;
    push(@html,"<pre>\n");
    foreach $_ (@params)
    {
	push(@html,"$_\t:" . join(",",$cgi->param($_)) . ":\n");
    }
    push(@html,"</pre>\n",$cgi->hr);

    my $g = $cgi->param('genome');
    my $ss  = $cgi->param('ss');
    if (! $g)
    {
	push(@html,$cgi->h1('You need to specify a genome in the URL'));
    }
    elsif (! $ss)
    {
	push(@html,$cgi->h1('You need to specify a subsystem (ss) in the URL'));
    }
    else
    {
	push(@html,&ss_row($env,$g,$ss));
    }
    my $html_txt = join("", @html);
    return($html_txt, $title);
}

sub ss_row {
    my ($env, $g, $ss) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      


    my @html;
    $ss =~ s/_/ /g;
#   my $rowH          =  $sapO->pegs_in_variants( -subsystems => [$ss], -genomes => [$g] );
    my $rowH          = &RC::subsystems_to_spreadsheets($env,[$ss],[$g]);
    $rowH             = $rowH->{$ss}->{$g};
    my $normalized_ss = $ss;
    $normalized_ss =~ s/_/ /g;
    if (! $rowH)
    {
	push(@html,$cgi->h3("It appears that $g is not in $normalized_ss"));
    }
    else
    {
	my %seen;
	my $col_hdrs = ['PEG','Role'];
	my $tab      = [];
	my $variant = shift @$rowH;
	foreach my $role_tuple (sort { &SeedUtils::by_fig_id($a->[1],$b->[1]) } @$rowH)
	{
	    my $role = shift @$role_tuple;
	    foreach my $peg (sort @$role_tuple)
	    {
		$seen{$role} = 1;
		push(@$tab,[&LinksUI::peg_link($env,$peg),$role]);
	    }
	}
	my @tab = sort { $a->[1] cmp $b->[1] } @$tab;
	push(@html,&HTML::make_table($col_hdrs,\@tab,"Variant $variant of $normalized_ss"));
#	my $roleH = $sapO->subsystem_roles( -ids => [$normalized_ss]);
	my $roleH = &RC::subsystems_to_roles($env,[$normalized_ss],0);

	my $all = $roleH->{$normalized_ss};
	my @missed = sort grep { ! $seen{$_} } @$all;
	if (@missed > 0)
	{
	    push(@html,$cgi->hr);
	    push(@html,&HTML::make_table(['Role','Find Candidates'],
					 [map { [$_,&LinksUI::find_candidates_for_role_link($env,$g,$_)] } @missed],
					 "Roles in $normalized_ss but not in $g"));
	}
    }
    return @html;
}

1;
