package gjocluster;

#
#  $matrix     # Data matrix lower left triangle; rows are i, cols are j (< i)
#              #    so row 0 is empty.
#

use strict;
use gjoavllib;
use gjonewicklib;
use Data::Dumper;

sub test
{
    my $opts = $_[-1] && ref($_[-1]) eq 'HASH' ? pop : {};

    my $file = -f $_[0] ? shift : 'test.fasta';
    
    eval { require 'gjoseqlib.pm'; } or die;

    my @seqs   = gjoseqlib::read_fasta( $file );

    my $matrix = pairwise_matrix_from_align( \@seqs, $opts );

    my @joins  = clusters_from_sims( $matrix, $opts );

    my $i = 0;
    my %lbl = map { $i++ => $_->[0] } @seqs;

    my $tree = cluster_list_to_newick( \@joins, \%lbl );
    print Dumper( $tree );

    my %lbl_to_ind = reverse %lbl;
    my @rep_ident = pick_representatives( $tree, $matrix, \%lbl_to_ind );
    print Dumper( \@rep_ident );

    exit;

    foreach ( cluster_list_to_table( \@joins, \%lbl ) )
    {
        print join( "\t", @$_ ), "\n";
    }
}


#===============================================================================
#  Produce a lower-left triangle pairwise comparison table from aligned
#  sequences.  If a similarity
#  calculation function is supplied, it will be used instead of the default
#  fraction sequence identity function. By supplying an appropriate function,
#  dissimilarities or distances can also be computed.
#
#    @matrix = pairwise_matrix_from_align(  @align, \%opts )
#   \@matrix = pairwise_matrix_from_align(  @align, \%opts )
#    @matrix = pairwise_matrix_from_align( \@align, \%opts )
#   \@matrix = pairwise_matrix_from_align( \@align, \%opts )
#
#  where @align is a list of: $seq, \$seq, or [$id, $def, $seq].
#
#  The first row of the matrix has no entries, unless symmetric or asymmetric
#      are specified.
#
#  Options:
#
#    asymmetric =>  $bool  #  Build a square matrix when func(i,j) != func(j,i)
#    dna        =>  $bool  #  Assume that the supplied sequences are DNA
#    measure    => \&func  #  User-supplied similarity (distance) function
#    protein    =>  $bool  #  Assume that the supplied sequences are protein
#    rna        =>  $bool  #  Assume that the supplied sequences are RNA
#    symmetric  =>  $bool  #  Build a square matrix when func(i,j) == func(j,i)
#
#  If a user measure is supplied, it is called as:
#
#    $val = &$func( $seq1, $seq2 )
#
#  where the sequences are raw sequences; they should not be modified by
#  the function.
#-------------------------------------------------------------------------------
sub pairwise_matrix_from_align
{
    my $opts = $_[-1] && ref($_[-1]) eq 'HASH' ? pop : {};

    my @seqs = ( ( @_ == 1 ) && ( ref($_[0]) eq 'ARRAY' ) ) ? @{$_[0]} : @_;
    @seqs = map { \$_ }      @seqs if ! ref($seqs[0]);
    @seqs = map { \$_->[2] } @seqs if   ref($seqs[0]) eq 'ARRAY' && @{$seqs[0]} == 3;

    my $func = $opts->{ measure };
    if ( ! ( $func && ref($func) eq 'CODE' ) )
    {
        my $nt = $opts->{ dna }
              || $opts->{ DNA }
              || $opts->{ rna }
              || $opts->{ RNA }
              || ( ! $opts->{ protein }
                   && ( gjoseqlib::guess_seq_type( ${$seqs[0]} ) =~ /^.NA/i )
                 );

        eval { require 'gjoalignment.pm'; }
            or return wantarray ? () : undef;

        $func = $nt ? \&gjoalignment::fraction_nt_identity
                    : \&gjoalignment::fraction_aa_identity;
    }

    my @mat = ();
    my $nseq = @seqs;
    for ( my $i = 0; $i < $nseq; $i++ )
    {
        my $row = [];
        my $seqi = $seqs[$i];
        for ( my $j = 0; $j < $i; $j++ )
        {
            push @$row, &$func( $$seqi, ${$seqs[$j]} );
        }
        push @mat, $row;
    }

    if ( $opts->{ symmetric } || $opts->{ asymmetric } )
    {
        my $asym = $opts->{ asymmetric };

        for ( my $i = 0; $i < $nseq; $i++ )
        {
            my $row  = $mat[$i];
            my $seqi = $seqs[$i];
            push @$row, &$func( $$seqi, $$seqi );

            for ( my $j = $i+1; $j < $nseq; $j++ )
            {
                push @$row, $asym ? &$func( $$seqi, ${$seqs[$j]} )
                                  :  $mat[$j]->[$i];
            }
        }
    }

    wantarray ? @mat : \@mat;
}


