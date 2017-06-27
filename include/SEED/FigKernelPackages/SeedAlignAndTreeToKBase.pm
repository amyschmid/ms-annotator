#
# Copyright (c) 2003-2012 University of Chicago and Fellowship
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

package SeedAlignAndTreeToKBase;

my $flush = <<'End_of_Notes_and_Questions';

Table field names should have hyphens, not underscores.

End_of_Notes_and_Questions

use strict;
use gjonewicklib;
use gjoseqlib;
use AlignsAndTreesServer;
use Digest::MD5;

use SAPserver;
use ALITREserver;
use Bio::KBase;
use Bio::KBase::CDMI::CDMIClient;
use Data::Dumper;

#===============================================================================
#  Based upon https://trac.kbase.us/projects/kbase/wiki/ExchangeFormatTrees
#
#  Alignment
#  =====================================
#  source-id        (email.source-db.version|source-db-aln-id, e.g. fangfang@anl.gov.SEED.2|aln00000001)
#  kb-aln-id        (will be a unique kbase id: 'kb|aln.XXXXX')
#  n-rows           (number of rows in the alignment)
#  n-cols           (number of columns in the alignment; allows assessing coverage in rows)
#  status           (string indicating if the alignment is active, superseded or bad)
#  is-concatenation (boolean value that indicates if leaves map to single sequences, or multiple sequences)
#  sequence-type    (string indicating type of string.  Initial support should include "Protein", "DNA", "RNA", "Mixed").
#  timestamp        (seconds since the epoch)
#  method           (string that either maps to another database, to capture workflows, or is a simple method name, e.g. "MOPipeLine")
#  parameters       (free form string that might be a hash to provide additional alignment parameters e.g., the program option values used)
#  protocol         (human readable description of the protocol, how did you get here with these sequences?)
#  source-db        (for indicating, if needed, where this alignment originated from, eg MO, SEED)
#  source-db-aln-id (for indicating the ID in the db where this alignment originated from)
#
#
#  ;; associated file named by "kb_aln_id.fasta" in the "Raw_Alignment_Files/" directory
#  AlignmentFile
#  =====================================
#  fasta_alignment (link to raw alignment fasta file; first word of every sequence definition must be unique in this file)
#
#
#  AlignmentAttribute
#  =====================================
#  kb-aln-id (maps this meta data to an alignment)
#  key       (string)
#  value     (string)
#
#
#  AlignmentRow
#  =====================================
#  kb-aln-id           (maps this row to a particular alignment)
#  row-number          (row number in the alignment file, count starts at '1')
#  row-id              (first word of description copied from original fasta file; must be unique within this alignment)
#  row-description     (text description copied from original fasta file if it exists)
#  n-components        (the number of components (e.g. concatenated sequences) that make up this alignment row)
#  beg-pos-in-aln      (the column (index starting at pos '1') in the alignment where this sequence row begins)
#  end-pos-in-aln      (the column (index starting at pos '1') in the alignment where this sequence row ends)
#  md5-of-ungapped-seq
#
#
#  ContainsAlignedProtein / IsAlignedProteinComponentOf
#  =====================================
#  kb-aln-id              (maps this component to a particular alignment)
#  aln-row-number         (row number in alignment file, count starts at '1')
#  index-in-concatenation (ordering starting from left to right in alignment row starting at '1')
#  parent-seq-id          (MD5 for protein sequence)
#  beg-pos-in-parent      (the alignment includes the original sequence starting at this postion, 1-based)
#  end-pos-in-parent      (the alignment includes the original sequence ending at this postion, 1-based)
#  parent-seq-len         (integer indicating length of original sequence)
#  beg-pos-in-aln         (integer value providing a coordinate/mapping to the starting column in the alignment where this sequence component begins)
#  end-pos-in-aln         (integer value providing a coordinate/mapping to the ending column in the alignment where this sequence component ends)
#  kb-feature-id          (associated kbase feature id, e.g., when intending to refer to a particular genome)
#
#
#  ContainsAlignedNucleotides / IsAlignedNucleotidesComponentOf
#  =====================================
#  kb-aln-id              (maps this component to a particular alignment)
#  aln-row-number         (row number in alignment file, count starts at '1')
#  index-in-concatenation (ordering starting from left to right in alignment row starting at '1')
#  parent-seq-id          (MD5 for contig sequence)
#  beg-pos-in-parent      (the alignment includes the original sequence starting at this postion, 1-based)
#  end-pos-in-parent      (the alignment includes the original sequence ending at this postion, 1-based)
#  parent-seq-len         (integer indicating length of original sequence)
#  beg-pos-in-aln         (integer value providing a coordinate/mapping to the starting column in the alignment where this sequence component begins)
#  end-pos-in-aln         (integer value providing a coordinate/mapping to the ending column in the alignment where this sequence component ends)
#  kb-feature-id          (associated kbase feature id, e.g., when intending to refer to a particular genome)
#
#
#  Tree
#  =====================================
#  source-id         (email.source-db.version|source-db-tree-id)
#  kb-tree-id        (will be a unique kbase id: e.g. 'kb|tree.XXXX')
#  kb-aln-id         (will be a mapping to the alignment that was used to build this tree)
#  status            (string indicating if the alignment is active, superseded or bad)
#  data-type         (lowercase string indicating the type of data this tree is built from; we set this to "sequence_alignment"
#                     for all alignment-based trees, but we may support "taxonomy", "gene_content" trees and more in the future)
#  timestamp         (seconds since the epoch)
#  method            (string that either maps to another database, to capture workflows, or is a simple method name, e.g. "MOPipeLine")
#  parameters        (free form string that might be a hash to provide additional tree parameters e.g., the program option values used)
#  protocol          (human readable summary)
#  source-db         (for indicating, if needed, where this tree originated from, eg MO, SEED)
#  source-db-tree-id (for indicating the ID in the db where this tree originated from)
#
#
#  ;; associated file named by "kb_tree_id.nwk" in the "Raw_Tree_Files/" directory
#  TreeFile
#  =====================================
#  newick-tree (link to a file; first word in leaf node name is leaf_id, must be
#               unique in tree, and be identical to the corresponding row-id key
#               in the AlignmentRow table; if tree includes unnested "[" and/or
#               "]" inside a comment, there must be a specified rule for parsing,
#               e.g., URI encoding)
#
#
#  TreeAttribute
#  =====================================
#  kb-tree-id (maps this meta data to a tree)
#  key        (string)
#  value      (string)
#
#
#  TreeNodeAttribute (provides a method to annotate nodes without associated alignment)
#  =====================================
#  kb-tree-id (will be a unique kbase id: e.g. 'kb|tree.XXXX')
#  node-id    (includes leaf ids)
#  key        (is_leaf could be used to ensure that all labeled nodes are indexed)
#  value      (string)
#
#===============================================================================
#
#  SeedAlignAndTreeToKBase::create_exchange( \%parameters )
#  SeedAlignAndTreeToKBase::create_exchange(  %parameters )
#
#  Parameters:
#
#    -debug_mode  => bool             #  D = 1 (this will be changed)
#    -directory   => directory_name   #  D = '.'
#    -log         => file_or_fh       #  message log file location (D = STDOUT)
#    -missing_md5 => keyword          #  prune | skip  (D = prune)
#    -quiet       => bool             #  omit informative messages
#
#-------------------------------------------------------------------------------

