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

package FIGtree;

# use Carp;
# use strict;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
	FIGtree_to_newick
	FIGtree_to_overbeek
	newick_to_FIGtree
	overbeek_to_FIGtree
       
        FIG_build_tree_from_subtrees
        FIG_chop_tree
        FIG_closest_common_ancestor
        FIG_collapse_node_node
        FIG_collapse_node_tip
        FIG_copy_tree
        FIG_dist_node_to_node
        FIG_dist_tip_to_tip
        FIG_dist_to_first_tip
        FIG_dist_to_node
        FIG_dist_to_root
        FIG_dist_to_tip
        FIG_duplicate_tips
        FIG_duplicate_nodes
        FIG_first_tip
        FIG_max_label
        FIG_min_label 
        FIG_nodes_of_tree
        FIG_nodes_within_dist
        FIG_num_nodes
        FIG_num_tips
        FIG_num_bunches
        FIG_path_length
        FIG_path_to_first_tip
        FIG_path_to_node
        FIG_path_to_node_ref
        FIG_path_to_root
        FIG_path_to_tip
        FIG_prefix_of
        FIG_print_node
        FIG_print_tree
        FIG_prune_node
        FIG_prune_tip
        FIG_random_order_tree
        FIG_region_size
        FIG_representative_tree
        FIG_reverse_tree
        FIG_shared_tips
        FIG_split_tree
        FIG_steps_to_node
        FIG_steps_to_root
        FIG_steps_to_fist_tip
        FIG_steps_to_tip
        FIG_tips_of_tree
        FIG_tips_within_dist
        FIG_tips_within_steps
        FIG_tree_diameter
        FIG_tree_length
        FIG_tree_depth
        FIG_tree_size
        add_FIG_branch_attrib  
        add_FIG_desc
        add_FIG_node_attrib 
        build_tip_count_hash
        collapse_FIG_tree
        collect_all_tips
        collect_all_nodes
        collect_tips_and_dist
        delete_elm
        delete_FIG_branch_attrib
        delete_FIG_descRef
        delete_FIG_ith_desc
        delete_FIG_node_attrib
        delete_FIG_node
        delete_FIG_tip 
        distance_along_path
        distance_along_path_2
        fill_FIGtree_parents
        fill_overbeek_parents
        first_tip_ref
        get_FIG_X
        get_FIG_branch_attrib
        get_FIG_context
        get_FIG_descList
        get_FIG_descRef
        get_FIG_ith_desc
        get_FIG_ith_branch_attribute
        get_FIG_ith_node_attribute
        get_FIG_label
        get_FIG_max_desc
        get_FIG_max_desc_ref
        get_FIG_max_label
        get_FIG_min_desc
        get_FIG_min_desc_ref
        get_FIG_min_label
        get_FIG_node_attrib
        get_FIG_num_branch_attrib
        get_FIG_num_node_attrib
        get_FIG_numDesc
        get_FIG_parent
        get_FIG_root 
        get_FIG_tipref      
        get_path_to_first_tip 
        get_path_to_root
        has_cycles
        is_FIG_bifurcating
        is_FIG_node
        is_FIG_root
        is_FIG_rooted
        is_FIG_tip
        is_FIG_tip_rooted
        is_FIG_unrooted
        is_desc_of_FIGnode
        is_tip_in_FIG
        layout_FIG_tree
        maxref_of_subtree
        minref_of_subtree
        most_distant_tip_path
        most_distant_tip_name
        most_distant_tip_ref
	normalize_FIG_tree
        nodes_down_within_dist
        nodes_up_within_dist
        print_attrib_hash
        read_FIG_from_str
        rearrange_FIG_largest_out
        rearrange_FIG_smallest_out
        reorder_FIG_against_tip_count
        reorder_FIG_by_tip_count
        reroot_FIG_by_path
        reroot_FIG_next_to_tip
        reroot_FIG_to_node
        reroot_FIG_to_node_ref
        reroot_FIG_to_tip

        set_FIG_label
        set_FIG_X
        set_FIG_parent
        set_FIG_descRef
        set_FIG_node_attrib
        set_FIG_branch_attrib
        set_FIG_ith_desc
        set_FIG_descList
        set_FIG_ith_node_attrib
        set_FIG_ith_branch_attrib
        set_FIG_undef_branch
        sort_list_of_pairs
        std_unrooted_FIG
        tips_down_within_steps
        tips_up_within_steps
        tot_nodes_within_dist
        tot_tips_within_steps
        uproot_FIG
        uproot_tip_to_node
        write_FIG_to_Newick
	);

our @EXPORT_OK = qw(
        get_FIG_label
        get_FIG_X
        get_FIG_parent
        get_FIG_node_attributes
        get_FIG_branch_attributes
        get_FIG_descList
        get_FIG_ith_desc
        get_FIG_ith_node_attribute
        set_FIG_label
        set_FIG_X
        set_FIG_parent
        set_FIG_descRef
        set_FIG_node_attrib
        set_FIG_branch_attrib
        set_FIG_ith_desc
        set_FIG_ith_node_attrib
        set_FIG_ith_branch_attrib
        add_FIG_desc
        add_FIG_node_attrib
        add_FIG_branch_attrib
        delete_FIG_ith_desc
        delete_FIG_ith_node_attrib
        delete_FIG_ith_branch_attrib
        delete_FIG_descRef
        );

use gjolists qw(
        common_prefix
        common_and_unique
        unique_suffixes
        unique_set
        duplicates
        random_order
        union
        intersection
        set_difference
        );

use gjonewicklib qw(
        writeNewickTree
        fwriteNewickTree
        strNewickTree
        formatNewickTree

        parse_newick_tree_str

        layout_tree
        );

#=============================================================================
# FIG tree
#
#  Tree is:
#
#     [ Label,
#       X,      # distance to parent
#       ParentPointer,
#       [ ChildPointer1, ... ],
#       %NodeAttributes,
#       %BranchAttributes
#     ]
#
#  Overbeek tree:
#
#     [ Label,
#       DistanceToParent,
#       [ ParentPointer, ChildPointer1, ... ],
#       [ Name1\tVal1, Name2\Val2, ... ]
#     ]
#
#  Olsen "newick" representation in perl:
#
#     $tree = \@rootnode;
#
#     @node = ( \@desc,  #  reference to list of descendants
#                $label, #  node label
#                $x,     #  branch length
#               \@c1,    #  reference to comment list 1
#               \@c2,    #  reference to comment list 2
#               \@c3,    #  reference to comment list 3
#               \@c4,    #  reference to comment list 4
#               \@c5     #  reference to comment list 5
#             )
#
#
#-------------------------------------------------------------------------
#  Internally used definitions
#-------------------------------------------------------------------------

sub array_ref { ref( $_[0] ) eq "ARRAY" }
sub hash_ref  { ref( $_[0] ) eq "HASH"  }
sub by_distance { return ($a->[1] <=> $b->[1]); }
sub by_name { return ($a->[0] <=> $b->[0]); }

sub delete_elm {
# deletes $elm from @$list";
    my ($list, $elm) = @_;
    array_ref( $list ) && defined($elm) || undef;
    if (scalar @$list == 1 ) { $list->[0] eq $elm ? () : undef; }
    for (my $i = 0 ; $i < scalar @$list; $i++) {
      if ($list->[$i] eq $elm)  { splice (@$list, $i, 1) }
    }
    $list;
}

#=============================================================================
# FIGtree's get operations
#=========================================================================
#
# Note: there is a distinction between fig-node and fig-tip
#       a fig-node is a node with descendants and no label
#       a fig-tip is a node without descendants and label.
#       when necessary, you will find separate functions for each
#=========================================================================
sub get_FIG_label { $_[0]->[0]  }
sub get_FIG_X {   $_[0]->[1]  }
sub get_FIG_parent {  $_[0]->[2] }
sub get_FIG_descRef {  $_[0]->[3] }
sub get_FIG_node_attrib {   $_[0]->[4]  }
sub get_FIG_branch_attrib {   $_[0]->[5]  }

sub get_FIG_numDesc {  
# $numDesc = get_FIG_numDesc($node) 
   my ($FIG_node) = @_;
   my $i = $FIG_node->[3];
   ! array_ref( $FIG_node)?  undef   :
   ! array_ref( $i  )  ?    undef    :
   (scalar @$i) <= 0 ? 0             : 
   scalar @$i                        ; 
}

sub get_FIG_descList {
    my $node = $_[0];
    ! array_ref( $node ) ? undef           :
      array_ref( $node->[3] ) ? @{ $node->[3] } :
                                ()              ;
}

sub get_FIG_ith_desc {
    my ( $FIG_node, $i ) = @_;
    ! array_ref( $FIG_node      ) ? undef  :
    array_ref( $FIG_node->[3] ) ? 
    $FIG_node->[3]->[$i-1]                 :
    undef                                  ;
}

sub get_FIG_num_node_attrib {
   my ($FIG_node) = @_;
   my $i = $FIG_node->[4];
   ! array_ref( $FIG_node) ? undef    : 
   ! hash_ref( $i  )  ?    undef      :
   (scalar keys %$i) <= 0 ? 0         : 
   scalar keys %$i                    ;    
}

sub get_FIG_num_branch_attrib {
   my ($FIG_node) = @_;
   my $i = $FIG_node->[5];
   ! array_ref( $FIG_node) ? undef    : 
   ! hash_ref( $i  )  ?    undef      :
   (scalar keys %$i) <= 0 ? 0         : 
   scalar keys %$i                    ;    
}

sub get_FIG_ith_node_attribute {
    my ( $FIG_node, $i ) = @_;
    ! array_ref( $FIG_node      ) ? undef  :
    array_ref( $FIG_node->[4] ) ? 
    $FIG_node->[4]->[$i-1]                 :
    undef                                  ;
}

sub get_FIG_ith_branch_attribute {
    my ( $FIG_node, $i ) = @_;
    ! array_ref( $FIG_node      ) ? undef  :
    array_ref( $FIG_node->[5] ) ? 
    $FIG_node->[5]->[$i-1]                 :
    undef                                  ;
}

sub get_FIG_tipref {
    my ($tree, $tipname) = @_;
    array_ref($tree) && defined($tipname) || undef;
    my @path = FIG_path_to_tip($tree, $tipname);
    scalar @path > 0 ? pop @path : undef;
}

sub get_FIG_root {
    my ($node) = @_;
    if ((! &is_FIG_node( $node )) && (! &is_FIG_tip($node))) { undef;  }  
    ! $node->[2] ?  return $node :
      return &get_FIG_root($node->[2]);  
}

#------------------------------------------------------------------
#  boolean functions
#------------------------------------------------------------------
sub is_FIG_node {  
#  A node with nonempty descend list
    my $FIG_node = $_[0];
    ! array_ref( $FIG_node ) ? undef :
    (  array_ref( $FIG_node->[3] ) && 
    ( @{ $FIG_node->[3] } > 0 ) )          ? 
    1 : undef
    ; 
}
                         