#-------------------------------------------------------------------------------
#  Do a clustering of similarities; default is complete linkage.
#
#    @joins = clusters_from_sims( \@matrix, \%opts )
#   \@joins = clusters_from_sims( \@matrix, \%opts )
#
#  where @matrix is a lower-left triangle similarity matrix.
#
#    @joins = ( [ index1, index1, depth ], ... )
#
#  The OTU indices are 0-based, and the resulting cluster is represented
#  by its minimum index in later joins.
#
#  Options:
#
#    function => \&func( $sim1, $sim2 )  #  calculation for sims of a cluster
#    mode     =>  keyword                #  complete, single, upgma, wpgma
#
#  Function versus mode? The following functions are equivalent to their
#  corresponding keywords.
#
#    function => sub { $_[0] <= $_[1] ? $_[0] : $_[1] }  # complete (D)
#    function => sub { $_[0] >  $_[1] ? $_[0] : $_[1] }  # single
#    function => sub { 0.5 * ( $_[0] + $_[1] ) }         # wpgma
#
#  upgma can only be specified as a mode since it requires cluster size
#  information, which changes as clusters are formed.
#
#  If a mode is supplied, it takes precedence.
#-------------------------------------------------------------------------------
sub clusters_from_sims
{
    my ( $matrix, $opts ) = @_;
    $matrix && ref( $matrix ) eq 'ARRAY' && @$matrix
        or return wantarray ? () : undef;

    $opts   ||= {};
 
    my $opts2 = {};  # Passed to the join_max function. Used for UPGMA weights.

    #  In the case of upgma, we initialize the membership count of the clusters
    #  to 1. The actual function will be set later.  If there is no user-
    #  supplied mode or function, we set the default mode to 'complete'.

    my $func = $opts->{ function };

    local $_ = $opts->{ mode } || ( $func ? '' : 'complete' );
    if ( /^upgma/i )
    {
        $opts2->{ upgma } = [ (1) x @$matrix ];
    }

    #  Other modes define the combining function.

    elsif ( $_ )
    {
        $func = /^complete/i ? sub { $_[0] <= $_[1] ? $_[0] : $_[1] }
              : /^single/i   ? sub { $_[0] >  $_[1] ? $_[0] : $_[1] }
              : /^wpgma/i    ? sub { 0.5 * ( $_[0] + $_[1] ) }
              :                undef
        $func or die "Bad mode option ($_) supplied to clusters_from_sims.";
    }

    else
    {
        ( ref($func) eq 'CODE' )
            or die "Bad function option supplied to clusters_from_sims.";
    }

    my $nrow    = @$matrix;
    my @inds    = ( 0 .. $nrow-1 );
    my @row_alv = initial_row_data( $matrix );    

    my @joins;
    while ( @inds > 1 )
    {
        push @joins, scalar join_max( $matrix, \@inds, \@row_alv, $func, $opts2 );
    }

    wantarray ? @joins : \@joins;
}


