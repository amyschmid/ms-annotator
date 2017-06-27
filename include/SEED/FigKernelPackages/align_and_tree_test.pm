package align_and_tree_test;

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

use strict;
use FIG;
use FIG_Config;
use DBrtns;
use Data::Dumper;

my $fig = new FIG;
my $dbH = $fig->db_handle;

#  load_alignments_and_trees( $directory );

sub load_alignments_and_trees
{
    print STDERR "1\n";
    return if ! $dbH;

    print STDERR "2\n";
    my $dir = shift || $ENV{ ATNG };
    $dir && -d $dir
        or print STDERR "Could not locate directory of alignment and tree data.\n"
            and exit;

    print STDERR "3\n";
    my $ids_in_tree_file  = "$dir/md5IDs_in_align_and_tree.tab";
    -s $ids_in_tree_file
        or print STDERR "Could not locate file md5IDs_in_align_and_tree.tab in directory '$dir'.\n"
            and exit;

    print STDERR "4\n";
    my $peg_to_md5_file = "$dir/pegs_with_md5.tab";
    -s $peg_to_md5_file
        or print STDERR "Could not locate file pegs_with_md5.tab in directory '$dir'.\n"
            and exit;

    print STDERR "5\n";
    my $ids_in_tree_table = "ids_in_tree_test";
    my $peg_to_md5_table  = "peg_to_md5_test";

    print STDERR "6\n";
    $dbH->drop_table(   tbl  => $ids_in_tree_table );
    $dbH->create_table( tbl  => $ids_in_tree_table,
                        flds => qq( id        CHAR(6),
                                    md5       CHAR(32),
                                    length    INTEGER,
                                    beg       INTEGER,
                                    end       INTEGER,
                                    location  VARCHAR(128)
                                  )
                      );

    print STDERR "7\n";
    $dbH->load_table( tbl  => $ids_in_tree_table,
                      file => $ids_in_tree_file
                    );

    print STDERR "8\n";
    $dbH->create_index( idx  => "id_ix",
                        tbl  => $ids_in_tree_table,
                        type => "btree",
                        flds => "id"
                      );

    print STDERR "9\n";
    $dbH->create_index( idx  => "md5_ix",
                        tbl  => $ids_in_tree_table,
                        type => "btree",
                        flds => "md5"
                      );


    print STDERR "10\n";
    $dbH->drop_table(   tbl  => $peg_to_md5_table );
    $dbH->create_table( tbl  => $peg_to_md5_table,
                        flds => qq( fid  VARCHAR(64),
                                    md5  CHAR(32)
                                  )
                      );

    print STDERR "11\n";
    $dbH->load_table( tbl  => $peg_to_md5_table,
                      file => $peg_to_md5_file
                     );

    print STDERR "12\n";
    $dbH->create_index( idx  => "fid_ix",
                        tbl  => $peg_to_md5_table,
                        type => "btree",
                        flds => "fid"
                      );

    print STDERR "13\n";
    $dbH->create_index( idx  => "md5_ix",
                        tbl  => $peg_to_md5_table,
                        type => "btree",
                        flds => "md5"
                      );

    print STDERR "14\n";
    my $global = $FIG_Config::global;
    if ( $global && -d $global && open( ATNG, ">$global/aligns_and_trees_dir.txt" ) )
    {
        print ATNG "$dir\n";
        close ATNG;
    }
}


