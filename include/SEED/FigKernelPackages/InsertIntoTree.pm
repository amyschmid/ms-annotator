#
# Copyright (c) 2003-2007 University of Chicago and Fellowship
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

package InsertIntoTree;

#===============================================================================
#  A package of functions for adding to a tree:
#
#     ( $tree, $likelihood ) = add_seq_to_tree( \%options );
#     ( $tree, $likelihood ) = add_seq_to_tree(  %options );
#       $tree                = add_seq_to_tree( \%options );
#       $tree                = add_seq_to_tree(  %options );
#
#     or with option all => 1:
#
#     @tree_likelihood_pairs = add_seq_to_tree( \%options );
#     @tree_likelihood_pairs = add_seq_to_tree(  %options );
#
#
#     $newtree = add_seq_to_big_tree( \%options )
#
#===============================================================================

use strict;
use gjonewicklib;
use gjophylip;

# use Carp;
# use Data::Dumper;

#===============================================================================
#  Function that tests all possible branches for the insertion of a new
#  sequence into an existing tree.
#
#     ( $tree, $likelihood ) = add_seq_to_tree( \%options );
#     ( $tree, $likelihood ) = add_seq_to_tree(  %options );
#       $tree                = add_seq_to_tree( \%options );
#       $tree                = add_seq_to_tree(  %options );
#
#  or when all => 1 is included among the options
#
#     @tree_likelihood_pairs = add_seq_to_tree( \%options );
#     @tree_likelihood_pairs = add_seq_to_tree(  %options );
#
#
#     Required "options":
#     -------------------------------------------------------------------------
#        align   => $align     = [ [id,def,seq ], ...] or [ [id,seq ], ...]
#        id      => $id        id of sequence to add to tree
#        tree    => $tree      overbeek or gjo starting tree
#     -------------------------------------------------------------------------
#
#
#     Other options:
#     -------------------------------------------------------------------------
#        all     => 1          Return list of all [ $tree, $likelihood ] pairs
#        tree    => $tree      overbeek or gjo starting tree
#     -------------------------------------------------------------------------
#
#
#     Also accepts mamy gjophylip::proml options, including:
#     -------------------------------------------------------------------------
#        alpha, categories, hmm, model, program, tmp, tmp_dir, weights
#     -------------------------------------------------------------------------
#
#===============================================================================
sub add_seq_to_tree
{
    my %args = ( ref( $_[0] ) eq 'HASH' ) ? %{$_[0]} : @_;

    my $align   = $args{ align };
    my $tree    = $args{ tree };
    my $id      = $args{ id };

    my $type = 'gjo';
    if ( gjonewicklib::is_overbeek_tree( $tree ) )
    {
        $type = 'overbeek';
        $tree = gjonewicklib::overbeek_to_gjonewick( $tree )
    }
    $tree = &gjonewicklib::uproot_newick( $tree );
    &gjonewicklib::newick_set_all_branches( $tree, 0.1 );  # In case of undefs

    my $tip_node = [ [], $id, 0.1 ];
    my $trees = &add_tip_to_each_branch( $tree, $tip_node );

    my %options = ( alignment   =>  $align,
                    tree_format =>  'gjo',
                    user_trees  =>  $trees, 
                   &tree_options( \%args )
                  );

    my @tree_and_likelihood = sort { $b->[1] <=> $a->[1] }
                              gjophylip::proml( \%options );

    #  Return them all?

    if ( $options{all} )
    {
        if ( $type eq 'overbeek' )
        {
            foreach ( @tree_and_likelihood )
            {
                $_->[0] = gjonewicklib::gjonewick_to_overbeek( $_->[0] )
            }
        }
        return wantarray ?  @tree_and_likelihood
                         : \@tree_and_likelihood
    }

    my ( $newtree, $lnlik ) = @{ $tree_and_likelihood[0] };
    if ($type eq "overbeek")
    {
        $newtree = &gjonewicklib::gjonewick_to_overbeek( $newtree );
    }

    return wantarray ? ( $newtree, $lnlik ) : $newtree;
}