#-------------------------------------------------------------------------------
#  Do one step in the clustering of similarities; find the maximal value and
#  merge the two subtrees.
#
#    ( $i, $j, $val ) = join_max( $matrix, \@inds, \@row_alv, \&func, \%opts );
#
#  Options:
#
#    upgma => \@clust_size  #  size of each otu
#
#-------------------------------------------------------------------------------
sub join_max
{
    my ( $matrix, $inds, $row_alv, $func, $opts ) = @_;
    $opts ||= {};

    my $max_val = -1;
    my $max_i;
    my $max_j;
    foreach my $i ( @$inds )
    {
        $i or next;
        my ( $j, $val ) = row_max( $row_alv->[$i] );
        next if $val <= $max_val;

        $max_i   = $i;
        $max_j   = $j;
        $max_val = $val;
    }

    my $mat_i = $matrix->[$max_i];
    my $row_i = $row_alv->[$max_i];

    my $mat_j = $matrix->[$max_j];
    my $row_j = $row_alv->[$max_j];

    #
    #  UPGMA is special since the combining function uses weights that are
    #  not known in advance.
    #
    #  This is wonderfully evil; even though the weight variables go out of
    #  scope, the weighted average function definition keeps their values,
    #  as in,
    #
    #  perl -e 'my $a=1; my $f; {my $a=2; $f=sub{$_[0]+$a}} $a=3; print &$f(10),"\n"'
    #  12
    #
    my $wgt = $opts->{ upgma };               # Value is \@cluster_size
    if ( $wgt && ref($wgt) eq 'ARRAY' )
    {
        my $wgt_i  = $wgt->[$max_i];          #  Weight of cluster i
        my $wgt_j  = $wgt->[$max_j];          #  Weight of cluster j
        my $wgt_ij = $wgt_i + $wgt_j;         #  Weight of cluster i union j
        $wgt->[$max_j] = $wgt_ij;             #  Update the weight for index j
        $func = sub { ( $_[0] * $wgt_i + $_[1] * $wgt_j ) / $wgt_ij }
    }

    #
    #  Update the matrix and the sorted-value trees. We always eliminate the
    #  highest numbered row and column.
    #
    foreach my $k ( @$inds )
    {
        next if $k == $max_i or $k == $max_j;

        my ( $mik, $mjk );
        if ( $k < $max_j )
        {
            $mik = $mat_i->[$k];
            $mjk = $mat_j->[$k];

            row_del( $row_i, $k, $mik );

            my $new = &$func( $mik, $mjk );
            if ( $mjk != $new )                    #  If the value changes
            {
                $mat_j->[$k] = $new;               #  Update matrix element

                row_del( $row_j, $k, $mjk );       #  Update avl tree
                row_add( $row_j, $k, $new );
            }
        }

        elsif ( $k < $max_i )
        {
            my $mat_k = $matrix->[$k];
            $mik = $mat_i->[$k];
            $mjk = $mat_k->[$max_j];

            row_del( $row_i, $k, $mik );

            my $new = &$func( $mik, $mjk );
            if ( $mjk != $new )                    #  If the value changes
            {
                $mat_k->[$max_j] = $new;           #  Update matrix element

                my $row_k = $row_alv->[$k];        #  Update avl tree
                row_del( $row_k, $max_j, $mjk );
                row_add( $row_k, $max_j, $new );
            }
        }

        else  # $k > $max_i
        {
            my $mat_k = $matrix->[$k];
            $mik = $mat_k->[$max_i];
            $mjk = $mat_k->[$max_j];

            my $row_k = $row_alv->[$k];
            row_del( $row_k, $max_i, $mik );

            my $new = &$func( $mik, $mjk );
            if ( $mjk != $new )                    #  If the value changes
            {
                $mat_k->[$max_j] = $new;           #  Update matrix element

                row_del( $row_k, $max_j, $mjk );   #  Update avl tree
                row_add( $row_k, $max_j, $new );
            }
        }
    }

    #  Update the list of active rows/columns:

    @$inds = grep { $_ != $max_i } @$inds;

    wantarray ? ( $max_i, $max_j, $max_val )
              : [ $max_i, $max_j, $max_val ];
}