{
package AlignsAndTrees;

#===============================================================================
#  perl functions for loading and accessing Alignments and Trees based on md5
#
#  Usage:  use AlignsAndTrees;
#
#    @alignIDs = all_alignIDs();
#   \@alignIDs = all_alignIDs();
#
#    @alignIDs = aligns_with_md5ID( $md5 );
#   \@alignIDs = aligns_with_md5ID( $md5 );
#
#    @md5IDs   = md5IDs_in_align( $alignID );
#   \@md5IDs   = md5IDs_in_align( $alignID );
#
#   \@seqs               = md5_alignment_by_ID( $alignID );
# ( \@seqs, \%metadata ) = md5_alignment_by_ID( $alignID );
#   \%metadata           = md5_alignment_metadata( $alignID );
#
#       $metadata{ $md5 } = [ $peg_length, $trim_beg, $trim_end, $location_string ]
#
#    @treeIDs  = all_treeIDs( );
#   \@treeIDs  = all_treeIDs( );
#
#    @treeIDs  = trees_with_md5ID( $md5 );
#   \@treeIDs  = trees_with_md5ID( $md5 );
#
#    @md5IDs   = md5IDs_in_tree( $treeID );
#   \@md5IDs   = md5IDs_in_tree( $treeID );
#
#    $tree     = md5_tree_by_ID( $treeID );
#
#===============================================================================

use gjoseqlib    qw( read_fasta );
use gjonewicklib qw( read_newick_tree );

my $data_dir = undef;
sub locate_data_dir
{
    if ( ! $data_dir )
    {
        my $global = $FIG_Config::global;
        if ( $global && -d $global && open( ATNG, "<$global/aligns_and_trees_dir.txt" ) )
        {
            $data_dir = <ATNG>;
            chomp $data_dir if $data_dir;
            close ATNG;
        }
        if ( ! $data_dir || ! -d $data_dir )
        {
            if ( $ENV{ ATNG } && -d $ENV{ ATNG } ) { $data_dir = $ENV{ ATNG } }
            else { die "Could not locate directory of alignments and trees.\n" }
        }
    }

    $data_dir;
}

#-------------------------------------------------------------------------------
#
#    @alignIDs = all_alignIDs();
#   \@alignIDs = all_alignIDs();
#
#-------------------------------------------------------------------------------
sub all_alignIDs
{
    my @ids;
    if ( $dbH )
    {
        my $db_response = $dbH->SQL( "SELECT DISTINCT id FROM ids_in_tree_test" );
        @ids = map { $_->[0] } @$db_response if $db_response && @$db_response;
    }
    wantarray ? @ids : \@ids;
}

#-------------------------------------------------------------------------------
#
#    @alignIDs = aligns_with_md5ID( $md5 );
#   \@alignIDs = aligns_with_md5ID( $md5 );
#
#-------------------------------------------------------------------------------
sub aligns_with_md5ID
{
    my ( $md5 ) = @_;
    my @ids;
    if ( $md5 && $dbH )
    {
        my $db_response = $dbH->SQL( "SELECT id FROM ids_in_tree_test WHERE md5 = '$md5'" );
        @ids = map { $_->[0] } @$db_response if $db_response && @$db_response;
    }
    wantarray ? @ids : \@ids;
}

#-------------------------------------------------------------------------------
#
#    @md5IDs = md5IDs_in_align( $alignID );
#   \@md5IDs = md5IDs_in_align( $alignID );
#
#-------------------------------------------------------------------------------
sub md5IDs_in_align
{
    my ( $alignID ) = @_;
    my @md5IDs;
    if ( $alignID && $dbH )
    {
        my $db_response = $dbH->SQL( "SELECT md5 FROM ids_in_tree_test WHERE id = '$alignID'" );
        @md5IDs = map { $_->[0] } @$db_response if $db_response && @$db_response;
    }
    wantarray ? @md5IDs : \@md5IDs;
}

#-------------------------------------------------------------------------------
#
#   \@seqs               = md5_alignment_by_ID( $alignID );
# ( \@seqs, \%metadata ) = md5_alignment_by_ID( $alignID );
#           \%metadata   = md5_alignment_metadata( $alignID );
#
#       $metadata{ $md5 } = [ $peg_length, $trim_beg, $trim_end, $location_string ]
#
#-------------------------------------------------------------------------------
sub md5_alignment_by_ID
{
    my ( $alignID ) = @_;
    my @align;
    if ( $alignID && ( $data_dir ||= locate_data_dir() ) )
    {
        my $file = "$data_dir/ali$alignID.fa";
        @align = map { $_->[1] = ''; $_ } gjoseqlib::read_fasta( $file ) if -f $file;
    }

    wantarray ? ( \@align, md5_alignment_metadata( $alignID ) ) : \@align;
}

sub md5_alignment_metadata
{
    my ( $alignID ) = @_;
    my %metadata;
    if ( $alignID && $dbH )
    {
        my $db_response = $dbH->SQL( "SELECT md5,length,beg,end,location FROM ids_in_tree_test WHERE id = '$alignID'" );
        %metadata = map { my ( $md5, @rest ) = @$_; ( $md5 => \@rest ) } @$db_response if $db_response && @$db_response;
    }
    \%metadata;
}


#-------------------------------------------------------------------------------
#
#    @treeIDs = all_treeIDs( );
#   \@treeIDs = all_treeIDs( );
#
#-------------------------------------------------------------------------------
sub all_treeIDs
{
    my @ids;
    if ( $dbH )
    {
        my $db_response = $dbH->SQL( "SELECT DISTINCT id FROM ids_in_tree_test" );
        @ids = map { $_->[0] } @$db_response if $db_response && @$db_response;
    }
    wantarray ? @ids : \@ids;
}

#-------------------------------------------------------------------------------
#
#    @treeIDs = trees_with_md5ID( $md5 );
#   \@treeIDs = trees_with_md5ID( $md5 );
#
#-------------------------------------------------------------------------------
sub trees_with_md5ID
{
    my ( $md5 ) = @_;
    my @ids;
    if ( $md5 && $dbH )
    {
        my $db_response = $dbH->SQL( "SELECT id FROM ids_in_tree_test WHERE md5 = '$md5'" );
        @ids = map { $_->[0] } @$db_response if $db_response && @$db_response;
    }
    wantarray ? @ids : \@ids;
}

#-------------------------------------------------------------------------------
#
#    @md5IDs = md5IDs_in_tree( $treeID );
#   \@md5IDs = md5IDs_in_tree( $treeID );
#
#-------------------------------------------------------------------------------
sub md5IDs_in_tree
{
    my ( $treeID ) = @_;
    my @md5IDs;
    if ( $treeID && $dbH )
    {
        my $db_response = $dbH->SQL( "SELECT md5 FROM ids_in_tree_test WHERE id = '$treeID'" );
        @md5IDs = map { $_->[0] } @$db_response if $db_response && @$db_response;
    }
    wantarray ? @md5IDs : \@md5IDs;
}

#-------------------------------------------------------------------------------
#
#    $tree = md5_tree_by_ID( $treeID );
#
#-------------------------------------------------------------------------------
sub md5_tree_by_ID
{
    my ( $treeID ) = @_;
    my $file;
    if ( $treeID && ( $data_dir ||= locate_data_dir() ) )
    {
        $file = "$data_dir/tree$treeID.nwk";
    }

    $file && -f $file ? gjonewicklib::read_newick_tree( $file ) : undef;
}
}  #  End of package AlignsAndTrees;


1;


