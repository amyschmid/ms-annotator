#
# Copyright (c) 2003-2006 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
# 
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License. 
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#


#### END tool_hdr ####

=pod

=head3 raedraw.pm

 A bunch of modules written by Rob to draw different things. Most of these are going to draw images
 using SVG that has many advantages over png/gif images.

 A lot of this is geared towards drawing the genome browser that I am working on. The idea is not only
 to plot sims but other data in tag/value pairs

=cut


package raedraw;
use strict;
use FIG;
use SVG;
use Data::Dumper;
my $fig=new FIG;


=head2 Methods

=head3 new

 Instantiate the script and figure out what we are looking for. These are the options.
 Remeber, this was originally taken from a standalone script I wrote, and then cgi-iffied.

 Returns a pointer to itself

Arguments that can be passed in
-genome		<genome> 			Number to draw as baseline
-compare_to	<genome1,genome2,genome3>    	A reference to a list of similar genomes to plot on image
						Note that this will be expanded with stuff, and some good stuff too


Image size
-width		<width>				Width of the image (default 800) 
-margin		<pixels> 			Left/right margin and gap btwn contigs (default 100) 
-top_marg 	<pixels>			Top margin (default=20)
-bottom_marg	<pixels>			Bottom margin (default=20) (note: was -p)
-box_height	<box height>  		       	Height of the box to color (default=10)

Display options
-rows 		<number>			Number of rows to split image into (default=1)
-box_no_score	<boolean>			Draw boxes around pegs with no score (was: l)
-box_score	<boolean>			Draw boxes around pegs with sims (default=1) (was k) 
-show_function	<peg number>			Show function every <peg number> pegs in target genome
-tick_mark_height <pixels>			Height of the tick marks to show (default=3)
-genome_lines	<boolean>			Draw lines where the genome should be
-twostrands	<boolean>			Put the boxes on two different strands for fwd and reverse (complement)
-bluescale	<boolean>			The default is to have darkest be a red color. This will make it a blue color
-scalefactor	([tag, scale])			An array of tuples on which to scale the numbers in tag/value pairs. Should end up so max no. is 1.

Other things
-abbrev		<boolean>			Use abbreviated names (default=1)
-stopshort 	<peg count>          Stop after drawing <peg count> pegs (just for development)


At the moment, $self->{'genome'} contains the genome that is drawn along the top, and $self->{'compareto'}
contains the comparators. We need to extend comparators so we can include homology and whatnot.

EOF

=cut

sub new {
 my ($class,%args) = @_;
 my $self = bless{},$class;

 # parse out the arguments that are handed in
 foreach my $arg (qw[genome width margin top_marg bottom_marg box_height rows show_function stopshort box_no_score tick_mark_height
 genome_lines maxn maxp bluescale user]) {
  $args{"-".$arg} && ($self->{$arg}=$args{"-".$arg})
 }
 foreach my $arg (qw[box_score abbrev twostrands]) {
  if (defined $args{"-".$arg}) {$self->{$arg}=$args{"-".$arg}} else {$self->{$arg}=$args{"-".$arg}=1}
 }

 return $self unless (defined $args{'-compare_to'});
 
 foreach my $arr ($args{"-scalefactor"}) { 
  $self->{'scale'}->{$arr->[0]}=$arr->[1];
 }

 
 $args{'-compare_to'} && $self->compareto($args{'-compare_to'});

 # predefined things
 $self->{'width'}	=800	unless (defined $self->{'width'});
 $self->{'box_height'}	=10    	unless (defined $self->{'box_height'});
 $self->{'margin'}	=100  	unless (defined $self->{'margin'});
 $self->{'top_marg'}	=20	unless (defined $self->{'top_marg'});
 $self->{'bot_marg'}	=20  	unless (defined $self->{'bot_marg'});
 $self->{'rows'}		=1  	unless (defined $self->{'rows'});
 $self->{'tick_mark_height'}    =3      unless (defined $self->{'tick_mark_height'});
 $self->{'maxn'}	=50  	unless (defined $self->{'maxn'});
 $self->{'maxp'}	=1e-5  	unless (defined $self->{'maxp'});


 # predefine some color things
 $self->{'brightness'}=100;
 $self->{'saturation'}=100;
 $self->{'maxhue'}=0;

 # each genome gets 3 box heights, and we have 2 top/bottom margins
 # we also need to add room for the target genome track.
 $self->{'height'}=(3 * $self->{'box_height'}* (scalar @{$self->compareto()} +1)) + ($self->{'top_marg'} + $self->{'bot_marg'});

 # we have the width of the image, and the effective width from which we calculate scaling of the pegs.
 # the effective width is the width * the number of rows we want
 $self->{'effectivewidth'}=$self->{'width'} * $self->{'rows'};

 $self->{'svg'}=SVG->new(-xmlns=>"http://www.w3.org/2000/svg");

 return $self;
}