sub initial_row_data
{
    my ( $matrix ) = @_;

    my $nrow = @$matrix;
    my @avl  = ();

    for ( my $i = 0; $i < $nrow; $i++ )
    {
        my $row_mat = $matrix->[$i];
        my $row_avl = row_new();
        for ( my $j = 0; $j < $i; $j++ )
        {
            row_add( $row_avl, $j, $row_mat->[$j] );
        }
        push @avl, $row_avl;
    }

    wantarray ? @avl : \@avl;
}


#-------------------------------------------------------------------------------
#  Get a matrix element from a lower-left triangle.
#
#    $Mij = Mij( $matrix, $i, $j )
#
#-------------------------------------------------------------------------------
sub Mij { $_[1] > $_[2] ? $_[0]->[$_[1]]->[$_[2]]
        : $_[1] < $_[2] ? $_[0]->[$_[2]]->[$_[1]]
        :                 undef
        }


#-------------------------------------------------------------------------------
#  Functions for maintaining AVL trees of the matrix rows.
#
#    $row         = new_row()
#                   row_add( $row, $j, $value )
#                   row_del( $row, $j, $value )
#  ( $j, $value ) = row_max( $row )
#  [ $j, $value ] = row_max( $row )
#
#-------------------------------------------------------------------------------
sub row_new { AVL->new( sub { $_[1]->[1] <=> $_[0]->[1]
                           || $_[0]->[0] <=> $_[1]->[0]
                            }
                      )
            }

sub row_add { $_[0]->add( [ $_[1], $_[2] ] ) }

sub row_del { $_[0]->del( [ $_[1], $_[2] ] ) }

sub row_max
{
    ( local $_ = $_[0]->first() ) ? wantarray ? @$_ : $_
                                  : wantarray ? ()  : undef;
}


#===============================================================================
#  Make a Newick tree based upon the clustering output.
#
#    $newick = cluster_list_to_newick( \@clusters, \%labels )
#    $newick = cluster_list_to_newick( \@clusters )
#
#  Default labels are t_00001, ... based upon the order in the data matrix
#  that was clustered.
#-------------------------------------------------------------------------------
sub cluster_list_to_newick
{
    my ( $clusters, $labels ) = @_;
    my $n_tip = @$clusters + 1;

    my $i = 0;
    my %label;
    %label = map { $_-1 => sprintf "t_%05d", $_ } ( 1 .. $n_tip );
    %label = ( %label, %$labels )                    if $labels && ref($labels) eq 'HASH';
    %label = ( %label, map { $i++ => $_ } @$labels ) if $labels && ref($labels) eq 'ARRAY';

    #  Build the tree tip nodes, tagged with their depth (zero for tips):

    my %subtree = map { $_ => [ [ [], $label{$_}, 0 ], 0 ] } keys %label;

    #  Build the internal nodes of the tree:

    my $n = 1;
    foreach ( @$clusters )
    {
        my ( $c2, $c1, $s ) = @$_;

        #  Get subtrees and their depths.

        my ( $st1, $d1 ) = @{ $subtree{ $c1 } };
        my ( $st2, $d2 ) = @{ $subtree{ $c2 } };

        #  New node depth is 1 minus the similarity. Set the node branch lengths.

        my $d = 1 - $s;
        $st1->[2] = sprintf( "%.6f", $d - $d1 );
        $st2->[2] = sprintf( "%.6f", $d - $d2 );

        #  Save the new node and its depth to the minimum cluster index.

        $subtree{ $c1 } = [ [ [ $st1, $st2 ], undef, 0 ], $d ];
    }

    #  The final tree is always at index zero:

    $subtree{ 0 }->[0];
}


sub cluster_list_to_table
{
    my ( $clusters, $labels ) = @_;
    my $n_tip = @$clusters + 1;

    my $i = 0;
    my %label;
    %label = map { $_-1 => sprintf "t_%05d", $_ } ( 1 .. $n_tip );
    %label = ( %label, %$labels )                    if $labels && ref($labels) eq 'HASH';
    %label = ( %label, map { $i++ => $_ } @$labels ) if $labels && ref($labels) eq 'ARRAY';

    my @out;
    my $n = 1;
    my $t = 1;
    foreach ( @$clusters )
    {
        my ( $c2, $c1, $s ) = @$_;
        my ( $l1, $l2 );
        defined( $l1 = $label{ $c1 } ) or ( $l1 = sprintf "t_%05d", $t++ );
        defined( $l2 = $label{ $c2 } ) or ( $l2 = sprintf "t_%05d", $t++ );
        my $node = sprintf "n_%05d", $n++;
        push @out, [ $node, $l1, $l2, sprintf( "%.6f", $s ) ];
        $label{ $c1 } = $node;
    }

    wantarray ? @out : \@out;
}


