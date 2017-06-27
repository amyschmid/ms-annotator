# -*- perl -*-
########################################################################
# Copyright (c) 2003-2009 University of Chicago and Fellowship
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
########################################################################

package gd_tree;

# use Data::Dumper;
# use Carp;

use GD;
use gjonewicklib;
use strict;

#  $string = '((A:1,B:2):3,(C:2,M:4):2);';
#  $tree = parse_newick_tree_str( $string );
#
#  $gd_image = gd_tree::gd_plot_newick( $tree, { bkg_color => [255,255,0] } );
#  print $gd_image->png;
#  print $gd_image->jpg;
#
#  gd_tree::newick_gd_png( $tree, { bkg_color => [255,255,0] } );  #  \*STDOUT
#  gd_tree::newick_gd_jpg( $tree, { bkg_color => [255,255,0] } );
#
#  $bool = gd_tree::gd_has_png()
#  $bool = gd_tree::gd_has_jpg()
#  \%fmt = gd_tree::gd_formats()  # hash keys: gd, jpg and png

{
    my $has_png;
    my $has_jpg;
    my %has = ();

    sub gd_has_png
    {
        return $has_png if defined $has_png;
        return $has_png = $has{ png } if keys %has;
        my $image = new GD::Image( 1, 1 );
        $image->colorAllocate( 255, 255, 255 );
        $has_png = 0;
        eval { $image->png; $has_png = 1; };
        $has_png;
    }

    sub gd_has_jpg
    {
        return 1;
        return $has_jpg if defined $has_jpg;
        return $has_jpg = $has{ jpg } if keys %has;
        my $image = new GD::Image( 1, 1 );
        $image->colorAllocate( 255, 255, 255 );
        $has_jpg = 0;
        eval { $image->jpeg; $has_jpg = 1; };
        $has_jpg;
    }

    sub gd_formats
    {
        if ( ! keys %has )
        {
            my $image = new GD::Image( 1, 1 );
            $image->colorAllocate( 255, 255, 255 );
            foreach my $fmt ( qw( jpg png gd ) )
            {
                $has{$fmt} = 0;
                eval { $image->$fmt; $has{$fmt} = 1; };
            }
        }
        \%has;
    }
}


#===============================================================================
#  newick_gd_png( $tree, \%options )
#===============================================================================
sub newick_gd_png
{
    my ( $tree, $options ) = @_;

    $options ||= {};
    my $file = $options->{ file };
    my $fh;
    if    ( ! $file )                { $fh = \*STDOUT }
    elsif ( ref( $file ) eq 'GLOB' ) { $fh = $file }
    else
    {
        open( $fh, ">$file" )
            or print STERR "Could not open $file.\n" and return 0;
    }

    my $image = gd_plot_newick( $tree, $options );

    print $fh $image->png;

    close( $fh ) if $file && ! ref( $file );
    return 1;
}


#===============================================================================
#  newick_gd_jpg( $tree, \%options )
#===============================================================================
sub newick_gd_jpg
{
    my ( $tree, $options ) = @_;

    $options ||= {};
    my $file = $options->{ file };
    my $fh;
    if    ( ! $file )                { $fh = \*STDOUT }
    elsif ( ref( $file ) eq 'GLOB' ) { $fh = $file }
    else
    {
        open( $fh, ">$file" )
            or print STERR "Could not open $file.\n" and return 0;
    }

    my $image = gd_plot_newick( $tree, $options );

    print $fh $image->jpg;

    close( $fh ) if $file && ! ref( $file );
    return 1;
}