=head3 compareto

 Get or set the list of genomes or other things that we will compare this to.
 args: 		A reference to an array of things to add to the comparisons
 returns: 	A reference to an array  of things that we will compare to

 Things we understand are:
 	genome number \d+\.\d+
	tagvalue pairs: must be as a ref to an array, and the first element MUST be 'tagvalue'
		the second element must be the tag, and the optional third and fourth elements 
		are cutoff values - anything below the third cutoff and above the fourth cutoff
		will not be shown.

=cut

sub compareto {
 my ($self, $ct)=@_;
 push (@{$self->{'compareto'}}, @$ct) if ($ct);
 return $self->{'compareto'};
}

=head3 show_function

 Set a boolean to show the function
 args:	 	boolean whether to set the function
 returns:	whether the function is shown or not

=cut

sub show_function {
 my ($self, $sf)=@_;
 if (defined $sf) {$self->{'show_function'}=$sf}
 return $self->{'show_function'}
}


=head3 write_image

 Write out the image to a file
 Args: A file name to write to
 Returns: 1 on success

=cut

sub write_image {
 my ($self, $file)=@_;

#print STDERR &Dumper($self);

 # make sure that we have something to compare to
 unless ($self->compareto()) {die "Couldn't find any genomes to compare to"}
 
 # at the moment this is essentially a sequential call, but i think we may mess with this soon....
 $self->_define_tracks unless ($self->{'track'});
 $self->_scale_image unless ($self->{'rowcount'});
 $self->_draw_image unless ($self->{'drawn'});
 $self->_hz_lines if ($self->{'genome_lines'}); 
 
 open (OUT, ">$file.tmp")  || die "Can't open $file";
 print OUT $self->{'svg'}->xmlify;
 close OUT;

# just fix the header definition
 open(IN, "$file.tmp") || die "Can't open $file.tmp";
 open(OUT, ">$file") || die "Can't open $file";
 while (<IN>)
 {
    if (m#\<svg height\=\"100\%\" width\=\"100\%\" xml\:xlink\=\"http\://www.w3.org/1999/xlink\"\>#) 
    {
        print OUT '<svg height="100%" width="100%" xmlns="http://www.w3.org/2000/svg"  xmlns:xlink="http://www.w3.org/1999/xlink">', "\n";
    }
    else {print OUT}
 }
 close IN;
 close OUT;
 unlink ("$file.tmp");


my $height=(1 + $self->{'rowcount'}) * (((scalar (keys %{$self->{'trackposn'}})) * $self->{'box_height'}* 3) + $self->{'top_marg'}+ $self->{'box_height'} + $self->{'bot_marg'}) +  $self->{'top_marg'}+ $self->{'bot_marg'};

 print STDERR "The image should be width: ", $self->{'width'}, " height: $height\n"; 
 print STDERR "The image is in $file\n";
        
 return ($self->{'width'}, $height);
}


=head3 _define_tracks

 Each genome has a track that contains all the information about the genome, including the boxes, names, and drawings. This is an internal method to define those tracks

 Args: none
 Returns: nothing

=cut

sub _define_tracks {
 my ($self)=@_;
 {
  my $gp=$self->{'top_marg'}+$self->{'box_height'};
  foreach my $simgen ($self->{'genome'}, @{$self->{'compareto'}}) {
   # we have to copy this so we don't alter the one in the array
   my $test_gen=$simgen;
   my $an;
   if (ref($test_gen) eq "ARRAY") {
    # it is a reference to an array (hence tag val pairs, so we want the 2nd item
    $test_gen=$test_gen->[1];
    if ($test_gen eq "pirsf") {$an = "PIR Superfamilies"}
    else {$an=uc($test_gen)}
   }
   elsif ($test_gen eq "subsystems") {
    $an = "FIG Subsystems";
   }
   $self->{'track'}->{$test_gen}=$self->{'svg'}->group(id=>"${test_gen}_group");
   $self->{'trackposn'}->{$test_gen}=$gp; 
   
   # if testgen is a genome (an is not defined) so we need to get the genome name
   
   if (!$an && $self->{'abbrev'}) {$an=$fig->abbrev($fig->genus_species($test_gen))}
   elsif (!$an) {$an=$fig->genus_species($test_gen)}
   $self->{'label'}->{$test_gen}=$an;
   $gp+=3*$self->{'box_height'};
  }
 }
}



=head3 _scale_image

 An internal method to figure out how long the whole genome is and use this as the baseline for the image

 We have somethinglike this for 3 contigs ccc and margins mmm: 
 Row1   mmm ccccccccccc mmm
 Row2   mmm ccc mmm ccc mmm
 Row3   mmm ccccccccccc mmm
 Row4   mmm cc mmm cccc mmm
 The total length is $effectivewidth, but we have to remove 2*rows*margins from this
 then we have to remove # contigs-1 * gap between them
 
 args: 		none
 returns:	none
 
=cut

sub _scale_image {
 my ($self)=@_;
 my %len; my @xs; $self->{'rowcount'}=0;
 my $absorow;
 {
  my $contigcount; 
  foreach my $contig ($fig->all_contigs($self->{'genome'})) {
   $contigcount++;
   $self->{'totallen'}+=$fig->contig_ln($self->{'genome'}, $contig);
   $len{$contig}=$fig->contig_ln($self->{'genome'}, $contig);
  }
 
 
  $contigcount = (($contigcount - 1) * $self->{'margin'}) + (2 * $self->{'rows'}*$self->{'margin'});
  $self->{'xmultiplier'}=$self->{'effectivewidth'}- $contigcount;
  # now we have the total length, the length of each contig, and the amount of free space. For each contig, the scale is
  # the percent of contg/totallen. The space that it takes up is that * free space
  # We also need to know the starts and stops for each row in nt and contigs
  my $offset=0; 
  foreach my $contig (sort {$fig->contig_ln($self->{'genome'}, $b) <=> $fig->contig_ln($self->{'genome'}, $a)} keys %len) {
   $self->{'xoffset'}->{$contig}=$self->{'margin'}+$offset;
 
 #print STDERR "For contig $contig, length is $len{$contig} and start is ", $self->{'xoffset'}->{$contig};
 #print STDERR " and end will be ", $self->{'xoffset'}->{$contig} + $self->{'margin'} + (($len{$contig}/$self->{'totallen'}) * $self->{'xmultiplier'}), "\n";
 
   ### Added rowinfo, but not sure about this
   push (@{$self->{'contigrows'}->{$contig}}, $self->{'rowcount'});
   my $laststart = $self->{'rowinfo'}->{$self->{'rowcount'}}->{$contig}->{'start'}=$self->{'xoffset'}->{$contig};
   my $rowend=$self->{'xoffset'}->{$contig} + (($len{$contig}/$self->{'totallen'}) * $self->{'xmultiplier'});
   while (($rowend-$laststart) > ($self->{'width'} - (2 * $self->{'margin'}))) {
    $laststart= 
   	 $self->{'rowinfo'}->{$self->{'rowcount'}+1}->{$contig}->{'start'}=
	 $self->{'rowinfo'}->{$self->{'rowcount'}}->{$contig}->{'end'}=
		 $self->{'rowinfo'}->{$self->{'rowcount'}}->{$contig}->{'start'}+($self->{'width'} - (2 * $self->{'margin'}));
    $self->{'rowcount'}++;
    push (@{$self->{'contigrows'}->{$contig}}, $self->{'rowcount'});
   }
   #$self->{'rowcount'}++;
   #push (@{$self->{'contigrows'}->{$contig}}, $self->{'rowcount'});
   $offset=$self->{'rowinfo'}->{$self->{'rowcount'}}->{$contig}->{'end'}=$rowend;
   #### End added  rowinfo section
  }
 }

  ##NOTE : ROWINFO HAS MARGINS INCLUDED

 # we want to find the absolute starts and stops for each row
 # print out the saved information
 for (my $i=0; $i <= $self->{'rowcount'}; $i++) {
  foreach my $c (keys %{$self->{'rowinfo'}->{$i}}) {
   if (!defined $absorow->{$i}->{'start'} || $absorow->{$i}->{'start'} > $self->{'rowinfo'}->{$i}->{$c}->{'start'}) 
   	 {$absorow->{$i}->{'start'} = $self->{'rowinfo'}->{$i}->{$c}->{'start'}}
   if (!defined $absorow->{$i}->{'end'}   || $absorow->{$i}->{'end'} < $self->{'rowinfo'}->{$i}->{$c}->{'end'})   
  	 {$absorow->{$i}->{'end'}   = $self->{'rowinfo'}->{$i}->{$c}->{'end'}}
  }
 }


 ### Define the rows
 for (my $row=0; $row <=$self->{'rowcount'}; $row++) {
  my $transform=$row * (((scalar keys %{$self->{'trackposn'}}) * $self->{'box_height'} * 3) + $self->{'top_marg'} + $self->{'bot_marg'});
  my $xtrans=$absorow->{$row}->{'start'} - $self->{'margin'};
  $self->{'rowgroup'}->{$row}=$self->{'svg'}->group(id=>"row_$row", transform=>"translate(-$xtrans, $transform)");
  
  # add genome labels to the rows
  foreach my $simgen (keys %{$self->{'trackposn'}}) {
   $self->{'rowgroup'}->{$row}->text(id=>"${simgen}_${row}_label", x=>$xtrans, y=>$self->{'trackposn'}->{$simgen}, textLength=>100, lengthAdjust=>"spacingAndGlyphs",
     style=>{'font-family'=>"Helvetica", 'font-size'=>"10", fill=>"black",})->cdata($self->{'label'}->{$simgen});
  }
 }
} # end _scale_image

=head3 _draw_genome

 An internal method to draw the genome that we are comparing to, and to define the locations of the pegs (perhaps)

 args:		none
 returns:	none

=cut

sub _draw_image {
 my ($self)=@_;
 $self->{'drawn'}=1;
 my $defs=$self->{'track'}->{$self->{'genome'}}->defs;
 my $time=time; my $pegcount;
 foreach my $peg ($fig->pegs_of($self->{'genome'})) {
  $pegcount++;
  last if ($self->{'stopshort'} && $self->{'stopshort'} == $pegcount);
  if ($self->{'user'} eq "master:RobE") {unless ($pegcount % 100) {print STDERR "Pegs done: $pegcount\n"}}
  # Define the location of the box once per peg
  # also use this to figure out which row to add it to
  my @loc=$fig->feature_location($peg);
  $loc[0] =~ m/^(.*)\_(\d+)\_(\d+)$/;
  my ($contig, $start, $stop)=($1, $2, $3);
  my $len=abs($stop-$start);
  
  # if the orf is in the same direction want the sim on top, if not want it below
  my $x=$self->{'xoffset'}->{$contig} + (($start/$self->{'totallen'}) * $self->{'xmultiplier'});
  my $boxwidth = (abs($stop-$start)/$self->{'totallen'})*$self->{'xmultiplier'};

  # figure out the correct row for the current location. The row is after we have split up the genome
  my $row;
  foreach my $addrow (@{$self->{'contigrows'}->{$contig}}) {
   if (abs($x) >= abs($self->{'rowinfo'}->{$addrow}->{$contig}->{'start'}) && abs($x) <= abs($self->{'rowinfo'}->{$addrow}->{$contig}->{'end'})) {$row=$addrow; last}
   elsif (abs($x) <= abs($self->{'rowinfo'}->{$addrow}->{$contig}->{'start'}) && abs($x) >= abs($self->{'rowinfo'}->{$addrow}->{$contig}->{'end'})) {$row=$addrow; last}
   #if ($x >= $self->{'rowinfo'}->{$addrow}->{$contig}->{'start'} && $x < $self->{'rowinfo'}->{$addrow}->{$contig}->{'end'}) {$row=$addrow; last}
  }
  unless (defined $row) {
   print STDERR "Couldn't get a row for $contig looking for a start of $x (real start: $start). These are the starts:\n";
   print STDERR "These are the contigrows: ", join " ", @{$self->{'contigrows'}->{$contig}}, "\n";
   print STDERR map {"$_: " . $self->{'rowinfo'}->{$_}->{$contig}->{'start'} . "\n"} @{$self->{'contigrows'}->{$contig}};
   print STDERR "These are the stops\n";
   print STDERR map {"$_: " . $self->{'rowinfo'}->{$_}->{$contig}->{'end'} . "\n"} @{$self->{'contigrows'}->{$contig}};
   print STDERR "\n";
   exit -1;
  }

  # show the function if we are supposed to
  if ($self->{'show_function'} && !($pegcount % $self->{'show_function'})) {$self->_add_functions($defs, $peg, $x, $boxwidth, $row)}
 

  # add a tick mark for the peg
  my $sl=$self->{'trackposn'}->{$self->{'genome'}}-$self->{'tick_mark_height'}; # start line
  my $el=$self->{'trackposn'}->{$self->{'genome'}}+$self->{'tick_mark_height'}; # end line
  $self->{'rowgroup'}->{$row}->line(x1=>$x, x2=>$x, y1=>$sl, y2=>$el);
  $self->{'rowgroup'}->{$row}->line(x1=>$x+$boxwidth, x2=>$x+$boxwidth, y1=>$sl, y2=>$el);
  
 
  #if we want the empty boxes draw them first and then the color thing will overwrite.
  if ($self->{'box_no_score'}) {
   foreach my $simgen (keys %{$self->{'trackposn'}}) {
    my $y=$self->{'trackposn'}->{$simgen};
    if ($start > $stop) {$y-=$self->{'box_height'}}
    $self->{'rowgroup'}->{$row}->rect(x=>$x, y=>$y, height=>$self->{'box_height'}, 
        width=>$boxwidth, id=>"${peg}_$y", style => {stroke => "rgb(0,0,0)", fill => "none"});
   }
  }
 
  # now for each peg we need to figure out what we need to add
  # figure out the strand
  my $comp=0;
  if ($self->{'twostrands'} && $start > $stop) {$comp=1}
  foreach my $match (@{$self->compareto()}) {
   next unless ($match);
   if (ref($match) eq "ARRAY" && $match->[0] eq "tagvalue") {
    # deal with tag value pairs
    $self->_plot_tag_value($peg, $x, $boxwidth, $row, $match);
   }
   elsif ($match eq "subsystems") {
    $self->_plot_subsystems($peg, $x, $boxwidth, $row, $match);
   }
   elsif ($match =~ /^\d+\.\d+/) {
    # it is a genome
    $self->_plot_sims($peg, $x, $boxwidth, $row, $match, $comp);
   }
   else {
    print STDERR "No support for matches to $match yet\n";
   }
  }
 }
}


=head3 _add_functions

 An internal method to add the functions to the image.
 Args: 		definitions (defs), peg, position (x) where to add the text, box width, row (y group) to add the text
 Returns:	None

 I want to make the text at 45 degrees, so we are going to have to make a path and then put the text on the path.
 This is tricky. What we do is define a horizontal path from the point where we want to start to the end of the image
 and we rotate it by 45 degrees. Then we put the text onto that path we have just created. Neato, huh?

=cut

sub _add_functions {
 my ($self, $defs, $peg, $position, $boxwidth, $row)=@_;
 return unless ($self->{'show_function'});
 my $funclocx=$position+($boxwidth/2); # this should be the middle of the box?
 my $funclocy=$self->{'trackposn'}->{$self->{'genome'}}-2;
 my $funcendx=$self->{'effectivewidth'}+$funclocx; # this doesn't matter it just needs to be off the image!
 $defs->path(id=>"${peg}_line", d=>"M $funclocx $funclocy L $funcendx $funclocy", transform=>"rotate(-45, $funclocx $funclocy)");
  

 # now just add the text as a textPath
 $self->{'rowgroup'}->{$row}->text(style=>{'font-family'=>"Helvetica, sans-serif", 'font-size'=>"2", fill=>"black",})
      ->textPath(id=>"${peg}_function", '-href'=>"#${peg}_line")
      ->cdata(scalar $fig->function_of($peg));
}


=head3 _plot_subsystems
 
 An internal method to plot a box if the peg is in a subsystem
 Takes the following as arguments:
   peg, position (x) where to draw the box, width of the box to draw, row (y group) 

 I am going to try and color the box based on some factor of the subsystems. I will keep saturation and brightness at 50%
 and then vary the hue from 0-360

=cut

sub _plot_subsystems {
 my ($self, $peg, $x, $boxwidth, $row)=@_;
 my $y=$self->{'trackposn'}->{'subsystems'} - (0.5 * $self->{'box_height'});
 
 unless (defined $self->{'maxhue'}) {$self->{'maxhue'}=-5}
 if ($self->{'maxhue'} > 360) {
  $self->{'maxhue'}=-5;
  $self->{'brightness'}-=10; 
  if ($self->{'brightness'} < 0) {
   $self->{'brightness'}=100;
   $self->{'saturation'}-=10;
  }
 }
 
 foreach my $ss (sort $fig->subsystems_for_peg($peg)) 
 {
  next if ($ss->[0] =~ /essential/i);
  next if ($self->{'subsystems'}->{$peg}->{$ss->[0]});
  $self->{'subsystems'}->{$peg}->{$ss->[0]}=1;
  unless ($self->{'hue'}->{$ss->[0]}) {$self->{'hue'}->{$ss->[0]}=$self->{'maxhue'}+5; $self->{'maxhue'}+=5}
  my @color=($self->{'hue'}, $self->{'saturation'}, $self->{'brightness'});
  if ($self->{'bluescale'}) {($color[0], $color[3])=($color[3], $color[0])}
  if ($self->{'box_score'}) {
   $self->{'rowgroup'}->{$row}->rect(x=>$x, y=>$y, height=>$self->{'box_height'}, 
        width=>$boxwidth, id=>$ss->[0].".".$peg, style => {stroke => "rgb(0,0,0)", fill => "rgb(@color)"});
  } else {
    $self->{'rowgroup'}->{$row}->rect(x=>$x, y=>$y, height=>$self->{'box_height'}, 
        width=>$boxwidth, id=>$ss->[0].$peg, style => {stroke => "none", fill => "rgb(@color)"}); 
  }
 }
}

=head3 _plot_tag_value
 
 An internal method to plot tag value pairs.
 Takes the following as arguments:
   peg, position (x) where to draw the box, width of the box to draw, row (y group) 
   and then a reference to the tagvalue pairs

   The last element must be a reference to an array with the following four items:
   'tagvalue' (ignored - just a boolean for this)
   'tag' -- tag that is used for the plot
   'minimum' -- optional, if supplied minimum cutoff
   'maximum' -- optional, if supplied maximum cutoff

=cut

sub _plot_tag_value {
 my ($self, $peg, $x, $boxwidth, $row, $tv)=@_;
 my $y=$self->{'trackposn'}->{$tv->[1]} - (0.5 * $self->{'box_height'});
 
 my $min=$tv->[2] if ($tv->[2]);
 my $max=$tv->[3] if ($tv->[3]);

 my @attr = $fig->feature_attributes($peg);
 if (@attr > 0) {
 foreach (@attr) {
    next if ($self->{'addedtv'}->{$tv->[1].$peg}); # specifically avoid dups with tag/value pairs
    $self->{'addedtv'}->{$tv->[1].$peg}=1;
    my($fid,$tag,$val,$url) = @$_;
    next unless (lc($tag) eq lc($tv->[1]));
    
    # we are going to test if it is a number. If it is not a number, we don't want to check min/max
    my $number=1;
    eval {
     use warnings; # make sure we warn
     local $SIG{__WARN__} = sub {die $_[0]}; # die if there is a warning
     $val+=0; # generate the warning
    };
    undef $number if ($@);
    
    next if ($number && $min && $val < $min);
    next if ($number && $max && $val > $max);
    # now color the box. We can do this based on the number. We should probably have a scale factor here, but I don't know what it is
    # so we'll let people supply it.
    my @color=(0,1,1); # maybe 1,1,1?
    if ($number) {
     @color=map {int(255 * $_)} my_color($number * $self->{'scale'}->{$tv->[1]});
    }
    if ($self->{'bluescale'}) {($color[0], $color[3])=($color[3], $color[0])}
    if ($self->{'box_score'}) {
    $self->{'rowgroup'}->{$row}->rect(x=>$x, y=>$y, height=>$self->{'box_height'}, 
         width=>$boxwidth, id=>$tv->[1].$peg, style => {stroke => "rgb(0,0,0)", fill => "rgb(@color)"});
    } else {
     $self->{'rowgroup'}->{$row}->rect(x=>$x, y=>$y, height=>$self->{'box_height'}, 
         width=>$boxwidth, id=>$tv->[1].$peg, style => {stroke => "none", fill => "rgb(@color)"});
    } 
  }
 }
}

  

=head3 _plot_sims

 An internal method to add the similarities to the image
 Args: 		peg, position (x) where to add the text, width of the box to draw, row (y group) to add the text,
 		genome to compare to, flag for whether to put below the line (complement essentially)
 Returns:       None

=cut
        

sub _plot_sims {
 ##### PLOT SIMS ##### 
 # find the sims for the genomes that we need
 my ($self, $peg, $x, $boxwidth, $row, $simgen, $comp)=@_;
 my %seensims; #  genomes we have seen sims from for this peg. So we only get the best hit
 foreach my $sim ($fig->sims($peg, $self->{'maxn'}, $self->{'maxp'}, 'fig')) {
  next unless ($fig->genome_of($$sim[1]) == $simgen && defined $self->{'trackposn'}->{$fig->genome_of($$sim[1])});
  # figure out the y posn
  my $y=$self->{'trackposn'}->{$simgen};
  if ($comp) {$y-=$self->{'box_height'}}
  # now we just need to color based on the sim
  my @color=map {int(255 * $_)} my_color($$sim[2]); # this will adjust it for rgb 0-255
  # color at the moment is on a red based scale, but I'd rather have it on a blue based scale as i am in a blue mood
  # (though not down in the dumps, I just like the color blue)
  # swap r and b, leave g the same
  if ($self->{'bluescale'}) {($color[0], $color[3])=($color[3], $color[0])}
  
  #now we need to make a box:
  #x from $x length $boxwidth
  #y from $y length $boxheight
  #color is in @{$colorgenome->{$fig->genome_of($$sim[1])}}
  if ($self->{'box_score'}) {
   $self->{'rowgroup'}->{$row}->rect(x=>$x, y=>$y, height=>$self->{'box_height'}, 
        width=>$boxwidth, id=>$$sim[1].$peg, style => {stroke => "rgb(0,0,0)", fill => "rgb(@color)"});
  } else {
   $self->{'rowgroup'}->{$row}->rect(x=>$x, y=>$y, height=>$self->{'box_height'}, 
        width=>$boxwidth, id=>$$sim[1].$peg, style => {stroke => "none", fill => "rgb(@color)"});
  } 
 }
 # lastx is used as the translate function x factor. We need to set it to the end position less the margin so we still have some margin (for error)
}



=head3 _hz_lines

 An internal method to add horizontal lines to an image where the genomes are
 Args:          None
 Returns:       None

=cut
        

sub _hz_lines {
 my ($self)=@_;
 for (my $row=0; $row <= $self->{'rowcount'}; $row++) {
  foreach my $contig (keys %{$self->{'rowinfo'}->{$row}}) { 
   my ($start, $end)=($self->{'rowinfo'}->{$row}->{$contig}->{'start'}, $self->{'rowinfo'}->{$row}->{$contig}->{'end'});
   foreach my $simgen (keys %{$self->{'trackposn'}}) {
    $self->{'rowgroup'}->{$row}->line(id=>"line_${simgen}_${contig}_$row", 
         x1=>$start, x2=>$end, y1=>$self->{'trackposn'}->{$simgen}, y2=>$self->{'trackposn'}->{$simgen});
   }
  }
 }
}
 


#### COLORS. 
#
# This has been stolen from protein.cgi written by Gary because I don't
# understand enough about colors

sub my_color {
    my $percent=shift;
    return (255,255,255) unless ($percent);
    $percent=1-$percent/100; # we want the more similar ones to be darker  
    my $hue = 5/6 * $percent - 1/12;
    my $sat = 1 - 10 * $percent / 9;
    my $br  = 1;
    return hsb2rgb( $hue, $sat, $br );
}


sub heat_map_color {
    my ($self, $fraction, $color)=@_;
    my $hue=$fraction/100;
    my @color=hsb2rgb($hue, 0.6, 1);# saturation and brightness are fixed at 100%
    if ($color eq 'blue') {($color[2], $color[0])=($color[0], $color[2])}
    elsif ($color eq 'green') {($color[1], $color[0])=($color[0], $color[1])}
    return @color;
}



#
#  Convert HSB to RGB.  Hue is taken to be in range 0 - 1 (red to red);
#

sub hsb2rgb {
    my ( $h, $s, $br ) = @_;
    $h = 6 * ($h - floor($h));      # Hue is made cyclic modulo 1
    if ( $s  > 1 ) { $s  = 1 } elsif ( $s  < 0 ) { $s  = 0 }
    if ( $br > 1 ) { $br = 1 } elsif ( $br < 0 ) { $br = 0 }
    my ( $r, $g, $b ) = ( $h <= 3 ) ? ( ( $h <= 1 ) ? ( 1,      $h,     0      )
                                      : ( $h <= 2 ) ? ( 2 - $h, 1,      0      )
                                      :               ( 0,      1,      $h - 2 )
                                      )
                                    : ( ( $h <= 4 ) ? ( 0,      4 - $h, 1      )
                                      : ( $h <= 5 ) ? ( $h - 4, 0,      1      )
                                      :               ( 1,      0,      6 - $h )
                                      );
    ( ( $r * $s + 1 - $s ) * $br,
      ( $g * $s + 1 - $s ) * $br,
      ( $b * $s + 1 - $s ) * $br
    )
}

sub floor {
    my $x = $_[0];
    defined( $x ) || return undef;
    ( $x >= 0 ) || ( int($x) == $x ) ? int( $x ) : -1 - int( - $x );
}

1;