#===============================================================================
#  I have a tree and corresponding similarity matrix. I want the best
#  representative of the full tree, and each subtree. This is intended
#  for ultrametric (cluster-based) trees, where the differences in diverges
#  have been lost.
#-------------------------------------------------------------------------------
#
#    @lbl_sim = pick_representatives( $tree, $matrix, \%tip_to_idx )
#   \@lbl_sim = pick_representatives( $tree, $matrix, \%tip_to_idx )
#
#    $tree         #  Newick tree
#    $matrix       #  Lower-left triangle similarity matrix
#    %tip_to_idx   #  Map from tip labels to a matrix row/column indices.
#                  #     This is optional if the tree tips have sequential
#                  #     numerical labels in the same order as the matrixl
#
#-------------------------------------------------------------------------------
sub pick_representatives
{
    my ( $tree, $matrix, $tip_idx ) = @_;
    $tree && ref($tree) eq 'ARRAY' && @$tree
        or die "gjocluster::pick_representatives:  Bad tree.\n";
    $matrix && ref($matrix) eq 'ARRAY' && @$matrix > 1
        or die "gjocluster::pick_representatives:  Bad matrix.\n";

    my $ind_ok = $tip_idx && ref($tip_idx) eq 'HASH' && keys %$tip_idx == @$matrix;
    if ( ! $ind_ok )
    {
        my @tips = sort { $a <=> $b }
                   grep { /^\d+$/ }
                   gjonewicklib::newick_tip_list( $tree );
        if ( ( @tips == @$matrix ) && ( $tips[-1] - $tips[0] + 1 == @$matrix ) )
        {
            my $min = $tips[0];
            $tip_idx = { map { $_ => $_-$min } @tips };
            $ind_ok = ( keys %$tip_idx == @$matrix );
        }
        $ind_ok
            or die "gjocluster::pick_representatives:  Bad tip_to_index map.\n";
    }

    my $rep_i = unrooted_rep( $matrix );
    my ( $rep ) = map { $tip_idx->{$_} == $rep_i ? $_ : () } keys %$tip_idx;
    defined( $rep )
        or die "gjocluster::pick_representatives:  Failed to get initial rep. Bad index?\n";

    my @reps = ( [ $rep, 0 ] );

    my $node_sim = {};
    index_depths( $tree, $node_sim );

    my @path = gjonewicklib::path_to_tip( $tree, $rep );
    push @reps, sister_rep( $tree, $rep, \@path, $matrix, $tip_idx, $node_sim );

    @reps = sort { $a->[1] <=> $b->[1] || lc $a->[0] cmp lc $b->[0] } @reps;

    wantarray ? @reps : \@reps;
}


