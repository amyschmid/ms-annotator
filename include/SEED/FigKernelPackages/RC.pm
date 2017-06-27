package RC;

use strict;
use CGI;
use HTML;
use Data::Dumper;
use Carp;
use gjostat;
use ALITREserver;
use UpdateServer;
use SeedEnv;

sub identical_genomes {
    my ($env, $md5) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};


    my @html;
#    my $md5H = $sapO->genomes_by_md5( -ids => [$md5] );
    my $md5H = &md5_to_genomes($env,[$md5]);
    if ($md5H && $md5H->{$md5})
    {
	my @genomes = @{$md5H->{$md5}};
	if (@genomes >= 1)
	{
	    my $dataH = &genome_data($env,\@genomes,['scientific_name','pegs','rnas' ] );
	    my $col_hdrs = ['ID','Name','PEGs','RNAs'];
	    my @tab = map { my $g = $_;  [&LinksUI::genome_link($env,$g),@{$dataH->{$g}}] } sort { $a <=> $b } @genomes;
	    push(@html,&HTML::make_table($col_hdrs,\@tab,'Identical Genomes'));
	}
    }
    return @html;
}
    
sub subsystems_for_genome {
    my ($env, $genome) = @_;
    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    my @html;
    
#    my $genH = $sapO->genomes_to_subsystems( -ids => [$genome], -all => 1);
    my $genH  = &genomes_to_subsystems($env,[$genome]);
    my $tuples;
    if ($genH && ($tuples = $genH->{$genome}))
    {
	my @tuples = sort { $a->[0] cmp $b->[0] } @$tuples;
	my $col_hdrs = ['Subsystem','Variant'];
	my @tab      = map { [&LinksUI::subsys_row_link($env,$genome,$_->[0]),
			      $_->[1]]} grep { $_->[1] !~ /^\*?(-1|0)$/ } @tuples;
	push(@html,&HTML::make_table($col_hdrs,\@tab,"Subsystems for $genome"));
    }
    return @html;
}
sub show_prot_sequence_of_fid {
    my ($env, $fid) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    my @html;

#    my $seqH = $sapO->ids_to_sequences( -ids => [$fid], -fasta => 1, -protein => 1 );
    my $seqH = &ids_to_sequences($env,[$fid],1,1);
    my $seq = $seqH->{$fid};
    push(@html,"<pre>" . ($seq ? $seq : '') . "</pre><br><br>");
    my $to_md5H = &fids_to_proteins($env,[$fid]);
    if (my $md5 = $to_md5H->{$fid})
    {
	my $md5H = &proteins_to_fids($env,[$md5]);
	my $pegs = $md5H->{$md5};
	if (@$pegs > 1)
	{
	    my $pegH = &fids_to_feature_data($env,$pegs);
	    my $col_hdrs = ['PEG','Genome','Function'];
	    my $tab = [ map { [&LinksUI::peg_link($env,$_),
			       $pegH->{$_}->{genome_name},
			       $pegH->{$_}->{feature_function}
                              ] 
                            } sort keys(%$pegH)
                      ];
	    push(@html,&HTML::make_table($col_hdrs,$tab,"PEGs with Identical Sequence"));
	}
       
	push(@html,"<br><br>",
	            $cgi->start_form(-action => $url),
	            $cgi->submit('Close Sims'),
	            $cgi->submit('NCBI Blast'),
	            $cgi->hidden(-name => 'fid', -value => $fid),
	            $cgi->hidden(-name => 'seq', -value => $seq),
	            $cgi->hidden(-name => 'user', -value => $user));
	if ($env->{kbase})
	{
	    push(@html,$cgi->hidden(-name => 'kb', -value => 1));
	}
	push(@html,$hidden_form_var,
	            $cgi->end_form);
    }
    return @html;
}

sub show_dna_sequence_of_fid {
    my ($env, $fid) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
    my @html;

#    my $seqH = $sapO->ids_to_sequences( -ids => [$fid], -fasta => 1 );
    my $seqH = &ids_to_sequences($env,[$fid],1,0);
    my $seq = $seqH->{$fid};
    push(@html,"<pre>\n" . ($seq ? $seq : '') . "</pre><br>");
    return @html;
}

sub other_annotations_for_fid {
    my ($env, $fid) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    my @html;

#    my $idH = $sapO->equiv_sequence_assertions( -ids => [$fid] );
    my $idH  = &equiv_sequence_assertions($env,[$fid]);
    my %stats;
    foreach my $tuple ( @{$idH->{$fid}})
    {
	my($id,$func,$source,$expert) = @$tuple;
	push(@{$stats{$source}->{$func}},[$id,$expert]);
    }
    my $col_hdrs = ['Source','Expert','Count','Function'];
    my $tab = [];
    foreach my $source (sort keys(%stats))
    {
	my $funcH = $stats{$source};
	foreach my $func (sort keys(%$funcH))
	{
	    my $x = $funcH->{$func};
	    my @tmp = grep { $_->[1] == 1 } @$x;
	    my $expert = (@tmp > 0) ? '*' : '';
	    push(@$tab,[&LinksUI::expand_links_to_equiv_prots($env,$fid,$source,$func),
			$expert,
			scalar @$x,
			$func]);
	}
    }
    push(@html,&HTML::make_table($col_hdrs,$tab,"Asserted Functions of Identical Proteins"));
    return @html;
}

sub expand_other_annotations_for_fid {
    my ($env, $fid, $source, $function) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    my @html;

#   my $idH = $sapO->equiv_sequence_assertions( -ids => [$fid] );
    my $idH  = &equiv_sequence_assertions($env,[$fid]);

    my $col_hdrs = ['Id','Expert','Function'];
    my @tab = map { my($id,$func,undef,$expert) = @$_;
		    [&LinksUI::id_link($env,$id),
		     $expert ? '*' : '',
		     $func] }
              sort { ($b->[3] cmp $a->[3] ) or ($a->[1] cmp $b->[1]) or ($a->[1] cmp $b->[1]) }
              grep { ($_->[2] eq $source) && ($_->[1] eq $function) }
              @{$idH->{$fid}};
    push(@html,&HTML::make_table($col_hdrs,\@tab,"Assignments to Proteins with the Same Sequence as $fid by $source"));
    return @html;
}

sub equiv_pegs {
    my($env,$fid) = @_;

#   my $md5H = $sapO->fids_to_proteins( -ids => [$fid] );
    my $md5H = &fids_to_proteins($env,[$fid]);
    my $md5  = $md5H->{$fid};
#   my $protH = $sapO->proteins_to_fids( -prots => [$md5] );
    my $protH = &proteins_to_fids($env,[$md5]);
    my $pegs = $protH->{$md5};
    return $pegs;
}

sub inconsistent_annotations_for_fid {
    my ($env, $fid) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};


    my @html;
    push(@html,&functions_of_identical_proteins($env,$fid));
    push(@html,&functions_of_projections($env,$fid));
    return @html;
}

sub functions_of_projections {
    my ($env, $fid) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    my @html;

    my $ats = new ALITREserver;
    my $protH;
    my $md5_fid;
    my $pegs;

#   my $md5H = $sapO->fids_to_proteins( -ids => [$fid] );
    my $md5H = &fids_to_proteins($env,[$fid]);

    if ($md5H && ($md5_fid = $md5H->{$fid}))
    {
	my $ats = $ats->get_projections(-ids => [$md5_fid], -details => 1);
	my $tuples;
	if ($tuples = $ats->{$md5_fid})
	{
	    my %md5sP = map { ($_->[0] => [$_->[1],$_->[2],$_->[3]]) } 
	                grep { $_->[3] >= 0.5 }
	                @$tuples; 
	    $md5sP{$md5_fid} = [10,100,1];
#	    $protH = $sapO->proteins_to_fids( -prots => [$md5_fid,keys(%md5sP)] );
	    $protH = &proteins_to_fids($env,[$md5_fid,keys(%md5sP)]);
	    if ($protH)
	    {
		my %others;
		foreach my $md5 (keys(%md5sP))
		{
		    my($iden,$context,$score) = @{$md5sP{$md5}};
		    if ($pegs = $protH->{$md5})
		    {
			foreach my $peg (@$pegs) 
			{ 
			    $others{$peg} = [$iden,$context,$score];
			}
		    }
		}
		$pegs = [keys(%others)];
		if (@$pegs > 0)
		{
#		    my $funcH = $sapO->ids_to_functions( -ids => [($fid,@$pegs)] );
		    my $funcH = &ids_to_functions($env,[($fid,@$pegs)]);
		    my %counts;
		    my %example;
		    foreach my $peg (keys(%$funcH))
		    {
			my $f = $funcH->{$peg} ? $funcH->{$peg} : '';
			$counts{$f}++;
			$example{$f} = $peg;
		    }
		    my $col_hdrs = ['Count','Function','Example','Context','Iden','Score'];
		    my @tab = map { [$counts{$_},
				     $_,
				     &LinksUI::peg_link($env,$example{$_}),
				     @{$others{$example{$_}}}] }
		              sort { $counts{$b} <=> $counts{$a} }
		              keys(%counts);
		    push(@html,&HTML::make_table($col_hdrs,\@tab,"Counts by Function of Projected Proteins"),"<br>");

		    if ((@tab > 1) && $user)
		    {
			my $best_func = $tab[0]->[1];
			my $to_change = join(":",grep { $funcH->{$_} ne $best_func } keys(%$funcH));
			push(@html,$cgi->start_form(-action => $url, -target => '_blank'),
			           $cgi->hidden(-name => 'to_change', -value => $to_change),
			           $cgi->hidden(-name => 'user', -value => $user),
			           $cgi->hidden(-name => 'func', -value => $best_func),
			           $cgi->checkbox(-name => 'check for duplicates', -value => 1 ),
			     "<br>");
			if ($env->{kbase})
			{
			    push(@html,$cgi->hidden(-name => 'kb', -value => 1));
			}
			push(@html,$cgi->submit('Make projections consistent'),$cgi->hr,
			           $cgi->end_form,
			           "<br>");
		    }
		}
	    }
	}
    }
    return @html;
}