#-------------------------------------------------------------------------------
#  Add the tip along all branches
#-------------------------------------------------------------------------------
sub add_tip_to_each_branch
{
    my ( $node, $tip, $root, $trees ) = @_;
    $root  ||= $node;                 # If no root, it is this node
    $trees ||= [];                    # If no incoming list, make an empty one

    my $ndesc = $node->[0] ? @{$node->[0]} : 0;
    for ( my $i = 0; $i < $ndesc; $i++ )
    {
        my $desc = $node->[0]->[$i];
        &add_tip_to_each_branch( $desc ,$tip, $root, $trees );
        my $new_node = [ [ $desc, $tip ], undef, 0.1 ];
        $node->[0]->[$i] = $new_node;    # Modify tree
        push @$trees, &gjonewicklib::copy_newick_tree( $root );  # Save tree
        $node->[0]->[$i] = $desc;        # Restore tree
    }

    return $trees;
}


#===============================================================================
#  add_seq_to_big_tree -- Subroutine superset of the functions of the scripts:
#
#      bring_tree_up_to_ali [-c CheckpointFile] [-a Alpha] [-n NeighSz] [-t TmpDir] Ali Tree
#      insert_prot_into_tree [-a alpha] [-n NeighSz] Ali Tree Id NJtree [Weights]
#
#  $newtree = add_seq_to_big_tree( \%options )
#
#
#      Required "options"
#      -------------------------------------------------------------------------
#          align        => \@align              #  [id,seq] or [id,def,seq]
#          tree         =>  $tree               #  starting tree for addition(s)
#      -------------------------------------------------------------------------
#      $tree can be in overbeek or gjonewick format.  The returned tree format
#          matches that supplied.
#
#
#      Optional "options"
#      -------------------------------------------------------------------------
#          checkpoint   =>  $checkpointfile     #  D = none
#          id           =>  $id_to_add          #  D = all in align but not tree
#          ids          => \@ids_to_add         #  D = all in align but not tree
#          neighborhood =>  $n_representatives  #  D = 40
#          rough_tree   =>  $rough_tree         #  D = protdist_neighbor tree
#          tip_priority => \&tip_priority( $distance_to_tip, $seq_length )   
#                                               #  D = 7 * log( $seq_length )
#                                               #        - log( $tip_distance )
#      -------------------------------------------------------------------------
#      $id_to_add defines a sequence in the alignment to be added to the tree.
#      @ids_to_add is an ordered list of ids to add to the tree.
#      If neither of the above is supplied, all sequences in the alignment but
#           not in the tree are added, from longest to shortest.
#      &tip_priority is a two argument function that assigns priorities for
#           tip selection in representative subtrees.  The first paramter is
#           the distance from the focus to the tip in the current tree.  The
#           second parameter is the number of informative sites in the sequence.
#
#
#      Options passed to proml and/or protdist_neighbor
#      -------------------------------------------------------------------------
#          alpha        =>  $alpha              #  D = inf
#          categories   =>  [ \@category_rates, site_categories ]
#          coef_of_var  =>  1/sqrt(alpha)       #  D = 0
#          gamma_bins   =>  $n_bins             #  D = 5
#          invar_frac   =>  $fraction           #  D = 0
#          model
#          neighbor     =>  $path_to_neighbor
#          persistance  =>  $rate_correl_range  #  D = 0
#          proml        =>  $path_to_proml
#          protdist     =>  $path_to_protdist
#          rate_hmm     =>  [ [rate,fraction], ... ]
#          tmp          =>  $place_for_tmp_dir
#          tmp_dir      =>  $place_for_temp_files
#          weights      =>  $site_weights
#      -------------------------------------------------------------------------
#      If $tmp_dir is specified and it exists, niether the temporary files nor
#          the directory are deleted.
#
#===============================================================================