sub is_FIG_root {  
#  A node with no parent ref
    my $FIG_node = $_[0];
    ! array_ref( $FIG_node ) ? undef :
    (  array_ref( $FIG_node->[2] ) && 
    ( @{ $FIG_node->[2] } == 0 ) )          ? 
    1 : undef
    ; 
}
 
sub is_desc_of_FIGnode {
# tests if $descref is descendant of $noderef
   my ($noderef, $descref) = @_;
   array_ref( $noderef ) &&  array_ref( $descref )  || undef; 
   my @children = get_FIG_descList($noderef);  
   my $found = "n";
   my $child;
   foreach $child (@children) { $found = "y" if ($child eq $descref); }
   $found eq "y" ? 1 : 0 ;
}

sub is_FIG_tip {
#  input is a noderef
    my $FIG_node = $_[0];  
    ! array_ref( $FIG_node ) ? undef      :            
    ( @{ $FIG_node->[3] } == 0 )          ? 
    1 : undef
    ;
}

sub is_tip_in_FIG {
# input: treeref and tip label. tests if tip label is in tree
   my ($tree , $tipname) = @_;
   my $tipref =  get_FIG_tipref($tree , $tipname);
   $tipref ? 1 : undef
   ;
}

sub is_FIG_rooted {
# tests if root node has two children
    my ($root) = @_;
    ! array_ref( $root      ) ? undef : 
      array_ref( $root->[3] ) ? @{ $root->[3] } == 2 :  
      0 ;  
}

sub is_FIG_unrooted {
# tests if root node has three children
    my ($root) = @_;
    ! array_ref( $root      ) ? undef : 
      array_ref( $root->[3] ) ? @{ $root->[3] } == 3 :  
      0 ;  
}

sub is_FIG_tip_rooted {
    my $node = $_[0];
    ! array_ref( $node      ) ? undef                :  # Not a node ref
      array_ref( $node->[3] ) ? @{ $node->[3] } == 1 :  # 1 branch
                                0                    ;  # No descend list
}

sub is_FIG_bifurcating {
    my ($node, $notroot) = @_;
    if ( ! array_ref( $node ) ) { return undef }    #  Bad arg

    my $n = get_FIG_numDesc($node);

    $n == 0 && ! $notroot                                        ? 0 :
    $n == 1 &&   $notroot                                        ? 0 :
    $n == 3 &&   $notroot                                        ? 0 :
    $n >  3                                                      ? 0 :
    $n >  2 && ! is_FIG_bifurcating(get_FIG_ith_desc($node,3,1)) ? 0 :
    $n >  1 && ! is_FIG_bifurcating(get_FIG_ith_desc($node,2,1)) ? 0 :
    $n >  0 && ! is_FIG_bifurcating(get_FIG_ith_desc($node,1,1)) ? 0 : $n
}

sub has_cycles {
# assumes path was acyclic when last insertion was made
# we only have to check if last insertion created a cycle
# note: path is a list of node refs
  my ($path) = @_;
  my $size = scalar @$path;
  my $last = $path->[$size-1];
  my $i=0,$found="no";
  while (($i<= ($size-2)) && ( $found == "no")) 
        { if ($path->[$i] eq $last) {$found="yes";}
          $i++; } 
  $found eq "yes" ? 1 : undef;
}

#-------------------------------------------------------------------------
#  update (i.e. set,add,delete) functions
#-------------------------------------------------------------------------
  
sub set_FIG_label { $_[0]->[0] = $_[1] }
sub set_FIG_X { $_[0]->[1] = $_[1] }
sub set_FIG_parent{ $_[0]->[2] = $_[1] }
sub set_FIG_descRef { $_[0]->[3] = $_[1] }
sub set_FIG_node_attrib { $_[0]->[4] = $_[1] }
sub set_FIG_branch_attrib {$_[0]->[5] = $_[1] }

sub set_FIG_descList {
# input: node, newList. Sets node's descList to newList
    my $node = shift;
    array_ref( $node ) || return;
    if ( array_ref( $node->[3] ) ) { @{ $node->[3] } =   @_ }
    else { $node->[3] = [ @_ ] }
}

sub set_FIG_ith_desc { 
# sets node1's ith-desc to arrayref of node2
    my ($node1, $i, $node2) = @_;
    array_ref( $node1 ) && array_ref( $node2 ) || return;
    if ( array_ref( $node1->[3] ) ) { $node1->[3]->[$i-1] = $node2 }
    else { $node1->[3] = [ $node2 ] }
}

sub set_FIG_undef_branch {
# searches in entire subtree rooted at $node for nodes w/undefined X
# and changes them to $x; returns number of nodes whose vals were reset
    my ($node, $x, $tot) = @_;
    array_ref($node) && defined($x) || return 0;

    if ( ! defined( get_FIG_X( $node ) ) ){
        set_FIG_X( $node, $x );
        $tot++;
    }
    if (is_FIG_tip($node)) {return $tot;}

    my $n = $tot;
    foreach $child (@{$node->[3]}) {
        $n += set_FIG_undef_branch( $child, $x, 0 );
    }
    $tot+= $n;
    return $tot;
}

sub add_FIG_desc {
# adds a descendant [$child] to node's descList
    my ($node, $child) = @_;
    my $numDesc = $node->[3];  
    array_ref( $node ) && array_ref( $child ) || return;  
    if ( array_ref( $node->[3] ) ) 
       { $node->[3]->[ scalar @$numDesc ] =   $child }
    else                            
       { $node->[3] = [ $child ] }
 }

sub add_FIG_node_attrib {
# adds a node attribute to node
    my ($node, $attrib) = @_;
    my ($key, $val);
    if ( array_ref( $node )  && hash_ref( $attrib ) ) {
       while (($key, $val) = each %$attrib) {
            push( @{ $node->[4]{ $key } }, $val);
            #print "$key, $val";
	  }
     }
}

sub add_FIG_branch_attrib {   
# adds a branch attribute to node
    my ($node, $attrib) = @_;
    my ($key, $val);
    if ( array_ref( $node )  && hash_ref( $attrib ) ) {
       while (($key, $val) = each %$attrib) {
            push( @{ $node->[5]{ $key } }, $val);
            # print "$key, $val";
	  }
     }
}
sub delete_FIG_ith_desc {
# deletes node's ith descendant
    my ( $node, $i ) = @_;
    if ((! array_ref( $node )) && (! array_ref( $node->[3])) )
      { return undef }
    elsif ($i == 1) { pop(@{$node->[3]}) }
    else { splice(@{$node->[3]},$ith-1,1) }
}

sub delete_FIG_descRef{
#deletes $noderef from node's desclist
    my ($node, $noderef) = @_;
    array_ref( $node ) && defined($noderef) || undef;
    my $numdesc = scalar @{$node->[3]};
    $numdesc || undef;

    if ($numdesc == 1 ) { shift(@{$node->[3]})  }
    elsif ($node->[3]->[$numdesc-1] eq $noderef ) { pop(@{$node->[3]}) }
    else
       { for ( my $i = 0; $i < $numdesc; $i++ ) {
           if ($node->[3]->[$i] eq $noderef) 
                 	{ splice(@{$node->[3]},$i,1) }
        }
    }
    $node->[3]; 
}

sub delete_FIG_node_attrib { 
# deletes node attribute from node's list     
    my ($node, $attrib) = @_;
    my ($key, $val);
    if ( array_ref( $node )  &&  hash_ref( $attrib ) ) {    
       while ( ($key,$val) = each %$attrib) {
          my $val1 = $node->[4]{$key};
          if (!array_ref($val1) ) 
             { delete $node->[4]{ $key } ; return ; }
          else
             {  
                for (my $i=0;$i < scalar @$val1; $i++) {
                  if ($val1->[$i] eq $val) { splice @$val1,i,1  }  
		}
                if (scalar @$val1 == 0) { 
                  delete $node->[4]{ $key }; return ; }
              }
	}
     }
    else { undef } 
}

sub delete_FIG_branch_attrib {    
# deletes branch attribute from node's list  
    my ($node, $attrib) = @_;
    my ($key, $val);
    if ( array_ref( $node )  &&  hash_ref( $attrib ) ) {    
       while ( ($key,$val) = each %$attrib) {
          my $val1 = $node->[5]{$key};
          if (!array_ref($val1) ) 
             { delete $node->[5]{ $key } ; return ; }
          else
             {  
                for (my $i=0;$i < scalar @$val1; $i++) {
                  if ($val1->[$i] eq $val) { splice @$val1,i,1  }  
		}
                if (scalar @$val1 == 0) { 
                  delete $node->[5]{ $key }; return ; }
              }
	}
     }
    else { undef } 
}

sub delete_FIG_tip {
# tip node is deleted. resulting tree is NOT normalized
  my ($tree, $tip1) = @_;
  array_ref($tree) && defined($tip1) || undef;
  if (! array_ref($tip1) ) 
     { # arg 2 is a tipname; we need a tipref
        $tip1 = get_FIG_tipref($tree,$tip1); 
     }
  is_FIG_tip($tip1) || undef;
  my $parent = $tip1->[2];
  array_ref($parent) || undef;
  delete_FIG_descRef($parent,$tip1);
  $parent;
}

sub delete_FIG_node {
# node1 is deleted from $tree; its descedants are added to 
# the parent's descList. Resulting $tree is NOT normalized 
  my ($tree, $node1) = @_;
  is_FIG_node($node1) || undef;
  if (is_FIG_root($node1)) { return uproot_FIG($node1) } 
  my $parent = $node1->[2];
  my $children = $node1->[3];
  if (@$children == 0) {
      delete_FIG_descRef($parent,$node1);  
      return $parent;    
     }
  delete_FIG_descRef($parent,$node1);   
  my $child;
  foreach $child (@$children) {
      add_FIG_desc($parent, $child); 
    }
  $parent;
}

#------------------------------------------------------------------
#  statistics functions -- tree operations without side effects
#------------------------------------------------------------------
sub FIG_tree_length {
# adds up the distances of all nodes of tree
    my ($node, $notroot) = @_;
    array_ref( $node) || return;
    my $x = $notroot ? get_FIG_X( $node ) : 0;
    defined( $x ) || ( $x = 1 );              
    #print "\nat node = $node with value of x = $x";
    my $imax = get_FIG_numDesc($node);
    for ( my $i = 1; $i <= $imax; $i++ ) {
        $x += FIG_tree_length( get_FIG_ith_desc($node, $i), 1 );
    }
    $x;
}

sub FIG_tree_diameter {
# locates the two most distant tips in tree and
# calculates distance of its path
  my ($fig) = @_;
  my @tpairs = sort_list_of_pairs( collect_tips_and_dist($fig) );
  my $t1 = shift @tpairs;
  my $x1 = shift @tpairs;
  my $x2 = pop @tpairs;
  my $t2 = pop @tpairs;
  &FIG_dist_tip_to_tip($fig,$t1->[0],$t2->[0]);
}

