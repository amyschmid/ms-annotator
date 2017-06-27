#
# Copyright (c) 2003-2011 University of Chicago and Fellowship
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

#  This is a collection point for miscellaneous functions created by GJO
#  that are useful in multiple scripts within the SEED.  They could be put
#  in FIG.pm, but these are less central.

package FIGgjo;

use gjocolorlib;
use strict;

#------------------------------------------------------------------------------
#  Default pallets for colorizing functions and roles.
#------------------------------------------------------------------------------

my $overflow_color = '#DDDDDD';
my $comment_color  = '#BBBBBB';
my $gray_color     = '#BBBBBB';

my @pallets = ( [ '#DDCCAA', '#FFAAAA', '#FFCC66', '#FFFF44',
                  '#CCFF66', '#88FF88', '#88EECC', '#88FFFF',
                  '#66CCFF', '#AAAAFF', '#CC88FF', '#FFAAFF'
                ],
                [ '#DDCCAA', '#FFAAAA', '#FFCC66', '#FFFF44',
                  '#AAFFAA', '#BBBBFF', '#FFAAFF'
                ]
              );

#  Find the smallest pallet that fits all of the colors

sub choose_pallet
{
    my ( $ncolor, $pallets ) = @_;
    my @pals = sort { @$b <=> @$a }  #  most to fewest colors
               ( $pallets ? @$pallets : @pallets );
    my $pallet = $pals[0];
    foreach ( @pals )
    {
        last if $ncolor > @$_;
        $pallet = $_;
    }
    wantarray ? @$pallet : $pallet;
}