sub create_exchange
{
    my $params = $_[0] && ref( $_[0] ) eq 'HASH' ? shift
               : @_ && ( @_ % 2 ) == 0           ? { @_ }
               :                                   {};

    my $dir         = $params->{ -directory } ||= $params->{ -dir } || '.';

    my $debug_mode  = exists( $params->{ -debug_mode } ) ? $params->{ -debug_mode } : 0;

    #  $missing_md5 = skip | prune
    my $missing_md5 = $params->{ -missing_md5 } ||= 'prune';

    my $quiet       = exists( $params->{ -quiet } ) ? $params->{ -quiet } : undef;

    my $verbose     = exists( $params->{ -verbose } ) ? $params->{ -verbose }
                    : defined( $quiet )               ? ! $quiet
                    :                                   1;

    my $log         = exists( $params->{ -log } ) ? $params->{ -log } : \*STDOUT;

    if ( ref($log) eq 'GLOB' ) { open( MESSAGE, '>&', $log ) }
    else                       { open( MESSAGE, '>',  $log ) }

    #
    #  Get server access objects
    #

    my $SAPserverO    = SAPserver->new();
    my $ALITREserverO = ALITREserver->new();
    my $CDMIO         = Bio::KBase->central_store();
    my $IDserverO     = Bio::KBase->id_server();

    #
    #  Get the list of alignments and trees
    #

    my @SeedAliTreeIds = AlignsAndTreesServer::all_alignIDs( $ALITREserverO )
        or print MESSAGE "No alignments and trees located.\n"
            and close( MESSAGE )
            and return 0;

    splice @SeedAliTreeIds, 10 if $debug_mode;

    #
    #  Get the alignment and tree attributes for each of the alignment/tree
    #  pairs:
    #

    my $SeedAlignTreeAttribH = $ALITREserverO->alignment_tree_metadata( -ids => \@SeedAliTreeIds );

    my @MissingSeedAttrib = grep { ! $SeedAlignTreeAttribH->{$_} } @SeedAliTreeIds;

    if ( @MissingSeedAttrib )
    {
        print MESSAGE "WARNING: Unable to obtain alignment/tree attribute data for ids:\n";
        my $DummyData = ['','','','','',''];
        foreach ( @MissingSeedAttrib )
        {
            print MESSAGE "    $_\n";
            $SeedAlignTreeAttribH->{$_} = $DummyData;
        }
        print MESSAGE "\n";
    }

    #
    #  The Sapling Alignment and Tree Server does not have distinguishable
    #  alignment and tree ids. We must either make the distinction in the
    #  external database name (adding the datatype to the database), or we
    #  can change our ids to distinguish alignments and trees. We have chosen
    #  the latter, so we use SEED as the source database, aln00000000 for
    #  alignment ids and tree00000000 as tree ids:
    #

    my $SeedDbName  = 'SEED';
    my $SeedAlignDB = "$SeedDbName";
    my $SeedTreeDB  = "$SeedDbName";

    my @SeedAlignExternIds = map { "aln$_" }  @SeedAliTreeIds;
    my @SeedTreeExternIds  = map { "tree$_" } @SeedAliTreeIds;

    #
    #  Get KBase alignment IDs
    #

    my $KBAlignIds = $IDserverO->external_ids_to_kbase_ids( $SeedAlignDB, \@SeedAlignExternIds ) || {};

    #  It is possible for my SEED external ID to be mapped to an incorrect
    #  KBase data type. I need to proofread the returned translations, and
    #  give a message if they are inappropriate.

    my ( $KBId );
    my %BadKBaseAlignId = map  { $KBId = $KBAlignIds->{$_};
                                 $KBId =~ /^kb\|aln\.(\d+)$/ ? () : ( $_ => $KBId )
                               }
                          keys %$KBAlignIds;

    if ( %BadKBaseAlignId )
    {
        print MESSAGE "ERROR: The following alignment(s) have inappropriate KBase ID mappings:\n";
        foreach ( sort keys %BadKBaseAlignId )
        {
            print MESSAGE "    $_ => $BadKBaseAlignId{$_}\n";
        }
        print MESSAGE "\n";
    }

    my @MissingAlignIds = grep { ! $KBAlignIds->{$_} }
                          @SeedAlignExternIds;

    if ( @MissingAlignIds )
    {
        my $KBAlignIdH;
        $KBAlignIdH = $IDserverO->register_ids( 'kb|aln', $SeedAlignDB, \@MissingAlignIds ) || {};

        my @MissingIds2 = ();
        foreach ( @MissingAlignIds )
        {
            if ( $KBAlignIdH->{$_} ) { $KBAlignIds->{$_} = $KBAlignIdH->{$_} }
            else                     { push @MissingIds2, $_ }
        }

        if ( @MissingIds2 )
        {
            print MESSAGE "ERROR: Failed to find or register KBase IDs for the following '$SeedAlignDB' alignment(s):\n";
            foreach ( @MissingIds2 ) { print MESSAGE "    $_\n" }
            print MESSAGE "\n";
        }
    }

    #
    #  Get KBase tree IDs
    #

    my $KBTreeIds = $IDserverO->external_ids_to_kbase_ids( $SeedTreeDB, \@SeedTreeExternIds ) || {};
    my %BadKBaseTreeId = map  { $KBId = $KBTreeIds->{$_};
                                $KBId =~ /^kb\|tree\.(\d+)$/ ? () : ( $_ => $KBId )
                              }
                         keys %$KBTreeIds;

    if ( %BadKBaseTreeId )
    {
        print MESSAGE "ERROR: The following tree(s) have inappropriate KBase ID mappings:\n";
        foreach ( sort keys %BadKBaseTreeId )
        {
            print MESSAGE "    $_ => $BadKBaseTreeId{$_}\n";
        }
        print MESSAGE "\n";
    }

    my @MissingTreeIds = grep { ! $KBTreeIds->{$_} } @SeedTreeExternIds;

    if ( @MissingTreeIds )
    {
        my $KBTreeIdH;
        $KBTreeIdH = $IDserverO->register_ids( 'kb|tree', $SeedTreeDB, \@MissingTreeIds ) || {};

        my @MissingIds2 = ();
        foreach ( @MissingTreeIds )
        {
            if ( $KBTreeIdH->{$_} ) { $KBTreeIds->{$_} = $KBTreeIdH->{$_} }
            else                    { push @MissingIds2, $_ }
        }

        if ( @MissingIds2 )
        {
            print MESSAGE "ERROR: Failed to find or register KBase IDs for the following '$SeedTreeDB' tree(s):\n";
            foreach ( @MissingIds2 ) { print MESSAGE "    $_\n" }
            print MESSAGE "\n";
        }
    }

    #
    #  Filter the ID set down to those that have good KBase IDs
    #

    @SeedAliTreeIds = grep { my $Id = "aln$_";  $KBAlignIds->{$Id} && ! $BadKBaseAlignId{$Id} }
                      grep { my $Id = "tree$_"; $KBTreeIds->{$Id}  && ! $BadKBaseTreeId{$Id}  }
                      @SeedAliTreeIds;
    if ( ! @SeedAliTreeIds )
    {
        print MESSAGE "No alignments and trees to export.\n\n";
        close( MESSAGE );
        return 0;
    }

    #
    #  Create the output directory, chdir to it, and open the output files
    #
    #      Alignment
    #      AlignmentAttribute
    #      AlignmentRow
    #      ContainsAlignedProtein
    #      ContainsAlignedNucleotides
    #      Tree
    #      TreeAttribute
    #      TreeNodeAttribute
    #

    -d $dir or mkdir( $dir );
    chdir( $dir );

    my $aln_file_dir = 'Raw_Alignment_Files';
    -d $aln_file_dir or mkdir( $aln_file_dir )
        or die "Could not find or make directory '$aln_file_dir' for alignments.";

    my $tree_file_dir = 'Raw_Tree_Files';
    -d $tree_file_dir or mkdir( $tree_file_dir )
        or die "Could not find or make directory '$tree_file_dir' for trees.";

    #  At the moment, we are not opening files we will not use. However, there
    #  would be no harm in doing so (the code closes all of these files, and
    #  deletes the empty ones at the end.

    open( ALIGN,     '>', 'Alignment.tab' )                  or die "Could not open 'Alignment";
    open( ALIGNATTR, '>', 'AlignmentAttribute.tab' )         or die "Could not open 'AlignmentAttribute";
    open( ALIGNROW,  '>', 'AlignmentRow.tab' )               or die "Could not open 'AlignmentRow";
    open( ALIGNPROT, '>', 'ContainsAlignedProtein.tab' )     or die "Could not open 'ContainsAlignedProtein";
  # open( ALIGNNUCL, '>', 'ContainsAlignedNucleotides.tab' ) or die "Could not open 'ContainsAlignedNucleotides";
    open( TREE,      '>', 'Tree.tab' )                       or die "Could not open 'Tree";
    open( TREEATTR,  '>', 'TreeAttribute.tab' )              or die "Could not open 'TreeAttribute";
    open( TREENODE,  '>', 'TreeNodeAttribute.tab' )          or die "Could not open 'TreeNodeAttribute";
    open( NEWPROT,   '>', 'NewProteinSequence.fasta' )       or die "Could not open 'NewProteinSequence.fasta";
  # open( NEWNUCL,   '>', 'NewNucleotideSequence.fasta' )    or die "Could not open 'NewNucleotideSequence.fasta";

    my %ProteinSequenceInKB;
    my %ContigSequenceInKB;    #  Not currently used

    foreach my $SeedAliTreeId ( @SeedAliTreeIds )
    {
        print MESSAGE "Processing $SeedAliTreeId\n" if $verbose;
        print MESSAGE "    " . $KBAlignIds->{"aln$SeedAliTreeId"} . "\n" if $verbose;
        print MESSAGE "    " . $KBTreeIds->{"tree$SeedAliTreeId"} . "\n" if $verbose;

        my $fail = '';

        #  Get the alignment data

        my ( $SeedAlignment, $SeedAlignMetadata ) = AlignsAndTreesServer::md5_alignment_by_ID( $ALITREserverO, $SeedAliTreeId );
        if ( ! ( $SeedAlignment && @$SeedAlignment ) )
        {
            print MESSAGE "ERROR: Failed to retrieve alignment and row metadata for '$SeedAliTreeId'.\n";
            print MESSAGE "Skipping alignment and tree 'SeedAliTreeId'.\n\n";
            next;
        }
        my $Seq1 = $SeedAlignment->[0];
        if ( ! $Seq1 || ref($Seq1) ne 'ARRAY' || @$Seq1 != 3 )
        {
            print MESSAGE "Bad sequence data structure for '$SeedAliTreeId'.\n\n";
            print MESSAGE "Skipping alignment and tree 'SeedAliTreeId'.\n\n";
            next;
        }
        my $SeedAlignExternId = "aln$SeedAliTreeId";

        #  Get the tree data

        my $SeedTree = AlignsAndTreesServer::md5_tree_by_ID( $ALITREserverO, $SeedAliTreeId );
        if ( ! $SeedTree )
        {
            print MESSAGE "ERROR: Failed to retrieve SEED tree '$SeedAliTreeId'.\n";
            print MESSAGE "Skipping alignment and tree 'SeedAliTreeId'.\n\n";
            next;
        }
        my $SeedTreeExternId = "tree$SeedAliTreeId";

        #
        #  We are going to make a quick pass through the alignment to find
        #  the list of parent sequences and whether they are present in KBase,
        #  need to be added to KBase from Sapling data, or are untraceable,
        #  and must be deleted from the alignment and tree.
        #

        printf MESSAGE "%7d rows\n", scalar @$SeedAlignment if $verbose;
        printf MESSAGE "%7d columns\n", length( $SeedAlignment->[0]->[2] ) if $verbose;

        my $n_cols = length( $SeedAlignment->[0]->[2] );
        my %NeedProteinSequence;
        my %NeedContigSequence;      #  We do not currently have any DNA alignments
        my %RowIdSeen;
        my $SeedRowNum = 0;
        foreach my $RowTriple ( @$SeedAlignment )
        {
            $SeedRowNum++;

            #  $SeedAlignMetadata{ $SeedRowId } = [ $ParentMD5, $ParentProtLen, $ParentTrimBeg, $ParentTrimEnd, $SeedLocationStr ]

            if ( ! $RowTriple || ref($RowTriple) ne 'ARRAY' || @$RowTriple != 3 ) {
                $fail = "ERROR: Bad sequence data structure at row $SeedRowNum of '$SeedAlignExternId'";
                last;
            }

            my ( $SeedRowId, $SeedRowDesc, $RowSeq ) = @$RowTriple;
            if ( ! $SeedRowId || $RowIdSeen{$SeedRowId}++ )
            {
                my $id = defined( $SeedRowId ) ? $SeedRowId : '';
                $fail = "ERROR: Missing or duplicated sequence ID ($id) at row $SeedRowNum of '$SeedAlignExternId'";
                last;
            }

            if ( ! $RowSeq || length( $RowSeq ) != $n_cols )
            {
                $fail = "ERROR: Sequence is missing or incorrect length in row '$SeedRowId' of '$SeedAlignExternId'";
                last;
            }

            my %BadSeqChar = map { $_ => 1 } $RowSeq =~ /([^-A-Za-z])/g;
            if ( keys %BadSeqChar )
            {
                printf MESSAGE "WARNING: Bad sequence characters (%s) in row '$SeedRowId' of '$SeedAlignExternId': ",
                               join( ', ', sort keys %BadSeqChar ), "\n";
            }

            my $SeedAlignRowMetadata = $SeedAlignMetadata->{ $SeedRowId };
            if ( ! $SeedAlignRowMetadata )
            {
                $fail = "ERROR: No metadata for row '$SeedRowId' of '$SeedAlignExternId'";
                last;
            }

            my ( $ParentMD5, $ParentProtLen, $ParentTrimBeg, $ParentTrimEnd, $SeedLocationStr ) = @$SeedAlignRowMetadata;
            if ( ! ( $ParentMD5 && $ParentProtLen && $ParentTrimBeg && $ParentTrimEnd && $SeedLocationStr ) )
            {
                $fail = "ERROR: Bad metadata for row '$SeedRowId' of '$SeedAlignExternId'";
                last;
            }

            my @LocationParts = map { /^(.+):(\d+)-(\d+)$/ ? [ $1, $2, $3 ]
                                    : /^(\d+)-(\d+)$/      ? [ $ParentMD5, $1, $2 ]
                                    :                        undef
                                    }
                                split /,/, $SeedLocationStr;

            if ( grep { ! defined( $_ ) } @LocationParts )
            {
                $fail = "ERROR: Bad location string '$SeedLocationStr' for row '$SeedRowId' of '$SeedAlignExternId'";
                last;
            }

            foreach my $MD5 ( map { $_->[0] } @LocationParts )
            {
                $NeedProteinSequence{ $MD5 }->{ $SeedRowId } = 1;
            }

            last if $fail;
        }

        if ( $fail )
        {
            print MESSAGE $fail, "\n";
            print MESSAGE "Skipping alignment and tree '$SeedAliTreeId'.\n\n";
            next;
        }

        #
        #  Verify that KBase has the parent sequences
        #

        my @UnverifiedProteins = grep { ! $ProteinSequenceInKB{$_} } keys %NeedProteinSequence;

        my @NewlyFoundInKBase  = verify_KB_has_ProteinSequence( $CDMIO, \@UnverifiedProteins );

        foreach ( @NewlyFoundInKBase ) { $ProteinSequenceInKB{$_} = 1 }

        my @NotYetInKBase = grep { ! $ProteinSequenceInKB{$_} } @UnverifiedProteins;

        #
        #  Get missing sequences from Sapling
        #

        my @NotInSaplingEither;
        if ( @NotYetInKBase )
        {
            printf MESSAGE "%7d proteins not yet in KBase\n", scalar @NotYetInKBase if $verbose;

            #  This has a temporary work around for a bug in select(),
            #  it loses the first member of the filter list.
            my $found = $SAPserverO->select( { -path   =>   'ProteinSequence',
                                               -filter => { 'ProteinSequence(id)' => [ '00000000000000000000000000000000', @NotYetInKBase ] },
                                               -fields => [ qw(id sequence) ],
                                             }
                                           );
            if ( $found && @$found )
            {
                my @NewSeq = map { [ $_->[0], '', $_->[1] ] } @$found;
                gjoseqlib::write_fasta( \*NEWPROT, \@NewSeq );

                foreach ( @$found ) { $ProteinSequenceInKB{ $_->[0] } = 1 }

                printf MESSAGE "%7d protein sequences will be added to KBase\n", scalar @NewSeq if $verbose;
            }

            @NotInSaplingEither = grep { ! $ProteinSequenceInKB{$_} } @NotYetInKBase;
        }

        if ( @NotInSaplingEither )
        {
            printf MESSAGE "%7d proteins not found on Sapling\n", scalar @NotInSaplingEither if $verbose;

            #  Dealing with this is very ugly because we do not have the parent
            #  sequence. We offer two options, 'prune' the alignment and tree
            #  to the sequences that we know, or 'skip' the alignment and tree.

            if ( $missing_md5 =~ /prune/i )
            {
                my %BadRowId = map { %{ $NeedProteinSequence{ $_ } } } @NotInSaplingEither;

                @$SeedAlignment = grep { ! $BadRowId{ $_->[0] } } @$SeedAlignment;
                $SeedAlignment = gjoseqlib::pack_alignment( $SeedAlignment );

                my @KeepIds = map { $_->[0] } @$SeedAlignment;
                $SeedTree = gjonewicklib::newick_subtree( $SeedTree, @KeepIds );
                
                if ( $verbose )
                {
                    print MESSAGE "    Removing the following row(s) from '$SeedAliTreeId':\n";
                    foreach ( sort keys %BadRowId ) { print MESSAGE "        $_\n" }
                    printf MESSAGE "%7d rows\n", scalar @$SeedAlignment;
                    printf MESSAGE "%7d columns\n", length( $SeedAlignment->[0]->[2] );
                }
            }
            else
            {
                $fail = 'WARNING: Could not locate the parent sequence(s) of one or more proteins.';
            }
        }

        if ( $fail )
        {
            print MESSAGE $fail, "\n";
            print MESSAGE "Skipping alignment and tree '$SeedAliTreeId'.\n\n";
            next;
        }

        #
        #  Assemble the data for the exchange files. First we will find any
        #
        #
        #  Alignment
        #

        my $kb_aln_id        = $KBAlignIds->{ $SeedAlignExternId };
        my $n_rows           = @$SeedAlignment;
           $n_cols           = length( $SeedAlignment->[0]->[2] );
        my $status           = 'active';
        my $is_concatenation = ( grep { $_->[4] =~ /,/ } values %$SeedAlignMetadata ) ? 1 : 0;
        my $sequence_type    = 'Protein';
        my $timestamp        = time;
        my $aln_method       = $SeedAlignTreeAttribH->{ $SeedAliTreeId }->[0] || '';
        my $aln_parameters   = $SeedAlignTreeAttribH->{ $SeedAliTreeId }->[1] || '';
        my $aln_protocol     = 'Sequences were identified with PSI-BLAST, trimmed to PSI-BLAST profile, aligned and treed'; # seeded_by figFAM... or protein fig|..., 
        my $aln_source_db    = $SeedAlignDB;
        my $aln_source_id    = $SeedAlignExternId;

        my $AlignRec = [ $kb_aln_id,
                         $n_rows,
                         $n_cols,
                         $status,
                         $is_concatenation,
                         $sequence_type,
                         $timestamp,
                         $aln_method,
                         $aln_parameters,
                         $aln_protocol,
                         $aln_source_db,
                         $aln_source_id
                       ];

        #
        #  AlignmentRow
        #

        my @AlignmentRowRec   = ();
        my @AlignmentRowParts = ();

        $SeedRowNum = 0;
        foreach my $RowTriple ( @$SeedAlignment )
        {
            $SeedRowNum++;

            #  $SeedAlignMetadata{ $SeedRowId } = [ $ParentMD5, $ParentProtLen, $ParentTrimBeg, $ParentTrimEnd, $SeedLocationStr ]

            my ( $SeedRowId, $SeedRowDesc, $RowSeq ) = @$RowTriple;
            my $SeedAlignRowMetadata = $SeedAlignMetadata->{ $SeedRowId };
            my ( $ParentMD5, $ParentProtLen, $ParentTrimBeg, $ParentTrimEnd, $SeedLocationStr ) = @$SeedAlignRowMetadata;

            my @LocationParts = map { /^(.+):(\d+)-(\d+)$/ ? [ $1, $2, $3 ]
                                    : /^(\d+)-(\d+)$/      ? [ $ParentMD5, $1, $2 ]
                                    :                        undef
                                    }
                                split /,/, $SeedLocationStr;

            #    $kb_aln_id;
            my   $row_number            = $SeedRowNum;
            my   $row_id                = $SeedRowId;
            my   $row_description       = $SeedRowDesc || '';
            my   $n_components          = @LocationParts;
            my ( $beg_pos_in_aln,
                 $end_pos_in_aln,
                 $md5_of_ungapped_seq ) = seq_summary( $RowSeq );

            push @AlignmentRowRec, [ $kb_aln_id,
                                     $row_number,
                                     $row_id,
                                     $row_description,
                                     $n_components,
                                     $beg_pos_in_aln,
                                     $end_pos_in_aln,
                                     $md5_of_ungapped_seq
                                   ];

            #
            #  ContainsAlignedProtein
            #

            my $SegIndex = 0;
            my $ColUsed  = 0;
            foreach my $LocPart ( @LocationParts )
            {
                my $PartLen = abs( $LocPart->[2] - $LocPart->[1] ) + 1;

                #    $kb_aln_id;
                #    $row_number;
                my   $index_in_concatenation = ++$SegIndex;
                my   $parent_seq_id          = $LocPart->[0];
                my   $beg_pos_in_parent      = $LocPart->[1];
                my   $end_pos_in_parent      = $LocPart->[2];
                my   $parent_seq_len         = $ParentProtLen;
                my ( $beg_pos_in_aln,
                     $end_pos_in_aln )       = beg_and_end( \$RowSeq, $ColUsed, $PartLen );
                my   $kb_feature_id          = '';

                $ColUsed = $end_pos_in_aln;

                push @AlignmentRowParts, [ $kb_aln_id,
                                           $row_number,
                                           $index_in_concatenation,
                                           $parent_seq_id,
                                           $beg_pos_in_parent,
                                           $end_pos_in_parent,
                                           $parent_seq_len,
                                           $beg_pos_in_aln,
                                           $end_pos_in_aln,
                                           $kb_feature_id
                                         ];
            }
        }

        #
        #  Tree
        #

        my $kb_tree_id       = $KBTreeIds->{ $SeedTreeExternId };
        #  $kb_aln_id
           $status           = 'active';
        my $data_type        = 'sequence_alignment';
        #  $timestamp
        my $tree_method      = $SeedAlignTreeAttribH->{ $SeedAliTreeId }->[3] || '';
        my $tree_parameters  = $SeedAlignTreeAttribH->{ $SeedAliTreeId }->[4] || '';
        my $tree_protocol    = 'Sequences were identified with PSI-BLAST, trimmed to PSI-BLAST profile, aligned and treed'; # seeded_by
        my $tree_source_db   = $SeedTreeDB;
        my $tree_source_id   = $SeedTreeExternId;

        my $TreeRec = [ $kb_tree_id,
                        $kb_aln_id,
                        $status,
                        $data_type,
                        $timestamp,
                        $tree_method,
                        $tree_parameters,
                        $tree_protocol,
                        $tree_source_db,
                        $tree_source_id
                      ];


        #
        #  TreeAttribute
        #
        
        my @TreeAttributeRec = ();
        
        push @TreeAttributeRec, [ $kb_tree_id, 'style',          'Phylogram' ];
        push @TreeAttributeRec, [ $kb_tree_id, 'bootstrap_type', 'Shimodaira-Hasegawa Test' ];
        push @TreeAttributeRec, [ $kb_tree_id, 'branch_length',  'Replacements per position' ];


        #
        #  Record the accumulated data:
        #

        #  Aligned Sequence FASTA file

        my $AlignFile = "$aln_file_dir/$kb_aln_id.fasta";
        gjoseqlib::write_fasta( $AlignFile, $SeedAlignment );

        #  Newick Tree File

        my $TreeFile = "$tree_file_dir/$kb_tree_id.newick";
        if ( open( TREEFILE, '>', $TreeFile ) )
        {
            gjonewicklib::writeNewickTree( $SeedTree, \*TREEFILE );
            close( TREEFILE );
        }
        else
        {
            print MESSAGE "Failed to open tree file '$TreeFile'.\n";
            print MESSAGE "Skipping alignment and tree 'SeedAliTreeId'.\n\n";
            next;
        }

        #  Alignment

        print ALIGN join( "\t", @$AlignRec ), "\n";

        #  AlignmentRow

        foreach ( @AlignmentRowRec )
        {
            print ALIGNROW join( "\t", @$_ ), "\n";
        }

        #  ContainsAlignedProtein

        foreach ( @AlignmentRowParts )
        {
            print ALIGNPROT join( "\t", @$_ ),  "\n";
        }

        #  Tree

        print TREE join( "\t", @$TreeRec ), "\n";

        # TreeAttribute

        foreach ( @TreeAttributeRec )
        {
            print TREEATTR join( "\t", @$_ ),  "\n";
        }

        print MESSAGE "\n" if $verbose;
    }

    close( ALIGN );
    close( ALIGNATTR );   # not currently used
    close( ALIGNROW );
    close( ALIGNPROT );
    close( TREE );
    close( TREEATTR );    # not currently used
    close( TREENODE );    # not currently used
    close( NEWPROT );
    close( NEWNUCL );     # not currently used
    close( MESSAGE );

    #  Delete optional files that end up without data:

    foreach ( qw( AlignmentAttribute.tab
                  ContainsAlignedProtein.tab
                  ContainsAlignedNucleotides.tab
                  TreeAttribute.tab
                  TreeNodeAttribute.tab
                  NewProteinSequence.fasta
                  NewNucleotideSequence.fasta
               ) ) 
    { unlink $_ if -f && ! -s; }

    return;
}