sub FIG_path_length {
# given a path, it calculates the distance/length of it
# check distance_along_path to get path length given
# two points rather than a path like it is here
    my $length=0;
    map { $length += get_FIG_X($_) } @_;
    return $length;
}
sub FIG_tree_depth {
# given a tree -its root node- it calculates depth of it;
# or in other words, the number of internal nodes between
# the root and its most distant tip
   my ($node) = @_;
   my $path = &most_distant_tip_path($node,1);
   return $path;
}

sub FIG_tree_size {
# number of internal and external nodes of the tree
# this way: takes n^2
#  return (FIG_num_nodes(@_) + FIG_num_tips(@_));
#this other way takes n
   my @nodes = collect_all_noderef(@_);
   return scalar @nodes;
}

sub FIG_num_bunches {
# a bunch is a subregion or split of the tree
# the right number of subregions is a heuristic
# in our case, we choose it based on the size of the tree
   my ($fig) = @_;
   my $lowN = int (log FIG_num_tips($fig));
   my $hiN = &FIG_tree_depth($fig);
   my $midN = 3;
   my @array = ($lowN, $hiN, $midN);
   sort { $a <=> $b } @array;
   my $numBunches = pop @array;
   while ($numBunches <= 0) { $numBunches = pop @array; }
   return $numBunches;
}
 
sub FIG_region_size {
# roughly speaking, we divide the tips evenly among the regions
# note, other heuristics can be implemented here
   my ($fig, $numBunches) = @_;
  if (! array_ref($fig)) { print "\split info missing, no tree"; return undef;}
  if (! $numBunches) { print "\nsplit info missing, no numbunch"; return undef;}
  if ($numBunches == 1) {print "\nnumbunch is one";return $fig; }

   my @tips = collect_all_tips($fig);  
   my $numtips = scalar @tips;
   my $regionSize = int ($numtips / $numBunches);
   if ($regionSize <= 0) { print "\nerror calculating size"; return undef; }
   else { return $regionSize; }
} 

sub FIG_nodes_of_tree {
# returns list of non-tip node references
   &collect_all_nodes( @_ );
}

sub FIG_tips_of_tree {
# returns list of tip labels of tree rooted at tree
    map { get_FIG_label($_) } collect_all_tips( @_ );
}

sub get_FIG_max_label {
# finds max of tree rooted at $tree
   my ($tree) = @_;
   my @tips = collect_all_tips($tree);
   my ($maxref, $max );
   $max = @tips->[0]->[1];
   $maxref = @tips->[0];
   for ($i=1; $i < @tips; $i++) {
     if ( @tips->[$i]->[1] > $max) {
         $max =  @tips->[$i]->[1];
         $maxref =  @tips->[$i] ;
       }
   }
   ($maxref, $max ); 
}

sub get_FIG_min_label {
# finds min of tree rooted at $tree
   my ($tree) = @_;
   my @tips = collect_all_tips($tree);
   my ($minref, $min); 
   $min = @tips->[0]->[1];
   $minref = @tips->[0];
   for ($i=1; $i < @tips; $i++) {
     if ( @tips->[$i]->[1] < $min) {
        $min = @tips->[$i]->[1] ;
        $minref = @tips->[$i] ;
      }
   }
   ($minref, $min); 
}


sub get_FIG_min_desc {
# ($minref,$min) = get_FIG_min_desc($node)
    my ( $FIG_node ) = @_;
    if ((! array_ref( $FIG_node)) && (! array_ref( $FIG_node->[3] ) ) ) 
       { return undef }
    my ($minref,$min);
    $min = $FIG_node->[3]->[0][1]; 
    $minref = $FIG_node->[3]->[0];
    my $i=1;
    while ($i < @{$FIG_node->[3]}) {
       if ( $FIG_node->[3]->[$i][1] < $min) 
          { $min = $FIG_node->[3]->[$i][1] ;
            $minref = $FIG_node->[3]->[$i] ; }
       $i++;
     }
    ($minref,$min);
}

sub get_FIG_max_desc {
# ($maxref,$max) = get_FIG_max_desc($node)
    my ( $FIG_node ) = @_;
    if ((! array_ref( $FIG_node)) && (! array_ref( $FIG_node->[3] ) ) ) 
       { return undef }
    my ($maxref,$max);
    $max = $FIG_node->[3]->[0][1]; 
    $maxref = $FIG_node->[3]->[0];
    my $i;
    foreach $i (1 ..@{$FIG_node->[3]}) {
       if ( $FIG_node->[3]->[$i][1] > $max) 
          { $max = $FIG_node->[3]->[$i][1] ; 
            $maxref = $FIG_node->[3]->[$i] ; }
     }
    ($maxref,$max);
}

sub FIG_tips_within_dist {
# collecting all tips in neighborhood of $tree
# dist is defined by val of node->X 
   my ($tree, $dis, $ttips) = @_;
   array_ref($tree) && defined($dis) || undef;
   my $l1 = tips_down_within_dist($tree, $dis, $ttips);
   my $l2 = tips_up_within_dist($tree, $dis, $ttips);
   push(@$ttips,@$l1);
   push(@$ttips,@$l2);   
   return $ttips;
}

sub FIG_nodes_within_dist {
# collecting all non-tip nodes in neighborhood of tree
   my ($tree, $dis, $tnodes) = @_;
   array_ref($tree) && defined($dis) || undef;
   my $l1 = nodes_down_within_dist($tree, $dis, $tnodes);
   my $l2 = nodes_up_within_dist($tree, $dis, $tnodes);
   shift @$l1;
   push(@$tnodes,@$l1);
   push(@$tnodes,@$l2);   
   return $tnodes;
}

sub FIG_tips_within_steps {
# collecting all tips in neighborhood of tree
# one step = one jump from a node to next node in same branch
   my ($tree, $step, $ttips) = @_;
   array_ref($tree) && defined($step) || undef;
   my $l1 = tips_down_within_steps($tree, $step, $ttips);
   my $l2 = tips_up_within_steps($tree, $step, $ttips);
   push(@$ttips,@$l1);
   push(@$ttips,@$l2);   
   return $ttips;
}

sub FIG_duplicate_tips {
# collects duplicate tips of subtree rooted at $fig
    my ($fig) = @_;
    my @listTips = collect_all_tips( $fig );
    duplicates(@listTips);
}

sub FIG_duplicate_nodes {
# collects duplicate non-tip nodes of subtree rooted at $fig
    my ($fig) = @_;
    my @listNodes = collect_all_nodes($fig);
    duplicates(@listNodes);
}

sub FIG_shared_tips {
# duplicate tips of two trees
    my ($Tree1, $Tree2) = @_;
    my ( @Tips1 ) = FIG_tips_of_tree( $Tree1 );
    my ( @Tips2 ) = FIG_tips_of_tree( $Tree2 );
    intersection( \@Tips1, \@Tips2 );
}

sub FIG_num_tips {
# tot tips/leaves of tree rooted at $fig
   ($fig)= @_;
   my @tips =  &collect_all_tips($fig);
   return scalar @tips;
}

sub FIG_num_nodes {
# tot non-tip nodes of tree rooted at $fig
   ($fig) = @_;
   my @nodes = collect_all_nodes($fig);
   return  scalar @nodes;
}



sub FIG_first_tip {
#first tip along path of $node
   my ($node) = @_;
   my $tipref = first_tip_ref($node);
   get_FIG_label($tipref);
}

sub first_tip_ref {
   my ($node) = @_;
   my $child;
   if ((! &is_FIG_node( $node )) && (! &is_FIG_tip($node))) { undef;  }  
   if (&is_FIG_tip( $node ) )  {  return $node;  }
   else {
       foreach $child (@{$node->[3]}) { 
          &is_FIG_tip( $child ) ?  return $child :
	         return &first_tip_ref ($child) ; 
       }
   }
}

sub FIG_dist_to_first_tip {
# distance from $node to first tip along that path
    my ($node) = @_;
    my $path = &get_path_to_first_tip($node);
    distance_along_path(@$path);
}

sub FIG_steps_to_fist_tip {
# steps needed to reach first tip from current pos at $node
    my ($node) = @_;
    my $path = get_path_to_first_tip($node);
    return scalar @$path -1;
}

sub FIG_prefix_of {
# input: treeref, tipname
# returns all non-tip nodes along path from root to tip
    my @path = FIG_path_to_tip(@_[0],@_[1]);
    pop @path;          #delete tipref from path
    @path;
}

sub FIG_dist_to_tip {
# caclulates distance from tree's root to tip 
    my ($tree, $tip) = @_;
    my @path = FIG_path_to_tip($tree, $tip);
    distance_along_path(@path);
}

sub FIG_steps_to_tip {
# calculates steps from root to tip
    my ($tree, $tip) = @_;
    my @path = FIG_path_to_tip($tree, $tip);
    return scalar @path - 1; 
}

sub FIG_dist_to_node {
# calculates distance from root to non-tip node
    my ($tree, $node) = @_;
    my @path = FIG_path_to_node_ref( $tree, $node);
    distance_along_path(@path);
}

sub FIG_steps_to_node {
# calculates steps from root to non-tip node
    my ($tree, $node) = @_;
    my @path = FIG_path_to_node_ref( $tree, $node);
    return scalar @path -1;
}

sub FIG_dist_to_root {
#calculates distance from noderef to root
    my ($tree, $node) = @_;
    FIG_dist_to_node($tree, $node);
}

sub FIG_steps_to_root {
#calculates steps from noderef to root
    my ($tree, $node) = @_;
    FIG_steps_to_node($tree, $node);
}

sub FIG_path_to_first_tip {
    my ($node) = @_;
    &get_path_to_first_tip($node,[]);
}


sub collect_all_tips {
# collects tiprefs of subtree rooted at $node
   ($node , @tipList) = @_;
   my $child;
   if ((! &is_FIG_node( $node )) && (! &is_FIG_tip($node))) { undef  } 
   if (&is_FIG_tip( $node ) )  {  push( @tipList, $node )}
   else {
       foreach $child (@{$node->[3]}) 
         { &collect_all_tips($child,@tipList); }
   }  
   return @tipList; 
}

sub collect_tips_and_dist {
# collects tiprefs of subtree rooted at $node
# it also calculates accum. distance from root to each tip
   $node = shift @_;
   my $dist = shift @_;
   @tipList = @_;
   my $child;
   my $parent;
   $dist = defined($dist) ? $dist : 0;
   
   if ((! &is_FIG_node( $node )) && (! &is_FIG_tip($node))) { undef  } 
   if (&is_FIG_tip( $node ) )  
        {  
         my $d = $dist + $node->[1];
         push( @tipList, ($node, $d) ); 
        }
   else {
        
        $dist += $node->[1];
        foreach $child (@{$node->[3]}) 
          { &collect_tips_and_dist($child, $dist, @tipList);}
        #now backtracking
        $parent = $node->[2];
        $dist -= $parent->[1];
   } 
   @tipList;
}