#------------------------------------------------------------------------------
#  colorize_roles creates a hash relating functions to html versions in which
#  identical roles are colored the same.  The functions cannot be html escaped
#  since they will then split on the ; at the end of the character codes.
#
#     %cell_info = colorize_roles(  @functions )
#     %cell_info = colorize_roles( \@functions )
#     %cell_info = colorize_roles( \%functions )
#     %cell_info = colorize_roles( \@functions, $current_func )
#     %cell_info = colorize_roles( \%functions, $current_func )
#
#  where:
#
#     @functions  list of functions
#     %functions  hash of functions (key does not matter)
#     %cell_info  hash of [ html_text, cell_color ], keyed by function
#------------------------------------------------------------------------------
sub colorize_roles
{
    my $role_clr = &role_colors( @_ );

    #  Make nonredundant list of functions:

    my %funcs = map { $_ => 1 }
                ( ref( $_[0] ) eq 'ARRAY' ? @{ $_[0] }
                : ref( $_[0] ) eq 'HASH'  ? map { $_[0]->{$_} } keys %{$_[0]}
                : @_
                );

    my $current_func = ref( $_[0] ) && defined $_[1] ? $_[1] : '';
    $funcs{ $current_func } = 1  if $current_func ne '';

    $current_func =~ s/ +#.*$//;

    foreach my $func ( keys %funcs )
    {
        if ( $func !~ /\S/ ) {
            $funcs{ $func } = [ '&nbsp;', '' ];
            next;
        }

        my ( $core_func, $comment ) = $func =~ /^(.*\S)( +#.*)$/ ? ( $1, $2 ) : ( $func, '' );
        my $is_current = $current_func eq $core_func;

        # Split roles:

        my @roles = split /( +\/ +| +@ +| *; +)/, $core_func;
        push @roles, $comment if $comment;

        $funcs{ $func } = join( '', map { colored_role( $_, $role_clr, $is_current ) } @roles );
    }

    wantarray ? %funcs : \%funcs;
}


#------------------------------------------------------------------------------
#  role_cell provides the html for a table cell containing a colorized role.
#
#     $role = colored_role( $role, \%role_clr, $is_curr )
#
#------------------------------------------------------------------------------
sub colored_role
{
    my ( $role ) = @_;
    colored_span( html_esc( $role ), get_role_color( @_ ) );
}


#------------------------------------------------------------------------------
#  colorize_roles creates a hash relating functions to html versions in which
#  identical roles are colored the same.
#
#     %colorized_function = colorize_roles(  @functions )
#     %colorized_function = colorize_roles( \@functions )
#     %colorized_function = colorize_roles( \%functions )
#     %colorized_function = colorize_roles( \@functions, $current_func )
#     %colorized_function = colorize_roles( \%functions, $current_func )
#
#  where:
#
#     @functions           list of functions
#     %functions           hash of functions (key does not matter)
#     %colorized_function  hash of colorized html text keyed by function
#------------------------------------------------------------------------------
# sub colorize_roles
# {
#     my $role_clr = role_colors( @_ );
# 
#     my @funcs = ref( $_[0] ) eq 'ARRAY' ? @{ $_[0] }
#               : ref( $_[0] ) eq 'HASH'  ? map { $_[0]->{$_} } keys %{$_[0]}
#               : @_;
# 
#     push @funcs, $_[1] if $_[1] && ref( $_[0] );
#     
#     my %funcs = map { $_ => 1 } @funcs;
# 
#     my %formatted_func = ();
#     foreach my $func ( keys %funcs )
#     {
#         $formatted_func{ $func }
#            = join( '', map { colored_span( html_esc( $_ ), $role_clr->{ $_ } ) }
#                        split /( +[#!].*$| *\; +| +\/ | +\@ +)/, $func
#                  );
#     }
# 
#     wantarray ? %formatted_func : \%formatted_func
# }


#------------------------------------------------------------------------------
#  colorize_roles_in_cell creates a hash relating functions to html versions
#  in which identical roles are colored the same.
#
#     %cell_info = colorize_roles_in_cell(  @functions )
#     %cell_info = colorize_roles_in_cell( \@functions )
#     %cell_info = colorize_roles_in_cell( \%functions )
#     %cell_info = colorize_roles_in_cell( \@functions, $current_func )
#     %cell_info = colorize_roles_in_cell( \%functions, $current_func )
#
#  where:
#
#     @functions  list of functions
#     %functions  hash of functions (key does not matter)
#     %cell_info  hash of [ html_text, cell_color ], keyed by function
#------------------------------------------------------------------------------
sub colorize_roles_in_cell
{
    my ( $role_clr, $clr_priority ) = role_colors( @_ );

    #  Make nonredundant list of functions:

    my %seen;
    my @funcs = grep { $_ && ! $seen{$_}++ }
                ( ref( $_[0] ) eq 'ARRAY' ? @{ $_[0] }
                : ref( $_[0] ) eq 'HASH'  ? map { $_[0]->{$_} } keys %{$_[0]}
                : @_
                );
    push @funcs, $_[1] if $_[1] && ! $seen{ $_[1] };

    my ( @parts, $cell, $c, $t );
    my %cell_info = ();
    foreach my $func ( @funcs )
    {
        $cell_info{ $func } = cell_guts( $func, $role_clr, $clr_priority );
    }

    wantarray ? %cell_info : \%cell_info
}


#------------------------------------------------------------------------------
#  colorize_roles_in_cell_2 creates a hash relating functions to html versions
#  in which identical roles are colored the same.
#
#     %cell_info = colorize_roles_in_cell_2(  @functions )
#     %cell_info = colorize_roles_in_cell_2( \@functions )
#     %cell_info = colorize_roles_in_cell_2( \%functions )
#     %cell_info = colorize_roles_in_cell_2( \@functions, $current_func )
#     %cell_info = colorize_roles_in_cell_2( \%functions, $current_func )
#
#  where:
#
#     @functions  list of functions
#     %functions  hash of functions (key does not matter)
#     %cell_info  hash of [ html_text, cell_color ], keyed by function
#------------------------------------------------------------------------------
sub colorize_roles_in_cell_2
{
    my ( $role_clr, $clr_priority ) = role_colors( @_ );

    #  Make nonredundant list of functions:

    my %seen;
    my @funcs = grep { $_ && ! $seen{$_}++ }
                ( ref( $_[0] ) eq 'ARRAY' ? @{ $_[0] }
                : ref( $_[0] ) eq 'HASH'  ? map { $_[0]->{$_} } keys %{$_[0]}
                : @_
                );

    my $current_func = ref( $_[0] ) && $_[1] ? $_[1] : '';
    $current_func =~ s/ +[#!].*$//;

    my ( @parts, $cell, $c, $t );
    my %cell_info = ();
    foreach my $func ( @funcs )
    {
        # Split multidomain proteins, displaying roles side-by-side:

        my @subcells = split / +\/ /, $func;
        if ( @subcells == 1 )
        {
            $cell_info{ $func } = cell_guts( $func, $role_clr, $clr_priority );
        }
        else
        {
            my $f2 = $func;
            $f2 =~ s/ +[#!].*$//;
            my $is_current = ( $f2 eq $current_func ) ? 1 : 0;

            my $html = '<TABLE><TR>'
                     . join( '', map { colored_cell( cell_guts( $_, $role_clr, $clr_priority, $is_current ) ) }
                                 @subcells
                           )
                     . '</TR></TABLE>';
            $cell_info{ $func } = [ $html, '' ];
        }
    }

    wantarray ? %cell_info : \%cell_info;
}


#------------------------------------------------------------------------------
#  cell_guts provides the html text and cell color for one function colorized
#  by role.
#
#      @html_color = cell_guts(  $function, \%role_clr, \%clr_priority, $is_curr )
#     \@html_color = cell_guts(  $function, \%role_clr, \%clr_priority, $is_curr )
#
#  where:
#
#     @html_color  = ( html_text, cell_color ) for the function
#------------------------------------------------------------------------------
sub cell_guts
{
    my ( $func, $role_clr, $clr_priority, $is_curr ) = @_;

    my $cc; # cell color
    my $rc; # role color
    my $rt; # role text
    my @parts = split /( +[#!].*$| *\; +| +\/ | +\@ +)/, $func;
    if ( $is_curr )
    {
        my %clrs2 = map { $_ => faded( $role_clr->{ $_ } ) } @parts;
        $role_clr = \%clrs2;
    }
    ( $cc ) = sort { $clr_priority->{$a} <=> $clr_priority->{$b} }
              grep { $_ }
              map  { $role_clr->{ $_ } }
              @parts;
    my @cell_guts = ( join( '', map { $rc = $role_clr->{ $_ };
                                      $rt = html_esc( $_ );
                                      $rc ne $cc ? colored_span( $rt, $rc ) : $rt
                                    }
                                @parts
                          ),
                      $cc
                    );

    wantarray ? @cell_guts : \@cell_guts;
}


#------------------------------------------------------------------------------
#  colorize_roles_in_cell_3 creates a hash relating functions to html versions
#  in which identical roles are colored the same.  The functions cannot be
#  html escaped since they will then split on the ; at the end of the character
#  codes.
#
#     %cell_info = colorize_roles_in_cell_3(  @functions )
#     %cell_info = colorize_roles_in_cell_3( \@functions )
#     %cell_info = colorize_roles_in_cell_3( \%functions )
#     %cell_info = colorize_roles_in_cell_3( \@functions, $current_func )
#     %cell_info = colorize_roles_in_cell_3( \%functions, $current_func )
#
#  where:
#
#     @functions  list of functions
#     %functions  hash of functions (key does not matter)
#     %cell_info  hash of [ html_text, cell_color ], keyed by function
#------------------------------------------------------------------------------
sub colorize_roles_in_cell_3
{
    my $role_clr = &role_colors( @_ );

    #  Make nonredundant list of functions:

    my %funcs = map { $_ => 1 }
                ( ref( $_[0] ) eq 'ARRAY' ? @{ $_[0] }
                : ref( $_[0] ) eq 'HASH'  ? map { $_[0]->{$_} } keys %{$_[0]}
                : @_
                );

    my $current_func = ref( $_[0] ) && defined $_[1] ? $_[1] : '';
    $funcs{ $current_func } = 1  if $current_func ne '';

    $current_func =~ s/ +#.*$//;

    foreach my $func ( keys %funcs )
    {
        if ( $func !~ /\S/ ) {
            $funcs{ $func } = [ '&nbsp;', '' ];
            next;
        }

        my ( $core_func, $comment ) = $func =~ /^(.*\S)( +#.*)$/ ? ( $1, $2 ) : ( $func, '' );
        my $is_current = $current_func eq $core_func;

        # Split roles:

        my @roles = split /( +\/ +| +@ +| *; +)/, $core_func;
        push @roles, $comment if $comment;

        #  If there is only one role, we do not build a table:

        if ( @roles == 1 )
        {
            my $role  = $roles[0];
            $funcs{ $func } = [ html_esc( $role ), get_role_color( $role, $role_clr, $is_current ) ];
            next;
        }

        $funcs{ $func } = [ join( '', '<TABLE><TR>',
                                      ( map { role_cell( $_, $role_clr, $is_current ) } @roles ),
                                      '</TR></TABLE>'
                                ),
                            $gray_color
                          ];
    }

    wantarray ? %funcs : \%funcs;
}


#------------------------------------------------------------------------------
#  role_cell provides the html for a table cell containing a colorized role.
#
#     $cell = role_cell( $role, \%role_clr, $is_curr )
#
#------------------------------------------------------------------------------
sub role_cell
{
    my ( $role ) = @_;
    colored_cell( html_esc( $role ), get_role_color( @_ ) );
}


#------------------------------------------------------------------------------
#  role_cell provides the html for a table cell containing a colorized role.
#
#     $cell = role_cell( $role, \%role_clr, $is_curr )
#
#------------------------------------------------------------------------------
sub get_role_color
{
    my ( $role, $role_clr, $is_curr ) = @_;

    my $color;
    if ( $role =~ / *#/ ) {
        $color = $comment_color;
    }
    elsif ( $role =~ /[0-9A-Za-z]/ ) {
        $color = $role_clr->{ $role } || $overflow_color;
        $color = &faded( $color ) if $is_curr;
    }
    else {
        $color = $gray_color;
    }

    $color;
}


#------------------------------------------------------------------------------
#  role_colors creates a hash of colors for roles in a set of functions.
#
#     %colors = role_colors(  @functions )
#     %colors = role_colors( \@functions )
#     %colors = role_colors( \%functions )
#     %colors = role_colors( \@functions, $current_func )
#     %colors = role_colors( \%functions, $current_func )
#
#  where:
#
#     @functions  list of functions
#     %functions  hash of functions (key does not matter)
#     %colors     hash of colors keyed by role
#------------------------------------------------------------------------------
sub role_colors
{
    my $funcs = ref( $_[0] ) eq 'ARRAY' ? $_[0]
              : ref( $_[0] ) eq 'HASH'  ? [ values %{$_[0]} ]
              : [ @_ ];

    my $current_func = ref( $_[0] ) && $_[1] ? $_[1] : '';

    #  count function occurrances

    my %func_cnt = ();
    foreach ( @$funcs, $current_func ? $current_func : () )
    {
        $func_cnt{ $_ }++ if defined $_ && /\S/;
    }

    #  count role occurances

    my %role_cnt = ();
    foreach my $func ( keys %func_cnt )
    {
        my $cnt = $func_cnt{ $func };
        $func =~ s/ +[#!].*$//;
        foreach ( split / *\; +| +\/ | +\@ +/, $func )
        {
            $role_cnt{ $_ } += $cnt if $_ =~ /\S/;
        }
    }

    #  Order roles

    $current_func =~ s/ +[#!].*$//;  #  strip comment
    my @current_roles = grep { /\S/ } split / *\; +| +\/ | +\@ +/, $current_func;
    foreach ( @current_roles ) { $role_cnt{ $_ } += 1e9 }
    my @roles = sort { $role_cnt{ $b } <=> $role_cnt{ $a } } keys %role_cnt;

    #  Choose a pallet

    my @colors = ( '#FFFFFF', choose_pallet( scalar @roles ), $overflow_color );

    #  Index colors by relative priority

    my $n = 0;
    my %clr_priority = map { $_ => $n++ } ( @colors );

    #  Index roles by color

    shift @colors if @current_roles != 1;  #  White is only used if it is unique current role

    my %role_clr;
    foreach ( @roles ) { $role_clr{ $_ } = ( shift @colors ) || $overflow_color }

    wantarray ? ( \%role_clr, \%clr_priority ) : \%role_clr;
}


#------------------------------------------------------------------------------
#  colorize_functions creates a hash relating functions to html versions in
#  which identical functions are colored the same.
#
#     %colorized_function = colorize_functions(  @functions )
#     %colorized_function = colorize_functions( \@functions )
#     %colorized_function = colorize_functions( \%functions )
#     %colorized_function = colorize_functions( \@functions, $current_func )
#     %colorized_function = colorize_functions( \%functions, $current_func )
#
#  where:
#
#     @functions           list of functions
#     %functions           hash of functions (key does not matter)
#     %colorized_function  hash of colorized html text keyed by function
#------------------------------------------------------------------------------
sub colorize_functions
{
    my %func_color = function_colors( @_ );
 
    my %formatted_func = ();
    foreach my $func ( keys %func_color )
    {
        $formatted_func{ $func } = colored_span( html_esc( $func ), $func_color{ $func } );
    }

    wantarray ? %formatted_func : \%formatted_func;
}


#------------------------------------------------------------------------------
#  function_colors creates a hash of colors for a list of functions.
#
#     %colors = function_colors(  @functions )
#     %colors = function_colors( \@functions )
#     %colors = function_colors( \%functions )
#     %colors = function_colors( \@functions, $current_func )
#     %colors = function_colors( \%functions, $current_func )
#
#  where:
#
#     @functions  list of functions
#     %functions  hash of functions (key does not matter)
#     %colors     hash of colors keyed by function
#------------------------------------------------------------------------------
sub function_colors
{
    my $funcs = ref( $_[0] ) eq 'ARRAY' ? $_[0]
              : ref( $_[0] ) eq 'HASH'  ? [ map { $_[0]->{$_} } keys %{$_[0]} ]
              : [ @_ ];

    my $current_func = ref( $_[0] ) && $_[1] ? $_[1] : '';

    my %func_cnt = ();
    foreach ( @$funcs, $current_func ? $current_func : () )
    {
        $func_cnt{ $_ }++ if defined $_ && /\S/;
    }

    $func_cnt{ $current_func } += 1e9 if $current_func;

    my @funcs = sort { $func_cnt{ $b } <=> $func_cnt{ $a } }
                keys %func_cnt;

    my @colors = ( choose_pallet( scalar @funcs ), $overflow_color );
    unshift @colors, '#FFFFFF' if $current_func;

    my %func_color;
    foreach ( @funcs ) { $func_color{ $_ } = ( shift @colors ) || $overflow_color }

    wantarray ? %func_color : \%func_color;
}


#------------------------------------------------------------------------------
#  This is a sufficient set of escaping for text in HTML (function and alias).
#
#     $html = html_esc( $text )
#------------------------------------------------------------------------------
sub html_esc { local $_ = $_[0]; s/\&/&amp;/g; s/\>/&gt;/g; s/\</&lt;/g; $_ }


#------------------------------------------------------------------------------
#  Set background color for html text:
#
#     $html = colored_span( $text, $color )
#------------------------------------------------------------------------------
sub colored_span
{
    return ! defined $_[0] || ! length $_[0] ? ''       # No text
         : ! defined $_[1] || ! $_[1]        ? $_[0]    # No color
         : qq(<SPAN Style="background-color: $_[1]">$_[0]</SPAN>)
}


#------------------------------------------------------------------------------
#  colored cell provides html text for one cell
#
#     $table_cell_html = colored_cell( $text, $color )
#------------------------------------------------------------------------------
sub colored_cell
{
    join( '', ( $_[1] ? qq(<TD Style="background-color: $_[1]">) : '<TD>' ),
              ( defined $_[0] ? $_[0] : '&nbsp' ),
              '</TD>'
        );
}


#------------------------------------------------------------------------------
#  blend an html color with white
#
#     $faded_color = faded( $color )
#------------------------------------------------------------------------------
sub faded { gjocolorlib::blend_html_colors( $_[0], '#FFFFFF' ) }


1;

