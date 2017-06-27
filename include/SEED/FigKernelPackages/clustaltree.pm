#
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
#

package clustaltree;

#  A package of functions for a clustal tree
#
#  $tree = tree_with_clustal( \@alignment );

use Carp;
use strict;
use gjonewicklib;

my $is_fig;
eval { require FIG; require FIG_Config; $is_fig = 1 };
eval { require Data::Dumper };

my ( $ext_bin, $tmp_dir );
if ( $is_fig )
{
    $ext_bin = "$FIG_Config::ext_bin";
    $tmp_dir =  $FIG_Config::temp;
}
else
{
    $ext_bin = '';
    $tmp_dir = -d '/tmp' ? '/tmp' : '.';
}

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(
        tree_with_clustal
        );


#===============================================================================
#  Tree sequence with clustalw and return the tree.  Tree is gjonewick format.
#
#    $tree = tree_with_clustal(  @alignment )
#    $tree = tree_with_clustal( \@alignment )
#
#  Currently very pedantic:
#     $tree is gjonewick format.
#     @alignment is composed of triples: ( $id, $definition, $sequence )
#===============================================================================
sub tree_with_clustal
{
    @_ and ref( $_[0] ) eq 'ARRAY' or return undef;
    my @seqs = ref( $_[0]->[0] ) eq 'ARRAY' ? @{ $_[0] } : @_;

    #  Temporary file names:

    my $seqfile  = "$tmp_dir/clustaltree_tmp_${$}.aln";
    my $treefile = "$tmp_dir/clustaltree_tmp_${$}.ph";

    #  Remap the id to be clustal-friendly, saving the originals in a hash:

    my ( $id, $def, $seq, $id2, %ori_id, @seqs2 );

    my $type = guess_type( $seqs[0]->[2] );
    $id2 = "seq00000";
    @seqs2 = map { ( $id, $def, $seq ) = @$_;
                   $ori_id{ ++$id2 } = $id . ( $def ? " $def" : '' );
                   [ $id2, '', clean_for_clustal( $seq, $type ) ]
                 } @seqs;

    open( SEQ, ">$seqfile" ) || return undef;
    foreach ( @seqs2 ) { print SEQ ">$_->[0]\n$_->[2]\n" }
    close SEQ;

    #  Do the tree:

    my $clustalw = $ext_bin ? "$ext_bin/clustalw" : 'clustalw';
    &run( "$clustalw -infile='$seqfile' -newtree='$treefile' -tree > /dev/null" );

    my $tree = &gjonewicklib::read_newick_tree( $treefile );
    $tree || return undef;

    #  Clean up:

    unlink( $seqfile, $treefile );

    #  Restore the ids:

    &gjonewicklib::newick_relabel_tips( $tree, \%ori_id );
}


sub guess_type
{
    local $_ = shift;
    return undef if ! $_;
    tr/A-Za-z//cd;          #  Only letters
    ( tr/ACGTUacgtu// > ( 0.5 * length ) ) ? 'n' : 'p';
}


sub clean_for_clustal
{
    local $_ = uc( shift );
    s/\s+//g;
    my $type = ( shift ) || guess_type( $_ );
    if ( $type =~ m/^n/i )
    {
        tr[EFIJLOPQUXZ]
          [NNNNNNNNTNN];
    }
    else
    {
        tr[BJOUZ*]
          [XXXCXX];
    }
    s/[^A-Z]/-/g;   # Nonstandard gaps
    $_
}


sub run { system( $_[0] ) == 0 || confess( "FAILED: $_[0]" ) }


1;