sub check_dups {
    my ($env, $pegs, $new_func) = @_;

    my $sapO = $env->{sap};


    my %by_genome;
    foreach my $peg (@$pegs)
    {
	$by_genome{&SeedUtils::genome_of($peg)}++;
    }
    my @genomes = keys(%by_genome);
#   my $occH = $sapO->occ_of_role( -functions => [$new_func], -genomes => \@genomes );
    my $occH = &occ_of_role($env,[$new_func],\@genomes);
    my $occF = $occH->{$new_func};
    foreach my $peg (@$occF)
    {
	$by_genome{&SeedUtils::genome_of($peg)}++;
    }
    my @ok = grep { $by_genome{&SeedUtils::genome_of($_)} == 1 } @$occF;
    return @ok;
}

sub functions_of_identical_proteins {
    my ($env, $fid) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};


    my @html;
    my $protH;
    my $md5;
    my $pegs = &equiv_pegs($env,$fid);
    my @others = grep { $_ ne $fid } @$pegs;
    if (@$pegs > 0)
    {
#	my $funcH = $sapO->ids_to_functions( -ids => [($fid,@$pegs)] );
	my $funcH = &ids_to_functions($env,[($fid,@$pegs)]);
	my %counts;
	my %example;
	foreach my $peg (keys(%$funcH))
	{
	    my $f = $funcH->{$peg} ? $funcH->{$peg} : '';
	    $counts{$f}++;
	    $example{$f} = $peg;
	}
	my $col_hdrs = ['Count','Function','Example'];
	my @tab = map { [$counts{$_},$_,&LinksUI::peg_link($env,$example{$_})] }
	          sort { $counts{$b} <=> $counts{$a} }
		  keys(%counts);
	my $best_func = $tab[0]->[1];
	my $to_change = join(":",grep { $funcH->{$_} ne $best_func } keys(%$funcH));
	push(@html,&HTML::make_table($col_hdrs,\@tab,"Counts by Function of Identical Proteins"),"<br>");
	if (@tab > 1) 
	{
		    
	    push(@html,
		       $cgi->start_form(-action => $url, -target => '_blank'),
		       $cgi->checkbox(-name => 'check for duplicates', -value => 1 ),
		       "<br>",
		       $cgi->hidden(-name => 'to_change', -value => $to_change),
		       $cgi->hidden(-name => 'user', -value => $user),
		       $cgi->hidden(-name => 'func', -value => $best_func));
	    if ($env->{kbase})
	    {
		push(@html,$cgi->hidden(-name => 'kb', -value => 1));
	    }
	    push(@html,$cgi->submit('Make identical consistent'),$cgi->hr,
		       $cgi->end_form,
		       "<br>");
	}
    }
    else
    {
	push(@html,$cgi->h2("$fid led to no annotations"));
    }
    return @html;
}

sub show_fc_for_fid {
    my ($env, $fid) = @_;

    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};


    my $fc = &functionally_coupled($env,$fid);

    my @html = ();
    if ($fc && (@$fc > 0))
    {
	my $col_hdrs = ['Sc','PEG Coupled To','Function of Coupled PEG'];
	my $tab = [];
	foreach my $tuple (@$fc)
	{
	    my($sc,$peg2,$func2) = @$tuple;
	    my $peg2_link = &LinksUI::peg_link($env,$peg2);
	    push(@$tab,[$sc,$peg2_link,&set_ec_links($env,$func2)]);
	}
	push(@html,&HTML::make_table($col_hdrs,$tab,"PEGs Functionally-Coupled to $fid"));
    }
    return @html;
}

sub show_subsys_for_fid {
    my ($env, $fid) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    my @html = ();
#   my $subsysL = $sapO->get({ -objects => 'Feature IsContainedIn MachineRole HasRole Role AND MachineRole IsRoleFor Implements Variant IsDescribedBy Subsystem',
#			       -filter => { 'Feature(id)'   => $fid },
#			       -fields => { 'Role(id)'      => 'role',
#					    'Subsystem(id)' => 'ss',
#					    'Variant(code)' => 'var' }
#			   });
    my $subsysL = &fid_subsystem_data($env,$fid);
    if ($subsysL && (@$subsysL > 0))
    {
	my $col_hdrs = ['Variant','Subsystem','Role'];
	my $tab = [];
	foreach my $tuple (@$subsysL)
	{
	    push(@$tab,[$tuple->{'var'},
			&LinksUI::subsys_row_link($env,&RC::genome_of($env,$fid),
						  $tuple->{'ss'}),
			                          &LinksUI::role_link($env,$tuple->{'role'})]);
	}
	if (@$tab > 0)
	{
	    push(@html,&HTML::make_table($col_hdrs,$tab,"Subsystems Containing $fid"),"<br>");
	}
    }
    return @html;
}


sub show_FIGfam {
    my ($env, $ff) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};


    my @html;
#   my $ffH      = $sapO->figfam_function( -ids => [$ff] );
    my $ffH      = &protein_families_to_functions($env,[$ff]);
    my $ff_func  = $ffH->{$ff};

#   my $pegs     = $sapO->figfam_fids( -id => $ff);
    my $pegsH    = &protein_families_to_fids($env,[$ff]);
    my $pegs     = $pegsH->{$ff};
    my $col_hdrs = ['PEG','Genome','AAs','Dlits','Has Trees','Function'];
    my $tab      = [];
#   my $dataH = $sapO->ids_to_data( -ids => $pegs, 
#				    -data => ['fig-id','genome-name','function','length','publications']);

    my $dataH = &fids_to_data($env,$pegs);
    my $treeH = AlignsAndTreesServer::pegIDs_to_aligns(@$pegs);

    my @tab = sort { ($b->[3] cmp $a->[3]) or ($a->[2] <=> $b->[2]) or ($a->[1] cmp $b->[1]) }
              map { my $tuple = $dataH->{$_}; 
		    if ($tuple && (my($peg,$gs,$func,$len,$dlits) = @$tuple))
		    {
			my $n = 0;
			if (defined $treeH->{$peg}) {
			    $n = scalar @{$treeH->{$peg}};
			}
			[&LinksUI::peg_link($env,$peg),
			 $gs,
			 ($len && ($len > 0)) ? int($len/3) : '',
			 ($dlits && (@$dlits > 0)) ? &LinksUI::dlit_links($dlits) : '',
			 $n ? $n : '',
			 &set_ec_links($env,$func)];
		    }
		    else
		    {
			()
		    }
		  } 
              @$pegs;
    my @lens = map { $_->[2] ? $_->[2] : () } @tab;

    my($mean, $stddev) = &gjostat::mean_stddev(@lens);
    $mean = sprintf("%0.2f",$mean);
    $stddev = sprintf("%0.2f",$stddev);
    push(@html,$cgi->h3("Mean length = $mean; standard deviation = $stddev"));
    push(@html,&HTML::make_table($col_hdrs,\@tab,"FIGfam $ff"));

    return @html;
}

sub show_fc_FIGfams {
    my ($env, $ff) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};


    my @html;
