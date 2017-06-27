package AliTreeIdConvert;

#
# Copyright (c) 2003-2010 University of Chicago and Fellowship
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

#===============================================================================
#  perl functions for changing alignment and tree sequence ids.
#
#  Usage:  use AliTreeIdConvert;
#
#===============================================================================

use strict;
use FIG;
use gjonewicklib;
use Data::Dumper;

#-------------------------------------------------------------------------------
#  Functions for interconverting alignments and trees that md5-based ids and
#  fid-based ids.  Because the md5 id is based on the sequences, multiple
#  fids can have the same md5 id.  These are reduced to a single instance on
#  conversion to md5, and expanded to all known corresponding fids on conversion
#  back to fids.
#
#    ( \@md5_align, \%md5_locs ) = fid_align_to_md5_align( $fig, \@fid_align, \%fid_locs, $relaxed );
#    ( \@md5_align, \%md5_locs ) = fid_align_to_md5_align(       \@fid_align, \%fid_locs, $relaxed );
#    ( \@fid_align, \%fid_locs ) = md5_align_to_fid_align( $fig, \@md5_align, \%md5_locs, $relaxed );
#    ( \@fid_align, \%fid_locs ) = md5_align_to_fid_align(       \@md5_align, \%md5_locs, $relaxed );
#       $md5_tree                = fid_tree_to_md5_tree( $fig, $fid_tree, $relaxed );
#       $md5_tree                = fid_tree_to_md5_tree(       $fid_tree, $relaxed );
#       $fid_tree                = md5_tree_to_fid_tree( $fig, $md5_tree, $relaxed );
#       $fid_tree                = md5_tree_to_fid_tree(       $md5_tree, $relaxed );
#
#  $fig        An optional FIG object (or similar) for the id conversion.
#              If not supplied, a FIG object is temporarily created.
#
#  @fid_align  An alignment, as fid_definition_sequence triples.
#
#  @md5_align  An alignment, as md5_definition_sequence triples.
#
#  %fid_locs   A hash defining the subsequences in the alignment, keyed by fid
#
#  %md5_locs   A hash defining the subsequences in the alignment, keyed by md5
#
#  $fid_tree   A gjonewick tree structure with fid ids.
#
#  $md5_tree   A gjonewick tree structure with md5 ids.
#
#  $relaxed    If set to a true value, untranslatable ids are retained.  By
#              default they are deleted from the alignment or tree.
#-------------------------------------------------------------------------------

sub fid_align_to_md5_align
{
    my $fig = UNIVERSAL::can( $_[0], 'md5_of_peg' ) ? shift : new FIG;
    my ( $fid_align, $fid_loc, $relaxed ) = @_;
    $fid_align && ref( $fid_align ) eq 'ARRAY'
        or return ();

    my @md5_align;
    my %md5_loc;

    my %seen;
    foreach ( @$fid_align )
    {
        my $fid = $_->[0];
        my $md5 = $fig->md5_of_peg( $fid );
        $md5 = $fid if ! $md5 && $relaxed;
        next if ! $md5 || $seen{ $md5 }++;

        push @md5_align, [ $md5, $_->[1], $_->[2] ];
        if ( $fid_loc && ref( $fid_loc ) eq 'HASH' )
        {
            my $loc = $fid_loc->{ $fid };
            $md5_loc{ $md5 } = $loc if $loc;
        }
    }

    return ( \@md5_align, \%md5_loc );
}


sub md5_align_to_fid_align
{
    my $fig = UNIVERSAL::can( $_[0], 'pegs_with_md5' ) ? shift : new FIG;
    my ( $md5_align, $md5_locs, $relaxed ) = @_;
    $md5_align && ref( $md5_align ) eq 'ARRAY'
        or return ();

    my ( @fid_align, %fid_locs );

    foreach ( @$md5_align )
    {
        my $md5  = $_->[0];
        my @fids = $fig->pegs_with_md5( $md5 );
        @fids = ( $md5 ) if ! @fids && $relaxed;
        foreach my $fid ( @fids )
        {
            push @fid_align, [ $fid, $_->[1], $_->[2] ];
        }
        if ( $md5_locs && ref( $md5_locs ) eq 'HASH' )
        {
            my $loc = $md5_locs->{ $md5 };
            if ( $loc )
            {
                foreach my $fid ( @fids ) { $fid_locs{ $fid } = $loc; }
            }
        }
    }

    return ( \@fid_align, \%fid_locs );
}


sub fid_tree_to_md5_tree
{
    my $fig = UNIVERSAL::can( $_[0], 'md5_of_peg' ) ? shift : new FIG;
    my ( $fid_tree, $relaxed ) = @_;
    $fid_tree && ref( $fid_tree ) eq 'ARRAY'
        or return undef;

    my ( %seen, %tip_to_md5 );
    foreach my $fid ( gjonewicklib::newick_tip_list( $fid_tree ) )
    {
        my $md5 = $fig->md5_of_peg( $fid );
        $md5 = $fid if ! $md5 && $relaxed;
        $tip_to_md5{ $fid } = $md5 if $md5 && ! $seen{ $md5 }++;
    }

    gjonewicklib::newick_relabel_tips( gjonewicklib::newick_subtree( $fid_tree, keys %tip_to_md5 ), \%tip_to_md5 );
}


sub md5_tree_to_fid_tree
{
    my $fig = UNIVERSAL::can( $_[0], 'pegs_with_md5' ) ? shift : new FIG;
    my ( $md5_tree, $relaxed ) = @_;
    $md5_tree && ref( $md5_tree ) eq 'ARRAY'
        or return ();

    my @tips = gjonewicklib::newick_tip_list( $md5_tree );
    @tips or return undef;

    my %md5_2_fids;
    my $prune = 0;
    foreach my $md5 ( @tips )
    {
        my @fids = $fig->pegs_with_md5( $md5 );
        @fids = ( $md5 ) if ! @fids && $relaxed;
        if ( ! @fids ) { $prune = 1; next }
        $md5_2_fids{ $md5 } = \@fids;
    }

    $md5_tree = gjonewicklib::newick_subtree( $md5_tree, [ keys %md5_2_fids ] ) if $prune;

    expand_duplicate_tips( gjonewicklib::copy_newick_tree( $md5_tree ), \%md5_2_fids );
}


#-------------------------------------------------------------------------------
#  Use a hash to relabel, and potentially expand the tips in a newick tree.
#
#  $node = expand_duplicate_tips( $node, \%new_names )
#
#-------------------------------------------------------------------------------
sub expand_duplicate_tips
{
    my ( $node, $new_names ) = @_;

    my @desc = gjonewicklib::newick_desc_list( $node );

    if ( @desc )
    {
        foreach ( @desc ) { expand_duplicate_tips( $_, $new_names ) }
    }
    else
    {
        my $new;
        if ( gjonewicklib::node_has_lbl( $node )
          && defined( $new = $new_names->{ gjonewicklib::newick_lbl( $node ) } )
           )
        {
            my @new = @$new;
            if ( @new == 1 )
            {
                gjonewicklib::set_newick_lbl( $node, $new[0] );
            }
            elsif ( @new > 1 )
            {
                gjonewicklib::set_newick_desc_ref( $node, [ map { [ [], $_, 0 ] } @new ] );
                gjonewicklib::set_newick_lbl( $node, undef );
            }
        }
    }

    $node;
}


1;