sub sort_list_of_pairs {
# gets a list of the form a1, a2, b1, b2, c1, c2 ... where x1, x2 are
# two fields for same object, also x1 is a ref and x2 is a string
# we sort in ascending order by  the second field x2
 my ( @rest ) = @_;
 my $mat;
 my $i=1;
 while (@rest) {
  $mat[$i][1] = shift @rest;
  $mat[$i][2] = shift @rest;
  $i++;
 }
 my @pairs; 
 for (my $k=1; $k < $i; $k++) {
    for (my $l=$k; $l < $i; $l++) {
         if ($mat[$l][2] < $mat[$k][2]) {
            $temp2 = $mat[$k][2];      $temp1 = $mat[$k][1];
            $mat[$k][2] = $mat[$l][2]; $mat[$k][1] = $mat[$l][1];
            $mat[$l][2] = $temp2;      $mat[$l][1] = $temp1;
          }
     }
     push (@pairs, ($mat[$k]->[1], $mat[$k]->[2]) );
 }
 @pairs;  
}

sub collect_all_nodes {
# collects all non-tip noderefs of subtree rooted at $node
   ($node , @nodeList) = @_;
   my $child;
   if ((! &is_FIG_node( $node )) && (! &is_FIG_tip($node))) { undef;  }  
   if (&is_FIG_tip( $node ) )    { undef  } 
   else {
       push (@nodeList, $node); 
       foreach $child (@{$node->[3]}) 
         { &collect_all_nodes($child,@nodeList); }
   }  
   return @nodeList; 
}

sub collect_all_noderef {
# collects all noderefs, leaf and nonleaf,
# of subtree rooted at $node
   ($node , @nodeList) = @_;
   my $child;
   array_ref($node) || undef;
   if ((! &is_FIG_node( $node )) && (! &is_FIG_tip($node))) { undef;  }  
   else
      {
       push (@nodeList, $node); 
       foreach $child (@{$node->[3]}) 
         { &collect_all_noderef($child,@nodeList); }
      }  
   
   return @nodeList; 
}

sub tipref_to_tipname {
# gets a list of tip refs and returns a list of tip labels 
    map { get_FIG_label($_) } @_ ;
}

sub tips_down_within_dist {
# collects tips of tree rooted at $node that are within $dist
   my ($node, $dist) = @_;
   array_ref($node) && defined($dist) || undef;
   tot_tips_within_dist($node, $dist);
}

sub tips_up_within_dist {
# collects tips of tree that end at this node and that are within $dist
   my ($node, $dist, $list) = @_;
   ! array_ref($node) ? return undef : 1;
   if ($dist < 0 ) { return undef }
   my $parent = $node->[2];
   if ( ! $parent) { return undef }
   my $vl;
   if ($parent->[3]->[0] eq $node )  { 
      $vl = tot_tips_within_dist($parent->[3]->[1], 
        ($dist- ($node->[1]+ $parent->[3]->[1]->[1])), $list);    }
   else {
      $vl = tot_tips_within_dist($parent->[3]->[0], 
        ($dist- ($node->[1]+ $parent->[3]->[0]->[1])), $list) ;   }
   push(@$list, @$vl);
   tips_up_within_dist($parent, $dist - $node->[1], $list);
   return $list;
}

sub tot_tips_within_dist {
   ($node, $dist1, $tot) = @_;
   array_ref($node) || undef;
   my ($child,$len);
   $len = $dist1;
   if ($len < 0 ) { return () }
   if ( is_FIG_tip($node) ) {
           if ($len >= 0 ) { return push(@$tot,$node->[0]); }
           else { return (); }
    }
   foreach $child (@{$node->[3]}) { 
         tot_tips_within_dist($child,$len-$child->[1],$tot); 
      }
    $tot? $tot : undef;
}


sub nodes_down_within_dist {
# collects non-tip nodes of tree rooted at $node that are within $dist
   my ($node, $dist) = @_;
   array_ref($node) && defined($dist) || undef;
   tot_nodes_within_dist($node, $dist, []);
}

sub nodes_up_within_dist {
# collects nodes of tree that end at this node and that are within $dist
   my ($node, $dist, $list) = @_;
   ! array_ref($node) ? return undef : 1;
   $dist < 0 ? return undef : push(@$list,$node) ;
   my $parent = $node->[2];
   if ( ! $parent) { return  }
   my $vl;
   if ($parent->[3]->[0] eq $node )  {       
      $vl = tot_nodes_within_dist($parent->[3]->[1], 
        ($dist- ($node->[1]+ $parent->[3]->[1]->[1])) );   }
   else {
      $vl = tot_nodes_within_dist($parent->[3]->[0], 
        ($dist- ($node->[1]+ $parent->[3]->[0]->[1])) ) ;  }
   push(@$list, @$vl);
   nodes_up_within_dist($parent, $dist - $node->[1], $list);
   return $list;
}

sub tot_nodes_within_dist {
   ($node, $dist, $tot) = @_;
   if ($dist < 0 ) { return undef }
   if ( is_FIG_root($node) ) { return push(@$tot, $node); }
   if ( is_FIG_tip($node) ) { return (); }
   push(@$tot, $node);
   my ($child,$len);
   $len = $dist;
   foreach $child (@{$node->[3]}) { 
         if ( ($len >= $child->[1]) && (! is_FIG_tip($child))) 
            { push(@$tot, $child)  }
         tot_nodes_within_dist($child,$len-$child->[1],$tot); 
      }
    $tot ? $tot : undef ;
}

sub tips_down_within_steps {
# 
   my ($node, $steps) = @_;
   array_ref($node) && defined($steps) || undef;
   tot_tips_within_steps($node, $steps);
}

sub tips_up_within_steps {
   my ($node, $steps, $list) = @_;
   print "\ngetting tips up from node=$node steps left=$steps tips=$list";
   ! array_ref($node) ? return undef : 1;
   if ($steps < 0 ) { return undef }
   my $parent = $node->[2];
   if ( ! $parent) { return undef }
   my $vl;
   if ($parent->[3]->[0] eq $node )  { 
      $vl = tot_tips_within_steps($parent->[3]->[1], ($steps-2), $list); }
   else {
      $vl = tot_tips_within_steps($parent->[3]->[0], ($steps-2), $list); }
   if (@$vl) { push(@$list, @$vl); }
   tips_up_within_steps($parent, --$steps, $list);
   return $list;
}

sub tot_tips_within_steps {
   ($node, $steps1, $tot) = @_;
   array_ref($node) || undef;
   print "\ntot_tips start: node=$node tot=$tot stepsleft=$steps1";
   my ($child,$len);
   $len = $steps1;
   if ($len < 0 ) { return (); }
   if ( is_FIG_tip($node) ) {
     $len >= 0 ?  return push(@$tot,$node->[0]) : return ();
    }
   foreach $child (@{$node->[3]}) { 
     tot_tips_within_steps($child,$len-1,$tot);
   }
   print "\ntot_tips end: node=$node tot=$tot stepsleft=$steps1";
   $tot? $tot : undef;
}

sub maxref_of_subtree
{
   ($node) = @_;
   my ($t, $x) = most_distant_tip_ref($node,1);
   return ($t, $x);   
}

sub minref_of_subtree
{
   ($node) = @_;
   my ($t, $x) = closest_tip_ref($node,1);
   return ($t, $x);  
}

sub get_path_to_first_tip {
   ($node, $path) = @_;
   my $child;
   array_ref($node) || undef;
   push(@$path,$node);
   is_FIG_tip( $node ) ? 
      return $path                                       :
      return get_path_to_first_tip($node->[3]->[0],$path);
}

sub FIG_path_to_tip {
    my ($node, $tip, @path0) = @_;
    array_ref( $node )  &&  defined( $tip ) || return undef;
    push( @path0, $node);
    my $imax = get_FIG_numDesc($node);
    if ( $imax < 1 ) { 
        return ( $node->[0] eq $tip ) ? @path0 : () }
    my @path;
    for (my $i = 1; $i <= $imax; $i++ ) {
       @path = FIG_path_to_tip( get_FIG_ith_desc($node, $i),$tip,@path0);
       if ( @path ) { return @path }
    }

    ();  #  Not found
}

sub FIG_path_to_root {
# input could be noderef or tipname
    my ($tree, $node) = @_;
    array_ref($tree) || undef;
    array_ref($node) ?  get_path_to_root($node,[]):
    reverse FIG_path_to_tip($tree, $node)  ;
}

sub get_path_to_root {
   ($node, @path) = @_;
   if ((! &is_FIG_node( $node )) && (! &is_FIG_tip($node))) { undef;  }  
   push(@path, $node); 
   if (!$node->[2]) { return @path;  }
   else {
        get_path_to_root($node->[2],$path);
      }
}


sub FIG_path_to_node_ref {
# it only works when noderef is in node's subtree
    my ($node, $noderef, @path0) = @_;
    push( @path0, $node);
    if ( $node eq $noderef ) { return @path0 }

    my @path;
    my $imax = get_FIG_numDesc($node);
    for ( my $i = 1; $i <= $imax; $i++ ) {
       @path = 
         FIG_path_to_node_ref( get_FIG_ith_desc($node, $i), $noderef,@path0);
       if ( @path ) { return @path }
    }

    ();  #  Not found
}

sub FIG_path_to_node {
# node could be $tipname | [$tipname] |  $t1 $t2 $t3
    my ($node, $tip1, $tip2, $tip3) = @_;
    #print "\nargs node= $node t1= $tip1 t2= $tip2 t3= $tip3";
    array_ref( $node ) && defined( $tip1 ) || return ();

    # Allow arg 2 to be an array reference
    if ( array_ref( $tip1 ) ) { ( $tip1, $tip2, $tip3 ) = @$tip1 }
    
    my @p1 = FIG_path_to_tip($node, $tip1);         
    @p1 || return ();   
    #print "\npatht1= @p1";
    defined( $tip2 ) && defined( $tip3 ) || return @p1; 

    my @p2 = FIG_path_to_tip($node, $tip2);
    my @p3 = FIG_path_to_tip($node, $tip3);

    @p2 && @p3 || return ();                        
    #print "\npatht2= @p2 patht3= @p3";
    # Find the common prefix for each pair of paths
    my @p12 = common_prefix( \@p1, \@p2 );
    my @p13 = common_prefix( \@p1, \@p3 );
    my @p23 = common_prefix( \@p2, \@p3 );

    # Return the longest common prefix of any two paths
    ( @p12 >= @p13 && @p12 >= @p23 ) ? @p12 :
    ( @p13 >= @p23 )                 ? @p13 :
                                       @p23 ;
}

sub distance_along_path {
# paths with format: [noderef1, noderef2,...]
    my $node = shift;
    array_ref( $node ) || return undef;
    my $d1 = get_FIG_X( $node );
    my $d2 = @_ ? distance_along_path(@_) : 0;
    defined($d1) && defined($d2) ? $d1 + $d2 : undef;
}

sub distance_along_path_2 {
# paths with format: [descIndex1, nodeRef1, descRef2, nodeRef2,...]
    shift;                 #  Discard descendant number
    my $node = shift;
    array_ref( $node ) || return undef;
    my $d1 = get_FIG_X( $node );
    my $d2 = @_ ? distance_along_path_2(@_) : 0;
    defined($d1) && defined($d2) ? $d1 + $d2 : undef;
}