#   my $ffH = $sapO->related_figfams( -ids => [$ff] );
    my $ffH = &protein_families_to_co_occurring_families($env,[$ff]);
    if ($ffH && ($ffH = $ffH->{$ff}) && (@$ffH > 0))
    {
#	my $funcH      = $sapO->figfam_function( -ids => [$ff] );
	my $funcH      = &protein_families_to_functions($env,[$ff]);
	my $ff_func    = $funcH->{$ff};
	my $col_hdrs   = ['FIGfam','Score','FIGfam Function'];
	my @tab        = map { [&LinksUI::ff_link($env,$_->[0] ),
				$_->[1]->[0],
				$_->[1]->[1]] } 
	                 sort { $b->[1]->[0] <=> $a->[1]->[0] }
	                 grep { $_->[1]->[0] >= 10 }
	                 @$ffH;
	push(@html,&HTML::make_table($col_hdrs,\@tab,"FIGfams Functionall Coupled to $ff : $ff_func"));
    }
    return @html;
}

# The last argument ($fid) is optional.  If it is there, you get back an extra table of
# coregulated PEGs that are not in the atomic regulon (that is, they have PCCs with absolute values
# greater than or equal to 0.5
#
sub show_ar {
    my ($env, $ar, $fid) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    my @html = ();
#   my $arH = $sapO->regulons_to_fids( -ids => [$ar] );
    my $arH = &regulons_to_fids($env, [$ar] );
    my $fids = $arH->{$ar};
    if ($fids)
    {
	my @sorted = sort @$fids;
	my($html,$funcH) = &table_of_fids($env,\@sorted,"Atomic Regulon $ar");
	push(@html,@$html,$cgi->hr);
	if ($fid)
	{
	    push(@html,&coregulation($env,$fid,$fids,$funcH));
	}
    }
    else
    {
	push(@html,$cgi->h3("$ar appears to be an invalid atomic regulon ID"));
    }
    return @html;
}

sub coregulation {
    my ($env, $fid, $fids, $funcH) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};


    my @html;
    my @sorted = sort @$fids;
    my %in_ar = map { $_ => 1 } @sorted;
    my $coregH = &coregulated($env,\@sorted);
    if (@sorted  <= 30)
    {
	push(@html,&pcc_matrix(\@sorted,$coregH));
    }
    my $coreg_pegs = $coregH->{$fid};
    my @not_in_ar = sort grep { ! $in_ar{$_} } keys(%$coreg_pegs);
    push(@html,$cgi->hr);
    if (@not_in_ar > 0)
    {
	my $set = [$fid,@not_in_ar];
	if (@$set <= 20)
	{
	    my($html,$funcH) = &table_of_fids($env,$set,"Coregulated, but not in Atomic Regulon");
	    push(@html,@$html);
	    my $coregH2 = &coregulated($env,$set);
	    push(@html,&pcc_matrix($set,$coregH2));
	    push(@html,$cgi->hr);
	}
	else
	{
	    push(@html,&table_with_pcc($env,\@not_in_ar,$fid, $seedviewer_page_obj));
	    push(@html,$cgi->hr);
	}
    }
    return @html;
}

sub pcc_matrix {
    my($fids,$coregH) = @_;

    my @names = map { ($_ =~ /\.((peg|rna)\.\d+)$/) ? $1 : $_ } @$fids;
    my $col_hdrs = ['',@names];
    my $tab = [];
    my $i;
    for ($i=0; ($i < @names); $i++)
    {
	my $H = $coregH->{$fids->[$i]};
	my $vals = [$names[$i]];
	my $j;
	for ($j = 0; ($j < @names); $j++)
	{
	    my $v = $H->{$fids->[$j]};
	    $v = $v ? sprintf("%0.3f",$v) : '';
	    push(@$vals,($i == $j) ? '' : $v);
	}
	push(@$tab,$vals);
    }
    return &HTML::make_table($col_hdrs,$tab,'Pearson Correlation Coefficients');
}

sub table_of_fids {
    my ($env, $fids, $title) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};


#   my $funcH = $sapO->ids_to_functions(-ids => $fids);
    my $funcH = &ids_to_functions($env,$fids);
    my $col_hdrs = ['Feature','Function'];
    my $tab = [];
    foreach my $fid (@$fids)
    {
	push(@$tab,[&LinksUI::peg_link($env,$fid),&function_of($env,$funcH,$fid)]);
    }
    my @html = &HTML::make_table($col_hdrs,$tab,$title);
    return (\@html,$funcH);
}

sub table_with_pcc {
    my ($env, $fids, $fid) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

#   my $funcH = $sapO->ids_to_functions(-ids => $fids);
    my $funcH = &ids_to_functions($env,$fids);
    my $col_hdrs = ['PCC','Feature','Function'];
    my $tab = [];
#   my $pccH = $sapO->coregulated_fids( -ids => [$fid] );
    my $pccH = &coregulated($env,$fids);
    foreach my $fid2 (@$fids)
    {
	my $pcc = $pccH->{$fid2}->{$fid};
	$pcc = sprintf("%0.3f",$pcc);
	push(@$tab,[$pcc,&LinksUI::peg_link($env,$fid2),&function_of($env,$funcH,$fid2)]);
    }
    my @tab = sort { $b->[0] <=> $a->[0] } @$tab;
    my @html = &HTML::make_table($col_hdrs,\@tab,"FIDs with Strong Correlations to $fid (but not in Atomic Regulon)");
    return @html;
}

sub functionally_coupled {
    my ($env, $peg) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};


#   my $fcL    = $sapO->get({ -objects => ['Feature','IsInPair','Pairing','Determines','PairSet'],
#			      -filter => { 'Feature(id)' => $peg },
#			      -fields => { 'IsInPair(to-link)' => 'pairing',
#					   'PairSet(score)'    => 'score' }
#			  });
    my $fcH     = &fc($env,[$peg]);
    my $coupled = $fcH->{$peg};
#   my $funcH = $sapO->ids_to_functions( -ids => [map { $_->[0] } @coupled] );
    my $funcH = &ids_to_functions($env,[map { $_->[0] } @$coupled]);

    return [map { [$_->[1],$_->[0],&function_of($env,$funcH,$_->[0])] } sort { $b->[1] <=> $a->[1] } @$coupled];
}

sub function_of {
    my ($env, $funcH, $fid) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    return $funcH->{$fid} ? &set_ec_links($env,$funcH->{$fid}) : '';
}

sub in_atomic_regulon {
    my ($env, $peg) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      

#   my $arL = $sapO->fids_to_regulons( -ids => [$peg] );
    my $arL = &fids_to_regulons($env,[$peg]);
    my $pegH = $arL->{$peg};
    my @sorted = sort { $pegH->{$b} <=> $pegH->{$a} } keys(%$pegH);
    return $sorted[0] ? [$sorted[0],$pegH->{$sorted[0]}] : undef;
}

sub comments_for_fid {
    my ($env, $fid) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      
    my @html;
#   my $fidH = $sapO->ids_to_annotations( -ids => [$fid] );
    my $fidH = &fids_to_annotations($env,[$fid]);
    if (my $anno = $fidH->{$fid})
    {
	my $col_hdrs = ['When','Who','Annotation'];
	my @tab      = map { [scalar localtime($_->[2]),$_->[1],$_->[0]] } 
	               sort { ($b->[2] <=> $a->[2]) or ($a->[0] cmp $b->[0]) } 
	               @$anno;
	push(@html,&HTML::make_table($col_hdrs,\@tab,"Annotations for $fid"));
    }
    return @html;
}

sub history_of_assignments {
    my ($env, $fid) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};


    my @html;
#   my $ffH = $sapO->ids_to_figfams( -ids => [$fid] );
    my $ffH = &fids_to_figfams($env,[$fid]);
    if (my $ff = $ffH->{$fid}->[0])
    {
#	my $fids   = $sapO->figfam_fids( -id => $ff);
	my $fidsH  = &protein_families_to_fids($env,[$ff]);
	my $fids   = $fidsH->{$ff};
#	my $funcH  = $sapO->ids_to_functions( -ids => $fids );
	my $funcH  = &ids_to_functions($env,$fids );
	if (my $func = $funcH->{$fid})
	{
	    my @pegs = grep { $funcH->{$_} eq $func } @$fids;
#	    my $annoH = $sapO->ids_to_annotations( -ids => \@pegs);
            my $annoH = &fids_to_annotations($env,\@pegs);
	    my @relevant;
	    foreach my $peg (@pegs)
	    {
		my @annotations = map { [@$_,$peg] }
		                  grep { ($_->[0] =~ /(Assigned based on)|(Set master function)|(Set function)|(Set FIG function)/) &&
					 ($_->[1] !~ /(rapid)|(auto)|(repair)/) } @{$annoH->{$peg}};
		push(@relevant,@annotations);
	    }
	    my $col_hdrs = ['PEG','When','Who','Annotation'];
	    my @tab      = map { [&LinksUI::peg_link($env,$_->[3]), scalar localtime($_->[2]),$_->[1],$_->[0]] } 
	                   sort { ($b->[2] <=> $a->[2]) or ($a->[0] cmp $b->[0]) } 
	                   @relevant;
	    push(@html,&HTML::make_table($col_hdrs,\@tab,"Relevant Annotations for $fid"));
	}
    }
    return @html;
}

