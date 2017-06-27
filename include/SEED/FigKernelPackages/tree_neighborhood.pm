package tree_neighborhood;

use Data::Dumper;

use strict;

# @rep_tips = n_tips_for_neighborhood( $tree, $n );

# $node_start_end = branch_intervals_and_nodes( $tree );
# @node_start_end = branch_intervals_and_nodes( $tree );

# \%node_to_rep_tip = tip_representing_node( $tree );

# $nodes = n_representatives( $n, $id_start_end );
# $nodes = n_representatives( $n, @id_start_end );
# @nodes = n_representatives( $n, $id_start_end );
# @nodes = n_representatives( $n, @id_start_end );


# @rep_tips = n_tips_for_neighborhood( $tree, $n );

sub n_tips_for_neighborhood
{
    my ( $tree, $n ) = @_;
    my @tips = @{&tree_utilities::tips_of_tree( $tree )};
    if ( $n && ( @tips <= $n ) ) { return @tips }
    my $id_start_end = branch_intervals_and_nodes( $tree );
    my $nodes = n_representatives( $n, $id_start_end );
    my $node_to_rep_tip = tip_representing_node( $tree );
    my @rep_tips = map { $node_to_rep_tip->{ $_ } } @$nodes;
    return wantarray ? @rep_tips : \@rep_tips;
}

sub n_representatives
{
    my $n = shift;
    my @unprocessed = sort { $a->[1] <=> $b->[1] }
                      ( ref( $_[0]->[0] ) eq 'ARRAY' ) ? @{ $_[0] } : @_;
    my @active = ();
    my ( $current_interval, $current_point );
    while ( ( @active < $n ) && @unprocessed )
    {
        $current_interval = shift @unprocessed;
        $current_point = $current_interval->[1];
        @active = grep { $_->[2] > $current_point } @active;
        push @active, $current_interval;
    }

    my @ids = map { $_->[0] } @active;
    return wantarray() ? @ids : \@ids;
}

#  Overbeek tree:
#
#     [ Label,
#       DistanceToParent,
#       [ ParentPointer, ChildPointer1, ... ],
#       [ Name1\tVal1, Name2\Val2, ... ]
#     ]
#

sub branch_intervals_and_nodes
{
    my ( $node, $parent_x ) = @_;
    $parent_x ||= 0;
    my ( $label, $dx, $desc ) = @$node;
    my $x = $parent_x + $dx;
    my $interval = [ $node, $parent_x, (@$desc > 1) ? $x : 1e100 ];
    my @intervals = ( $interval,
                      map { &branch_intervals_and_nodes( $_, $x ) } @$desc[ 1 .. $#{@$desc} ]
                    );
    return wantarray() ? @intervals : \@intervals;
}



sub tip_representing_node
{
    my ( $tree ) = @_;
    my $hash = {};
    &tip_representing_node_1( $tree, $hash );
    return $hash;
}


sub tip_representing_node_1
{
    my ( $node, $hash ) = @_;
    my ( $label, $dx, $desc ) = @$node;
    $dx ||= 0;
    if ( @$desc > 1 )
    {
        my ( $rep, $min_dist ) = ( undef, 1e100 );
        foreach my $node2 ( @$desc[ 1 .. $#{@$desc} ] )
        {
            my ( $tip, $dist ) = &tip_representing_node_1( $node2, $hash );
            if ( $dist < $min_dist ) { $min_dist = $dist; $rep = $tip }
        }
        $hash->{ $node } = $rep;
        return ( $rep, $min_dist + $dx );
    }
    else
    {
        $hash->{ $node } = $label;
        return ( $label, $dx );
    }
}

sub focused_neighborhood {
    my($tree,$id,$approx_tree,$n) = @_;

    my $hash = {};
    foreach my $tip (@{ &tree_utilities::tips_of_tree($tree)})
    {
	$hash->{$tip} = 1;
    }
    $hash->{$id} = 1;
    my $subtree = &tree_utilities::subtree($approx_tree,$hash);
    my $indexes = &tree_utilities::tree_index_tables($subtree);
    my $tree1   = &tree_utilities::root_tree_at_node($indexes,$id);
    my $desc    = $tree1->[2]->[1];
    my @tips = &tree_neighborhood::n_tips_for_neighborhood($desc,$n);
    my %hash2 = map { $_ => 1 } @tips;
    return &tree_utilities::subtree($tree,\%hash2);
}

1;