sub most_distant_tip_path {
    my ($node) = @_;
    my ($tmax, $xmax) = most_distant_tip_ref($node);
    my @pmax = FIG_path_to_node_ref($node, $tmax); 
    @pmax;
}
sub closest_tip_path {
    my ($node) = @_;
    my ($tmin, $xmin) = closest_tip_ref($node);
    my @pmin = FIG_path_to_node_ref($node, $tmin); 
    @pmin;
}
sub closest_tip_ref {
    my ($node) = @_;
    my @tpairs = sort_list_of_pairs( collect_tips_and_dist($node) );
    my $tmin = shift @tpairs;
    my $xmin = shift @tpairs;
    ( $tmin, $xmin );
}

sub most_distant_tip_ref {
    my ($node) = @_;
    my @tpairs = sort_list_of_pairs( collect_tips_and_dist($node) );
    my $xmax = pop @tpairs;
    my $tmax = pop @tpairs;
    ( $tmax, $xmax );
}

sub most_distant_tip_name {
    my ($tipref, $xmax) = most_distant_tip_ref( $_[0] );
    ( get_FIG_label( $tipref ), $xmax )
}

sub closest_tip_name {
    my ($tipref, $xmin) = closest_tip_ref( $_[0] );
    ( get_FIG_label( $tipref ), $xmin )
}

sub FIG_dist_tip_to_tip {
# tip1 and tip2 should be tip labels and contained in subtree rooted at $node
    my ($node, $tip1, $tip2) = @_;

    array_ref( $node ) && defined( $tip1 )
                       && defined( $tip2 ) || return undef;

    my @p1 = FIG_path_to_tip($node, $tip1);
    my @p2 = FIG_path_to_tip($node, $tip2);
    @p1 && @p2 || return undef;   
   
    # Find the unique suffixes of the two paths
    my ( $suf1, $suf2 ) = unique_suffixes( \@p1, \@p2 );
    my $d1 = @$suf1 ? distance_along_path( @$suf1 ) : 0;
    my $d2 = @$suf2 ? distance_along_path( @$suf2 ) : 0;
    defined( $d1 ) && defined( $d2 ) ? $d1 + $d2 : undef;
} 
  
sub FIG_dist_node_to_node {
# both node1 and node2 must be refs and in the subtree rooted at $node
# node1 ,node2 could be= $tipname | [$tipname] |  $t1 $t2 $t3 
    my ($node, $node1, $node2) = @_;

    array_ref( $node ) && defined( $node1 )
                       && defined( $node2 ) || return undef;
    my @p1 = FIG_path_to_node($node, $node1);
    my @p2 = FIG_path_to_node($node, $node2);
    @p1 && @p2 || return undef;     

    # Find the unique suffixes of the two paths
    my ( $suf1, $suf2 ) = unique_suffixes( \@p1, \@p2 );
    my $d1 = @$suf1 ? distance_along_path( @$suf1 ) : 0;
    my $d2 = @$suf2 ? distance_along_path( @$suf2 ) : 0;
    defined( $d1 ) && defined( $d2 ) ? $d1 + $d2 : undef;
}

sub get_FIG_context {
# gets tips and nodes within $dist of current $node
    my($node,$dist) = @_;
    array_ref($node) && defined($n) || 0;
    my $tips = FIG_tips_within_dist($node, $dist);
    my $nodes = FIG_nodes_within_dist($node, $dist);
    return @$tips + @$nodes;
}

sub FIG_closest_common_ancestor {
# finds common ancestor of up to three tips 
    my ($tree, @tips) = @_;
    array_ref($tree) || return undef;
    (scalar @tips > 0) || return undef;

    my @paths;
    foreach $tip (@tips) {
      push( @paths, [ FIG_path_to_tip($tree,$tip) ]);
    }
    #simple cases first
    if (scalar @paths == 1) 
       { my $p = @paths[0];
         return @$p; }
    if (scalar @paths == 2) 
       { return common_prefix( @paths[0], @paths[1]) ; }
    if (scalar @paths == 3) 
      { 
        my @p12 = common_prefix( @paths[0], @paths[1]) ;
        my @p13 = common_prefix( @paths[0], @paths[2]) ;
        my @p23 = common_prefix( @paths[1], @paths[2]) ;

        # Return the shortest common prefix 
        return common_prefix(\@p12,[common_prefix(\@p13,\@p23)]);
      }
    # more than three tips. Not processed here
    undef;
}
 

#==================================================================
#  Tree manipulations
#  Note: most funtions in this section will alter the tree
#==================================================================
sub FIG_copy_tree {
# creates a copy of the subtree rooted at $node
    my ($node, $parent) = @_;
    array_ref( $node ) || return undef;
    my ( $label, $X, $p, $FIG_desc_list, $node_attrib, $branch_attrib ) 
       = @$node;

    # copying hashes
    my $nattrib_ref = [];
    my $battrib_ref = [];

    my ( $key, $val);
    if ( hash_ref( $node_attrib ) ) {
        @$nattrib_ref = map {
            $key = $_;
            $val = $node_attrib->{$key};
            ref( $val ) eq "ARRAY" ? map { "$key\t$_" } @$val : "$_\t$val" ;
                           } keys %$node_attrib;
    }
    if ( hash_ref( $branch_attrib ) ) {
        push( @$battrib_ref, map {
            $key = $_;
            $val = $branch_attrib->{$key};
            ref( $val ) eq "ARRAY" ? map { "$key\t$_" } @$val : "$_\t$val";
                           } keys %$branch_attrib );
    }

    # creating fig node 
    my $nfig=[ $label,$X,$parent,undef,$nattrib_ref,$battrib_ref]; 

    # doing the same for each child in descendants list
    if ( $FIG_desc_list && @$FIG_desc_list ) {
        my $desc_ref = [ map {FIG_copy_tree( $_, $nfig )} @$FIG_desc_list ];
        foreach ( @$desc_ref[ 1 .. @$desc_ref-1 ] ) {
            ( ref( $_ ) eq "ARRAY" ) || return undef
        }
        $nfig->[3] = $desc_ref;
    }
    else {
        $nfig->[3] = [ ];
    }

    $nfig;
}

sub FIG_build_tree_from_subtrees {
# creates a root node and appends the trees to its descList
    my($tree1,$tree2, $label, $x) = @_;
    array_ref($tree1) && array_ref($tree2) || undef;
    my $nfig = [$label,$x, undef, undef,[],[]];
    $tree1->[2] = $nfig;
    $tree2->[2] = $nfig;
    $nfig->[3]->[0]= $tree1;
    $nfig->[3]->[1]= $tree2;
    return $nfig;
}

sub FIG_reverse_tree {
# reverses order of tree [in place]
    my ($node) = @_;

    my $imax = get_FIG_numDesc( $node );
    if ( $imax > 0 ) {
        set_FIG_descList( $node, reverse get_FIG_descList( $node ) );
        for ( my $i = 1; $i <= $imax; $i++ ) {
            FIG_reverse_tree( get_FIG_ith_desc( $node, $i ) );
        }
    }
    $node;
}

sub FIG_top_tree {
# creates a copy of a tree, then truncates all subtrees so all branches
# will have lengths no larger than $depth
   my ($tree, $depth) = @_;
   array_ref($tree) && defined($depth) || undef;
   my $newtree = FIG_copy_tree($tree);
   FIG_chop_tree($newtree, $depth);
}

sub FIG_chop_tree {
#  chops branches [i.e. tip and/or complete subtrees] 
#  of tree rooted at $node; resulting branch-lengths are <= $depth
   my ($node,$depth) = @_;
   array_ref($node) && defined($depth) || undef;
   my $sz = FIG_tree_length($node);
   if ($sz <= $depth) 
       { print "\n nothing to chop depth > treeLength"; 
         return undef; }
   #my $root = get_FIG_root($node);
   chop_tree($node, $node, $depth);
}

sub chop_tree {
# chops entire sections of the tree rooted at $node
# whose branch-lengths are larger than $depth
    ($tree, $node,$depth) = @_;
    array_ref($node) && array_ref($root) && defined($depth)|| undef;
    my ($child, $len);
    $len = $depth;
    if ($len < 0) 
    {
      #need to chop at this point.
      is_FIG_tip($node) ? return FIG_prune_tip($tree, $node) :
                          return FIG_prune_node($tree, $node);
    }
    foreach $child (@{$node->[3]}) {
      chop_tree($tree, $child, $len-$child->[1]);
    }
}

sub FIG_split_tree {
# we split the tree at random into subregions, AKA bunches 
# Our approach: at least one region is sure to contain 
# the tree's representative leaves; the other regions 
# will contain leaves that were selected at random

  my ($fig, $numBunches) = @_;
  my @trees;
  if (! array_ref($fig)) { print "\split info missing, no tree"; return undef;}
  if (! $numBunches) { print "\nsplit info missing, no numbunch"; return undef;}
  if ($numBunches == 1) {print "\nno split, numbunch is one";return $fig; }
  

  # so far, we will use these heuristics; later on
  # we need to replace this one with min spanning tree
  # or some such
  my $size = FIG_region_size($fig, $numBunches );
  $trees[1] = FIG_representative_tree(FIG_copy_tree($fig), $size );
  for (my $i = 2; $i <= $numBunches; $i++) {
    $trees[$i] = &get_random_minitree(FIG_copy_tree($fig),$size );
  }
  return @trees;
}
 
sub get_random_minitree {
  my ($tree,$size) = @_;
  array_ref($tree) && defined($size) || undef;
  my $tip;
  my @tips = FIG_tips_of_tree($tree);  
  my @randTips = random_order(@tips);
  my @minitree = splice @randTips, 0,$size;
  my @tipsToremove = set_difference(\@tips, \@minitree);
  if (! @tipsToremove) {return undef;}
  foreach $tip (@tipsToremove) { FIG_prune_tip($tree,$tip);  }
  return $tree;
} 


sub FIG_representative_tree {
# thins the tree off of small tips until tree is of specified size
   my ($tree, $size) = @_;
   my $tip;  
   array_ref($tree) && defined($size) || undef;
   my @tiprefs = collect_all_tips( $tree );
   my @sortedtips = sort by_distance @tiprefs;
   my $to_remove = (scalar @sortedtips) - $size;
   if ($to_remove <= 0) { return $tree; }
   my @tips= tipref_to_tipname(@sortedtips);
   while ($to_remove > 0)
     {
       $tip = shift @tips;
       FIG_prune_tip($tree,$tip);
       $to_remove--;
     }
   $tree;
}

