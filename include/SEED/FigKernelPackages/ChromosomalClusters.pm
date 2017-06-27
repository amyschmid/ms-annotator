
#
# Module that incorporates the guts of what used to be in
# chromosomal_clusters.cgi. We put it here so we can use this code in the
# batch-mode script that precomputes the clustering data for incorporation
# in distributed SEED data releases.
#

use FIG;
use HTML;
use GenoGraphics;
    
use Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

use strict;
use CGI;

@EXPORT = qw(compute_pin_for_peg);

#
# Compute a pin. This is a little weird since it uses a CGI object for
# parameter passing, but that's because it used to be a CGI script.
#

sub compute_pin_for_peg
{
    my($fig, $peg, $cgi) = @_;

    my $html = [];
    if (!ref($cgi))
    {
	$cgi = new CGI();
    }

    $cgi->param('prot', $peg);

    my $sim_cutoff = $cgi->param('sim_cutoff');
    if (! $sim_cutoff) { $sim_cutoff = 1.0e-20 }

    my ( $prot, $pinned_to, $in_pin, $uniL, $uniM ) = get_prot_and_pins( $fig, $cgi, $html );

    if (!$prot)
    {
	return undef;
    }

    my ($gg, $all_pegs, $pegI ) = get_initial_gg_and_all_pegs( $fig, $cgi, $prot, $pinned_to, $uniL, $uniM );

    my( $color, $text ) = form_sets_and_set_color_and_text( $fig, $cgi, $gg, $pegI, $all_pegs, $sim_cutoff );

    my $vals = update_gg_with_color_and_text( $cgi, $gg, $color, $text, $prot );


    if ( @$gg > 0 )
    {
	&thin_out_over_max( $cgi, $prot, $gg, $html, $in_pin );
    }
    return($gg);
}

#  Everything below here is subroutines. =======================================

sub pick_color {
    my( $cgi, $all_pegs, $color_set, $i, $colors ) = @_;

    if ( @$colors > 0 )
    {
	my( $j, $peg, $color );
	my %colors_imported = map { ( $peg, $color ) = $_ =~ /^(.*):([^:]*)$/ } @$colors;
	for ($j=0; ($j < @$color_set) && (! $colors_imported{$all_pegs->[$color_set->[$j]]}); $j++) {}
	if ($j < @$color_set)
	{
	    return $colors_imported{$all_pegs->[$color_set->[$j]]};
	}
    }
    return ( $i == 0 ) ? "red" : "color$i";
}

sub pick_text {
    my($cgi,$all_pegs,$color_set,$i,$texts) = @_;
    my($peg,$text,$j);

    if (@$texts > 0)
    {
	my %texts_imported = map { ($peg,$text) = split(/:/,$_); $peg => $text } @$texts;
	for ($j=0; ($j < @$color_set) && (! $texts_imported{$all_pegs->[$color_set->[$j]]}); $j++) {}
	if ($j < @$color_set)
	{
	    return $texts_imported{$all_pegs->[$color_set->[$j]]};
	}
    }
    return $i+1;
}

sub in {
    my( $x, $xL ) = @_;

    foreach ( @$xL ) { if ( $x == $_ ) { return 1 } }
    return 0;
}

sub in_bounds {
    my($min,$max,$x) = @_;

    if     ($x < $min)     { return $min }
    elsif  ($x > $max)     { return $max }
    else                   { return $x   }
}

sub decr_coords {
    my($genes,$min) = @_;
    my($gene);

    foreach $gene (@$genes)
    {
	$gene->[0] -= $min;
	$gene->[1] -= $min;
    }
    return $genes;
}

sub flip_map {
    my($genes,$min,$max) = @_;
    my($gene);
    
    foreach $gene (@$genes)
    {
	($gene->[0],$gene->[1]) = ($max - $gene->[1],$max - $gene->[0]);
	$gene->[2] = ($gene->[2] eq "rightArrow") ? "leftArrow" : "rightArrow";
    }
    return $genes;
}

sub gs_of {
    my($peg) = @_;
    
    $peg =~ /fig\|(\d+)/;
    return $1;
}


#  How about some color commentary?