#===============================================================================
#  Make a GD plot of a tree:
#
#    $gd_image          = gd_plot_newick( $node, \%options );
#  ( $gd_image, $hash ) = gd_plot_newick( $node, \%options );
#
#     $node   newick tree root node
#
#  Options:
#
#     bar_position   => position           # D = ll (lower_left)
#     bkg_color      => [ @RGB ]           # D = transparent
#     dy             => pixels             # vertical spacing (D = 12)
#     font           => gb_font_name       # D depends size
#     font_size      => pixels             # synonym for text_size
#     line_color     => [ @RGB ]           # D = black
#     min_dx         => min_node_spacing   # D = 0
#     scale_bar      => length             # D is based on drawing size
#     text_bkg_color => [ @RGB ]           # D = none
#     text_color     => [ @RGB ]           # D = black
#     text_size      => pixels             # D = 0.8 * dy
#     thickness      => pixels             # tree line thickness (D = 1)
#     width          => pixels             # width of tree w/o labels (D = 540)
#     x_scale        => pixels_per_unit_x  # D is scaled to fit width
#
#  All color RGB values are on 0-255 color intensity range
#
#    $hash is a reference to a hash of data about the tree and its layout.
#
#    $hash->{ $node }->{ lbl_rect } is the coordinates (ul, lr) of the label
#        of node refered to my $node.  These can be used to build an image map.
#
#===============================================================================
sub gd_plot_newick
{
    my ( $node, $options ) = @_;
    array_ref( $node ) || die "Bad node passed to text_plot_newick\n";

    #  colors will all be [r,g,b] in 0 - 255 range;
    #  sizes will all be in pixels
    #  work on a local copy of options, so I can write to it

    my %options = ref( $options ) eq 'HASH' ? %$options : ();

    #  Vertical size adjustments:

    my ( $dy_key ) = grep { /^dy/i } keys %options;
    $options{ dy } = $dy_key ? $options{ $dy_key } : undef;

    #  Allow font_size or text_size

    my ( $font_size_key ) = grep { /^fo?nt.*si?z/i || /^te?xt.*si?z/i } keys %options;
    $options{ font_size } = $font_size_key ? $options{ $font_size_key } : undef;

    adjust_font( \%options );  #  This adds options

    #  Horizontal size adjustments:

    my ( $wid_key ) = grep { /^wid/i } keys %options;
    my $width = $options{ width } = $wid_key ? $options{ $wid_key } : 72 * 7.5;

    my ( $min_dx_key ) = grep { /dx/i && ! /la?be?l/i } keys %options;
    $options{ min_dx } = $min_dx_key ? $options{ $min_dx_key } : 0;

    my $max_x = newick_max_X( $node );
    my ( $x_scale_key ) = grep { /x_?scale/i } keys %options;
    my $x_scale = $options{ $x_scale_key }
               || $width / ( $max_x || 1 );
    $options{ x_scale } = $x_scale;

    #  Scale bar:

    my ( $bar_key ) = grep { /bar/i && ! /pos/i } keys %options;
    my $bar_len = $options{ $bar_key };
    $bar_len  = bar_length( $max_x ) if ! defined( $bar_len );
    $options{ bar_len } = $bar_len;

    my $bar_pos;
    if ( $bar_len > 0 )
    {
        my ( $bar_pos_key ) = grep { /bar.*pos/i } keys %options;
        my $bar_val = $options{ $bar_pos_key };
        $bar_pos = $bar_val =~ /up.*rig/i         ? 'ur'     :
                   $bar_val =~ /low.*rig/i        ? 'lr'     :
                   $bar_val =~ /up/i              ? 'ul'     :
                   $bar_val =~ /low/i             ? 'll'     :
                   $bar_val =~ /^(ur|ul|lr|ll)$/i ? $bar_val :
                                                    'll';
        $options{ bar_pos } = $bar_pos;    
        $options{ bar_font } = $options{ font } || 'gdSmallFont';
    }

    #  Line adjustment:

    my ( $thickness_key ) = grep { /thick/i } keys %options;
    my $thickness = $thickness_key ? $options{ $thickness_key } : 1;
    $thickness = int( $thickness + 0.5 );
    $options{ thickness } = $thickness || 1;

    my ( $line_color_key ) = grep { /^lin.*co?lo?r/i } keys %options;
    my $line_color = $line_color_key ? $options{ $line_color_key } : [0,0,0];
    $options{ line_color } = $line_color;

    #  Other colors:

    my ( $bkg_color_key ) = grep { /^b.*k.*g.*co?lo?r/i } keys %options;
    my $bkg_color = $bkg_color_key ? $options{ $bkg_color_key } : undef;
    $options{ bkg_color } = $bkg_color;

    my ( $text_color_key ) = grep { /^te?xt.*co?lo?r/i && ! /bkg/ } keys %options;
    my $text_color = $text_color_key ? $options{ $text_color_key } : [0,0,0];
    $options{ text_color } = $text_color;

    my ( $text_bkg_color_key ) = grep { /^te?xt.*bkg.*co?lo?r/i } keys %options;
    my $text_bkg_color = $text_bkg_color_key ? $options{ $text_bkg_color_key } : undef;
    $options{ text_bkg_color } = $text_bkg_color;

    my $hash = {};
    my $dy = $options{ dy };
    layout_gd_tree( $node, $hash, \%options,
                    int( 2*$thickness + 0.4999 ), int( 0.5*$dy + 0.4999 )
                  );

    render_gd_tree( $node, $hash, \%options );
}


