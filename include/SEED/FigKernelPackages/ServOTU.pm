package ServOTU;

#
# This file is part of an application created with create-new-page.
# The implementation module is FigKernelPackages/ServOTU.pm.
# The SeedViewer page module is SeedViewer/WebPage/SeedViewerServeOTU.pm.
# The CGI script is FigWebServices/serv_feature.cgi.
#
# The SeedViewer url is http://yourseed/seedviewer.cgi?page=SeedViewerServeOTU
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

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my  $seedviewer_page_obj = $env->{seedviewer_page_obj}; 




    my $title = "OTU Page";

    my @html = ();

    my @params = $cgi->param;
    push(@html,"<pre>\n");
    foreach $_ (@params)
    {
	push(@html,"$_\t:" . join(",",$cgi->param($_)) . ":\n");
    }
    push(@html,"</pre>\n",$cgi->hr);

    my $otu = $cgi->param('otu');
    if ((! $otu) && 
	(! $cgi->param('Reconcile Using Modeling Roles') ) &&
	(! $cgi->param('Reconcile Using Subsystems Roles') ))
    {
	push(@html,$cgi->h1('You need to specify an OTU id (representative genome ID) in the URL'));
    }
    else
    {
	my @genomes = $cgi->param('genome');
	if ((@genomes == 2) && $cgi->param('Reconcile Using Modeling Roles'))
	{
	    push(@html,&RC::reconcile_genomes_using_modeling_roles($env,\@genomes));
	}
	elsif ((@genomes == 2) && $cgi->param('Reconcile Using Subsystems Roles'))
	{
	    push(@html,&RC::reconcile_genomes_using_actual_subsys_roles($env,\@genomes));
	}
	else
	{
	    push(@html,&show_otu($env,$otu));
	}
    }
    my $html_txt = join("", @html);
    return($html_txt, $title);
}


sub show_otu {
    my ($env, $otu) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      

    my @html;

#   my $genH   = $sapO->otu_members( -ids => [$otu] );
    my $genH   = &RC::otu_members($env,[$otu]);
    my $others = $genH->{$otu};
    my @otu_genomes = @{$genH->{$otu}};

#   $genH      = $sapO->genome_names( -ids => \@otu_genomes );
    $genH      = &RC::genome_names($env,\@otu_genomes);

    my $col_hdrs = ['','GenomeID','Name'];
    my @tab = map { [$cgi->checkbox( -name => 'genome', -value => $_, -label => ''),
                     $genH->{$_},
                     &LinksUI::genome_link($env,$_)] }
              sort { $genH->{$a} cmp $genH->{$b} }
              @otu_genomes;
    push(@html,$cgi->start_form(-action => $url, target => '_blank'),
	       $cgi->hidden(-name => 'otu', -value => $otu),
	       &HTML::make_table($col_hdrs,\@tab,"Genomes in the same OTU as $otu"), "<br>",
	       $cgi->submit('Reconcile Using Modeling Roles'),
	       $cgi->submit('Reconcile Using Subsystems Roles'),
	 "<br>"
        );

    return @html;
}

    
1;