sub collapse_FIG_tree {
# searches entire tree rooted at $tree and collapses unneces. branches.
# there are two cases: 
#                     node-tip  -> tip  collapse
#                     node-node -> node collapse
   my ($tree) = @_;
   array_ref($tree) || undef;
   if ( is_FIG_tip($tree) ) { return; }
   if ( (! is_FIG_tip($tree) ) && ( get_FIG_numDesc($tree) == 1) )
     { 
        is_FIG_tip($tree->[3]->[0]) ?
          FIG_collapse_node_tip($tree)  :
          FIG_collapse_node_node($tree) ;
      }
   my $child;
   foreach $child (@{$tree->[3]}) {
      collapse_FIG_tree($child);
   }
   $tree;
}
sub FIG_collapse_node_tip {
# $node has one descendant which is a tip 
# we collapse both node and tip into one [tip]
  my ($node) = @_;
  array_ref($node) || undef;
  my $child = $node->[3];
  if (scalar @$child > 1) { #stop. more than one child
     return undef; }
  my $tip = shift @$child;
  is_FIG_tip($tip) || undef;

  # collapsing tip and node into one tip";
  $node->[0] = join($node->[0],$tip->[0]);
  $node->[1] += $tip->[1];
  $node->[3] = [];
  add_FIG_node_attrib($node, $tip->[4]);
  add_FIG_branch_attrib($node, $tip->[5]); 
 
  $node;
}

sub FIG_collapse_node_node {
# $node has one descendant which is NOT a tip 
# we collapse both nodes into one [node]
  my ($node) = @_;
  array_ref($node1) || undef;

  my $child = $node->[3];
  if (scalar @$child > 1) { return undef; }
  my $child = shift @$child;
  if (is_FIG_tip($child) ) { return FIG_collapse_node_tip($node) }

  # collapsing two nodes into one
  $node->[0] = join($node->[0],$child->[0]);
  $node->[1] += $child->[1];
  $node->[3] = $child->[3];
  add_FIG_node_attrib($node,$child->[4]);
  add_FIG_branch_attrib($node,$child->[5]); 

  $node;
}

sub FIG_prune_tip {
# tip node is deleted,  then tree is normalized w/ local operations
# input could be tipref or tipname
  my ($tree, $tip1) = @_;

  array_ref($tree) && defined($tip1) || undef;

  if (! array_ref($tip1) ) 
     { # arg 2 is a tipname; we need a tipref
        $tip1 = get_FIG_tipref($tree,$tip1); 
     }

  if (!is_FIG_tip($tip1)) {print "\ntip not in tree: ";
                           print $tip1;return undef;}
  my $parent = $tip1->[2];
  if (! array_ref($parent)) {print "\nlast tip, now empty tree";return undef; }
  my $children = $parent->[3];
  my @leaves;
  my $tip2;
  my $child;

  #some of the children may not be tips; let's find out
  foreach $child (@{$parent->[3]})
    { if ($child->[0]) { push (@leaves,$child); } }
 
  if (scalar @leaves == 3)
    { 
      # unrooted tree. Delete tip from the parent's descList
      delete_FIG_descRef($parent,$tip1); 
      return tree;
    }
  if (scalar @leaves == 2)
    { 
      # need to collapse tip2 and tip1's parent nodes into one
      ($tip2) = pop @leaves;
      if ($tip2->[0] eq $tip1->[0]) { $tip2= pop @leaves; }
      $parent->[0] = $tip2->[0];
      $parent->[1] += $tip2->[1];
      $parent->[3] = undef;     
      if (array_ref($tip2->[4]) )
      {add_FIG_node_attrib($parent, $tip2->[4]);}
      if (array_ref( $tip2->[5]) ) 
      {add_FIG_branch_attrib($parent, $tip2->[5]); }
      return tree;
    }
  if (scalar @leaves == 1)
    {
      if (@$children == 1) {
        # just delete tip from the parent's descList
        $parent->[3] = undef;
        return tree;
      }
      else {
        # we have one tip and one node hanging out of parent node
        # we need to collapse two nodes in a row into one
        FIG_prune_node($parent,$tip1);
        return tree;
      }
    }  
   if (scalar @leaves == 0) 
    { print "\nabsurd, no tips"; return tree; }    
  return $tree;
}


sub FIG_prune_node {
# entire subtree rooted at $node1 is deleted,  
# resulting $tree is normalized with local operations
  my ($tree, $node1) = @_;
  is_FIG_node($node1) || undef;
  if (is_FIG_root($node1)) { return uproot_FIG($node1) } 
  my $parent = $node1->[2];
  my $grandp = $parent->[2];
  my $children = $parent->[3];
  my $node2;
  if ( ! $grandp) 
     { # close to root; just delete it from parent's desc list
      delete_FIG_descRef($parent,$node1);  
      return $parent;    
     }
  if (@$children == 2)
    { # need to collapse parent and sibling into one";
      $node2 = ($children->[0] eq $node1) ? 
               $children->[1] : $children->[0];
      $node2->[0] = $parent->[0];
      $node2->[1] += $parent->[1];
      $node2->[2] = $grandp;
      add_FIG_node_attrib($node2,$parent->[4]);
      add_FIG_branch_attrib($node2,$parent->[5]); 
      delete_FIG_descRef($grandp,$parent);
      add_FIG_desc($grandp,$node2); 
    }
  else {return undef }
  $node2;
}

sub normalize_FIG_tree {
# performs global operations on tree to get rid of nodes
# with a single child
    my ($node) = @_;

    my @descends = get_FIG_descList( $node );
    if ( @descends == 0 ) { return ( $node, lc get_FIG_label( $node ) ) }

    my %hash = map { (normalize_FIG_tree( $_ ))[1] => $_ } @descends;
    my @keylist = sort { $a cmp $b } keys %hash;
    set_FIG_descList( $node, map { $hash{$_} } @keylist );

    ($node, $keylist[0]);
}

sub std_unrooted_FIG {
    my ($tree) = @_;
    my ($mintip) = sort { lc $a cmp lc $b } FIG_tips_of_tree( $tree );
    ( normalize_FIG_tree( reroot_next_to_tip( $tree, $mintip ) ) )[0];
}


sub build_tip_count_hash {
    my ($node, $cntref) = @_;
    my ($i, $imax, $cnt);

    $imax = get_FIG_numDesc($node);
    if ($imax < 1) { $cnt = 1 }
    else {
        $cnt = 0;
        for ( $i = 1; $i <= $imax; $i++ ) {
           $cnt += build_tip_count_hash(get_FIG_ith_desc($node, $i),$cntref );
        }
    }

    $cntref->{$node} = $cnt;
    $cnt;
}

sub FIG_random_order_tree {
    my ($node) = @_;
    my $nd = get_FIG_numDesc($node);
    if ( $nd <  1 ) { return $node }       #  Do nothing to a tip
    #  Reorder this subtree:
    my $dl_ref = get_FIG_descRef($node);
    @$dl_ref = random_order( @$dl_ref );
    #  Reorder descendants:
    for ( my $i = 0; $i < $nd; $i++ ) {
        FIG_random_order_tree( $dl_ref->[$i] );
    }
    $node;
}

sub reorder_FIG_by_tip_count {
    my ($node, $cntref, $dir) = @_;

    my $nd = get_FIG_numDesc($node);
    if ( $nd <  1 ) { return $node }       #  Do nothing to a tip

    #  Reorder this subtree:

    my $dl_ref = get_FIG_descRef($node);
    if    ( $dir < 0 ) {                   #  Big group first
        @$dl_ref = sort { $cntref->{$b} <=> $cntref->{$a} } @$dl_ref;
    }
    elsif ( $dir > 0 ) {                   #  Small group first
        @$dl_ref = sort { $cntref->{$a} <=> $cntref->{$b} } @$dl_ref;
    }

    #  Reorder within descendant subtrees:

    my $step = 0;
    if (abs($dir) < 1e5) {
        $dir = 1 - $nd;                              #  Midgroup => as is
    #   $dir = 1 - $nd + ( $dir < 0 ? -0.5 : 0.5 );  #  Midgroup => outward
        $step = 2;
    }

    for ( my $i = 0; $i < $nd; $i++ ) {
        reorder_FIG_by_tip_count( $dl_ref->[$i], $cntref, $dir );
        $dir += $step;
    }

    $node;
}

sub reorder_FIG_against_tip_count {
    my ($node, $cntref, $dir) = @_;

    my $nd = get_FIG_numDesc($node);
    if ( $nd <  1 ) { return $node }       #  Do nothing to a tip

    #  Reorder this subtree:

    my $dl_ref = get_FIG_descRef($node);
    if    ( $dir > 0 ) {                   #  Big group first
        @$dl_ref = sort { $cntref->{$b} <=> $cntref->{$a} } @$dl_ref;
    }
    elsif ( $dir < 0 ) {                   #  Small group first
        @$dl_ref = sort { $cntref->{$a} <=> $cntref->{$b} } @$dl_ref;
    }

    #  Reorder within descendant subtrees:

    my $step = 0;
    if (abs($dir) < 1e5) {
        $dir = 1 - $nd;                              #  Midgroup => as is
    #   $dir = 1 - $nd + ( $dir < 0 ? -0.5 : 0.5 );  #  Midgroup => outward
        $step = 2;
    }

    for ( my $i = 0; $i < $nd; $i++ ) {
        reorder_FIG_by_tip_count( $dl_ref->[$i], $cntref, $dir );
        $dir += $step;
    }

    $node;
}

sub rearrange_FIG_smallest_out {
    my ($tree, $dir) = @_;
    my %cnt;

    $dir = ! $dir       ?        0 :  #  Undefined or zero
             $dir <= -2 ? -1000000 :
             $dir <   0 ?       -1 :
             $dir >=  2 ?  1000000 :
                                 1 ;
    build_tip_count_hash( $tree, \%cnt );
    reorder_FIG_against_tip_count( $tree, \%cnt, $dir );
}

sub rearrange_FIG_largest_out {
    my ($tree, $dir) = @_;
    my %cnt;

    $dir = ! $dir       ?        0 :  #  Undefined or zero
             $dir <= -2 ? -1000000 :
             $dir <   0 ?       -1 :
             $dir >=  2 ?  1000000 :
                                 1 ;
    build_tip_count_hash( $tree, \%cnt );
    reorder_FIG_by_tip_count( $tree, \%cnt, $dir );
}