#-------------------------------------------------------------------------------
#  Given a similarity matrix, find the most distant pair of sequences (or
#  something close to that), and the sequence that is closest to both
#  (the maximum of the minimum similarities).
#
#    $index = unrooted_rep( $matrix )
#
#-------------------------------------------------------------------------------
sub unrooted_rep
{
    my ( $matrix ) = @_;
    $matrix && ref($matrix) eq 'ARRAY' && @$matrix > 1
        or die "gjocluster::unrooted_rep:  Bad matrix.\n";

    return 0 if @$matrix < 3;

    my $imax = @$matrix;
    my $i1;
    my $min = 1e100;
    for ( my $i = 1; $i < $imax; $i++ )
    {
        my $ident = Mij( $matrix, 0, $i );
        next if $ident >= $min;
        $i1  = $i;
        $min = $ident;
    }

    my $i2;
    my $min = 1e100;
    for ( my $i = 1; $i < $imax; $i++ )
    {
        next if $i == $i1;
        my $ident = Mij( $matrix, $i1, $i );
        next if $ident >= $min;
        $i2  = $i;
        $min = $ident;
    }

    my $i2;
    $min = 1e100;
    for ( my $i = 1; $i < $imax; $i++ )
    {
        next if $i == $i1;
        my $ident = Mij( $matrix, $i1, $i );
        next if $ident >= $min;
        $i2  = $i;
        $min = $ident;
    }

    #  Find sequence closest to both $seq1 and $seq2:

    my $i_rep;
    my $max = -1;
    for ( my $i = 0; $i < $imax; $i++ )
    {
        next if $i == $i1 or $i == $i2;
        my $ident = min2( Mij( $matrix, $i1, $i ), Mij( $matrix, $i2, $i ) );
        next if $ident <= $max;
        $i_rep = $i;
        $max   = $ident;
    }

    $i_rep;
}


#-------------------------------------------------------------------------------
#  Index the similarity value at every node. This defines the identity at which
#  a new representative must be added.
#
#    $depth_of_parent = index_depths( $node, \%node_sim )
#
#-------------------------------------------------------------------------------
sub index_depths
{
    my ( $node, $node_sim ) = @_;

    my $depth = 0;
    foreach ( gjonewicklib::newick_desc_list( $node ) )
    {
        $depth = index_depths( $_, $node_sim );
    }

    $node_sim->{ $node } = 1 - $depth;  # This is the similarity

    $depth + ( gjonewicklib::newick_x( $node ) || 0 );
}


#-------------------------------------------------------------------------------
#  Every subtree representative except the first is the subtree sequence most
#  similar to the representative of its sister subtree.
#
#     @reps = sister_rep( $node, $rep, $path, $matrix, \%tip_idx, \%node_sim )
#
#     $node      #  tree node for which sister subtrees reps are being found
#     $rep       #  the label of the representative of this subtree
#    \@path      #  nodes and descendent numbers from here to the rep tip
#     $matrix    #  lower left similarity matrix of the sequences
#    \%tip_idx   #  map from tip name in tree to row/column index in sim matrix
#    \%node_sim  #  map from node ref to similarity value at the node
#
#-------------------------------------------------------------------------------
sub sister_rep
{
    my ( $node, $rep, $path, $matrix, $tip_idx, $node_sim ) = @_;

    my ( undef, $rep_i, @path ) = @$path;

    my @desc = gjonewicklib::newick_desc_list( $node );

    #  Split out the node leading to the subtree representative:

    my ( $rep_node ) = splice( @desc, $rep_i-1, 1 );

    #  Continue descent toward the subtree representative:

    my @reps;
    if ( @path >= 3 )
    {
        @reps = sister_rep( $rep_node, $rep, \@path, $matrix, $tip_idx, $node_sim );
    }

    #
    #  For each sister node in the tree, find its rep (most similar to
    #  overall group rep), and visit its subtree.
    #

    my $rep_i = $tip_idx->{ $rep };  # index of matrix row of rep
    my $depth = $node_sim->{ $node };    # depth of this node
    foreach my $sis_node ( @desc )
    {
        my $sis_rep;
        my $max_sim = -1;
        foreach ( gjonewicklib::newick_tip_list( $sis_node ) )
        {
            my $sis_sim = Mij( $matrix, $rep_i, $tip_idx->{ $_ } );
            next unless $sis_sim > $max_sim;
            $max_sim = $sis_sim;
            $sis_rep = $_;
        }

        push @reps, [ $sis_rep, $depth ];

        my @sis_path = gjonewicklib::path_to_tip( $sis_node, $sis_rep );
        if ( @sis_path >= 3 )
        {
            push @reps, sister_rep( $sis_node, $sis_rep, \@sis_path, $matrix, $tip_idx, $node_sim );
        }
    }

    @reps;
}


sub min2 { $_[0] <= $_[1] ? $_[0] : $_[1] }
sub max2 { $_[0] >= $_[1] ? $_[0] : $_[1] }


1;
