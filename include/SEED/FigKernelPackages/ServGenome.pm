package ServGenome;

#
# This file is part of an application created with create-new-page.
# The implementation module is FigKernelPackages/ServGenome.pm.
# The SeedViewer page module is SeedViewer/WebPage/SV_ServGenome.pm.
# The CGI script is FigWebServices/serv_genome.cgi.
#
# The SeedViewer url is http://yourseed/seedviewer.cgi?page=SV_ServGenome
# The CGI url is http://yourseed/serv_genome.cgi
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


    my $title = "Genome Page";

    my @html = ();

    my @params = $cgi->param;
    push(@html,"<pre>\n");
    foreach $_ (@params)
    {
	push(@html,"$_\t:" . join(",",$cgi->param($_)) . ":\n");
    }
    push(@html,"</pre>\n",$cgi->hr);

    my $genome = $cgi->param('genome');
    if (! $genome)
    {
	push(@html,$cgi->h1('You need to specify a genome id in the URL'));
    }
    elsif ($cgi->param('validate'))
    {
	push(@html,&RC::validate_translations_for_genome($env,$genome));
    }
    elsif ($cgi->param('show_subsys'))
    {
	push(@html,&RC::subsystems_for_genome($env,$genome));
    }
    elsif (my $g2 = $cgi->param('compare_genome'))
    {
	push(@html,&RC::compare_two_genomes($env,$genome,$g2));
    }
    else
    {
	push(@html,&show_genome($env, $genome));
    }
    my $html_txt = join("", @html);
    return($html_txt, $title);
}


sub show_genome {
    my ($env, $genome) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    my @html;
#   my $dataH = $sapO->genome_data( -ids  => [$genome],
#			    -data => ['complete',
#				      'contigs',
#				      'dna-size',
#				      'gc-content',
#				      'genetic-code',
#				      'pegs',
#				      'rnas',
#				      'name',
#				      'taxonomy',
#				      'md5'
#				      ] );

    my $dataH = &RC::genome_data($env,[$genome], ['complete',
				      'contigs',
				      'dna_size',
				      'gc_content',
				      'genetic_code',
				      'pegs',
				      'rnas',
				      'scientific_name',
				      'taxonomy',
				      'genome_md5'
				      ] );
#   my $otuH = $sapO->representative( -ids => [$genome] );
    my $otuH = &RC::representative($env,[$genome]);
    my $otu_link = $otuH->{$genome} ? &LinksUI::otu_link($env,$otuH->{$genome}) : '';
    my $data;
    if ($dataH && ($data = $dataH->{$genome}))
    {
	my($complete,$contigs,$dna_sz,$gc,$code,$pegsN,$rnasN,$gs,$tax,$md5) = @$data;
	$env->{genetic_code} = $code;
	$gc = sprintf("%0.2f",$gc);
	$complete = $complete ? "Genome is considered complete" : "Genome is not considered complete";
	push(@html,$cgi->h1("$genome: $gs"),"<br>");
	push(@html,"<pre>
Status: $complete
Number of contigs: $contigs
Size: $dna_sz bp
Genetic code: $code
GC ratio: $gc
Number of protein-encoding genes (PEGs): $pegsN
Number of RNAs: $rnasN
Taxonomy: $tax
MD5: $md5
OTU (representative genome ID): $otu_link
</pre>
",$cgi->hr);
	push(@html,&RC::identical_genomes($env,$md5),"<br>");
	push(@html,&LinksUI::subsystems_for_genome_link($env,$genome));
	push(@html,$cgi->start_form(-action => $url),
	           $cgi->hidden(-name => 'genome', -value => $genome),
	           $cgi->hidden(-name => 'user', -value => $user),
	           "<br><br>Compare with: ",
	           $cgi->textfield(-name => 'compare_genome',-size => 15, -override => 1),
	           "<br>",
	           $cgi->submit('Compare'),
	           $cgi->end_form
	     );
	push(@html,"<br>",&LinksUI::genome_validate_link($env,$genome),"<br>");
    }
    return @html;
}

1;