sub reroot_FIG_by_path {
    my ($node1, @rest) = @_;
    array_ref( $node1 ) || return undef;     

    @rest || return $node1; 

    my $node2 = $rest[0];           
    is_desc_of_FIGnode($node1, $node2) || return undef; 

    #removing node2 from node1's descendant list
    my $dl1 = delete_elm( $node1->[3], $node2 );
    my $nd1 = @$dl1;

    #  Append node 1 to node 2 descendant list (does not alter numbering):
    my $dl2 = get_FIG_descRef( $node2 );
    if ( array_ref($dl2) ) { push (@$dl2, $node1 )}
    else                   { set_FIG_descList( $node2, [ $node1 ] ) }

    #  Move c1 comments from node 1 to node 2:

    my $C11 = $node1->[4]->{ "Newick_C1" };
    my $C12 = $node2->[4]->{ "Newick_C1" };
    ! defined( $C11 ) || set_FIG_node_attrib( $node1,( 'Newick_C1' =>undef ));
    if ( $C12 && @$C12 ) {                      
        if ( $C11 && @$C11 ) { unshift @$C12, @$C11 }
    }
    elsif ( $C11 && @$C11 ) {set_FIG_node_attrib($node2,('Newick_C1'=>$C11))}  

    #  Swap branch lengths and comments for reversal of link direction:

    my $x1 = get_FIG_X( $node1 );
    my $x2 = get_FIG_X( $node2 );
    ! defined( $x1 ) && ! defined ( $x2 ) || set_FIG_X( $node1, $x2 );
    ! defined( $x1 ) && ! defined ( $x2 ) || set_FIG_X( $node2, $x1 );

    my $c41 = $node1->[5]->{ "Newick_C4" };
    my $c42 = $node2->[5]->{ "Newick_C4" }; 
    ! defined( $c42 ) || ! @$c42 || 
    set_FIG_branch_attrib($node1,('Newick_C4'=>$c42)) ;
    ! defined( $c41 ) || ! @$c41 || 
    set_FIG_branch_attrib($node2,('Newick_C4'=>$c41)) ;


    my $c51 = $node1->[5]->{ "Newick_C5" };
    my $c52 = $node2->[5]->{ "Newick_C5" };
    ! defined( $c52 ) || ! @$c52 || 
    set_FIG_branch_attrib($node1,('Newick_C5'=>$c52)) ;

    ! defined( $c51 ) || ! @$c51 || 
    set_FIG_branch_attrib($node2,('Newick_C5'=>$c51)) ;

    reroot_FIG_by_path( @rest );        
}

sub reroot_FIG_to_tip {
    my ($tree, $tipname) = @_;
    my @path = FIG_path_to_tip( $tree, $tipname );
    reroot_FIG_by_path(@path);
}
sub reroot_FIG_next_to_tip {
    my ($tree, $tipname) = @_;
    my @path = FIG_path_to_tip( $tree, $tipname );
    @path || return undef;
    @path == 1 ? reroot_FIG_by_path( $tree, 1,get_FIG_ith_desc( $tree, 1 ) )
               : reroot_FIG_by_path( @path[0 .. @path-3] );
}
sub reroot_FIG_to_node {
    reroot_FIG_by_path( FIG_path_to_node( @_ ) );
}
sub reroot_FIG_to_node_ref {
    my ($tree, $node) = @_;
    reroot_FIG_by_path( FIG_path_to_node_ref( $tree, $node ) );
}

sub uproot_tip_to_node {
    my ($node) = @_;
    is_FIG_tip_rooted( $node ) || return $node;

    #  Path to the sole descendant:
    reroot_FIG_by_path( $node, 1, get_FIG_ith_desc( $node, 1 ) );
}

sub uproot_FIG {
# removes bifurcating tree
    my ($node0) = @_;
    is_FIG_rooted( $node0 ) || return $node0;
    
    my $node1 = get_FIG_ith_desc( $node0, 1 );
    my $node2 = get_FIG_ith_desc( $node0, 2 );

    #  Ensure that node1 has at least 1 descendant
    if    (get_FIG_numDesc($node1) ) { }
    elsif (get_FIG_numDesc($node2) ) { ($node1,$node2) = ($node2, $node1) }
    else { die "uproot_FIG requires more that 2 taxa\n" }

    push(@{ get_FIG_descRef($node1) }, $node2);   

    #  Prefix node1 branch to that of node2:

    add_FIG_branch_attrib($node2,get_FIG_branch_attrib($node1));
    set_FIG_X($node2, $node2->[1]+$node1->[1]);

    set_FIG_X($node1, undef); 
    set_FIG_branch_attrib($node1, undef); 


    #  Tree prefix comment lists (as references):
    my $C10 = $node0->[4]->{ "Newick_C1" };
    my $C11 = $node1->[4]->{ "Newick_C1" };

    if ( $C11 && @$C11 ) { 
        if ( $C10 && @$C10 ) { unshift @$C11, @$C10 }
    }
    else { set_FIG_node_attrib($node1,('Newick_C1'=>$C10)) }
    set_FIG_node_attrib($node0,('Newick_C1'=>undef));

    $node1;
}


#------------------------------------------------------------------
#  I/O [parse/print] functions
#------------------------------------------------------------------

sub FIG_print_node_attrib {
   my ($FIG_node) = @_;
   my ( $label, $X, $parent, $FIG_desc_list, $node_attrib, $branch_attrib )
       = @$FIG_node;
   my ($key, $val);
   if ( hash_ref( $node_attrib ) ) {
         while ($key = each %$node_attrib)
             {
               $val = $node_attrib->{$key};
               if (@$val > 0) { print "$key: "; map {print  "$_, " } @$val;} 
               else { print "$key: ",$val ; }
	     }
      }       
}      

sub FIG_print_branch_attrib { 
   my ($FIG_node) = @_;
   my ( $label, $X, $parent, $FIG_desc_list, $node_attrib, $branch_attrib )
       = @$FIG_node;
   my ($key, $val);
   if ( hash_ref( $branch_attrib ) ) {
         while ($key = each %$branch_attrib)
             {
               $val = $branch_attrib->{$key};
               if (@$val > 0) { print "$key: "; map {print  "$_, " } @$val;} 
               else { print "$key: ",$val ; }
	     }
      }
    
}

sub print_attrib_hash {
   my ($hash) = @_;
   my ($key, $val);
   if ( hash_ref( $hash ) ) {
         while ($key = each %$hash)
             {
               $val = $hash->{$key};
               @$val > 1 ? print "$key: ",@$val : print "$key: ",$val ;
	     }
      }
    else { print "\nnot a hash table" }
}

sub FIG_print_node {
   my ($FIG_node) = @_;
   my ( $label, $X, $parent, $FIG_desc_list, $node_attrib, $branch_attrib )
       = @$FIG_node;
   my $child;
   print "\nnode info= \n";
   print "ref : $FIG_node lbl: $label len: $X  par: $parent ";
   print " node?: ", &is_FIG_node($FIG_node); 
   print " leaf?: ", &is_FIG_tip($FIG_node); 
   print "\nnumChildren: ", &get_FIG_numDesc($FIG_node);  
   print " childrenRefs: @$FIG_desc_list ";
   print "\nnAtt: $node_attrib len = ",&get_FIG_num_node_attrib;
   print " key:vals= "; print FIG_print_node_attrib($FIG_node); 
   print "\nbAtt: $branch_attrib len =", &get_FIG_num_branch_attrib;
   print " key:vals= "; print FIG_print_branch_attrib($FIG_node);
}

sub FIG_print_tree {
   my ($FIG_node) = @_;
   my $child;
   &FIG_print_node($FIG_node);
   foreach $child (@{$FIG_node->[3]}) { &FIG_print_tree($child); }
}

sub write_FIG_to_Newick {
# writes to file the FIG tree in Newick format
    my ($figtree) = @_;
    open $fh, ">newickOut";
    writeNewickTree( FIGtree_to_newick($figtree), $fh );
    close $fh;
}

sub read_FIG_from_str {
# reads a string and creates a fig tree with it
   my ($string) = @_;
   my $newick = parse_newick_tree_str( $string );
   my $fig = newick_to_FIGtree( $newick );
   $fig;
}

sub layout_FIG_tree {
   my ($fignode) = @_;
   layout_tree( FIGtree_to_newick($fignode) );
}

#=========================================================================
#  Interconverting Overbeek tree and FIG_tree:
#=========================================================================
#  overbeek_to_FIGtree
#-------------------------------------------------------------------------

sub overbeek_to_FIGtree {
    my ( $ro_node, $parent ) = @_;
    ( ref( $ro_node ) eq "ARRAY" ) && ( @$ro_node ) || return undef;

    ( ref( $parent ) eq "ARRAY" ) || ( $parent = undef );

    my ( $label, $X, $ro_desc_list, $ro_attrib_list ) = @$ro_node;
    ( array_ref($ro_desc_list) && ( @$ro_desc_list ) ) || return undef;

    #  Process the node attribute list key value pairs.  Newick comments are
    #  special case in that they always go in a list, not a standalone value.
    #  Comments 4 and 5 are branch properties in a FIGtree.

    my $n_attrib_ref = undef;
    my $b_attrib_ref = undef;

    if ( ref( $ro_attrib_list ) eq "ARRAY" ) {
        my %n_attribs = ();
        my %b_attribs = ();
        my ( $key, $val );

        foreach ( @$ro_attrib_list ) {
            if ( $_ =~ /^([^\t]+)\t(.*)$/ ) {
                ( $key, $val ) = ( $1, $2 );
                if ( $key =~ /^Newick_C[1-3]$/ ) {
                    if ( $n_attribs{ $key } ) { push @{ $n_attribs{ $key } }, $val }
                    else                      { $n_attribs{ $key } = [ $val ] }
                }
                elsif ( $key =~ /^Newick_C[45]$/ ) {
                    if ( $b_attribs{ $key } ) { push @{ $b_attribs{ $key } }, $val }
                    else                      { $b_attribs{ $key } = [ $val ] }
                }
                else {
                    $n_attribs{ $key } = $val;
                }
            }
        }
        if ( %n_attribs ) { $n_attrib_ref = \%n_attribs }
        if ( %b_attribs ) { $b_attrib_ref = \%b_attribs }
    }

    #  We need to create the FIGtree node reference before we can create the
    #  children:

    my $FIG_node = [ $label,
                     $X,
                     $parent,
                     undef,
                     $b_attrib_ref ? ( $n_attrib_ref, $b_attrib_ref )
                   : $n_attrib_ref ? ( $n_attrib_ref )
                   :                 ()
                   ];

    #  Build the descendent list, and check that all child nodes are defined:

    if ( @$ro_desc_list > 1 ) {
        my $desc_ref = [ map { overbeek_to_FIGtree( $_, $FIG_node )
                             } @$ro_desc_list[ 1 .. @$ro_desc_list-1 ]
                       ];
        foreach ( @$desc_ref ) { ( ref( $_ ) eq "ARRAY" ) || return undef }
        $FIG_node->[3] = $desc_ref;
    }

    $FIG_node;
}


#-------------------------------------------------------------------------
#  FIGtree_to_overbeek
#-------------------------------------------------------------------------