sub subsystems_containing_role {
    my ($env, $role) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};


    my @html;
#   my $roleH = $sapO->roles_to_subsystems( -roles => [$role] );
    my $roleH = &roles_to_subsystems($env,[$role]);
    my $subsys = $roleH->{$role};
    if ($subsys && (@$subsys > 0))
    {
	my $col_hdrs = ['Subsystems'];
	my @tab = sort map { [&LinksUI::subsystem_link($env,$_)] } @$subsys;
	push(@html,&HTML::make_table($col_hdrs,\@tab,"Subsystems Containing $role"),"<br>");
    }
    return @html;
}

sub role_to_reactions {
    my ($env, $role) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};


    my @html;
#   my $complexH = $sapO->roles_to_complexes( -ids => [$role] );
    my $complexH = &roles_to_complexes($env,[$role]);
    my $tuples = $complexH->{$role};

    if ($tuples && (@$tuples > 0))
    {
	my @complexes = map { $_->[0] } @$tuples;
	my %optional  = map { $_->[0] => $_->[1] } @$tuples;
#	my $dataH     = $sapO->complex_data( -ids => \@complexes, -data => ['name','roles','reactions'] );
	my $dataH     = &complex_data($env,\@complexes);
	if ($dataH)
	{
	    my $col_hdrs = ['ComplexID','Complex Name','Optional Flag','Reactions'];
	    my $tab = [];
	    foreach my $complex (@complexes)
	    {
		my $name      = $dataH->{$complex}->[0]; $name = $name ? $name : '';
		my $reactions = $dataH->{$complex}->[2]; $reactions = $reactions ? $reactions : [];
		push(@$tab,[&LinksUI::complex_link($env,$complex),
			    $name,
			    $optional{$complex} ? 'optional' : 'required',
			    &LinksUI::reaction_links($env,$reactions),
			   ]);
	    }
	    push(@html,&HTML::make_table($col_hdrs,$tab,"Reactions Impacted by $role"),"<br>");
	}
    }
    return @html;
}

sub role_to_FIGfams {
    my ($env, $role) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};


    my @html;
    my $ffs;
#   my $roleH = $sapO->roles_to_figfams( -roles => [$role] );
    my $roleH = &roles_to_protein_families($env,[$role]);

    if ($roleH && ($ffs = $roleH->{$role}) && (@$ffs > 0))
    {
#	my $ffH = $sapO->figfam_function( -ids => $ffs );
	my $ffH = &protein_families_to_functions($env,$ffs);

	if ($ffH)
	{
#	    my $sizeH = $sapO->figfam_fids_batch( -ids => $ffs );
	    my $sizeH = &protein_families_to_fids($env,$ffs);

	    my $col_hdrs = ['FIGfam','Size','Function'];
	    my $tab = [];
	    foreach my $ff (@$ffs)
	    {
		my $sz = @{$sizeH->{$ff}};
		push(@$tab,[ &LinksUI::ff_link($env,$ff),
			     $sz,
			     $ffH->{$ff} ]);
	    }
	    push(@html,&HTML::make_table($col_hdrs,$tab,"FIGfams Implementing $role"));
	}
    }
    return @html;
}

sub complex_to_reactions {
    my ($env, $complex) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    
    my @html;
#   my $dataH = $sapO->complex_data( -ids => [$complex], -data => ['name','roles','reactions']);
    my $dataH = &complex_data($env,[$complex]);
    my $reactions;
    if ($dataH && ($reactions = $dataH->{$complex}->[2]))
    {
#	my $reactH   = $sapO->reaction_strings( -ids => $reactions, -names => 'only');
	my $reactH   = &reaction_strings($env,$reactions);

	my $col_hdrs = ['ID','Reaction'];
	my @tab      = map { [&LinksUI::reaction_link($env,$_), 
			      &set_compound_links($env,$reactH->{$_})] } sort keys(%$reactH) ;
	push(@html,&HTML::make_table($col_hdrs,\@tab,"Reactions Implemented by Complex $complex"));
    }    
    return @html;
}

sub complexes_for_reaction {
    my ($env, $reaction) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    my @html;
#   my $reactH  = $sapO->reactions_to_complexes( -ids => [$reaction] );
    my $reactH  = &reactions_to_complexes($env,[$reaction]);
    my $complexes;
    if ($reactH && ($complexes = $reactH->{$reaction}) && (@$complexes > 0))
    {
#	my $dataH = $sapO->complex_data( -ids => $complexes, -data => ['name','roles','reactions'] );
	my $dataH = &complex_data($env,$complexes);
	foreach my $complex (@$complexes)
	{
	    my $col_hdrs = ['Complex Name','Optional Flag','Role'];
	    my $tab = [];
	    my $name      = $dataH->{$complex}->[0]; $name = $name ? $name : '';
	    my $roles     = $dataH->{$complex}->[1]; 
	    foreach my $tuple (@$roles)
	    {
		push(@$tab,[$name,
			    $tuple->[1] ? 'optional' : 'required',
			    &LinksUI::role_link($env,$tuple->[0])
			   ]);
	    }
	    push(@html,&HTML::make_table($col_hdrs,$tab,"complex: $complex"),"<br>");
	}
    }
    return @html;
}
	


# use names => 1 (not 'only') in reaction_strings (and set compound links)
# I am not doing this now, since we will probably just link to the model SEED
#
sub set_compound_links {
    my ($env, $reaction_string) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      
    return $reaction_string;
}

sub roles_in_complex {
    my ($env, $complex) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    
    my @html;
#   my $dataH = $sapO->complex_data( -ids => [$complex], -data => ['roles']);
    my $dataH = &complex_data($env,[$complex]);
    my $tuples;
    if ($dataH && ($tuples = $dataH->{$complex}->[1]))
    {
	my $col_hdrs = ['Optional','Role'];
	my @tab      = map { [$_->[1],&LinksUI::role_link($env,$_->[0])] } 
	               sort { ($a->[1] <=> $b->[1]) or ($a->[0] cmp $b->[0]) }
	               @$tuples;
	push(@html,&HTML::make_table($col_hdrs,\@tab,"Roles in Complex $complex"));
    }    
    return @html;
}

sub set_ec_links {
    my ($env, $func) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      

    if ($func =~ /^(.*)(\(EC (\d+\.\d+\.\d+\.\d+)\))(.*)$/)
    {
	my $before = $1;
	my $after  = $4;
	my $ec     = $3;
	my $link   = &LinksUI::ec_link($env,$ec);
	my $before = $before ? &set_ec_links($env,$before) : '';
	my $after  = $after  ? &set_ec_links($env,$after)  : '';
	return join('',($before,'(EC ',$link,')',$after));
    }
    else
    {
	return $func;
    }
}

sub reconcile_genomes_using_modeling_roles {
    my ($env, $genomes) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    my @html = ();
#   my $roles = $sapO->all_roles_used_in_models();
    my $roles = &all_roles_used_in_models($env);

    my @roles = sort @$roles;
    push(@html,&reconciliation_table($env,$genomes,\@roles));
    return @html;
}

sub reconcile_genomes_using_actual_subsys_roles {
    my ($env, $genomes) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};


    my @html = ();
#   my $genH = $sapO->genomes_to_subsystems( -ids => $genomes, -all => 1);
    my $genH = &genomes_to_subsystems($env,$genomes);
 
    my %in_ss = map { @$_ } map { @{$genH->{$_}} } @$genomes;
    my @ss = keys(%in_ss);
 
#   my $ssH = $sapO->subsystem_roles( -ids => \@ss, -aux => 1 );
    my $ssH = &Subsystem_roles($env,\@ss,1);

    my %roles = map { $_ => 1 } map { @{$ssH->{$_}} } sort keys(%$ssH);
    my @roles = sort keys(%roles);
    push(@html,&reconciliation_table($env,$genomes,\@roles));
    return @html;
}