sub show_commentary {
    my($fig,$cgi,$html,$sim_cutoff) = @_;

    my(@vals,$val,%by_set,$col_hdrs,$tab,$n,$occ,$org,$fid,$set,$x,$i,%by_line,%fid_to_line);
    $cgi->delete('request');

    @vals = $cgi->param('show');
    foreach $val (@vals)
    {
	( $n, $i, $fid, $org, $occ ) = split( /\@/, $val );
	push( @{ $by_set{$n}  }, [ $i, $org, $occ, $fid ] );
	push( @{ $by_line{$i} }, $n );
	if ($n == 1) { $fid_to_line{$fid} = $i }
    }

    my($func,$user_entry,$func_entry,$target);

    my $user = $cgi->param('user');
    if ($user)
    {
	$target = "window$$";
    }

    foreach $set (sort { $a <=> $b } keys(%by_set))
    {
	if ($cgi->param('uni'))
	{
	    $col_hdrs = ["Set","Organism","Occ","UniProt","UniProt Function","PEG","SS",
	                  &evidence_codes_link($cgi),"Ln","Function"];
	}
	else
	{
	    $col_hdrs = ["Set","Organism","Occ","PEG","SS",&evidence_codes_link($cgi),"Ln","Function"];
	}
	$tab = [];

	if ($user)
	{
	    push(@$html,$cgi->start_form(-method => 'post', 
					 -target => $target,
					 -action => &FIG::cgi_url . "/fid_checked.cgi"),
		 $cgi->hidden(-name => 'user', -value => $user)
		 );
	}

	#  For colorized functions we need to get the functions, then set the
	#  colors.  Given the structure of the current code, it seems easiest
	#  to accumulate the information on a first pass, exactly as done now,
	#  but then go back and stuff  the colors in (possibly even by keeping
	#  a stack of references to the ultimate locations).

	my( @uni, $uni_link );
	my @func_summary = ();
	my %func_count = ();
	my %order = ();
	my $cnt = 0;

	foreach $x ( sort { ($a->[0] <=> $b->[0]) or ($a->[2] <=> $b->[2]) } @{ $by_set{$set} } )
	{
	    ( undef, $org, $occ, $fid ) = @$x;
	    my $tran_len = $fig->translation_length($fid);
	    my @subs    = $fig->peg_to_subsystems($fid);
	    my $in_sub  = @subs;

	    @uni = $cgi->param('uni') ? $fig->to_alias($fid,"uni") : "";
	    $uni_link = join( ", ", map { &HTML::uni_link( $cgi, $_ ) } @uni );

	    $user_entry = &HTML::fid_link( $cgi, $fid );

	    if ($user)
	    {
		$user_entry = $cgi->checkbox(-name => 'checked', -label => '', -value => $fid) . "&nbsp; $user_entry";
	    }

	    $func = $fig->function_of($fid,$cgi->param('user'));
	    if ($user && $func)
	    {
		$func_entry = $cgi->checkbox(-name => 'from', -label => '', -value => $fid) . "&nbsp; $func";
	    }
	    else
	    {
		$func_entry = $func;
	    }

	    #  Record the count of each function, and the order of first occurance:

	    if ( $func ) { ( $func_count{ $func }++ ) or ( $order{ $func } = ++$cnt ) }

	    #  We need to build a table entry that HTML::make_table will color
	    #  the cell.  It would certainly be possible to use the old colon
	    #  delimited prefix.  Rob Edwards added the really nice feature that
	    #  if the cell contents are a reference to an array, then the first
	    #  element in the content, and the second element is the tag.  We
	    #  Will till it in so that if nothing else happens it is fine.

	    my $func_ref = [ $func_entry, "td" ];
	    my $uni_ref  = undef;
	    my $uni_func = undef;
	    # my $ev = join("<br>",$fig->evidence_codes($fid));
	    my $ev = '';

	    if ($cgi->param('uni'))
	    {
		my $uni_entry;
		$uni_func = (@uni > 0) ? $fig->function_of($uni[0]) : "";
		if ( $uni_func && $user )
		{
		    $uni_entry = $cgi->checkbox(-name => 'from', -label => '', -value => $uni[0]) . "&nbsp; $uni_func";
		}
		else
		{
		    $uni_entry = $uni_func;
		}
		$uni_ref = [ $uni_entry, "td" ];
		push( @$tab,[ $set, $org, $occ, $uni_link, $uni_ref, $user_entry, $in_sub, $ev,$tran_len, $func_ref ] );
	    }
	    else
	    {
		push( @$tab, [ $set, $org, $occ, $user_entry, $in_sub, $ev, $tran_len, $func_ref ] );
	    }

	    #  Remember the information we need to do the coloring:

	    push @func_summary, [ $func, $func_ref, $uni_func, $uni_ref ];
	}

	#  Okay, let's propose some colors:

	my @colors = qw( #EECCAA #FFAAAA #FFCC66 #FFFF00 #AAFFAA #BBBBFF #FFAAFF ); # #FFFFFF
	my %func_color = map  { $_ => ( shift @colors || "#DDDDDD" ) }
	                 sort { $func_count{ $b } <=> $func_count{ $a }
	                     or      $order{ $a } <=> $order{ $b }
	                      }
	                 keys %func_count;

	my ( $row );
	foreach $row ( @func_summary )
	{
	    my ( $func, $func_ref, $uni_func, $uni_ref ) = @$row;
	    $func_ref->[1] = "td bgcolor=" . ( $func_color{ $func } || "#DDDDDD" );
	    if ( $uni_ref )
	    {
		$uni_ref->[1] = "td bgcolor=" . ( $func_color{ $uni_func } || "#DDDDDD" )
	    }
	}

	push( @$html, &HTML::make_table( $col_hdrs, $tab, "Description By Set" ) );

	if ($user)
	{
	    push(@$html,$cgi->submit('assign/annotate'),$cgi->end_form);
	    push(@$html,$cgi->end_form);
	}
    }


    #  Build a form for extracting subsets of genomes:

    my $target = "window$$";
    push(@$html,$cgi->start_form(-method => 'post', 
				 -action => &FIG::cgi_url . "/chromosomal_clusters.cgi",
				 -target => $target),
	 $cgi->hidden(-name => 'sim_cutoff', -value => $sim_cutoff));

    foreach $set (keys(%by_set))
    {
	my($x,$set0,$peg);
	$set0 = $set - 1;
	foreach $x (@{$by_set{$set}})
	{
	    $peg = $x->[3];
	    push(@$html,$cgi->hidden(-name => "color", -value => "$peg:color$set0"),
		        $cgi->hidden(-name => "text",  -value => "$peg:$set"));
	}
    }

    my $prot = $cgi->param('prot');

    $col_hdrs = ["show","map","genome","description","PEG","colors"];
    $tab      = [];
    $set      = $by_set{1};

    my %seen_peg;
    foreach $x (sort { $a->[1] cmp $b->[1] } @$set)
    {
	(undef,$org,undef,$fid) = @$x;
	next if ($seen_peg{$fid});
	$seen_peg{$fid} = 1;

	push(@$tab,[$cgi->checkbox(-name => 'pinned_to', 
				   -checked => 1,
				   -label => '',
				   -value => $fid),
		    $org,&FIG::genome_of($fid),$fig->org_of($fid),&HTML::fid_link($cgi,$fid),
		    join(",",sort { $a <=> $b } @{$by_line{$fid_to_line{$fid}}})
		   ]);
    }
    push(@$html,$cgi->hr);
    push(@$html,&HTML::make_table($col_hdrs,$tab,"Keep Just Checked"),
                $cgi->hidden(-name => 'user', -value => $user),
#               $cgi->hidden(-name => 'prot', -value => $prot),
#               $cgi->hidden(-name => 'pinned_to', -value => $prot),
	        $cgi->br,
                $cgi->submit('Picked Maps Only'),
	        $cgi->end_form);
}


sub get_prot_and_pins {
    my($fig,$cgi,$html) = @_;

    my $prot = $cgi->param('prot');
    my @pegs = map { split(/,/,$_) } $cgi->param('pinned_to');
    my @nonfig = grep { $_ !~ /^fig\|/ } @pegs;
    my @pinned_to = ();

    my $uniL = {};
    my $uniM = {};

    if (@nonfig > 0)
    {
	my $col_hdrs = ["UniProt ID","UniProt Org","UniProt Function","FIG IDs","FIG orgs","FIG Functions"];
	my $tab = [];
	my $x;
	foreach $x (@nonfig)
	{
	    if ($x =~ /^[A-Z0-9]{6}$/)
	    {
		$x = "uni|$x";
	    }
	    my @to_fig = &resolve_id($fig,$x);
	    my($fig_id,$fig_func,$fig_org);
	    if (@to_fig == 0)
	    {
		$fig_id = "No Matched FIG IDs";
		$fig_func = "";
		$fig_org = "";
	        $x =~ /uni\|(\S+)/;
		$uniM->{$1} = 1;
	    }
	    else
	    {
		$fig_id = join("<br>",map { &HTML::fid_link($cgi,$_) } @to_fig);
		$fig_func = join("<br>",map { $fig->function_of($_) } @to_fig);
		$fig_org  = join("<br>",map { $fig->org_of($_) } @to_fig);
		push(@pinned_to,@to_fig);
	    }
	    my $uni_org = $fig->org_of($x);
	    push(@$tab,[&HTML::uni_link($cgi,$x),$fig->org_of($x),scalar $fig->function_of($x),$fig_id,$fig_org,$fig_func]);
	}
	push(@$html,$cgi->hr);
	push(@$html,&HTML::make_table($col_hdrs,$tab,"Correspondence Between UniProt and FIG IDs"));
	push(@$html,$cgi->hr);
    }
    else
    {
	@pinned_to = @pegs;
    }

    #  Make @pinned_to non-redundant by building a hash and extracting the keys

    my %pinned_to = map { $_ => 1 } @pinned_to;
    @pinned_to = sort { &FIG::by_fig_id($a,$b) } keys(%pinned_to);
#   print STDERR &Dumper(\@pinned_to);

    #  Do we have an explicit or implicit protein?

    if ((! $prot) && (@pinned_to < 2))
    {
	return undef;
    }

    #  No explicit protein, take one from the list:

    if (! $prot)
    {
	$prot = shift @pinned_to;
    }

    my $in_pin = @pinned_to;

    #  Make sure that there are pins

    if (@pinned_to < 1)
    {
	@pinned_to = &get_pin($fig,$prot);
	$in_pin = @pinned_to;
	my $max = $cgi->param('maxpin');
	$max = $max ? $max : 300;
	if (@pinned_to > (2 * $max))
	{
	    @pinned_to = &limit_pinned($prot,\@pinned_to,2 * $max);
	}
    }

#   print STDERR &Dumper(\@pinned_to); 
    if (@pinned_to == 0)
    {
	return undef;
    }

    #  Ensure that there is exactly one copy of $prot, then sort by taxonomy:

    @pinned_to = ( $prot, grep { $_ ne $prot } @pinned_to );
    @pinned_to = $fig->sort_fids_by_taxonomy(@pinned_to);
#   print &Dumper([$prot,\@pinned_to,$in_pin]);

    #  $uniL is always {}.  What was it for? -- GJO

    return ( $prot, \@pinned_to, $in_pin, $uniL, $uniM );
}



sub get_initial_gg_and_all_pegs {
    my( $fig, $cgi, $prot, $pinned_to, $uniL, $uniM ) = @_;

    #  $prot       is the protein the reference protein
    #  @$pinned_to is the complete list of proteins to be aligned across genomes
    #  $uniL       is {} and is never used!
    #  %$uniM      is a hash of uniprot ids from $cgi->param('pinned_to'),
    #                  with no other information.  They create empty lines.

    my $gg = [];
    my($peg,$loc,$org,$contig,$beg,$end,$min,$max,$genes,$feat,$fid);
    my($contig1,$beg1,$end1,@all_pegs,$map,$mid,$pegI);

    foreach $peg ( @$pinned_to )
    {
    	$org = $fig->org_of($peg);
#       print STDERR "processing $peg\n";
	$loc = $fig->feature_location($peg);
	if ( $loc)
	{
	    ($contig,$beg,$end) = $fig->boundaries_of($loc);
	    if ($contig && $beg && $end)
	    {
		$mid = int(($beg + $end) / 2);
		$min = $mid - 8000;
		$max = $mid + 8000;
		$genes = [];
		($feat,undef,undef) = $fig->genes_in_region($fig->genome_of($peg),$contig,$min,$max);
#	        print STDERR &Dumper($feat);
		foreach $fid (@$feat)
		{
		    ($contig1,$beg1,$end1) = $fig->boundaries_of($fig->feature_location($fid));
#		    print STDERR "contig1=$contig1 beg1=$beg1 end1=$end1\n";
#		    print STDERR &Dumper([$fid,$fig->feature_location($fid),$fig->boundaries_of($fig->feature_location($fid))]);
		    $beg1 = &in_bounds($min,$max,$beg1);
		    $end1 = &in_bounds($min,$max,$end1);

                    #  Build the pop-up information for the gene:

		    if (0)
		    {

                    my $function = $fig->function_of($fid);
		    my $aliases1 = $fig->feature_aliases($fid);
                    my ( $uniprot ) = $aliases1 =~ /(uni\|[^,]+)/;


                    my $info  = join( '<br/>', "<b>Org:</b> $org",
                    				"<b>PEG:</b> $fid",
                                               "<b>Contig:</b> $contig1",
                                               "<b>Begin:</b> $beg1",
                                               "<b>End:</b> $end1",
                                               ( $function ? "<b>Function:</b> $function" : () ),
                                               ( $uniprot ? "<b>Uniprot ID:</b> $uniprot" : () )
                                    );

		    my @allattributes=$fig->get_attributes($fid);
		    foreach my $eachattr (@allattributes) {
			my ($gotpeg,$gottag,$val, $url)=@$eachattr;
			$info .= "<br/><b>Attribute:</b> $gottag $val $url";
		    }
		}
		    my $info = '';

		    push( @$genes, [ &FIG::min($beg1,$end1),
		                     &FIG::max($beg1,$end1),
		                     ($beg1 < $end1) ? "rightArrow" : "leftArrow",
		                     "",
		                     "",
		                     $fid,
		                     $info
		                   ] );

		    if ( $fid =~ /peg/ ) { push @all_pegs, $fid }
		}

		#  Everything is done for the one "genome", push it onto GenoGraphics input:
                #  Sequence title can be replaced by [ title, url, popup_text, menu, popup_title ]

                #$map = [ [ FIG::abbrev( $org ), undef, $desc, undef, 'Contig' ],
                my $org  = $fig->org_of( $peg );
                my $desc = "Genome: $org<br />Contig: $contig";
                $map = [ [ FIG::abbrev( $org ), undef, $desc, undef, 'Contig' ],
		         0,
		         $max+1-$min,
		         ($beg < $end) ? &decr_coords($genes,$min) : &flip_map($genes,$min,$max)
		       ];

		push( @$gg, $map );
	    }
	}
    }

    &GenoGraphics::disambiguate_maps($gg);

    #  %$uniM is a hash of uniprot IDs.  This just draws blank genome lines for each.

    foreach $_ (sort keys %$uniM )
    {
	push( @$gg, [ $_, 0, 8000, [] ] );
    }
#   print STDERR &Dumper($gg); die "abort";

    #  move all pegs from the $prot genome to the front of all_pegs.

    my $genome_of_prot = $prot ? FIG::genome_of( $prot ) : "";

    if ( $genome_of_prot ) {
	my @tmp = ();
	foreach $peg ( @all_pegs )
	{
	    if ( $genome_of_prot eq FIG::genome_of( $peg ) ) { unshift @tmp, $peg }
	    else                                             { push    @tmp, $peg }
	}
	@all_pegs = @tmp;
    }

    #  Find the index of $prot in @all_pegs


    for ($pegI = 0; ($pegI < @all_pegs) && ($prot ne $all_pegs[$pegI]); $pegI++) {}
    if ($pegI == @all_pegs)
    {
	$pegI = 0;
    }

#   print STDERR "pegi=$pegI prot=$prot $all_pegs[$pegI]\n";

   return ( $gg, \@all_pegs, $pegI );
}


sub add_change_sim_threshhold_form {
    my($cgi,$html, $prot, $pinned_to) = @_;

    my $user = $cgi->param('user');

    my @change_sim_threshhold_form = ();
    push(@change_sim_threshhold_form,start_form(-action => &FIG::cgi_url . "/chromosomal_clusters.cgi"));
    if ($user)
    {
	push(@change_sim_threshhold_form,hidden(-name => "user", -value => $user));
    }	

    my $max = $cgi->param('maxpin');
    $max = $max ? $max : 300;

    push(@change_sim_threshhold_form,hidden(-name => "maxpin", -value => $max));
    push(@change_sim_threshhold_form,hidden(-name => "prot", -value => $prot));
    push(@change_sim_threshhold_form,hidden(-name => "pinned_to", -value => [@$pinned_to]));
    push(@change_sim_threshhold_form,"Similarity Threshold: ", $cgi->textfield(-name => 'sim_cutoff', -size => 10, -value => 1.0e-20),
                                     $cgi->submit('compute at given similarity threshhold'),
                                     $cgi->end_form);
    push(@$html,@change_sim_threshhold_form);
    return;
}


#  I now attempt to document, clean code, and make orphan genes gray.  Wish us all luck. -- GJO

sub form_sets_and_set_color_and_text {
    my( $fig, $cgi, $gg, $pegI, $all_pegs, $sim_cutoff ) = @_;

    #  @$gg       is GenoGraphics objects (maps exist, but they will be modified)
    #  $pegI      is index of the reference protein in @$all_pegs
    #  @$all_pegs is a list of all proteins on the diagram

    #  all of the PEGs are now stashed in $all_pegs.  We are going to now look up similarities
    #  between them and form connections.  The tricky part is that we are going to use "raw" sims,
    #  which means that we need to translate IDs; a single ID in a raw similarity may refer to multiple
    #  entries in $all_pegs.  $pos_of{$peg} is set to a list of positions (of essentially identical PEGs).

    my %peg2i;   #  map from id (in @$all_pegs) to index in @$all_pegs
    my %pos_of;  #  maps representative id to indexes in @$all_pegs, and original id to its index
    my @rep_ids; #  list of representative ids (product of all maps_to_id)

    #
    # Expt: pull from sims server.
    #
    my $ua = LWP::UserAgent->new();
    my %args = ();
    $args{id} = $all_pegs;
    $args{mapping} = 1;

    my %maps_to_id;
    my %reps;
    my $res = $ua->post("http://bio-ppc-44/simserver/perl/sims2.pl", \%args);
    if (!$res->is_success)
    {
	die "getreps failed: " . $res->code . " " . $res->status_line . "\n";
    }
    my $c = $res->content;
    while ($c =~ /(.*)\n/g)
    {
	my($rep, @list) = split(/\t/, $1);
	$reps{$rep} = {};

	map { my($id, $len) = split(/,/, $_);  $maps_to_id{$id} = $rep;  } @list;
    }

    #
    # get the sims too.
    #
    my @sims = $fig->sims($all_pegs, 500, $sim_cutoff, 'raw');
    my %sims;
    map { push(@{$sims{$_->id1}}, $_) } @sims;


    my ( $i, $id_i );
    for ($i=0; ($i < @$all_pegs); $i++)
    {
	$id_i = $all_pegs->[$i];
	$peg2i{ $id_i } = $i;

	my $rep = $maps_to_id{$id_i};
	defined( $pos_of{ $rep } ) or push @rep_ids, $rep;
	push @{ $pos_of{ $rep } }, $i;
	if ( $rep ne $id_i )
	{
	    push @{ $pos_of{ $id_i } }, $i;
	}
    }

    # print STDERR Dumper(\%pos_of, \%peg2i, \@rep_ids);

    #  @{$conn{ $rep }} will list all connections of a representative id
    #  (this used to be for every protein, not the representatives).

    my %conn;

    my @texts  = $cgi->param('text');   # map of id to text
    my @colors = $cgi->param('color');  # peg:color pairs
    my @color_sets = ();

    #  Case 1, find sets of related sequences using sims:

    if ( @colors == 0 )
    {
	#  Get sequence similarities among representatives

	my ( $rep, $id2 );
	foreach $rep ( @rep_ids )
	{
	    #  We get $sim_cutoff as a global var (ouch)

	    $conn{ $rep } = [ map { defined( $pos_of{ $id2 = $_->id2 } ) ? $id2 : () }
	                      @{$sims{$rep}}
	                    ];
	}
        # print STDERR &Dumper(\%conn);

	#  Build similarity clusters

	my %seen = ();
	foreach $rep ( @rep_ids )
	{
	    next if $seen{ $rep };

	    my @cluster = ( $rep );
	    my @pending = ( $rep );
	    $seen{ $rep } = 1;

	    while ( $id2 = shift @pending )
	    {
		my $k;
		foreach $k ( @{ $conn{ $id2 } } )
		{
		    next if $seen{ $k };

		    push @cluster, $k;
		    push @pending, $k;
		    $seen{ $k } = 1;
		}

	    }
	    if ( @cluster > 1 ) { push @color_sets, \@cluster }
	}

	#  Clusters were built by representatives.
	#  Map (and expand) back to lists of indices into @all_pegs.

	@color_sets = map { [ map { @{ $pos_of{ $_ } } } @$_ ] }
	              @color_sets;
    }
    else  #  Case 2, supplied colors are group labels that should be same color
    {
	my( %sets, $peg, $x, $color );
	foreach $x ( @colors )
	{
	    ( $peg, $color ) = $x =~ /^(.*):([^:]*)$/;
	    if ( $peg2i{ $peg } )
	    {
		push @{ $sets{ $color } }, $peg2i{ $peg };
	    }
	}

	@color_sets = map { $sets{ $_ } } keys %sets;
    }

    #  Order the clusters from largest to smallest

    @color_sets = sort { @$b <=> @$a } @color_sets;
    # foreach ( @color_sets ) { print STDERR "[ ", join( ", ", @$_ ), " ]\n" }

    #  Move cluster with reference prot to the beginning:

    my $set1;
    @color_sets = map { ( &in( $pegI, $_ ) &&  ( $set1 = $_ ) ) ? () : $_ } @color_sets;
    if ( $set1 )
    {
	unshift @color_sets, $set1;
#	print STDERR &Dumper(["color_sets",[map { [ map { $all_pegs->[$_] } @$_ ] } @color_sets]]); die "aborted";
    }
#   else
#   {
#       print STDERR &Dumper(\@color_sets);
#       print STDERR "could not find initial PEG in color sets\n";
#   }

    my( %color, %text, $i, $j );
    for ( $i=0; ($i < @color_sets); $i++)
    {
	my $color_set_i = $color_sets[ $i ];
	my $picked_color = &pick_color( $cgi, $all_pegs, $color_set_i, $i, \@colors );
	my $picked_text  = &pick_text(  $cgi, $all_pegs, $color_set_i, $i, \@texts );

	foreach $j ( @$color_set_i )
	{
	    $color{$all_pegs->[$j]} = $picked_color;
	    $text{$all_pegs->[$j]}  = $picked_text;
	}
    }

#   print STDERR &Dumper($all_pegs,\@color_sets);
    return (\%color,\%text);
}

sub add_commentary_form {
    my($prot,$user,$cgi,$html,$vals) = @_;


    my @commentary_form = ();
    my $ctarget = "window$$";

    my $uni = $cgi->param('uni');
    if (! defined($uni)) { $uni = "" }

    push(@commentary_form,start_form(-target => $ctarget,
				     -action => &FIG::cgi_url . "/chromosomal_clusters.cgi"
				    ));
    push(@commentary_form,hidden(-name => "request", -value => "show_commentary"));
    push(@commentary_form,hidden(-name => "prot", -value => $prot));
    push(@commentary_form,hidden(-name => "user", -value => $user));
    push(@commentary_form,hidden(-name => "uni", -value => $uni));

    push(@commentary_form,hidden(-name => "show", -value => [@$vals]));
    push(@commentary_form,submit('commentary'));
    push(@commentary_form,end_form());
    push(@$html,@commentary_form);
    
    return;
}

sub update_gg_with_color_and_text {
    my( $cgi, $gg, $color, $text, $prot ) = @_;

    my( $gene, $n, %how_many, $x, $map, $i, %got_color );

    my %must_have_color;

    my @must_have = $cgi->param('must_have');
    push @must_have, $prot;

    my @vals = ();
    for ( $i = (@$gg - 1); ($i >= 0); $i--)
    {
	my @vals1 = ();
	$map = $gg->[$i];  # @$map = ( abbrev, min_coord, max_coord, \@genes )
	
	undef %got_color;
	my $got_red = 0;
	my $found = 0;
	undef %how_many;

	foreach $gene ( @{$map->[3]} )
	{
	    #  @$gene = ( min_coord, max_coord, symbol, color, text, id_link, pop_up_info )

	    my $id = $gene->[5];
	    if ( $x = $color->{ $id } )
	    {
		$gene->[3] = $x;
		$gene->[4] = $n = $text->{ $id };
		$got_color{ $x } = 1;
	        if ( ( $x =~ /^(red|color0)$/ )
	          && &FIG::between( $gene->[0], ($map->[1]+$map->[2])/2, $gene->[1] )
	            ) { $got_red = 1 }
		$how_many{ $n }++;
		push @vals1, join( "@", $n, $i, $id, $map->[0], $how_many{$n} );
		$found++;
	    }
	    else
	    {
		$gene->[3] = "ltgray";  # Light gray
	    }
	    #
	    # RDO: for this code, don't change into a link. We want that
	    # to be done locally on a SEED.
	    #
	    # $gene->[5] = &HTML::fid_link( $cgi, $id, 0, 1 );
	}

	for ( $x = 0; ( $x < @must_have ) && $got_color{ $color->{ $must_have[ $x ] } }; $x++ ) {}
	if ( ( $x < @must_have ) || ( ! $got_red ) )
	{
#	    print STDERR &Dumper($map);
	    if ( @{ $map->[3] } > 0 ) { splice( @$gg, $i, 1 ) }
	}
	else
	{
	    push @vals, @vals1;
	}
    }
#   print STDERR &Dumper($gg);

    return \@vals;
}

sub thin_out_over_max {
    my($cgi,$prot,$gg,$html,$in_pin) = @_;

    my $user = $cgi->param('user');
    $user = $user ? $user : "";

    my $max = $cgi->param('maxpin');
    $max = $max ? $max : 300;

    if ($in_pin > $max)
    {
	my $sim_cutoff = $cgi->param('sim_cutoff');
	if (! $sim_cutoff) { $sim_cutoff = 1.0e-20 }

	my $to = &FIG::min(scalar @$gg,$max);
	push(@$html,$cgi->h1("Truncating from $in_pin pins to $to pins"),
	            $cgi->start_form(-action => &FIG::cgi_url . "/chromosomal_clusters.cgi"),,
	            "Max Pins: ", $cgi->textfield(-name => 'maxpin',
						  -value => $_,
						  -override => 1),
                    $cgi->hidden(-name => 'user', -value => $user),
                    $cgi->hidden(-name => 'prot', -value => $prot),
                    $cgi->hidden(-name => 'sim_cutoff', -value => $sim_cutoff),
	            $cgi->submit("Recompute after adjusting Max Pins"),
	            $cgi->end_form,
	            $cgi->hr);

	if (@$gg > $max)
	{
	    my($i,$to_cut);
	    for ($i=0; ($i < @$gg) && (! &in_map($prot,$gg->[$i])); $i++) {}

	    if ($i < @$gg)
	    {
		my $beg = $i - int($max/2);
		my $end = $i + int($max/2);
		if (($beg < 0) && ($end < @$gg))
		{
		    $beg = 0;
		    $end = $beg + ($max - 1);
		}
		elsif (($end >= @$gg) && ($beg > 0))
		{
		    $end = @$gg - 1;
		    $beg = $end - ($max - 1);
		}
		
		if ($end < (@$gg - 1))
		{
		    splice(@$gg,$end+1);
		}
		
		if ($beg > 0)
		{
		    splice(@$gg,0,$beg);
		}
	    }
	}
    }
}

sub in_map {
    my($peg,$map) = @_;
    my $i;

    my $genes = $map->[3];
    for ($i=0; ($i < @$genes) && (index($genes->[$i]->[5],"$peg\&") < 0); $i++) {}
    return ($i < @$genes);
}
    
sub limit_pinned {
    my($prot,$pinned_to,$max) = @_;

    my($i,$to_cut);
    for ($i=0; ($i < @$pinned_to) && ($pinned_to->[$i] ne $prot); $i++) {}

    if ($i < @$pinned_to)
    {
	my $beg = $i - int($max/2);
	my $end = $i + int($max/2);
	if (($beg < 0) && ($end < @$pinned_to))
	{
	    $beg = 0;
	    $end = $beg + ($max - 1);
	}
	elsif (($end >= @$pinned_to) && ($beg > 0))
	{
	    $end = @$pinned_to - 1;
	    $beg = $end - ($max - 1);
	}
	
	if ($end < (@$pinned_to - 1))
	{
	    splice(@$pinned_to,$end+1);
	}
	
	if ($beg > 0)
	{
	    splice(@$pinned_to,0,$beg);
	}
    }
    return @$pinned_to;
}

sub resolve_id {
    my($fig,$id) = @_;
    my(@pegs);

    if ($id =~ /^fig/)              { return $id }

    if (@pegs = $fig->by_alias($id)) { return @pegs }

    if (($id =~ /^[A-Z0-9]{6}$/) && (@pegs = $fig->by_alias("uni|$id")))   { return @pegs }

    if (($id =~ /^\d+$/) && (@pegs = $fig->by_alias("gi|$id")))            { return @pegs }

    if (($id =~ /^\d+$/) && (@pegs = $fig->by_alias("gi|$id")))            { return @pegs }

    return ();
}

sub cache_html {
    my($fig,$cgi,$html) = @_;

    my @params = sort $cgi->param;
#   print STDERR &Dumper(\@params);
    if ((@params == 3) &&
	($params[0] eq 'prot') &&
	($params[1] eq 'uni') &&
	($params[2] eq 'user'))
    {
	my $prot = $cgi->param('prot');
	if ($prot =~ /^fig\|\d+\.\d+\.peg\.\d+$/)
	{
	    my $user = $cgi->param('user');
	    my $uni  = $cgi->param('uni');
	    my $file = &cache_file($prot,$uni);
	    if (open(CACHE,">$file"))
	    {
		foreach $_ (@$html)
		{
#		    $_ =~ s/user=$user/USER=@@@/g;
		    print CACHE $_;
		}
		close(CACHE);
	    }
	}
    }
}

sub cache_file {
    my($prot,$uni) = @_;

    &FIG::verify_dir("$FIG_Config::temp/Cache");
    return "$FIG_Config::temp/Cache/$prot:$uni";
}

sub handled_by_cache {
    my($fig,$cgi) = @_;

    my @params = sort $cgi->param;

    my $is_sprout = $cgi->param('SPROUT');

    my $i;
    for ($i=0; ($params[$i] =~ /prot|uni|user|SPROUT/); $i++) {}

#    warn "handled_by_cache: i=$i params=@params\n";
    if ($i == @params)
    {
	my $prot = $cgi->param('prot');
	if ($prot =~ /^fig\|\d+\.\d+\.peg\.\d+$/)
	{
	    my $sprout = $is_sprout ? "&SPROUT=1" : "";			
	    my $user = $cgi->param('user');
	    my $uni  = $cgi->param('uni');
	    my $file = &cache_file($prot,$uni);

	    if (open(CACHE,"<$file"))
	    {
		warn "Using local cache $file\n";
		my $html = [];
		my $fig_loc;
		my $to_loc = &FIG::cgi_url;
		$to_loc =~ /http:\/\/(.*?)\/FIG/;
		$to_loc = $1;
		while (defined($_ = <CACHE>))
		{
		    if ((! $fig_loc) && ($_ =~ /http:\/\/(.*?)\/FIG\/chromosomal_clusters.cgi/))
		    {
			$fig_loc = quotemeta $1;
		    }

		    $_ =~ s/http:\/\/$fig_loc\//http:\/\/$to_loc\//g;
		    $_ =~ s/USER=\@\@\@/user=$user$sprout/g;
		    $_ =~ s/\buser=[^&;\"]*/user=$user$sprout/g;

		    push(@$html,$_);
		}
		close(CACHE);
		
		my_show_page($cgi,$html);
		return 1;
	    }
            else
            {
		my $to_loc = &FIG::cgi_url;
                my $h;
                if ($h = get_pins_html($fig, $prot))
                {
		    #
		    # If we're in sprout, strip the form at the end.
		    # We need to also tack on a hidden variable that sets SPROUT=1.
		    #

		    my $html = [];

		    for (split(/\n/, $h))
		    {
			if ($is_sprout)
			{
			    if(/form.*GENDB/)
			    {
				last;
			    }
			    elsif (/type="submit" name=\"(commentary|compute)/)
			    {
				push(@$html, qq(<input type="hidden" name="SPROUT" value="1">\n));
			    }

			    #
			    # Don't offer the recompute option.#
			    #

			    s,Similarity Threshold:.*value="compute at given similarity threshhold" />,,;
			    
			}
			s/user=master:cached/user=$user$sprout/g;
			s/name="user" value="master:cached"/name="user" value="$user"/;
			push(@$html, "$_\n");
		    }
		    
		    my_show_page($cgi, $html);
		    return 1;
                }
	    }
	}
    }
    return 0;
}

sub get_pin {
    my($fig,$peg) = @_;

    my($peg2,%pinned_to,$tuple);

    if ($fig->is_complete($fig->genome_of($peg)))
    {
	foreach $peg2 (map { $_->[0] } $fig->coupled_to($peg))
	{
	    foreach $tuple ($fig->coupling_evidence($peg,$peg2))
	    {
		$pinned_to{$tuple->[0]} = 1;
	    }
	}
	my @tmp = $fig->sort_fids_by_taxonomy(keys(%pinned_to));
	if (@tmp > 0)
	{
	    return @tmp;
	}
    }
    return $fig->sort_fids_by_taxonomy($fig->in_pch_pin_with($peg));
}

sub get_pins_html
{
    my($fig, $peg) = @_;

    my $ua = new LWP::UserAgent;

    my $peg_enc = uri_escape($peg);
    my $my_url_enc = uri_escape($fig->cgi_url());
    my $pins_url = "http://clearinghouse.theseed.org/Clearinghouse/pins_for_peg.cgi";

    my $url = "$pins_url?peg=$peg_enc&fig_base=$my_url_enc";
    my $resp = $ua->get($url);

    if ($resp->is_success)
    {
        return $resp->content;
    }
    else
    {
        return undef;
    }
}

sub my_show_page
{
    my($cgi, $html) = @_;
    
    if ($cgi->param('SPROUT'))
    {
	my $h = { pins => $html };
	print "Content-Type: text/html\n";
	print "\n";
	my $templ = "$FIG_Config::fig/CGI/Html/CCluster_tmpl.html";
	print PageBuilder::Build("<$templ", $h,"Html");
    }
    else
    {
	&HTML::show_page($cgi, $html);
    }
}

sub evidence_codes_link {
    my($cgi) = $_;

    return "<A href=\"Html/evidence_codes.html\" target=\"SEED_or_SPROUT_help\">Ev</A>";
}

sub evidence_codes {
    my($fig,$peg) = @_;

    if ($peg !~ /^fig\|\d+\.\d+\.peg\.\d+$/) { return "" }

    my @codes = $fig->get_attributes($peg, "evidence_code");
    my @pretty_codes = ();
    foreach my $code (@codes) {
	my $pretty_code = $code->[2];
	if ($pretty_code =~ /;/) {
	    my ($cd, $ss) = split(";", $code->[2]);
	    $ss =~ s/_/ /g;
	    $pretty_code = $cd . " in " . $ss;
	}
	push(@pretty_codes, $pretty_code);
    }
    return @pretty_codes;
}



#####################################################################