sub FIGtree_to_overbeek {
    my ( $FIG_node, $parent ) = @_;
    ( ref( $FIG_node ) eq "ARRAY" ) && ( @$FIG_node ) || return undef;

    ( ref( $parent ) eq "ARRAY" ) || ( $parent = 0 );

    my ( $label, $X, undef, $FIG_desc_list, $node_attrib, $branch_attrib ) = @$FIG_node;
    ( ! $FIG_desc_list ) || ( ref( $FIG_desc_list ) eq "ARRAY" ) || return undef;

    #  Build attribute key-value pairs.  Expand lists into multiple
    #  instances of same key:

    my $attrib_ref = [];
    my ( $key, $val);
    if ( ref( $node_attrib ) eq "HASH" ) {
        @$attrib_ref = map {
            $key = $_;
            $val = $node_attrib->{$key};
            ref( $val ) eq "ARRAY" ? map { "$key\t$_" } @$val : "$_\t$val"
                           } keys %$node_attrib;
    }
    if ( ref( $branch_attrib ) eq "HASH" ) {
        push( @$attrib_ref, map {
            $key = $_;
            $val = $branch_attrib->{$key};
            ref( $val ) eq "ARRAY" ? map { "$key\t$_" } @$val : "$_\t$val"
                               } keys %$branch_attrib);
    }

    #  Create the Overbeek node so that we have parent reference for the
    #  children:

    my $ro_node = [ $label, $X, undef, $attrib_ref ];

    #  Build the descendent list, with the parent node as the first element:

    if ( $FIG_desc_list && @$FIG_desc_list ) {
        my $desc_ref = [ $parent,
                         map { FIGtree_to_overbeek( $_, $ro_node ) } @$FIG_desc_list
                       ];
        foreach ( @$desc_ref[ 1 .. @$desc_ref-1 ] ) {
            ( ref( $_ ) eq "ARRAY" ) || return undef
        }
        $ro_node->[2] = $desc_ref;
    }
    else {
        $ro_node->[2] = [ $parent ];
    }

    $ro_node;
}


#=========================================================================
#  Parent node references in FIG trees and Overbeek trees.
#
#  Both FIG trees and Overbeek trees include a reference back to the
#  parent node.  We should condsider it it is worth routinely maintaining
#  these values (creating them as the tree is created), or wether to fill
#  them in only when needed (which will be very fast).
#
#  The following two routines add/update the values in an existing tree.
#=========================================================================
#  fill_FIGtree_parents
#-------------------------------------------------------------------------

sub fill_FIGtree_parents {
    my ( $FIG_node, $parent ) = @_;
    ( ref( $FIG_node ) eq "ARRAY" ) && ( @$FIG_node ) || return undef;

    ( ref( $parent ) eq "ARRAY" ) || ( $parent = undef );
    $FIG_node->[2] = $parent;

    #  Work through the descendent list:
    
    my $desc_list = $FIG_node->[3];
    if ( ref( $desc_list ) eq "ARRAY" ) {
        foreach ( @$desc_list ) {
            fill_FIGtree_parents( $_, $FIG_node ) || return undef;
        }
    }

    $FIG_node;
}


#-------------------------------------------------------------------------
#  fill_overbeek_parents
#-------------------------------------------------------------------------

sub fill_overbeek_parents {
    my ( $ro_node, $parent ) = @_;
    ( ref( $ro_node ) eq "ARRAY" ) && ( @$ro_node ) || return undef;

    ( ref( $parent ) eq "ARRAY" ) || ( $parent = 0 );

    my $desc_list = $ro_node->[2];
    if ( ! $desc_list ) {
        $ro_node->[2] = [ $parent ];
    }
    else {
        ( ref( $desc_list ) eq "ARRAY" ) || return undef;
        $desc_list->[0] = $parent;

        #  Work through the rest of the descendent list:

        my $last_index = @$desc_list - 1;
        foreach ( @$desc_list[ 1 .. $last_index ] ) {
            fill_overbeek_parents( $_, $ro_node ) || return undef;
        }
    }

    $ro_node;
}


#=========================================================================
#  Interconverting Newick tree and FIG_tree:
#=========================================================================
#  newick_to_FIGtree
#-------------------------------------------------------------------------

sub newick_to_FIGtree {
    my ( $newick_node, $parent ) = @_;
    ( ref( $newick_node ) eq "ARRAY" ) && ( @$newick_node ) || return undef;

    ( ref( $parent ) eq "ARRAY" ) || ( $parent = undef );

    my ( $desc_list, $label, $X, $c1, $c2, $c3, $c4, $c5 ) = @$newick_node;

    #  Put C1, C2 and C3 values in the node attribute list, with the key
    #  "Newick_CN".  Check C1 comments for "FIG_tree_node_attribute"
    #  values.  These are pulled out of the Newick comment and are made
    #  into node key-value pairs.

    my $node_attrib = undef;
    if ( $c1 || $c2 || $c3 ) {
        $node_attrib = {};
        if ( $c1 ) {
            ( ref( $c1 ) eq "ARRAY" ) || return undef;
            my @c1b = ();
            foreach ( @$c1 ) {
                if  (   ( ref( $_ ) eq "ARRAY" )
                     && ( $_->[0] eq "FIG_tree_node_attribute" )
                    ) {
                    $node_attrib->{ $_->[1] } = $_->[2];
                }
                else {
                    push @c1b, $_;
                }
            }
            if ( @c1b ) {
                $node_attrib->{ "Newick_C1" } = ( @$c1 == @c1b ) ? $c1 : \@c1b;
            }
        }
        if ( $c2 ) { $node_attrib->{ "Newick_C2" } = $c2 }
        if ( $c3 ) { $node_attrib->{ "Newick_C3" } = $c3 }
    }

    #  Put C4 and C5 values in the branch attribute list, with the key
    #  "Newick_CN".  Check C4 comments for "FIG_tree_branch_attribute"
    #  values.  These are pulled out of the Newick comment and are made
    #  into branch key-value pairs.

    my $branch_attrib = undef;
    if ( $c4 || $c5 ) {
        $branch_attrib = {};
        if ( $c4 ) {
            ( ref( $c4 ) eq "ARRAY" ) || return undef;
            my @c4b = ();
            foreach ( @$c4 ) {
                if  (   ( ref( $_ ) eq "ARRAY" )
                     && ( $_->[0] eq "FIG_tree_branch_attribute" )
                    ) {
                    $branch_attrib->{ $_->[1] } = $_->[2];
                }
                else {
                    push @c4b, $_;
                }
            }
            if ( @c4b ) {
                $branch_attrib->{ "Newick_C4" } = ( @$c4 == @c4b ) ? $c4 : \@c4b;
            }
        }
        if ( $c5 ) { $branch_attrib->{ "Newick_C5" } = $c5 }
    }

    #  We need a FIG node reference before we can create the children

    my $FIG_node = [ $label,
                     $X,
                     $parent,
                     undef,
                     ( $node_attrib || $branch_attrib ? $node_attrib   : () ),
                     (                 $branch_attrib ? $branch_attrib : () )
                   ];

    #  Make the descendent list and check that all the children are defined:

    if ( $desc_list ) {
        ( ref( $desc_list ) eq "ARRAY" ) || return undef;
        if ( @$desc_list ) {
            my $FIG_desc_ref = [ map { newick_to_FIGtree( $_, $FIG_node ) }
                                    @$desc_list
                               ];
            foreach ( @$FIG_desc_ref ) { ( ref( $_ ) eq "ARRAY" ) || return undef }
            $FIG_node->[3] = $FIG_desc_ref;
        }
    }

    $FIG_node;
}


#-------------------------------------------------------------------------
#  FIGtree_to_newick
#-------------------------------------------------------------------------

sub FIGtree_to_newick {
    my ( $FIG_node ) = @_;
    ( ref( $FIG_node ) eq "ARRAY" ) && ( @$FIG_node ) || return undef;

    my ( $label, $X, undef, $FIG_desc_list, $node_attrib, $branch_attrib ) = @$FIG_node;
    ( ! $FIG_desc_list ) || ( ref( $FIG_desc_list ) eq "ARRAY" ) || return undef;

    my ( $c1, $c2, $c3, $c4, $c5 );
    if ( ref( $node_attrib ) eq "HASH" ) {
        if ( $node_attrib->{ "Newick_C1" } ) {
            $c1 = $node_attrib->{ "Newick_C1" };
            ! defined( $c1 ) || ( ref( $c1 ) eq "ARRAY" ) || ( $c1 = [ $c1 ] );
        }
        if ( $node_attrib->{ "Newick_C2" } ) {
            $c2 = $node_attrib->{ "Newick_C2" };
            ! defined( $c2 ) || ( ref( $c2 ) eq "ARRAY" ) || ( $c2 = [ $c2 ] );
        }
        if ( $node_attrib->{ "Newick_C3" } ) {
            $c3 = $node_attrib->{ "Newick_C3" };
            ! defined( $c3 ) || ( ref( $c3 ) eq "ARRAY" ) || ( $c3 = [ $c3 ] );
        }
        if ( $node_attrib->{ "Newick_C4" } ) {
            $c4 = $node_attrib->{ "Newick_C4" };
            ! defined( $c4 ) || ( ref( $c4 ) eq "ARRAY" ) || ( $c4 = [ $c4 ] );
        }
        if ( $node_attrib->{ "Newick_C5" } ) {
            $c5 = $node_attrib->{ "Newick_C5" };
            ! defined( $c5 ) || ( ref( $c5 ) eq "ARRAY" ) || ( $c5 = [ $c5 ] );
        }

        #  Any node attributes that are not newick comments, will get
        #  pushed on C1 as 3-element lists with first element eq
        #  "FIG_tree_node_attribute"

        my @keys = map { /^Newick_C[1-5]$/ ? () : $_ } keys %$node_attrib;
        if ( @keys ) {
            my @c1b = $c1 ? @$c1 : ();
            push @c1b, map { [ "FIG_tree_node_attribute", $_, $node_attrib->{ $_ } ]
                           } @keys;
            $c1 = \@c1b;
        }
    }

    if ( ref( $branch_attrib ) eq "HASH" ) {
        if ( $branch_attrib->{ "Newick_C4" } ) {
            $c4 = $branch_attrib->{ "Newick_C4" };
            ! defined( $c4 ) || ( ref( $c4 ) eq "ARRAY" ) ||  ( $c4 = [ $c4 ] );
        }
        if ( $branch_attrib->{ "Newick_C5" } ) {
            $c5 = $branch_attrib->{ "Newick_C5" };
            ! defined( $c5 ) || ( ref( $c5 ) eq "ARRAY" ) ||  ( $c5 = [ $c5 ] );
        }

        #  Any branch attributes that are not newick comments, will get
        #  pushed on C4 as 3-element lists with first element eq
        #  "FIG_tree_branch_attribute"

        my @keys = map { /^Newick_C[45]$/ ? () : $_ } keys %$branch_attrib;
        if ( @keys ) {
            my @c4b = $c4 ? @$c4 : ();
            push @c4b, map { [ "FIG_tree_branch_attribute", $_, $branch_attrib->{ $_ } ]
                           } @keys;
            $c4 = \@c4b;
        }
    }

    my $desc_ref = undef;
    if ( $FIG_desc_list && @$FIG_desc_list ) {
        $desc_ref = [ map { FIGtree_to_newick( $_ ) } @$FIG_desc_list ];
        foreach ( @$desc_ref ) { array_ref( $_ ) || return undef }
    }

    [ $desc_ref, $label, $X, $c5 ? ( $c1, $c2, $c3, $c4, $c5 )
                           : $c4 ? ( $c1, $c2, $c3, $c4 )
                           : $c3 ? ( $c1, $c2, $c3 )
                           : $c2 ? ( $c1, $c2 )
                           : $c1 ? ( $c1 )
                           :       ()
    ];
}


1;