sub reconciliation_table {
    my ($env, $genomes, $roles) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

#   my $roleH = $sapO->occ_of_role( -roles => $roles, -genomes => $genomes );
    my $roleH = &occ_of_role($env,$roles,$genomes);

    my $col_hdrs = ["In $genomes->[0]","In $genomes->[1]",'Role'];
    my $tab = [];
    my($g1,$g2) = @$genomes;
    foreach my $role (@$roles)
    {
	my $pegs = $roleH->{$role};
	my @in_g1 = grep { &SeedUtils::genome_of($_) eq $g1 } @$pegs;
	my @in_g2 = grep { &SeedUtils::genome_of($_) eq $g2 } @$pegs;
	if (@in_g1 != @in_g2)
	{
	    my $other_peg;
	    if (@in_g1 < 1)    { $other_peg = $in_g2[0] }
	    elsif (@in_g2 < 1) { $other_peg = $in_g1[0] }

	    push(@$tab,[&rec_links($env,\@in_g1,$g1,$other_peg),
			&rec_links($env,\@in_g2,$g2,$other_peg),
			$role]);
	}
    }
    return &HTML::make_table($col_hdrs,$tab,"Differences to be Considered");
}

sub rec_links {
    my ($env, $pegs, $genome, $other_peg) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    return (@$pegs > 0) ? &LinksUI::peg_links($env,$pegs) 
	                : &LinksUI::find_candidates_for_role_link($env,$genome,$other_peg);
}

# currently not called - we need it to search for missing, I think
sub other_peg {
    my($env,$role,$g) = @_;

#   my $idH = $sapO->genome_names( -ids => [$g] );
    my $idH = &genome_names($env,[$g]);

    my $gname = $idH->{$g};
    my $roleH;;
    if ($gname && ($gname =~ /^(\S+)/))
    {
	my $prefix  = $1;
#	my $gH      = $sapO->all_genomes( -complete => 1 );
	my $gH      = &all_complete_genomes($env);

	my @genomes = map { $_->[0] }
	              grep { index($_->[1],$prefix) == 0 } 
	              map { [$_,$gH->{$_}] } keys(%$gH);
#	$roleH  = $sapO->occ_of_role( -roles => [$role], -genomes => \@genomes);
	$roleH  = &occ_of_role($env,[$role],\@genomes);
    }
    else
    {
#	$roleH  = $sapO->occ_of_role( -roles => [$role] );
	$roleH = &occ_of_role($env,[$role],[]);
    }
    my $pegs = $roleH->{$role};
    return defined($pegs->[0]) ? $pegs->[0] : undef;
}
    

use AlignsAndTreesServer;

sub trees_exist {
    my($peg) = @_;

    my @alignIDs = AlignsAndTreesServer::aligns_with_pegID( $peg );
    my $num = @alignIDs;
    return $num;
}


#####################  UPDATES ##########################

sub make_annotation {
    my ($env, $fid, $anno) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $sapdb = $env->{sapdb};
    my $user = $env->{user};    
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      
    UpdateServer::make_annotation($cgi, $user, $sapdb, $fig, $fid, $anno);
    my @html = ();

    my @html;
    push(@html,$cgi->h3("Added Comment to $fid"));
    push(@html,"<pre>$anno\n</pre>");
    return @html;
}

sub assign_function {
    my ($env, $new_func, @pegs) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $sapdb = $env->{sapdb};
    my $user = $env->{user};    
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};

    my @html = ();
    if (! $user ) { push(@html,$cgi->h2("You need to specify a user to do an assignment")); return }

    UpdateServer::assign_function($cgi, $user, $sapdb, $fig, $new_func, @pegs);
    my $pegs = join(",",@pegs);
    push(@html,$cgi->h3("Changed function of $pegs to \"$new_func\""));

    return @html;
}

sub record_pmid {
    my ($env, $fid, $pmid) = @_;

    my $fig = $env->{fig};
    my $cgi = $env->{cgi};
    my $sapO = $env->{sap};
    my $user = $env->{user};    
    my $url = $env->{url};
    my $hidden_form_var = $env->{hidden_form_var};
    my $seedviewer_page_obj = $env->{seedviewer_page_obj};
      
    my @html;
    my @ids = split(/[\s,]+/,$pmid);
    foreach my $id (@ids)
    {
	push(@html,$cgi->h3("Added PubMed ID $id to $fid"));
    }
    return @html;
}

sub compare_two_genomes {
    my($env,$g1,$g2) = @_;

    my @html;
    my $cgi = $env->{cgi};
    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	push(@html,$cgi->h2("Comparison of Genomes Not Yet Supported"));
    }
    else
    {
	my $sapO  = $env->{sap};
	my $geneL = $sapO->gene_correspondence_map({ -genome1 => $g1,
						     -genome2 => $g2,
						     -fullOutput => 1,
						     -passive => 0 } );
	my %geneH1 = map { ($_->[0] => $_) } @$geneL;
	my %geneH2 = map { ($_->[1] => $_) } @$geneL;   ### Note: this drops many-1 mapping
	my $genH  = $sapO->all_features( -ids => [$g1,$g2], -type => ['peg']);
	my $n1 = @{$genH->{$g1}};
	my $n2 = @{$genH->{$g2}};
	my $mapped = @$geneL;
	my $to = keys(%geneH2);
	push(@html,"$n1 genes in $g1<br>",
	           "$n2 genes in $g2<br>",
	           "$mapped genes were mapped to $to genes in $g2<br>");
	my %roles_in_models = map { $_ =~ /(\S.*\S)/; ($1 => 1) } `$FIG_Config::bin/svr_all_roles_used_in_models`;
	my $funcH1 = $sapO->ids_to_functions( -ids => $genH->{$g1});
	my $funcH2 = $sapO->ids_to_functions( -ids => $genH->{$g2});
	my $in1 = &in_one($funcH1,\%roles_in_models);
	my $in2 = &in_one($funcH2,\%roles_in_models);
	my @just1 = grep { ! $in2->{$_} } keys(%$in1);
	my @just2 = grep { ! $in1->{$_} } keys(%$in2);
	$_ = @just1; push(@html,"<br>$_ roles in just $g1\n");
	$_ = @just2; push(@html,"<br>$_ roles in just $g2\n");
	push(@html,&show_diff($env,$g1,$g2,\@just1,$in1,\%geneH1,$funcH1,$funcH2));
    }
    return @html;
}

sub in_one {
    my($funcH,$rolesH) = @_;

    my %pegs_with_role;
    foreach my $peg (keys(%$funcH))
    {
	my @roles = grep { $rolesH->{$_} } &SeedUtils::roles_of_function($funcH->{$peg});
	foreach my $role (@roles)
	{
	    push(@{$pegs_with_role{$role}},$peg);
	}
    }
    return \%pegs_with_role;
}
									 
sub show_diff {
    my($env,$g1,$g2,$just,$pegs_in,$map_to_other,$funcH,$funcH_other)  = @_;

    my %seen;
    my @html;
    my $cgi = $env->{cgi};
    if (@$just > 0)
    {
	my $col_hdrs = ['Role','PEG1','Function1','<<<<','BBH','%iden','context','>>>>','PEG2','Function2'];
	my $tab = [];
	for my $role (sort @$just)
	{
	    my $pegs = $pegs_in->{$role};
	    foreach my $peg1 (@$pegs)
	    {
		if ($_  = $map_to_other->{$peg1}->[1]) 
		{
		    my $peg2 = $_;
		    my $bbh   = $map_to_other->{$peg1}->[8];
		    my $iden  = $map_to_other->{$peg1}->[9];
		    my $context = $map_to_other->{$peg1}->[2];
		    my $func1 = $funcH->{$peg1};
		    my $func2 = $funcH_other->{$peg2};
		    my $assign1_link = &LinksUI::assign_link($env,$func1,$peg2);
		    my $assign2_link = &LinksUI::assign_link($env,$func2,$peg1);
		    push(@$tab,[$role,&LinksUI::peg_link($env,$peg1),$func1,$assign2_link,
				$bbh,$iden,$context,
				$assign1_link,&LinksUI::peg_link($env,$peg2),$func2]);
		}
	    }
	}
	push(@html,&HTML::make_table($col_hdrs,$tab,"Proposed Candidates for $g2"));
    }
    return @html;
}

				     
############################

sub singleton_tuples_to_list {
    my($tuples) = @_;

    return [map { $_->[0] } @$tuples];
}

