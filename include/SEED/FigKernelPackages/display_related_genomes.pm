package display_related_genomes;

use strict;
use gjocolorlib;
eval { use Data::Dumper };

#  Use FIGjs.pm if available:

my $have_FIGjs;
eval { require FIGjs; $have_FIGjs = 1; };

my @clrkey  = qw( 1 2 3 4 5 6 7 );
my $lastkey = 0;

my @colors2 = qw( #cccccc #ddbb99 #ffaaaa #ffcc66 #ffff00 #aaffaa #bbddff #ddaaff );
my @colors1 = map { gjocolorlib::blend_html_colors( $_, 'white' ) } @colors2;

my $breakcolor = '#dddddd';
my $breakwidth = 3;

#===============================================================================
#  display_related_genomes::display()
#
#  index  id  len | type  index  id | ...
#
#  $html = display_related_genomes( $contig_entries, $headings, $options )
#
#     contig_entries  = [ contig_entry, ... ]
#     contig_entry    = [ peg_entry, ... ]
#     peg_entry       = [ contig, index, id, len, mouseover, related_entries ]
#     related_engties = [ related_entry, ... ]
#     related_entry   = [ type, index, id, identity, mouseover ]
#     type            = <-> | -> | -    (bbh, best hit, or no hit)
#     mouseover       = [ pop_up_title_html, pop_up_body_html, href_url ];
#
#     headings        = [ heading, ... ] = column heading information
#     heading         = [ pop_up_title_html, pop_up_body_html, href_url ]
#
#  Options:
#
#     breakcolor =>  $html_color #  Color of genome separator (D = #dddddd)
#     breakwidth =>  $points     #  Width of genome separator (D = 3)
#     id_link    => \&function   #  Function that coverts an id to an html link
#     page       =>  $boolean    #  0 for invoking from CGI; 1 gives HTML page
#
#===============================================================================
sub display
{
    my ( $contig_entries, $headings, $options ) = @_;
    $contig_entries && ref ( $contig_entries ) eq 'ARRAY' && $headings && ref( $headings ) eq 'ARRAY'
        or print STDERR "display_related_genomes requires contig_entries and headings\n"
            and return '';
    $options ||= {};

    $breakcolor  = $options->{ breakcolor } if $options->{ breakcolor };
    $breakwidth  = $options->{ breakwidth } if $options->{ breakwidth };
    my $color_by = $options->{ color_by } || 'identity';
    my $page     = $options->{ page }     || 0;

    #  Genome names

    my ( $genome1, @genomes ) = map { $_->[0] } @$headings;

    my $gen_sep = "<TH BgColor=$breakcolor Width=$breakwidth></TH>";
    my @genome_header = ( "  <TR>",
                          join( "\n    $gen_sep\n", map { genome_column_head( $_ ) } @$headings ),
                          "  </TR>"
                        );

    #  Look at the data contig-by-contig:

    my @contigs;
    my %n_genes;
    foreach ( @$contig_entries )
    {
        my $contig = $_->[0]->[0];
        push @contigs, $contig;
        $n_genes{ $contig } = @$_;
    }

    #  Build the contig navigation menu:

    my $contig_menu = join( '<BR />',
                            "<B>Go to contig:</B>",
                            map { "<A Href=\"#$_\">$_</A> - $n_genes{$_} genes" }
                                @contigs
                          );

    my $contig_mouseover = mouseover( 'Contig navigation', 'Click for menu', $contig_menu, '', '' );

    #  Start writing the html:

    my @html;
    if ($page)
    {
	push @html, "<HTML>",
	            "<HEAD>",
	            "<TITLE>$headings->[0]->[0] Genome comparisons</TITLE>",
                    "</HEAD>",
                    "",
                    "<BODY>";
    }
    push @html, mouseover_JavaScript();

    my $tbl_cols = 4 * @$headings + 3;
    push @html, "<TABLE Cols=$tbl_cols>\n";

    my $contig_entry;
    foreach $contig_entry ( @$contig_entries )
    {
        my $contig = $contig_entry->[0]->[0];

        my ( $peg_entry, $genome_data );

        #  Genome names

        push @html, @genome_header;

        #  Column headers

        push @html, "  <TR>",
                    "    <TH><A Name=$contig $contig_mouseover>Index</A></TH>",
                    "    <TH>Id</TH>",
                    "    <TH>Length</TH>";

        my $genome2;
        foreach $genome2 ( @genomes )
        {
            push @html, "    <TH BgColor=$breakcolor></TH>",
                        "    <TH>Match<BR />type</TH>",
                        "    <TH>Index</TH>",
                        "    <TH>Id</TH>";
        }
        push @html, "  </TR>\n";

        #  Contig data

        foreach $peg_entry ( @$contig_entry )  # per gene information
        {
            #  Write the HTML for each gene in the contig:

            my ( $g1, $id1, $len1, $mouseover, $genome_data ) = @$peg_entry;

            push @html, "  <TR Align=center>",
                        "    <TD>$g1</TD>",
                        linked_datum( $id1, undef, $mouseover ),
                        "    <TD>$len1</TD>";

            my @g2 = @genomes;
            my $genome2;
            foreach my $info2 ( @$genome_data )
            {
                my ( $t2, $g2, $id2, $f_id, $mouseover ) = @$info2;
                $genome2 = shift @g2;

                if ( $g2 )
                {
                    my $color;
                    # Hue goes red, green, blue, red over the inverval 0 - 1
                    # We want 0.003 -> 0.01 -> 0.03 -> 0.10 -> 0.3 -> 1
                    # log( $diff ) / log( 10 ) is log10( $diff ); it starts at
                    #     -3 for identity to 0 at 100% different.
                    # -log( $diff ) / log( 10 ) starts at 3 and becomes 0 at 100% diff.
                    # 2/9 of that takes the hue from blue to red at diff goes from 0 to 1.

                    my $diff = 1 - $f_id + 0.001;
    
                    $color = gjocolorlib::rgb2html(
                                  gjocolorlib::hsb2rgb( -2/9 * log( $diff ) / log( 10 ), # hue
                                                        $t2 eq '<->' ? 0.4 : 0.2,        # saturation
                                                        1.0                              # brightness
                                                      )
                                                  );

                    push @html, $gen_sep,
                                "    <TD BgColor=$color>$t2</TD>",
                                "    <TD BgColor=$color>$g2</TD>",
                                linked_datum( $id2, $color, $mouseover );
                }
                else
                {
                    push @html, $gen_sep,
                                "    <TD>$t2</TD>",
                                "    <TD>&nbsp;</TD>",
                                "    <TD>&nbsp;</TD>";
                }
            }
            push @html, "  </TR>";
        }
    }

    push @html, "</TABLE>";
    if ($page)
    {
	push @html,"</BODY>","</HTML>";
    }
    return join( "\n", @html );
}


#===============================================================================
#  display_related_genomes
#
#  $html = display_related_genomes( $contig_entries, $headings, $options )
#
#     contig_entries  = [ contig_entry, ... ]
#     contig_entry    = [ peg_entry, ... ]
#     peg_entry       = [ contig, gene, peg_len, mouseover, related_entries ]
#     related_engties = [ related_entry, ... ]
#     related_entry   = [ type, contig, gene, indentity_frac, mouseover ]
#     type            = <-> | -> | -    (bbh, best hit, or no hit)
#     mouseover       = [ pop_up_title_html, pop_up_body_html, href_url ];
#
#     headings        = [ heading, ... ] = column heading information
#     heading         = [ pop_up_title_html, pop_up_body_html, href_url ]
#
#  Options:
#
#     color_by   => keyword    -- color matching entries by identity or contig 
#     breakcolor => html_color -- color of genome separator (D = #dddddd)
#     breakwidth => points     -- width of genome separator (D = 3)
#     page       => boolean    -- 0 for invoking from CGI; 1 gives HTML page
#
#===============================================================================
sub display_related_genomes
{
    my ( $contig_entries, $headings, $options ) = @_;
    $contig_entries && ref ( $contig_entries ) eq 'ARRAY' && $headings && ref( $headings ) eq 'ARRAY'
        or print STDERR "display_related_genomes requires contig_entries and headings\n"
            and return '';
    $options ||= {};

    my $color_by = $options->{ color_by } || 'identity';
    $breakcolor  = $options->{ breakcolor } if $options->{ breakcolor };
    $breakwidth  = $options->{ breakwidth } if $options->{ breakwidth };
    my $page     = $options->{ page } || 0;

    #  Genome names

    my ( $genome1, @genomes ) = map { $_->[0] } @$headings;

    my $gen_sep = "<TH BgColor=$breakcolor Width=$breakwidth></TH>";
    my @genome_header = ( "  <TR>",
                          join( "\n    $gen_sep\n", map { genome_column_head( $_ ) } @$headings ),
                          "  </TR>"
                        );

    #  Look at the data contig-by-contig:

    my @contigs;
    my %n_genes;
    foreach ( @$contig_entries )
    {
        my $contig = $_->[0]->[0];
        push @contigs, $contig;
        $n_genes{ $contig } = @$_;
    }

    #  Build the contig navigation menu:

    my $contig_menu = join( '<BR />',
                            "<B>Go to contig:</B>",
                            map { "<A Href=\"#$_\">$_</A> - $n_genes{$_} genes" }
                                @contigs
                          );

    my $contig_mouseover = mouseover( 'Contig navigation', 'Click for menu', $contig_menu, '', '' );

    #  Start writing the html:

    my @html;
    if ($page)
    {
	push @html, "<HTML>",
	            "<HEAD>",
	            "<TITLE>$headings->[0]->[0] Genome comparisons</TITLE>",
                    "</HEAD>",
                    "",
                    "<BODY>";
    }
    push @html, mouseover_JavaScript();

    my $tbl_cols = 4 * @$headings + 3;
    push @html, "<TABLE Cols=$tbl_cols>\n";

    my $contig_entry;
    foreach $contig_entry ( @$contig_entries )
    {
        my $contig = $contig_entry->[0]->[0];

        #  Work out contig colors for each genome:

        my ( $peg_entry, $genome_data );
        my %counts;  # hash with counts per contig for each genome
        my %colors;  # hash mapping contig to color for each genome

        if ( $color_by =~ /contig/ )
        {
            my ( $genome2, $c2, @g2 );
            foreach $peg_entry ( @$contig_entry )  # per gene information
            {
                @g2 = @genomes;
                foreach $genome_data ( @{ $peg_entry->[4] } )
                {
                    $genome2 = shift @g2;
                    $c2 = $genome_data->[1];
                    $counts{ $genome2 }->{ $c2 }++ if $c2;
                }
            }

            foreach $genome2 ( @genomes )
            {
                my @clr = @clrkey;
                my %clr = map  { $_->[0] => ( shift @clr ) || 0 }   # contig->color
                          sort { $b->[1] <=> $a->[1] }              # sort by counts
                          map  { [ $_, $counts{ $genome2 }->{ $_ } ] }   # contig-counts pair
                          keys %{ $counts{ $genome2 } };                 # contigs

                $colors{ $genome2 } = \%clr;
            }
        }

        #  Genome names

        push @html, @genome_header;

        #  Column headers

        push @html, "  <TR>",
                    "    <TH><A Name=$contig $contig_mouseover>Contig</A></TH>",
                    "    <TH>Gene</TH>",
                    "    <TH>Length</TH>";

        my $genome2;
        foreach $genome2 ( @genomes )
        {
            push @html, "    <TH BgColor=$breakcolor></TH>",
                        "    <TH>Match<BR />type</TH>",
                        "    <TH>Contig</TH>",
                        "    <TH>Gene</TH>";
        }
        push @html, "  </TR>\n";

        #  Contig data

        foreach $peg_entry ( @$contig_entry )  # per gene information
        {
            #  Write the HTML for each gene in the contig:

            my ( $c1, $g1, $len1, $mouseover, $genome_data ) = @$peg_entry;

            push @html, "  <TR Align=center>",
                        "    <TD>$c1</TD>",
                        linked_datum( $g1, undef, $mouseover ),
                        "    <TD>$len1</TD>";

            my @g2 = @genomes;
            my $genome2;
            foreach my $info2 ( @$genome_data )
            {
                my ( $t2, $c2, $g2, $f_id, $mouseover ) = @$info2;
                $genome2 = shift @g2;

                if ( $g2 )
                {
                    my $color;
                    if ( $color_by =~ /ident/ )
                    {
                        # Hue goes red, green, blue, red over the inverval 0 - 1
                        # We want 0.003 -> 0.01 -> 0.03 -> 0.10 -> 0.3 -> 1
                        # log( $diff ) / log( 10 ) is log10( $diff ); it starts at
                        #     -3 for identity to 0 at 100% different.
                        # -log( $diff ) / log( 10 ) starts at 3 and becomes 0 at 100% diff.
                        # 2/9 of that takes the hue from blue to red at diff goes from 0 to 1.

                        my $diff = 1 - $f_id + 0.001;
    
                        $color = gjocolorlib::rgb2html(
                                      gjocolorlib::hsb2rgb( -2/9 * log( $diff ) / log( 10 ), # hue
                                                            $t2 eq '<->' ? 0.4 : 0.2,        # saturation
                                                            1.0                              # brightness
                                                          )
                                                      );
                    }
                    else
                    {
                        my $clrkey = $colors{ $genome2 }->{ $c2 };
                        $color = $t2 eq '<->' ? $colors2[$clrkey] : $colors1[$clrkey];
                    }

                    push @html, $gen_sep,
                                "    <TD BgColor=$color>$t2</TD>",
                                "    <TD BgColor=$color>$c2</TD>",
                                linked_datum( $g2, $color, $mouseover );
                }
                else
                {
                    push @html, $gen_sep,
                                "    <TD>$t2</TD>",
                                "    <TD> </TD>",
                                "    <TD> </TD>";
                }
            }
            push @html, "  </TR>";
        }
    }

    push @html, "</TABLE>";
    if ($page)
    {
	push @html,"</BODY>","</HTML>";
    }
    return join( "\n", @html );
}


#-------------------------------------------------------------------------------
#  Build the html string for the column header for a genome:
#
#     $html = genome_column_head( $heading )
#
#-------------------------------------------------------------------------------
sub genome_column_head
{
    my ( $abbrev, $text, $link ) = @{ $_[0] };
    $link = $link ? qq( HRef="$link" Target="$abbrev")  : '';
    my $mouse = $text ? mouseover( $abbrev, $text )     : '';
    $abbrev = qq(<A$link>$abbrev</A>) if $link;
    qq(    <TH ColSpan=3$mouse>$abbrev</TH>);
}


#-------------------------------------------------------------------------------
#  Build the html string for the column header for a genome:
#
#     $html = linked_datum( $datum, $color, $mouseover )
#
#-------------------------------------------------------------------------------
sub linked_datum
{
    my ( $datum, $color, $mouse ) = @_;
    my ( $id, $text, $link ) = ( $mouse && ref( $mouse ) eq 'ARRAY' ) ? @$mouse : ();
    $mouse = $text  ? mouseover( $id, $text || '&nbsp;' ) : '';
    $link  = $link  ? qq( HRef="$link" Target="$id")      : '';
    $color = $color ? qq( BgColor=$color)                 : '';
    $datum = qq(<A$link>$datum</A>) if $link;
    qq(    <TD$color$mouse>$datum</TD>);
}


#-------------------------------------------------------------------------------
#  Escape special characters in text for use in inline javascript string:
#
#     $js_string = js_escape( $text )
#
#-------------------------------------------------------------------------------
sub js_escape { local $_ = $_[0] || ''; s/'/\\'/g; s/"/&quot;/g; $_ }


#-------------------------------------------------------------------------------
#  Return a string for adding an onMouseover tooltip handler:
#
#     mouseover( $title, $text, $menu, $parent, $titlecolor, $bodycolor )
#
#  The code here is virtually identical to that in FIGjs.pm, but makes this
#  SEED independent.
#-------------------------------------------------------------------------------
sub mouseover
{
    if ( $have_FIGjs ) { return &FIGjs::mouseover( @_ ) }

    my ($title, $text, $menu, $parent, $titlecolor, $bodycolor) = @_;

    $title = js_escape( $title );
    $text  = js_escape( $text  );
    $menu  = js_escape( $menu  );

    qq( onMouseover="javascript:if( ! this.tooltip ) this.tooltip=new Popup_Tooltip( this, '$title', '$text', '$menu', '$parent', '$titlecolor', '$bodycolor' ); this.tooltip.addHandler(); return false;")
}


#-------------------------------------------------------------------------------
#  Return a text string with the necessary JavaScript for the mouseover
#  tooltips.
#
#     $html = mouseover_JavaScript()
#
#  The code here is virtually identical to that in FIGjs.pm, but makes this
#  SEED independent.
#-------------------------------------------------------------------------------
sub mouseover_JavaScript
{
    if ( $have_FIGjs ) { return &FIGjs::toolTipScript( ) }

    return <<'End_of_JavaScript';
<SCRIPT Language='JavaScript'>
//
//  javascript class for tooltips and popup menus
//
//  This class manages the information, creating area to draw tooltips and
//  popup menus and provides the event handlers to handle them
//
var DIV_WIDTH=400;
var px;     // position suffix with "px" in some cases
var initialized = false;
var ns4 = false;
var ie4 = false;
var ie5 = false;
var kon = false;
var iemac = false;
var tooltip_name='popup_tooltip_div';

function Popup_Tooltip(object, tooltip_title, tooltip_text,
                       popup_menu, use_parent_pos, head_color,
                       body_color) {
    // The first time an object of this class is instantiated,
    // we have to setup some browser specific settings

    if (!initialized) {
         ns4 = (document.layers) ? true : false;
         ie4 = (document.all) ? true : false;
         ie5 = ((ie4) && ((navigator.userAgent.indexOf('MSIE 5') > 0) ||
                (navigator.userAgent.indexOf('MSIE 6') > 0))) ? true : false;
         kon = (navigator.userAgent.indexOf('konqueror') > 0) ? true : false;
         if(ns4||kon) {
             //setTimeout("window.onresize = function () {window.location.reload();};", 2000);
         }
         ns4 ? px="" : px="px";
         iemac = ((ie4 || ie5) && (navigator.userAgent.indexOf('Mac') > 0)) ? true : false;

         initialized=true;
    }

    if (iemac) { return; } // Give up

    this.tooltip_title = tooltip_title;
    this.tooltip_text  = tooltip_text;

    if (head_color) { this.head_color = head_color; }
    else            { this.head_color = "#333399";  }

    if (body_color) { this.body_color = body_color; }
    else            { this.body_color = "#CCCCFF";  }

    this.popup_menu = popup_menu;
    if (use_parent_pos) {
        this.popup_menu_x = object.offsetLeft;
        this.popup_menu_y = object.offsetTop + object.offsetHeight + 3;
    }
    else {
        this.popup_menu_x = -1;
        this.popup_menu_y = -1;
    }

    // create the div if necessary
    // the div may be shared between several instances
    // of this class

    this.div = getDiv(tooltip_name);
    if (! this.div) {
        // create a hidden div to contain the information
        this.div = document.createElement("div");
        this.div.id=tooltip_name;
        this.div.style.position="absolute";
        this.div.style.zIndex=0;
        this.div.style.top="0"+px;
        this.div.style.left="0"+px;
        this.div.style.visibility=ns4?"hide":"hidden";
        this.div.tooltip_visible=0;
        this.div.menu_visible=0
        document.body.appendChild(this.div);
    }

    // register methods

    this.showTip = showTip;
    this.hideTip = hideTip;
    this.fillTip = fillTip;
    this.showMenu = showMenu;
    this.hideMenu = hideMenu;
    this.fillMenu = fillMenu;
    this.addHandler = addHandler;
    this.delHandler = delHandler;
    this.mousemove = mousemove;
    this.showDiv = showDiv;

    // object state

    this.attached = object;
    object.tooltip = this;
}

function getDiv() {
    if      (ie5 || ie4)      { return document.all[tooltip_name]; }
    else if (document.layers) { return document.layers[tooltip_name]; }
    else if (document.all)    { return document.all[tooltip_name]; }
                                return document.getElementById(tooltip_name);
}

function hideTip() {
    if (this.div.tooltip_visible) {
        this.div.innerHTML="";
        this.div.style.visibility=ns4?"hide":"hidden";
        this.div.tooltip_visible=0;
    }
}

function hideMenu() {
    if (this.div && this.div.menu_visible) {
        this.div.innerHTML="";
        this.div.style.visibility=ns4?"hide":"hidden";
        this.div.menu_visible=0;
    }
}

function fillTip() {
    this.hideTip();
    this.hideMenu();
    if (this.tooltip_title && this.tooltip_text) {
        this.div.innerHTML='<table width='+DIV_WIDTH+' border=0 cellpadding=2 cellspacing=0 bgcolor="'+this.head_color+'"><tr><td class="tiptd"><table width="100%" border=0 cellpadding=0 cellspacing=0><tr><th><span class="ptt"><b><font color="#FFFFFF">'+this.tooltip_title+'</font></b></span></th></tr></table><table width="100%" border=0 cellpadding=2 cellspacing=0 bgcolor="'+this.body_color+'"><tr><td><span class="pst"><font color="#000000">'+this.tooltip_text+'</font></span></td></tr></table></td></tr></table>';
        this.div.tooltip_visible=1;
    }
}

function fillMenu() {
    this.hideTip();
    this.hideMenu();
    if (this.popup_menu) {
        this.div.innerHTML='<table cellspacing="2" cellpadding="1" bgcolor="#000000"><tr bgcolor="#eeeeee"><td><div style="max-height:300px;min-width:100px;overflow:auto;">'+this.popup_menu+'</div></td></tr></table>';
        this.div.menu_visible=1;
    }
}

function showDiv(x,y) {
    winW=(window.innerWidth)? window.innerWidth+window.pageXOffset-16 :
        document.body.offsetWidth-20;
    winH=(window.innerHeight)?window.innerHeight+window.pageYOffset :
        document.body.offsetHeight;
    if (window.getComputedStyle) {
        current_style = window.getComputedStyle(this.div,null);
        div_width = parseInt(current_style.width);
        div_height = parseInt(current_style.height);
    }
    else {
        div_width = this.div.offsetWidth;
        div_height = this.div.offsetHeight;
    }
    this.div.style.left=(((x + div_width) > winW) ? winW - div_width : x) + px;
    this.div.style.top=(((y + div_height) > winH) ? winH - div_height: y) + px;
//    this.div.style.color = "#eeeeee";
    this.div.style.visibility=ns4?"show":"visible";
}

function showTip(e,y) {
    if (!this.div.menu_visible) {
        if (!this.div.tooltip_visible) {
            this.fillTip();
        }
        var x;
        if (typeof(e) == 'number') {
            x = e;
        }
        else {
            x=e.pageX?e.pageX:e.clientX?e.clientX:0;
            y=e.pageY?e.pageY:e.clientY?e.clientY:0;
        }
        x+=2; y+=2;
        this.showDiv(x,y);
        this.div.tooltip_visible=1;
    }
}

function showMenu(e) {
    if (this.div) {
        if (!this.div.menu_visible) {
            this.fillMenu();
        }
        var x;
        var y;

        // if the menu position was given as parameter
        // to the constructor, then use that position
        // or fall back to mouse position

        if (this.popup_menu_x != -1) {
            x = this.popup_menu_x;
            y = this.popup_menu_y;
        }
        else {
            x = e.pageX ? e.pageX : e.clientX ? e.clientX : 0;
            y = e.pageY ? e.pageY : e.clientY ? e.clientY : 0;
        }
        this.showDiv(x,y);
        this.div.menu_visible=1;
    }
}

//  Add the event handler to the parent object.
//  The tooltip is managed by the mouseover and mouseout
//  events. mousemove is captured, too

function addHandler() {
    if (iemac) { return; }  // ignore Ie on mac

    if(this.tooltip_text) {
        this.fillTip();
        this.attached.onmouseover = function (e) {
            this.tooltip.showTip(e);
            return false;
        };
        this.attached.onmousemove = function (e) {
            this.tooltip.mousemove(e);
            return false;
        };
    }

    if (this.popup_menu) {
        this.attached.onclick = function (e) {
                   this.tooltip.showMenu(e);

                   // reset event handlers
                   if (this.tooltip_text) {
                       this.onmousemove=null;
                       this.onmouseover=null;
                       this.onclick=null;
                   }

                   // there are two mouseout events,
                   // one when the mouse enters the inner region
                   // of our div, and one when the mouse leaves the
                   // div. we need to handle both of them
                   // since the div itself got no physical region on
                   // the screen, we need to catch event for its
                   // child elements
                   this.tooltip.div.moved_in=0;
                   this.tooltip.div.onmouseout=function (e) {
                       var div = getDiv(tooltip_name);
                       if (e.target.parentNode == div) {
                           if (div.moved_in) {
                               div.menu_visible = 0;
                               div.innerHTML="";
                               div.style.visibility=ns4?"hide":"hidden";
                           }
                           else {
                               div.moved_in=1;
                           }
                           return true;
                       };
                       return true;
                   };
                   this.tooltip.div.onclick=function() {
                       this.menu_visible = 0;
                       this.innerHTML="";
                       this.style.visibility=ns4?"hide":"hidden";
                       return true;
                   }
                   return false; // do not follow existing links if a menu was defined!

        };
    }
    this.attached.onmouseout = function () {
                                   this.tooltip.delHandler();
                                   return false;
                               };
}

function delHandler() {
    if (this.div.menu_visible) { return true; }

    // clean up

    if (this.popup_menu) { this.attached.onmousedown = null; }
    this.hideMenu();
    this.hideTip();
    this.attached.onmousemove = null;
    this.attached.onmouseout = null;

    // re-register the handler for mouse over

    this.attached.onmouseover = function (e) {
                                    this.tooltip.addHandler(e);
                                    return true;
                                };
    return false;
}

function mousemove(e) {
    if (this.div.tooltip_visible) {
        if (e) {
            x=e.pageX?e.pageX:e.clientX?e.clientX:0;
            y=e.pageY?e.pageY:e.clientY?e.clientY:0;
        }
        else if (event) {
            x=event.clientX;
            y=event.clientY;
        }
        else {
            x=0; y=0;
        }

        if(document.documentElement) // Workaround for scroll offset of IE
        {
            x+=document.documentElement.scrollLeft;
            y+=document.documentElement.scrollTop;
        }
        this.showTip(x,y);
    }
}

function setValue(id , val) {
   var element = document.getElementById(id);
   element.value = val;
}
</SCRIPT>

End_of_JavaScript
}


1;