sub bar_length
{
    my ( $max_x ) = @_;
    my $target = 0.4 * $max_x;
    my $e = 10**( int( log($target)/log(10) + 100 ) -100 );
    my $f = $target / $e;
    ( $f >= 10 ? 10 : $f >= 5 ? 5 : $f >= 2 ? 2 : 1 ) * $e;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  ( $root_y, $xmax, $yn ) = layout_gd_tree( $node, $hash, $options, $x0, $y0, $parent )
#
#  GD coordinate 0,0 is upper left corner
#
#  $hash->{ $node } = { x0 => $x0, x => $x, y => $y, y1 => $y1, y2 => $y2,
#                       xmax => $xmax, y0 => $y0, yn => $yn
#                     }
#
#      y0 _ _ _ _ _ _ _ _ _ _ _ _ _ _
#                     +----------+ label_1
#      y1 - - - - +---+
#                 |   +----+ label_2
#      y - - +----+
#                 |    +------+ label_3
#      y2 - -|- - +----+
#            |         |   +--------+  label_4
#            |    |    +---+        |
#      yn _ _|_ _ |_ _ _ _ +---+  label_5
#            |    |                 |
#            x0   x                xmax
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub layout_gd_tree
{
    my ( $node, $hash, $options, $x0, $y0, $parent ) = @_;
    array_ref( $node ) || die "Bad node ref passed to layout_printer_plot\n";
    hash_ref(  $hash ) || die "Bad hash ref passed to layout_printer_plot\n";

    my $x_scale = $options->{ x_scale };
    my $min_dx  = $options->{ min_dx };
    my $dy      = $options->{ dy };

    my $dx = gjonewicklib::newick_x( $node );
    if ( defined( $dx ) )
    {
        $dx *= $x_scale;
        $dx >= $min_dx or $dx = $min_dx;
    }
    else
    {
        $dx = $parent ? $min_dx : 0;
    }
    $dx = int( $dx + 0.4999 );

    my ( $x, $y, $y1, $y2, $xmax, $yn );

    $x = $x0 + $dx;
    my @dl = gjonewicklib::newick_desc_list( $node );

    if ( ! @dl )               #  A tip
    {
        $xmax = $x;
        $y    = $y1 = $y2 = int( $y0 + 0.5 * $dy + 0.4999 );
        $yn   = $y0 + $dy;
    }
    else                       #  A subtree
    {
        $xmax = -1e100;
        my $xmaxi;
        my $yi;
        my @nodelist = ();
        $yn = $y0;

        foreach ( @dl )
        {
            push @nodelist, $_;
            ( $yi, $xmaxi, $yn ) = layout_gd_tree( $_, $hash, $options, $x, $yn, $node );
            if ( $xmaxi > $xmax ) { $xmax = $xmaxi }
        }

        #  Use of nodelist is overkill for saving first and last values,
        #  but eases implimentation of alternative y-value calculations.

        $y1 = $hash->{ $nodelist[ 0] }->{ y };
        $y2 = $hash->{ $nodelist[-1] }->{ y };
        $y   = int( 0.5 * ( $y1 + $y2 ) + 0.4999 );
    }

    $hash->{ $node } = { x0 => $x0, x => $x, y => $y, y1 => $y1, y2 => $y2,
                         xmax => $xmax, y0 => $y0, yn => $yn,
                         parent => $parent
                       };

    #  Scan comment 1 for embedded format information:

    my $c1 = gjonewicklib::newick_c1( $node );
    my %c1 = ();
    foreach ( grep { s/^&&gdTree:\s*// || s/^&&treeLayout:\s*// }
                   ( ref $c1 eq 'ARRAY' ? @$c1 : ( $c1 ) )  # $c1 should be an array ref, but allow a string
            )
    {
        my @data = map { /(\S+)\s*=>?\s*\[\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\]/ ? [ $1, [$2,$3,$4] ] :  # color
                         /(\S+)\s*=>?\s*(\S+)/                                   ? [ $1, $2 ]         :  # other key=value
                                                                                 ()
                       } split /\s*;\s*/, $_;
        foreach ( @data ) { $c1{ $_->[0] } = $_->[1] }
    }

    $hash->{ $node }->{ inherit } = \%c1 if keys %c1;

    ( $y, $xmax, $yn );
}


#
#  $image = render_gd_tree( $node, $hash, $options )
#
sub render_gd_tree
{
    my ( $node, $hash, $options ) = @_;

    my $nodeinfo = $hash->{ $node };
    my $xmax = pict_width( $node, $hash, $options );
    $options->{ xmax } = $xmax;

    #  Start a new image

    my $ymax = int( $nodeinfo->{ yn } + 0.5 * $options->{ dy } + 0.4999 );
    $options->{ ymax } = $ymax;
    my @size = ( $xmax + 1, $ymax + 1 );
    my $image = myNewImage( @size );      # trueColor is false

    #  Background is done outside of my color management:

    my $bkg;
    if ( $options->{ bkg_color } )
    {
        $bkg = $image->colorAllocate( @{ $options->{ bkg_color } } );
    }
    else
    {
        #  Lets us use white on a transparent background (evil).
        $bkg = $image->colorAllocate( 254, 254, 254 );
        $image->transparent( $bkg );
    }
    $options->{ bkg_index } = $bkg;

    #  Draw the tree

    render_gd_tree2( $image, $node, $hash, $options );

    #  Scale bar; oh bother:

    if ( $options->{ bar_pos } && $options->{ bar_font } )
    {
        my $bar_pos = $options->{ bar_pos };
        my $bar_len = int( $options->{ bar_len } * $options->{ x_scale } + 0.5 );
        my ( $x1, $x2, $y, $lo );
        if ( $bar_pos =~ /^.l$/i )
        {
            $x1 = $nodeinfo->{ x0 };
            $x2 = $x1 + $bar_len;
        }
        else
        {
            $x1 = $nodeinfo->{ xmax } - 2 * $options->{ thickness };
            $x2 = $x1 - $bar_len;
        }
        my $lbl_x = int( 0.5*($x1+$x2+1) );
        if ( $bar_pos =~ /^u.$/i )
        {
            $y  = $nodeinfo->{ y0 };
            $lo = 16;
        }
        else
        {
            $y  = $nodeinfo->{ yn };
            $lo = 14;
        }

        $image->setThickness( $options->{ thickness } );
        my $line_color = myGetColor( $image, $options->{ line_color } );
        $image->line( $x1, $y, $x2, $y, $line_color );

        my $text_color = myGetColor( $image, $options->{ text_color } );
        my $opt = { text_color   => $text_color,
                    label_origin => $lo
                  };
        gdPlacedText( $image, "$options->{bar_len}", $options->{ bar_font }, $lbl_x, $y, $opt );
    }

    wantarray ? ( $image, $hash ) : $image;
}


#
#  $image = render_gd_tree2( $image, $node, $hash, $options )
#
sub render_gd_tree2
{
    my ( $image, $node, $hash, $options ) = @_;

    my $nodeinfo = $hash->{ $node };

    #  Are there localized options?

    if ( ref $nodeinfo->{ inherit } eq 'HASH' )
    {
        $options = { %$options };
        foreach ( keys %{ $nodeinfo->{ inherit } } )
        {
            $options->{ $_ } = $nodeinfo->{ inherit }->{ $_ };
        }
    }

    my $x0 = $nodeinfo->{ x0 };
    my $x  = $nodeinfo->{ x };
    my $y  = $nodeinfo->{ y };

    if ( $nodeinfo->{ inherit }->{ bkg_color } )
    {
        my $x1   = max( int( 0.5*($x0+$x+1)), $x0+1 );
        my $xmax = $options->{ xmax };
        my $y0   = $nodeinfo->{ y0 };
        my $yn   = $nodeinfo->{ yn };
        my $bkg_color = myGetColor( $image, $nodeinfo->{ inherit }->{ bkg_color } );
        $image->setThickness( 1 );
        $image->filledRectangle( $x1, $y0, $xmax, $yn, $bkg_color );
    }

    $image->setThickness( $options->{ thickness } );
    my $line_color = myGetColor( $image, $options->{ line_color } );

    my @dl = gjonewicklib::newick_desc_list( $node );
    if ( ! @dl )               #  A tip
    {
        $image->line( $x0, $y, $x, $y, $line_color );
        my $lbl = gjonewicklib::newick_lbl( $node );
        my $font_size = $options->{ font_size };
        if ( $lbl && $font_size )
        {
            my $lbl_x = $x + $options->{ lbl_dx };
            my $font  = $options->{ font };
            my $text_color = myGetColor( $image, $options->{ text_color } );
            my $text_bkg = $options->{ text_bkg_color };
            my $text_bkg_color = $text_bkg ? myGetColor( $image, $text_bkg ) : undef;
            my @rectangle = ();
            if ( $font )
            {
                my $opt = { text_color     => $text_color,
                            ( $text_bkg_color ? ( text_bkg_color => $text_bkg_color ) : () ),
                          # text_border    => 1,
                            label_origin   => 2
                          };
                @rectangle = gdPlacedText( $image, $lbl, $font, $lbl_x, $y, $opt );
            }
            else
            {
                my $len = int( 0.5 * $font_size * length( $lbl ) + 0.5 );
                my $thick = $options->{ lbl_line };
                @rectangle = ( $lbl_x,        int( $y - 0.5*$thick ),
                               $lbl_x + $len, int( $y + 0.5*$thick )
                             );
                $image->setThickness( $thick );
                $image->line( $lbl_x, $y, $lbl_x+$len, $y, $text_bkg_color || $text_color );
            }
            $nodeinfo->{ lbl_rect } = \@rectangle;
        }
    }
    else
    {
        $image->line( $nodeinfo->{ x0 }, $y, $x, $y, $line_color );
        $image->line( $x, $nodeinfo->{ y1 }, $x, $nodeinfo->{ y2 }, $line_color );

        foreach ( @dl ) { render_gd_tree2( $image, $_, $hash, $options ) }
    }

    $image
}


sub pict_width
{
    my ( $node, $hash, $options ) = @_;
    return $hash->{ xmax } if ( $options->{ font_size } < 1 );

    my $xmax;
    my @dl = gjonewicklib::newick_desc_list( $node );
    if ( ! @dl )
    {
        $xmax = $hash->{ $node }->{ x };
        my $lbl  = gjonewicklib::newick_lbl( $node );
        if ( $lbl )
        {
            $xmax += $options->{ lbl_dx } + 2;
            my $font = $options->{ font };
            if ( $font )
            {
                $xmax += textWidth( $lbl, $font );
            }
            else
            {
                $xmax += int( 0.5 * $options->{ font_size } * length( $lbl ) + 0.9999 );
            }
        }
    }
    else
    {
        $xmax = -1e100;
        foreach ( @dl )
        {
            my $x = pict_width( $_, $hash, $options );
            $xmax = $x if $x > $xmax;
        }
        
    }

    $xmax
}


#===============================================================================
#  A subroutine to simplify the placing of text strings in the GD environment.
#  The model is based upon label origin (LO) in HPGL.
#
#   13                          16                          19
#
#
#         3TTTTTTTTT  EEEEEEEEEE 6XX      XX  TTTTTTTTT9
#             TT      EE          XX      XX      TT
#             TT      EE            XX  XX        TT
#   12    2   TT      EEEEEEEE   5     X          TT   8    18
#             TT      EE            XX  XX        TT
#             TT      EE          XX      XX      TT
#         1   TT      EEEEEEEEEE 4XX      XX      TT   7
#
#
#   11                          14                          17
#
#  
#  GD has an odd font position model.  For example, for gdSmallFont:
#  __________________________________________________________________________
#  |O <- string origin point                       ^                     ^
#  |                                         top lead = 3                |
#  |                                _______________v_______________      |
#  |                    XX    XXXXXX                            ^        |
#  |        XX          XX  XX      XX            _________     |        |
#  |  XXXXXX      XXXX  XX  XX          XXXX  XX       ^      upper     font
#  |XX      XX  XX    XXXX    XXXX      XX  XX  XX   lower     case    height
#  |XX      XX  XX      XX        XX    XX  XX  XX    case     rise     = 13
#  |  XXXXXX    XX      XX          XX  XX  XX  XX    rise     = 8       |
#  |XX          XX    XXXX  XX      XX  XX  XX  XX    = 6       |        |
#  |  XXXXXX   |  XXXX  XX    XXXXXX    XX      XX_____v________v____    |
#  |XX      XX |                                      descent = 2        |
#  |_ XXXXXX __|___________________________________________v_____________v___
#  |           |
#  |<- width ->|
#  |    = 6    |
#
#-------------------------------------------------------------------------------
#  Block to ensure that font description hash is loaded
#-------------------------------------------------------------------------------

BEGIN {

my %fontData =
# font                   font           cell    cell    top   uc    lc   des-
# name                  object          width  height  lead  rise  rise  cent
( gdTinyFont       => [ gdTinyFont,       5,      8,     1,    6,    4,   1  ],
  gdSmallFont      => [ gdSmallFont,      6,     13,     3,    8,    6,   2  ],
  gdLargeFont      => [ gdLargeFont,      8,     16,     3,   10,    7,   3  ],
  gdMediumBoldFont => [ gdMediumBoldFont, 7,     13,     2,    9,    6,   2  ],
  gdGiantFont      => [ gdGiantFont,      9,     15,     3,   10,    7,   2  ]
);


sub adjust_font
{
    my ( $options ) = @_;

    my $dy        = $options->{ dy };
    my $font_size = $options->{ font_size };

    my ( $font_key ) = grep { /^font/i && ! ( /si?ze/i ) && ! ( /co?lo?r/i ) } keys %$options;
    my $font = $fontData{ $options->{ $font_key } } ? $options->{ $font_key }
                                                    : undef;

    if ( ! defined( $dy ) )
    {
        if ( ! $font )
        {
            $font = defined( $font_size ) ? fontFromSize( $font_size )
                                          : 'gdSmallFont';
        }
        $font_size = $fontData{$font}->[4] + $fontData{$font}->[6] if $font;
        $dy = max( int( 1.2 * $font_size + 0.5 ), 2 );
    }
    else
    {
        $dy = max( int( $dy + 0.5 ), 2 );
        if ( $font )
        {
            $font_size = $fontData{$font}->[4] + $fontData{$font}->[6];
        }
        else
        {
            $font_size = int( 0.85 * $dy ) if ! defined( $font_size );
            $font = fontFromSize( $font_size );
            $font_size = $fontData{$font}->[4] + $fontData{$font}->[6] if $font;
        }
    }
    $options->{ dy }        = $dy;
    $options->{ font_size } = $font_size;
    $options->{ font }      = $font;

    my $char_width;
    if ( $font )
    {
        $char_width = $fontData{$font}->[1];
        $options->{ lbl_dx } = int( 1.5 * $char_width );
    }
    else
    {
        $char_width = 0.5 * $font_size;
        $options->{ lbl_dx   } = int(       $font_size + 1 );
        $options->{ lbl_line } = int( 0.6 * $font_size + 0.5 );
    }
    $options->{ char_width } = $char_width;

    ( $dy, $font_size, $font )
}


sub fontFromSize
{
    my ( $font_size ) = @_;

    return $font_size <  6 ? undef
         : $font_size < 10 ? 'gdTinyFont'
         : $font_size < 13 ? 'gdSmallFont'
         :                   'gdLargeFont';
}


sub textWidth
{
    my ( $text, $fontname, $extra_chr ) = @_;
    $text && $fontname && $fontData{ $fontname }
        or return undef;
    $fontData{ $fontname }->[1] * ( length( $text ) + ( $extra_chr || 0 ) );
}


sub gdPlacedText
{
    my ( $image, $text, $fontname, $x0, $y0, $options ) = @_;
    $image && $text && $fontname && $fontData{ $fontname }
           && defined $x0 && defined $y0
           or return undef;
    $options = {} unless hash_ref( $options );
    my ( $text_color );
    if ( $options->{ text_color } )
    {
        $text_color = $options->{ text_color }
    }
    else
    {
        $text_color = $image->colorAllocate( 0, 0, 0 );
    }
    my $text_bkg_color = $options->{ text_bkg_color };
    my $textBorder = $options->{ text_border };
    $textBorder = 1 unless defined $textBorder;

    my ( $font, $fWidth, $fHeight, $fLead, $ucRise, $lcRise, $fDescent )
       = @{ $fontData{ $fontname } };

    my $label_origin = int( $options->{ label_origin } || 1 );
    return if $label_origin < 1 || $label_origin > 19 || $label_origin == 10;

    #  Adjust vertical position:

    my @v_offset = ( undef, 2, 1,  0, 2, 1,  0, 2, 1,  0,
                     undef, 3, 1, -1, 3, 1, -1, 3, 1, -1 );
    $y0 -= $fLead + int( 0.5 * $v_offset[ $label_origin ] * $ucRise );
    
    #  Adjust horizontal position:

    my $textWidth = length( $text ) * $fWidth;
    my @h_offset = ( undef,  0,  0,  0, 0, 0, 0, 0, 0, 0,
                     undef, -1, -1, -1, 0, 0, 0, 1, 1, 1 );
    $x0 -= int( 0.5 * $h_offset[ $label_origin ] * $ucRise
                + ( $label_origin >= 17 ? $textWidth     :
                    $label_origin >= 14 ? $textWidth / 2 :
                                          0
                  )
              );
    my @rect = ( $x0-$textBorder,              $y0+$fLead-$textBorder,
                 $x0+$textWidth+$textBorder-2, $y0+$fHeight+$textBorder-1 );
    if ( $text_bkg_color )
    {
        $image->filledRectangle( @rect, $text_bkg_color );
    }
    $image->string( $font, $x0, $y0, $text, $text_color);

    @rect;  # Return the rectangle
}
}  #  End of BEGIN block


#  We can pretty quickly manage colors without worrying about the GD limits.
#  Generally the idea is to not free any colors.  Just let automatic recycling
#  take over if necessary.
#
#  This is a fallback:

sub myGetColor_alt
{
    my $image = shift;
    my ( @RGB ) = map { $_ || 0 } ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_;
    $image->colorAllocate( @RGB );
}


BEGIN
{
my %colorSet;      # We allow concurrent images.  I don't know if GD does.
my $n_stable = 64;

sub myNewImage
{
    my $image = new GD::Image( @_ );   # width, height
    $image->trueColor( 0 );
    # $image->trueColor( 1 );  # GD has a very bad color saved state issue

    # Associate a color mapping to the image
    $colorSet{ $image } = { colorIndex   => {},
                            indexColor   => {},
                            recycleStack => [],
                            n_allo       =>  0,
                            is_stable    => {}
                          };

    $image;
}


sub myGetColor
{
    my $image = shift;

    my $colorSetH     = $colorSet{ $image };
    my $colorIndexH   = $colorSetH->{ colorIndex };
    my $indexColorH   = $colorSetH->{ indexColor };
    my $recycleStackA = $colorSetH->{ recycleStack };

    my ( @RGB ) = map { $_ || 0 } ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_;
    my $name = sprintf '%03d.%03d.%03d', @RGB;
    return $colorIndexH->{ $name } if $colorIndexH->{ $name };
    if ( $colorSetH->{ n_allo } > 250 )
    {
        my ( $del_name, $free_index ) = @{ shift @$recycleStackA };
        $image->colorDeallocate( $free_index );
        delete $colorIndexH->{ $del_name };
        delete $indexColorH->{ $free_index };
        $colorSetH->{ n_allo }--;
    }
    my $index = $image->colorAllocate( @RGB );
    $colorIndexH->{ $name  } = $index;
    $indexColorH->{ $index } = $name;
    if ( ++$colorSetH->{ n_allo } > $n_stable )
    {
        push @$recycleStackA, [ $name, $index ];
    }
    else
    {
        $colorSetH->{ is_stable }->{ $index } = 1;
    }

    $index;
}

sub myFreeColor
{
    my ( $image, $index ) = @_;

    my $colorSetH     = $colorSet{ $image };
    my $colorIndexH   = $colorSetH->{ colorIndex };
    my $indexColorH   = $colorSetH->{ indexColor };
    my $recycleStackA = $colorSetH->{ recycleStack };

    my $name = $indexColorH->{ $index };
    return unless $name;

    if ( $colorSetH->{ is_stable }->{ $index } )
    {
        delete $colorSetH->{ is_stable }->{ $index };
        if ( @$recycleStackA )
        {
            $colorSetH->{ is_stable }->{ $recycleStackA->[0]->[1] } = 1;
            shift @$recycleStackA;
        }
    }
    else
    {
        @$recycleStackA = grep { $_->[1] != $index } @$recycleStackA;
    }

    $image->colorDeallocate( $index );
    delete $colorIndexH->{ $name };
    delete $indexColorH->{ $index };
    $colorSetH->{ n_allo }--;
}

}


sub min       { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max       { $_[0] > $_[1] ? $_[0] : $_[1] }
sub array_ref { ref $_[0] eq 'ARRAY' }
sub hash_ref  { ref $_[0] eq 'HASH' }


1