sub genome_data {
    my($env,$genomes,$fields ) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};

	my $gH = $kbO->genomes_to_genome_data($genomes);

	my $dataH = {};
	foreach my $g (@$genomes)
	{
	    my $fieldH = $gH->{$g};
	    if (! $fieldH)
	    {
		$dataH->{$g} = undef;
	    }
	    else
	    {
		my @values   = map { $fieldH->{$_} } @$fields;
		$dataH->{$g} = \@values;
	    }
	}
	return $dataH;
    }
    else
    {
	my $sapO = $env->{sap};
	my @tmp = map { $_ =~ s/scientific[-_]//;
			 $_ =~ s/genome[-_]//;
			 $_ =~ s/_/-/; $_ } @$fields;
	$fields = \@tmp;
	my $dataH = $sapO->genome_data( -ids  => $genomes,
					    -data => $fields );
	return $dataH;
    }
}

sub md5_to_genomes {
    my($env,$md5s) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	my $md5H = $kbO->md5s_to_genomes($md5s);
	my $locH = {};
	foreach my $md5 (keys(%$md5H))
	{
	    my $genomes = $md5H->{$md5};
	    $locH->{$md5} = $genomes;
	}
	return $locH;
    }
    else
    {
	my $sapO = $env->{sap};
	my $md5H = $sapO->genomes_by_md5( -ids => $md5s );
	return $md5H;
    }
}

sub genomes_to_subsystems {
    my($env,$genomes) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	my $gH     = $kbO->genomes_to_subsystems($genomes);
	my $dataH  = {};
	foreach my $g (@$genomes)
	{
	    my $x  = $gH->{$g};
	    if (! $x)
	    {
		$dataH->{$g} = [];
	    }
	    else
	    {
		# we reorder the ouput and throw out entries with variants that are not active
		my @pairs = map { [$_->[1],$_->[0]] } grep { $_->[0] !~ /^\*?(0|-1)$/ } @$x;
		$dataH->{$g} = \@pairs;
	    }
	    return $dataH;
	}
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->genomes_to_subsystems( -ids => $genomes, -all => 1);
    }
}

sub ids_to_sequences {
    my($env,$fids,$fasta,$protein) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	if ($protein)
	{
	    my $seqH = $kbO->fids_to_protein_sequences($fids);
	    if ($fasta )
	    {
		foreach my $fid (keys(%$seqH))
		{
		    $seqH->{$fid} = &to_fasta($fid,$seqH->{$fid});
		}
	    }
	    return $seqH;
	}
	else  
	{
	    my $to_seqH  = $kbO->fids_to_dna_sequences($fids);
	    my $dataH  = {};
	    foreach my $fid (@$fids)
	    {
		my $seq = $to_seqH->{$fid};
		if ($fasta )
		{
		    $dataH->{$fid} = &to_fasta($fid,$seq);
		}
		else
		{
		    $dataH->{$fid} = $seq;
		}
	    }
	    return $dataH;
	}
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->ids_to_sequences( -ids => $fids, -fasta => $fasta, -protein => $protein );
    }
}

sub to_fasta {
    my($id,$seq) = @_;

    return &SeedUtils::create_fasta_record($id,'',$seq);
}

sub fids_to_feature_data {
    my($env,$fids) = @_;

    if ($env->{kbase})
    {
	my $kbO  = $env->{kbase};
	my $dataH = $kbO->fids_to_feature_data($fids);
	foreach my $fid (keys(%$dataH))
	{
	    $dataH->{$fid}->{feature_location} = &RC::loc_to_locstring($dataH->{$fid}->{feature_location});
	}
	return $dataH;
    }
    else
    {
	my $sapO = $env->{sap};
	my $tmpH =  $sapO->ids_to_data( -ids => $fids, -data => ['genome-name','function','length','location']);
	my $dataH = {};
	foreach my $fid (keys(%$tmpH))
	{
	    my($genome_name,$feature_function,$feature_length,$feature_location) = @{$tmpH->{$fid}->[0]};
	    $dataH->{$fid} = { genome_name 	=> $genome_name,
			       feature_function => $feature_function,
			       feature_length 	=> $feature_length,
			       feature_location => $feature_location
			     };
	}
	return $dataH;
    }
}

sub fids_to_figfams {
    my($env,$fids) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	my $ffH = $kbO->fids_to_protein_families($fids);
	return $ffH;
    }
    else
    {
	my $sapO = $env->{sap};
	my $ffH  = $sapO->ids_to_figfams( -ids => $fids );
	return $ffH;
    }
}

sub dlits_for_ids {
    my($env,$fids) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	my $litH = $kbO->fids_to_literature($fids);
	my $h = {};
	foreach my $fid (@$fids)
	{
	    my $tuples = $litH->{$fid};
	    $h->{$fid} = [map { $_->[0] } @$tuples];
	}
	return $h;
    }
    else
    {
	my $sapO = $env->{sap};
	my $dlitH = $sapO->dlits_for_ids( -ids => $fids );
	return $dlitH;
    }
}

sub complex_data {
    my($env,$cids) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	my $dataH = $kbO->complexes_to_complex_data($cids);
	foreach my $complex (keys(%$dataH))
	{
	    my $h = $dataH->{$complex};
	    $dataH->{$complex} = [$h->{complex_name},$h->{complex_roles},$h->{complex_reactions}];
	}
	return $dataH;
    }
    else
    {
	my $sapO = $env->{sap};
	my $dataH = $sapO->complex_data( -ids => $cids, -data => ['name','roles','reactions']);
	return $dataH;
    }
}

sub equiv_sequence_assertions {
    my($env,$fids) = @_;

    if ($env->{kbase})
    {
	my $kbO               = $env->{kbase};
	my $md5H              = $kbO->fids_to_proteins($fids);
	my %tmp               = map { $md5H->{$_} => 1 } keys(%$md5H);
	my @proteins          = keys(%tmp);
	my $assertionsH       = $kbO->equiv_sequence_assertions(\@proteins);
	my $dataH = {};
	foreach my $fid (@$fids)
	{
	    my $md5  = $md5H->{$fid};
	    if ($md5 && ($_ = $assertionsH->{$md5}))
	    {
		$dataH->{$fid} = $_;
	    }
	}
	return $dataH;
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->equiv_sequence_assertions( -ids => $fids );
    }
}

sub fids_to_proteins {
    my($env,$fids) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	return $kbO->fids_to_proteins($fids);
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->fids_to_proteins( -ids => $fids );
    }
}

sub proteins_to_fids {
    my($env,$md5s) = @_;

    if ($env->{kbase})
    {
	my $kbO    = $env->{kbase};
	my $md5H   = $kbO->proteins_to_fids($md5s);
	return $md5H;
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->proteins_to_fids( -prots => $md5s );
    }
}

sub ids_to_functions {
    my($env,$fids) = @_;

    if (! (ref($env) eq "HASH")) {  confess "bad reference " }

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	return $kbO->fids_to_functions($fids);
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->ids_to_functions( -ids => $fids );    
    }
}

#### NEED TO HANDLE EMPTY GENOMES (SEARCH ALL)
sub occ_of_role {
    my($env,$roles,$genomes) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	return $kbO->roles_to_fids($roles,$genomes);
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->occ_of_role( -roles => $roles, -genomes => $genomes );
    }
}

sub fid_subsystem_data {
    my($env,$fid) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	my $fidH = $kbO->fids_to_subsystem_data([$fid]);
	my $dataH = {};
	my $tuples = $fidH->{$fid};
	my @hash_versions = map { my($ss,$var,$role) = @$_; { ss => $ss,
							      var => $var,
							      role => $role
							      }} @$tuples;
	return\@hash_versions;
    }
    else
    {
	my $sapO = $env->{sap};
	my $subsysL = $sapO->get({ -objects => 'Feature IsContainedIn MachineRole HasRole Role AND MachineRole IsRoleFor Implements Variant IsDescribedBy Subsystem',
				   -filter => { 'Feature(id)'   => $fid },
				   -fields => { 'Role(id)'      => 'role',
						'Subsystem(id)' => 'ss',
						'Variant(code)' => 'var' }
			       });
	return $subsysL;
    }
}

sub protein_families_to_functions {
    my($env,$fams) = @_;

    if ($env->{kbase})
    {
	my $kbO               = $env->{kbase};
	return $kbO->protein_families_to_functions($fams);
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->figfam_function( -ids => $fams );
    }
}

sub protein_families_to_fids {
    my($env,$fams) = @_;

    if (! (ref($env) eq "HASH")) { confess "bad reference" }
    if ($env->{kbase})
    {
	my $kbO               = $env->{kbase};
	return $kbO->protein_families_to_fids($fams);
    }
    else
    {
	my $sapO = $env->{sap};
	my $dataH = $sapO->figfam_fids_batch( -ids => $fams);
	return $dataH;
    }
}