sub seq_summary
{
    local $_        = uc $_[0];
    my ($pre, $suf) = /^(-*)[^-].*[^-](-*)$/;
    my $beg         = length($pre) + 1;
    my $end         = length($_) - length($suf);
    
    s/[^A-Z]+//g;
#   s/U/T/g if ! /[EFILPQXZ]/;
    my $md5 = Digest::MD5::md5_hex( $_ );

    ( $beg, $end, $md5 );
}


sub beg_and_end
{
    my ( $seqR, $col_used, $n_residues ) = @_;
    local $_ = substr( $$seqR, $col_used );
    my ( $pre ) = /^(-*)/;
    my $beg = defined( $pre ) ? $col_used + length( $pre ) + 1 : undef;
    my ( $all ) = /^((?:-*[A-Za-z]){$n_residues})/;
    my $end = defined( $all ) ? $col_used + length( $all )     : undef;

    ( $beg, $end );
}


sub verify_KB_has_ProteinSequence
{
    my ( $CDMIO, $ids ) = @_;

    my @has;
    if ( ! $CDMIO || ! $ids || ( ref($ids) ne 'ARRAY' ) )
    {
        print MESSAGE "ERROR: Bad arguments in call to verify_KB_has_ProteinSequence()\n";
    }
    elsif ( @$ids )
    {
        my $have = $CDMIO->get_entity_ProteinSequence( $ids, [] ) || {};
        @has = sort keys %$have;
    }

    wantarray ? @has : \@has;
}


sub verify_KB_has_ContigSequence
{
    my ( $CDMIO, $ids ) = @_;

    my @has;
    if ( ! $CDMIO || ! $ids || ( ref($ids) ne 'ARRAY' ) )
    {
        print MESSAGE "ERROR: Bad arguments in call to verify_KB_has_ContigSequence()\n";
    }
    elsif ( @$ids )
    {
        my $have = $CDMIO->get_entity_ContigSequence( $ids, [] ) || {};
        @has = sort keys %$have;
    }

    wantarray ? @has : \@has;
}


1;