sub add_seq_to_big_tree
{
    my %args = ref( $_[0] ) eq 'HASH'  ? %{$_[0]}
             : ref( $_[0] ) eq 'ARRAY' ? @{$_[0]}
             : @_;
    my $align        = $args{ align }        || $args{ alignment };
    my $checkpoint   = $args{ checkpoint };
    my $id_to_ins    = $args{ id } || $args{ ids };
    my $rough_tree   = $args{ rough_tree }   || $args{ nj_tree };
    my $size_rep     = $args{ neighborhood } || 40;
    my $tip_priority = $args{ tip_priority };
    my $tree0        = $args{ tree };

    ( $align && ( ref( $align ) eq 'ARRAY' ) )
        or print STDERR "add_seq_to_big_tree called without valid alignment"
        and return undef;

    ( $tree0 && ( ref( $tree0 ) eq 'ARRAY' ) )
        or print STDERR "add_seq_to_big_tree called without valid tree"
        and return undef;

    if ( $tip_priority )
    {
        if ( ref( $tip_priority ) ne 'CODE' )
        {
            print STDERR "add_seq_to_big_tree:\n";
            print STDERR "   tip_priority option is not a function reference.\n";
            print STDERR "   Tree is unchanged.\n";
            return $tree0;
        }
    }
    else #  Default measure of tip_priority for representative trees.
    {    #
         #  Balance sequence length and branch length such that a 50% decrease
         #  in branch length is required to permit a 10% decrease in sequence
         #  length.
         #
         #  Called as: &$tip_priority( $distance_to_tip, $informative_sites )

         $tip_priority = sub { 7 * log( $_[1]+1 ) - log( $_[0]+0.0001 ) };
    }

    #  Build an index to the alignment and compute informative positions:

    my %in_align = map { $_->[0] => $_ } @$align;
    my %inform   = map { $_->[0] => &informative_sites( $_->[-1] ) } @$align;

    #  Convert tree format if necessary

    my $format = gjonewicklib::is_overbeek_tree( $tree0 ) ? 'overbeek' : 'gjo';
    my $tree = ( $format eq 'overbeek' ) ? gjonewicklib::overbeek_to_gjonewick( $tree0 )
                                         : gjonewicklib::copy_newick_tree( $tree0 );

    my $tips = &gjonewicklib::newick_tip_list( $tree );
    my %in_tree = map { $_ => 1 } @$tips;

    #  Check for sequences in the tree that are not in the alignment:

    my @extra_tips = sort grep { ! $in_align{ $_ } } @$tips;
    if ( @extra_tips )
    {
        print STDERR "add_seq_to_big_tree:\n";
        print STDERR "   Sequence(s) found in tree that are not in alignment:\n";
        print STDERR "   '", join( "', '", @extra_tips ), "'\n";
        print STDERR "   Tree is unchanged.\n";
        return $tree0;
    }

    my @ids_to_ins;
    if ( $id_to_ins ) #  User-supplied list.  Order is respected.
    {
        @ids_to_ins = ref( $id_to_ins ) eq 'ARRAY' ? @$id_to_ins : ( $id_to_ins );

        my @orphan_ids = grep { ! $in_align{ $_ } } @ids_to_ins;
        if ( @orphan_ids  )
        {
            print STDERR "add_seq_to_big_tree:\n";
            print STDERR "   Sequence(s) to add that are not in alignment:\n";
            print STDERR "   '", join( "', '", @orphan_ids ), "'\n";
            print STDERR "   Tree is unchanged.\n";
            return $tree0;
        }

        my @already_in = grep { $in_tree{ $_ } } @ids_to_ins;
        @ids_to_ins = grep { ! $in_tree{ $_ } } @ids_to_ins;
        if ( @already_in )
        {
            print STDERR "add_seq_to_big_tree:\n";
            print STDERR "   Sequence(s) to add that are already in tree:\n";
            print STDERR "   '", join( "', '", @orphan_ids ), "'\n";
            print STDERR "   Attempting to continue.\n" if @ids_to_ins;
        }

        if ( ! @ids_to_ins )
        {
            print STDERR "add_seq_to_big_tree:\n" if ! @already_in;
            print STDERR "   No sequences to add.  Tree is unchanged.\n";
            return $tree0;
        }
    }
    else  #  Add all ids in alignment, but not tree, from longest to shortest.
    {
        @ids_to_ins = sort { $inform{ $b } <=> $inform{ $a } }
                      grep { ! $in_tree{ $_ } }
                      keys %in_align;
        if ( ! @ids_to_ins )
        {
            print STDERR "add_seq_to_big_tree:\n";
            print STDERR "   All sequences in the alignment are in the tree.  Tree is unchanged.\n";
            return $tree0;
        }
    }

    #  Does the guide tree exit?  If so, check it:

    my $rough_tree0 = $rough_tree;
    my @rough_tips;

    if ( $rough_tree )
    {
        if ( gjonewicklib::is_overbeek_tree( $rough_tree ) )
        {
            $rough_tree = gjonewicklib::overbeek_to_gjonewick( $rough_tree )
        }

        #  Check the tip content:

        @rough_tips = gjonewicklib::newick_tip_list( $rough_tree );
        my %rough_tips = map { $_ => 1 } @rough_tips;

        #  Missing tips?
        #  We do not require that all of the sequences in $tree be in the
        #  rough_tree.  But there will almost certainly be a need for a
        #  significant number of sequences beyond those to be added. The
        #  user is responsible for a resonsonable representation in the
        #  rough_tree, if it is supplied.

        my @missing = grep { ! $rough_tips{ $_ } } @ids_to_ins;
        if ( @missing )
        {
            print STDERR "add_seq_to_big_tree:\n";
            print STDERR "   The supplied guide tree is missing the following ids:\n";
            print STDERR "   '", join( "', '", @missing ), "'\n";
            print STDERR "   Rebuilding using gjophylip::protdist_neighbor.\n";
            $rough_tree = undef;
        }
    }

    #  If there is a problem with the current guide tree, make one:

    if ( ! $rough_tree )
    {
        my %nj_opts = ( alignment   => [ map { $in_align{ $_ } } @$tips, @ids_to_ins ],
                        tree_format => 'gjo',
                       &tree_options( \%args )
                      );
        $rough_tree = gjophylip::protdist_neighbor( \%nj_opts );
        if ( ! $rough_tree )
        {
            print STDERR "add_seq_to_big_tree:\n";
            print STDERR "   Failed to create protdist_neighbor tree\n";
            print STDERR "   Tree is unchanged.\n";
            return $tree0;
        }

        @rough_tips = ( @$tips, @ids_to_ins );
    }

    #  Set up ML options, only the id_to_ins, subalignment and subtree change:

    my %options = ( tree_format => 'gjo',
                   &tree_options( \%args )
                  );

    my ( $current_approx, $node1, $x1, $node2, $x2, $x, $fraction,
         $tree2, $subtree, @st_tips
       );

    #  Add sequences one at a time:
    #
    #     $tree       - The current tree to which a new tip is being added.
    #
    #     $rough_tree - An approximate tree with new tips added.
    #
    #     $current_approx - A tree with current approximation of the insertion
    #                       point.  Initially this is drawn from $rough_tree,
    #                       but later it is based on insertion into a
    #                       neighborhood of $tree.
    #
    #     $subtree    - The extracted neighborhood of $tree to which a tip
    #                       is to be added.

    foreach $id_to_ins ( @ids_to_ins )
    {
	print STDERR "inserting $id_to_ins\n" if $ENV{'VERBOSE'};

        $options{ id } = $id_to_ins;

        #  Use rough_tree for initial current_approx, removing extra tips:

        $current_approx = gjonewicklib::copy_newick_tree( $rough_tree );
        if ( grep { ! $in_tree{ $_ } && ( $_ ne $id_to_ins ) } @rough_tips )
        {
            $current_approx = gjonewicklib::newick_subtree( $current_approx, $id_to_ins, @$tips );
            if ( ! gjonewicklib::newick_is_unrooted( $current_approx ) )
            {
                $current_approx = gjonewicklib::uproot_newick( $current_approx );
            }
        }

        #  Pull out neighborhoods, insert and interate until it repeats
        #  the same neighborhood.

        my %seen = ();
        while ( 1 )
        {
            print STDERR "    looking for insertion point\n" if $ENV{'VERBOSE'};

            ( $node1, $x1, $node2, $x2, $x ) =
                   gjonewicklib::newick_tip_insertion_point( $current_approx, $id_to_ins );
            print STDERR "    got it\n" if $ENV{'VERBOSE'};

            #  Project tip insertion point onto $tree and reroot at that location:

            $x1 = 0 if $x1 < 0;
            $x2 = 0 if $x2 < 0;
            $fraction = ( $x1 + $x2 > 0 ) ? $x1 / ( $x1 + $x2 ) : 0.5;
            $subtree = gjonewicklib::copy_newick_tree( $tree );
            $subtree = gjonewicklib::reroot_newick_between_nodes( $subtree, $node1, $node2, $fraction );
            print STDERR "    got subtree\n" if $ENV{'VERBOSE'};

            #  For this rooting, prioritize tips for representing their group:

            my %tip_dist = gjonewicklib::newick_tip_distances( $subtree );
            my %tip_priority = map{ $_ => &$tip_priority( $tip_dist{ $_ }, $inform{ $_ } ) } @$tips;
            print STDERR "    got tip_priority\n" if $ENV{'VERBOSE'};

            #  Extract the subtree:

            $subtree = gjonewicklib::root_neighborhood_representative_tree( $subtree, $size_rep, \%tip_priority );
            @st_tips = gjonewicklib::newick_tip_list( $subtree );

            #  Break if we have already pulled this subset of tips:

            my $tip_string = join( "\t", sort @st_tips );
            last if $seen{ $tip_string }++;

            print STDERR "$tip_string\n" if $ENV{'VERBOSE'};

            if ( ! gjonewicklib::newick_is_unrooted( $subtree ) )
            {
                $subtree = gjonewicklib::uproot_newick( $subtree );
            }
            gjonewicklib::printer_plot_newick( $subtree, \*STDOUT, undef, 1, 1 ) if $ENV{'VERBOSE'};

            #  Do the ML insertion:

            $options{ align } = [ map { $in_align{ $_ } } @st_tips, $id_to_ins ];
            $options{ tree  } = $subtree;
	    print STDERR "starting add_seq_to_tree\n" if $ENV{'VERBOSE'};
            $current_approx = &add_seq_to_tree( \%options );
	    print STDERR "back from add_seq_to_tree\n" if $ENV{'VERBOSE'};
        }

	print STDERR "got position\n" if $ENV{'VERBOSE'};

        #  Project this insertion point onto the full starting tree and insert
        #  (the location was computed above, for finding the neighborhood):

        my $newtip = [ undef, $id_to_ins, $x ];
        $tree = newick_insert_between_nodes( $tree, $newtip, $node1, $node2, $fraction );

        push @$tips, $id_to_ins;
        $in_tree{ $id_to_ins } = 1;

        if ( $checkpoint && open( CHECKPOINT, ">>$checkpoint" ) )
        {
            writeNewickTree( $tree, \*CHECKPOINT );
            close( CHECKPOINT );
        }
    }
    print STDERR "exitng\n" if $ENV{'VERBOSE'};
    ( $format eq 'overbeek' ) ? gjonewicklib::gjonewick_to_overbeek( $tree )
                              : $tree;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  tree_options -- filter tree options out of %args:
#
#     ( key => value, key => value ... ) = tree_options( \%args )
#     ( key => value, key => value ... ) = tree_options(  %args )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub tree_options
{
    my %args = ( ref( $_[0] ) eq 'HASH' ) ? %{$_[0]} : @_;
    my %tree_opt = map { canonical_key($_) => 1 }
                   qw(  alpha        categories    coef_of_var
                        gamma_bins   invar_frac    model
                        neighbor     persistance   proml
                        protdist     rate_hmm      tmp
                        tmp_dir      weights
                     );

    map { $_ => $args{ $_ } } grep { $tree_opt{canonical_key($_)} } keys %args;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  canonical_key -- canonical form of a key for accepting variants with
#      alternaive case, underscores or terminal s.
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub canonical_key { my $key = lc shift; $key =~ s/_//g; $key =~ s/s$//; $key }


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  informative_sites -- positions that are useful for assessing
#
#      $sites = informative_sites( $seq )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub informative_sites
{
    my $seq = uc shift;
    $seq =~ s/[^ACDEFGHIKLMNPQRSTUVWY]+//g;
    my $nt = $seq =~ tr/ACGNTU//;
    ( $nt >= 0.8 * length $seq ) ? $seq =~ tr/ACGTU//
                                 : $seq =~ tr/ACDEFGHIKLMNPQRSTVWY//
}

1;