sub fids_to_data {
    my($env,$fids) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	my $fidH = $kbO->fids_to_feature_data($fids);
	my $dataH = {};
	foreach my $fid (@$fids)
	{
	    my $fH = $fidH->{$fid};
	    my $genome_name = $fH->{genome_name} || '';
	    my $func        = $fH->{feature_function} || '';
	    my $length      = $fH->{feature_length} || '';
	    my $refs        = $fH->{feature_publications};
	    if ($refs && (@$refs > 0))
	    {
		$refs = [map { $_->[0] } @$refs];
	    }
	    else
	    {
		$refs = '';
	    }

	    my $loc         = $fH->{feature_location};
	    my $tuple = [$fid,$genome_name,$func,$length,$refs,$loc];
	    $dataH->{$fid} = $tuple;
	}
	return $dataH;
    }
    else
    {
	my $sapO = $env->{sap};
	my $dataH = $sapO->ids_to_data( -ids => $fids, 
					-data => ['fig-id','genome-name','function','length','publications','location']);
	foreach $_ (keys(%$dataH)) { $dataH->{$_} = $dataH->{$_}->[0] }  # collapse to just one
	return $dataH;
    }
}

sub protein_families_to_co_occurring_families {
    my($env,$fams) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	my $ffH = $kbO->protein_families_to_co_occurring_families($fams);
	foreach my $fam (keys(%$ffH))
	{
	    $ffH->{$fam} = [map { my($fam2,$sc,$func) = @$_; [$fam2,[$sc,$func]] } @{$ffH->{$fam}}];
	}
	return $ffH;
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->related_figfams( -ids => $fams );
    }
}

sub regulons_to_fids {
    my($env,$regulons) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	my $ffH = $kbO->atomic_regulons_to_fids($regulons);
	return $ffH;
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->regulons_to_fids( -ids => $regulons );
    }
}

sub fids_to_regulons {
    my($env,$fids) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	my $ffH = $kbO->fids_to_atomic_regulons($fids);
	my $dataH = {};
	foreach my $fid (@$fids)
	{
	    if ($_ = $ffH->{$fid})
	    {
		foreach my $tuple (@$_)
		{
		    my($reg,$sz) = @$tuple;
		    $dataH->{$fid}->{$reg} = $sz;
		}
	    }
	}
	return $dataH;
    }
    else
    {
	my $sapO = $env->{sap};
        my $arL = $sapO->fids_to_regulons( -ids => $fids );
	return $arL;
    }
}

sub coregulated {
    my($env,$fids) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	my $coexpH = $kbO->fids_to_coexpressed_fids($fids);
	my $dataH = {};
	foreach my $fid (keys(%$coexpH))
	{
	    my $cL  = $coexpH->{$fid};
	    foreach my $tuple (@$cL)
	    {
		my($fid1,$sc1) = @$tuple;
		$dataH->{$fid}->{$fid1} = $sc1;
	    }
	}
	return $dataH;
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->coregulated_fids( -ids => $fids );
    }
}

sub fc {
    my($env,$fids) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	return $kbO->fids_to_co_occurring_fids($fids);
    }
    else
    {
	my $sapO = $env->{sap};
	my $dataH = {};
	foreach my $peg (@$fids)
	{
	    my $fcL    = $sapO->get({ -objects => ['Feature','IsInPair','Pairing','Determines','PairSet'],
				      -filter => { 'Feature(id)' => $peg },
				      -fields => { 'IsInPair(to-link)' => 'pairing',
						   'PairSet(score)'    => 'score' }
				  });
	    my @coupled;
	    foreach $_ (@$fcL)
	    {
		my $sc      = $_->{score};
		my $pair    = $_->{pairing};
		my($p1,$p2) = split(':',$pair);
		my $other   = ($p1 eq $peg) ? $p2 : $p1;
		push(@coupled,[$other,$sc]);
	    }
	    $dataH->{$peg} = \@coupled;
	}
	return $dataH;
    }
}

sub fids_to_annotations {
    my($env,$fids) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	return $kbO->fids_to_annotations($fids);
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->ids_to_annotations( -ids => $fids );
    }
}

sub roles_to_subsystems {
    my($env,$roles) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	return $kbO->roles_to_subsystems($roles);
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->roles_to_subsystems(-roles => $roles);
    }
}


sub roles_to_complexes {
    my($env,$roles) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	my $res = $kbO->roles_to_complexes($roles);
	return $res;
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->roles_to_complexes(-ids => $roles);
    }
}

sub roles_to_protein_families {
    my($env,$roles) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	return $kbO->roles_to_protein_families($roles);
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->roles_to_figfams( -roles => $roles );
    }
}

sub reaction_strings {
    my($env,$reactions) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	return $kbO->reaction_strings($reactions,'only');
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->reaction_strings( -ids => $reactions, -names => 'only');
    }
}

sub reactions_to_complexes {
    my($env,$reactions) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	my $res = $kbO->reactions_to_complexes($reactions);
	return $res;
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->reactions_to_complexes( -ids => $reactions );
    }
}

sub all_roles_used_in_models {
    my($env) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	return $kbO->all_roles_used_in_models();
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->all_roles_used_in_models();
    }
}

sub subsystems_to_roles {
    my($env,$subsystems,$aux) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	return $kbO->subsystems_to_roles($subsystems,$aux);
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->subsystem_roles( -ids => $subsystems, -aux => $aux );
    }
}

sub genome_names {
    my($env,$genomes) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	my $fieldH = $kbO->get_entity_Genome($genomes,['scientific_name']);
	foreach my $g (@$genomes)
	{
	    $fieldH->{$g} = $fieldH->{$g}->{scientific_name};
	}
	return $fieldH;
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->genome_names( -ids => $genomes );
    }
}

sub all_complete_genomes {
    my($env) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
#### FIX THIS ####	
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->all_genomes( -complete => 1 );
    }
}

sub subsystems_to_spreadsheets {
    my($env,$subsystems,$genomes) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	my $dataH =  $kbO->subsystems_to_spreadsheets($subsystems,$genomes);
	foreach my $ss (keys(%$dataH))
	{
	    my $ssH = $dataH->{$ss};
	    foreach my $g (keys(%$ssH))
	    {
		my $tuple = $ssH->{$g};
		my($variant,$roleH) = @$tuple;
		my $old = [$variant];
		foreach my $role (sort keys(%$roleH))
		{
		    my $pegs = $roleH->{$role};
		    push(@$old,[$role,@$pegs]);
		}
		$ssH->{$g} = $old;
	    }
	}
	return $dataH;
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->pegs_in_variants( -subsystems => $subsystems, -genomes => $genomes );
    }
}

sub representative {
    my($env,$genomes) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	my $tmp = $kbO->representative($genomes);
	return $kbO->representative($genomes);
    }
    else
    {
	my $sapO = $env->{sap};
	return $sapO->representative( -ids => $genomes );
    }
}

sub otu_members {
    my($env,$genomes) = @_;

    if ($env->{kbase})
    {
	my $kbO = $env->{kbase};
	return $kbO->otu_members($genomes);
    }
    else
    {
	my $sapO = $env->{sap};
	my $genH = $sapO->otu_members( -ids => $genomes );
	foreach my $g (keys(%$genH))
	{
	    my $x = $genH->{$g};
	    $genH->{$g} = [$g,sort { $a <=> $b} keys(%$x)];
	}
	return $genH;
    }
}

sub type_of_feature {
    my($env,$fid) = @_;
    
    if ($fid =~ /^fig\|(\d+\.\d+)\.([a-z]+)\.\d+$/)   { return $2 }
    if ($fid =~ /^(kb\|g\.\d+)\.([a-z]{1,5})\.\d+$/)  { return $2 }
    if ($fid =~ /^(kb\|g\.\d+)\.\d+$/)                { return 'peg' }
    my $kbO = $env->{kbase};
    my $fieldH = $kbO->get_entity_Feature([$fid],['feature_type']);
    return $fieldH->{feature_type};
}

sub genome_of {
    my($env,$fid) = @_;

    if ($fid =~ /^fig\|(\d+\.\d+)\.([a-z]+)\.\d+$/)   { return $1 }
    if ($fid =~ /^(kb\|g\.\d+)\.([a-z]{1,5})\.\d+$/)  { return $1 }
    if ($fid =~ /^(kb\|g\.\d+)\.\d+$/)                { return $1 }
    my $kbO = $env->{kbase};
    my $res = $kbO->get_relationship_IsOwnedBy([$fid],[],['to-link'],[]);
    if ($res && (@$res > 0)) { return $res->[0]->[1]->{to_link} }
    return undef;
}

sub loc_to_locstring {
    my($loc) = @_;

    return join(",",map { "$_->[0]\_$_->[1]$_->[2]$_->[3]" } @$loc);
}


sub similarities_for_fid {
    my($env,$fid) = @_;

    my $cgi = $env->{cgi};
    my $md5 = &fids_to_proteins($env,[$fid])->{$fid};
    my @sims = &SeedUtils::sims("gnl|md5|$md5",10,1.0e-5,'raw',0);
    my $col_hdrs = ['id2','# Identical','identity','b1','e1','ln1','b2','e2','ln2','psc','Function'];
    my $tab = [];
    my @html;
    my @rep_pegs;
    foreach my $sim (@sims)
    {
	my $md5 = $sim->id2;
	$md5    =~ s/^gnl\|md5\|//;
	my $fids = &proteins_to_fids($env,[$md5])->{$md5};
	next if (! defined($fids));
	my $n = @$fids;
	if ($n > 0)
	{
	    push(@rep_pegs,$fids->[0]);
	    my $one_peg = &LinksUI::peg_prot_link($env,$fids->[0]);
	    push(@$tab,[$one_peg,$n,$sim->iden,$sim->b1,$sim->e1,$sim->ln1,$sim->b2,$sim->e2,$sim->ln2,$sim->psc]);
	}
    }
    my $funcH = &ids_to_functions($env,\@rep_pegs);
    my $i;
    for ($i=0; ($i < @rep_pegs); $i++) { push(@{$tab->[$i]},$funcH->{$rep_pegs[$i]}) }
    push(@html,$cgi->hr,&HTML::make_table($col_hdrs,$tab,"Similarities to $fid"));
    return @html;
}

sub in_regulons {
    my($env,$fid) = @_;

    my $rc;
    if (my $kbO = $env->{kbase})
    {
	my $dataH =  $kbO->fids_to_regulon_data([$fid]);
	return $dataH->{$fid};
    }
    else
    {
    }
}

sub show_regulons_for_fid {
    my($env,$fid) = @_;

    my @html;
    my $cgi = $env->{cgi};
    my $regulons = &RC::in_regulons($env,$fid);
    if ((! $regulons) || (@$regulons == 0))
    {
	return ();
    }
    my $col_hdrs = ['Regulon','Regulated FIDs','Transcription Factors'];
    my $tab = [];
    foreach my $reg_data (@$regulons)
    {
	my $fids                   = $reg_data->{regulon_set};
	my $fids_in_set_with_links = &LinksUI::peg_links($env,$fids);
	my $tfs                    = $reg_data->{tfs};
	my $tf_links               = &LinksUI::peg_links($env,$tfs);
	my $id                     = $reg_data->{regulon_id};
	push(@$tab,[$id,$fids_in_set_with_links,$tf_links]);
    }
    push(@html,&HTML::make_table($col_hdrs,$tab,"Regulons Containing $fid"),"<br><br>");
    return @html;
}

use URI::Escape;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);

sub get_blast_results {
    my($env,$seq) = @_;
    
    my $cgi = $env->{cgi};
    my $ua = LWP::UserAgent->new;
    my $program  = 'blastp';
    my $database = 'nr';
    my $query    = uri_escape($seq);
    my $args = "CMD=Put&PROGRAM=$program&DATABASE=$database&QUERY=" . $query;
    my $req = new HTTP::Request POST => 'http://www.ncbi.nlm.nih.gov/blast/Blast.cgi';
    $req->content_type('application/x-www-form-urlencoded');
    $req->content($args);
    my $response = $ua->request($req);
    $response->content =~ /^    RID = (.*$)/m;
    my $rid=$1;

    $response->content =~ /^    RTOE = (.*$)/m;
    my $rtoe=$1;
    sleep $rtoe;
    while (1)
    {
        sleep 5;
        my $req = new HTTP::Request GET => "http://www.ncbi.nlm.nih.gov/blast/Blast.cgi?CMD=Get&FORMAT_OBJECT=SearchInfo&RID=$rid";
        $response = $ua->request($req);
        if ($response->content =~ /\s+Status=WAITING/m)
        {
            next;
        }

        if ($response->content =~ /\s+Status=FAILED/m)
        {
            exit 4;
        }
        if ($response->content =~ /\s+Status=UNKNOWN/m)
        {
            exit 3;
        }
        if ($response->content =~ /\s+Status=READY/m) 
        {
            if ($response->content =~ /\s+ThereAreHits=yes/m)
            {
                last;
            }
            else
            {
                exit 2;
            }
        }
        exit 5;
    }
    $req = new HTTP::Request GET => "http://www.ncbi.nlm.nih.gov/blast/Blast.cgi?CMD=Get&FORMAT_TYPE=Text&RID=$rid";
    $response = $ua->request($req);
    my @html = $response->content;
    @html = map { &set_ncbi_links($_) } @html;					
    return @html;					
}

sub set_ncbi_links {
    my($x) = @_;

    if ($x =~ /^(.*)\b((gb|ref|emb|dbj|sp)\|[A-Za-z0-9\.\_]+)(.*)/s)
    {
	my($before,$id,$after) = ($1,$2,$4);
	return &set_ncbi_links($before) . &ncbi_prot_link($id) . &set_ncbi_links($after);
    }
    else
    {
	return $x;
    }
}

sub ncbi_prot_link {
    my($id) = @_;

    return "<a href=\"http://www.ncbi.nlm.nih.gov/protein/$id\" target=_blank>$id</a>";
}

sub validate_translations_for_genome {
    my($env,$genome) = @_;

    my $cgi  = $env->{cgi};
    my $code = $cgi->param('genetic_code');
    if ($code ne "11") { return ($cgi->h2("genetic code = $code is not supported")) }

    my @html;
    push(@html,"<pre>\n");

    if (my $kbO = $env->{kbase})
    {
	my $fidH = $kbO->genomes_to_fids([$genome],['CDS','peg']);
	my $fids = $fidH->{$genome};
	my $bad = 0;
	my $good = 0;
	foreach my $fid (@$fids)
	{
#	    next if ($bad >= 5);
	    my $seqH = $kbO->fids_to_dna_sequences([$fid]);
	    my $seq = $seqH->{$fid};
	    if ($seq)
	    {
		my $translation = &SeedUtils::translate($seq,undef,1);
		$translation =~ s/\*$//;
		my $protH = $kbO->fids_to_protein_sequences([$fid]);
		my $prot = $protH->{$fid};
		if (length($prot) == (length($translation)+1)) { chop $prot }
		if (length($prot) == (length($translation)-1)) { chop $translation }
		if (! &same_tran(uc substr($prot,1,-1),substr($translation,1,-1)))
		{
		    my $locH = $kbO->fids_to_locations([$fid]);
		    my $loc = $locH->{$fid};
		    my $loc_str = join(",",map { my($c,$b,$s,$l) = @$_; "$c\_$b$s$l" } @$loc);
		    $loc_str =~ /^([^+-]+)_\d+[+-]/;
		    my $contigKB = $1;
		    my $resH = $kbO->get_entity_Contig([$contigKB],['source_id']);
		    my $contig = $resH->{$contigKB}->{source_id};
		       $resH = $kbO->get_entity_Feature([$fid],['source_id']);
		    my $id   = $resH->{$fid}->{source_id};
		    push(@html,"\nCONTIG: $contigKB was $contig\nFEATURE: $fid was $id\n$loc_str\n$seq\n$translation\n$prot\n\n");
		    $bad++;
		}
		else
		{
		    $good++;
		}
	    }
	    else
	    {
		push(@html,"No sequence for $fid\n");
	    }
	}
	push(@html,"</pre>\n");

	if ($bad)
	{
	    my $n = $good + $bad;
	    push(@html,$cgi->h2("You have $bad bad translations ($bad out of $n looked at)"));
	}
	else
	{
	    push(@html,$cgi->h2("All translations ($good of them) match up as ok"));
	}
    }
    return @html;
}
	
sub same_tran {
    my($s1,$s2) = @_;

    if ($s1 eq $s2) { return 1 }
    if (length($s1) ne length($s2)) { return 0 }
    my $i;
    for ($i=0; ($i < length($s1)) && &ok_char(substr($s1,$i,1),substr($s2,$i,1)); $i++) {}
    return ($i == length($s1));
}

sub ok_char {
    my($c1,$c2) = @_;

    return ((uc $c1 eq uc $c2) || (uc $c1 eq "X") || (uc $c2 eq "X"));
}

1;
