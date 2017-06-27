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

package SeedCodonUsageToKBase;

my $flush = <<'End_of_Notes_and_Questions';

End_of_Notes_and_Questions

use strict;
use gjocodonlib;
use GenomeCodonUsages;
use Bio::KBase;
use Cwd;
use Data::Dumper;

#===============================================================================
#  Based upon https://trac.kbase.us/projects/kbase/wiki/...
#
#  Single file form, suggested as Exchange format:
#
#  CodonUsageExchange.tab
#  =====================================
#  kb-cu-id      (string; will be a unique KBase id: 'kb|cu.XXXXX')
#  frequencies   (long-string; codon usage frequencies with comma between synonymous codons and vertical bar between amino acids)
#  genetic-code  (int; NCBI genetic code number for these relative codon usage frequencies)
#  type          (string; nature of the particular set: average, modal, high-expression, nonnative, ...)
#  subtype       (string; further qualification of the type: 0, 1 or 2 for high-expression types)
#  kb-g-id       (string; KBase genome id
#  =====================================
#
#  Files for the loader:
#  
#  CodonUsage.tab
#  =====================================
#  kb-cu-id      (string; will be a unique KBase id: 'kb|cu.XXXXX')
#  frequencies   (long-string; codon usage frequencies with comma between synonymous codons and vertical bar between amino acids)
#  genetic-code  (int; NCBI genetic code number for these relative codon usage frequencies)
#  type          (string; nature of the particular set: average, modal, high-expression, nonnative, ...)
#  subtype       (string; further qualification of the type: 0, 1 or 2 for high-expression types)
#  =====================================
#
#  UsesCodons.tab
#  =====================================
#  kb-g-id       (string; KBase genome id
#  kb-cu-id      (string; KBase codon usage id: 'kb|cu.XXXXX')
#  =====================================
#
#-------------------------------------------------------------------------------
#
#  $okay = create_exchange( \%params );       # Build exchange from GenomeCodonUsages.pm
#  $okay = verify_exchange_file( \%params );
#          exchange_to_load_tables( \%params );
#
#  Parameters and options:
#
#      -debug_mode    => $bool        # set true for special debug behavior
#      -dir           => $dir         # path to output file directory
#      -exchange_file => $path        # path to exchange file
#      -log           => $file_of_fh  # location for log messages (D = STDERR)
#      -quiet         => $bool        # suppress verbose log messages
#      -test_mode     => $count       # number of genomes or records to process
#      -verbose       => $bool        # enable verbose message logging
#
#  Example:
#
#   #!/usr/bin/env perl -w
#   #
#   #  BuildCodonUsageExchAndLoadFiles [directory (D=codon_usage_files)]
#   #
#   use strict;
#   use SeedCodonUsageToKBase;
#   
#   my $dir = @ARGV && $ARGV[0] ? shift : 'codon_usage_files';
#   
#   my $exchfile = 'CodonUsageExchange.tab';
#   
#   SeedCodonUsageToKBase::create_exchange( { -directory     => $dir,
#                                             -exchange_file => $exchfile,
#                                           # -test_mode     => 5,   # number of genomes to process
#                                             -verbose       => 0,
#                                           }
#                                         ) or exit;
#   
#   SeedCodonUsageToKBase::verify_exchange_file( { -directory     => $dir,
#                                                  -exchange_file => $exchfile,
#                                                  -verbose       => 0
#                                                }
#                                              ) or exit;
#   
#   SeedCodonUsageToKBase::exchange_to_load_tables( { -directory     => $dir,
#                                                     -exchange_file => $exchfile,
#                                                   # -test_mode     => 20,  # number of entries to process
#                                                     -verbose       => 0
#                                                   }
#                                                 );
#
#-------------------------------------------------------------------------------

sub create_exchange
{
    my $params = $_[0] && ref( $_[0] ) eq 'HASH' ? shift
               : @_ && ( @_ % 2 ) == 0           ? { @_ }
               :                                   {};

    my $debug_mode  = exists( $params->{ -debug_mode } ) ? $params->{ -debug_mode } : 0;

    my $dir         = $params->{ -directory } ||= $params->{ -dir } || '.';

    my $exch_file   = $params->{ -exchange_file } ||= $params->{ -file } || 'CodonUsageExchange.tab';

    my $log         = exists( $params->{ -log } ) ? $params->{ -log } : \*STDOUT;

    my $quiet       = exists( $params->{ -quiet } ) ? $params->{ -quiet } : undef;

    my $test_mode   = $params->{ -test_mode } || 0;    # Number of genomes to process

    my $verbose     = exists( $params->{ -verbose } ) ? $params->{ -verbose }
                    : defined( $quiet )               ? ! $quiet
                    :                                   1;

    if ( ref($log) eq 'GLOB' ) { open( MESSAGE, '>&', $log ) }
    else                       { open( MESSAGE, '>',  $log ) }

    #
    #  Get server access objects
    #

    my $CDMIO     = Bio::KBase->central_store();
    my $IDserverO = Bio::KBase->id_server();

    #
    #  Table of SEED genomes in KBase, and their genetic codes
    #

    my $SEED_KBase_gids = $CDMIO->get_relationship_Submitted( [ 'SEED' ],
                                                              [],
                                                              [],
                                                              [ qw( id source_id genetic_code ) ]
                                                            ) || [];

    #
    #  Get the codon usages from GenomeCodonUsages.pm
    #

    my @by_kb_gid = sort { $a->[4] <=> $b->[4] }
                    map  { my $kb_gid   = $_->[2]->{id};
                           my $seed_gid = $_->[2]->{source_id};
                           my $gencode  = $_->[2]->{genetic_code};
                           my $gf = $GenomeCodonUsages::genome_freqs{ $seed_gid };
                           # print STDERR "Missing codon usage: $kb_gid\t$seed_gid\n" if ! $gf;
                           $gf ? [ $seed_gid, $kb_gid, $gf, $gencode, ( $kb_gid =~ /g\.(\d+)$/ ) ] : ()
                         }
                    @$SEED_KBase_gids;

    #
    #  Expand the available codon usages
    #

    my @type_subtypekey_kbtype = ( [ qw( average    av_subtype  average ) ],
                                   [ qw( modal      md_subtype  modal ) ],
                                   [ qw( high_expr  he_subtype  high-expression ) ],
                                   [ qw( nonnative  nn_subtype  nonnative ) ]
                                 );

    splice @by_kb_gid, $test_mode if $test_mode;

    my @usages;
    foreach ( @by_kb_gid )
    {
        my ( $seed_gid, $kb_gid, $gf, $gencode, undef ) = @$_;
        foreach ( @type_subtypekey_kbtype )
        {
            my ( $type, $subtypekey, $kbtype ) = @$_;
            my $subtype = $gf->{ $subtypekey };
            $subtype = '' if ! defined $subtype;
            my $freq = $gf->{ $type };
            if ( $freq )
            {
                # I am making up a structured "SEED ID" for the codon usage,
                # so that I can register the id and get a KBase ID. The fact
                # this is a simple restructuring of the data means that I can
                # always make the association.

                my $seed_cuid = "fig|$seed_gid.cu.$type";
                $seed_cuid .= ".$subtype" if length($subtype);

                push @usages, [ $seed_cuid,
                                undef,    # will become $KBase_cuid
                                $kbtype,
                                $subtype,
                                gjocodonlib::frequencies_as_string( $freq ),
                                $gencode,
                                $kb_gid
                              ];
            }
        }
    }

    #
    #  Get KBase codon usage IDs
    #

    my $SeedDB = 'SEED';

    my @SeedCUIds  = map { $_->[0] } @usages;
    my $KBaseCUIds = $IDserverO->external_ids_to_kbase_ids( $SeedDB, \@SeedCUIds ) || {};

    #  It is possible for my SEED external ID to be mapped to an incorrect
    #  KBase data type. I need to proofread the returned translations, and
    #  give a message if they are inappropriate.

    my $KBaseId;
    my %BadKBaseCUId = map { $KBaseId = $KBaseCUIds->{$_};
                             $KBaseId =~ /^kb\|cu\.(\d+)$/ ? () : ( $_ => $KBaseId )
                           }
                       keys %$KBaseCUIds;

    if ( %BadKBaseCUId )
    {
        print MESSAGE "ERROR: The following codon usages(s) have inappropriate KBase ID mappings:\n";
        foreach ( sort keys %BadKBaseCUId )
        {
            print MESSAGE "    $_ => $BadKBaseCUId{$_}\n";
        }
        print MESSAGE "\n";
    }

    #  Get new IDs for those that do not yet exist.

    my @MissingCUIds = grep { ! $KBaseCUIds->{$_} } @SeedCUIds;

    if ( @MissingCUIds )
    {
        my $KBaseCUIdH;
        $KBaseCUIdH = $IDserverO->register_ids( 'kb|cu', $SeedDB, \@MissingCUIds ) || {};

        my @MissingIds2 = ();
        foreach ( @MissingCUIds )
        {
            if ( $KBaseCUIdH->{$_} ) { $KBaseCUIds->{$_} = $KBaseCUIdH->{$_} }
            else                     { push @MissingIds2, $_ }
        }

        if ( @MissingIds2 )
        {
            print MESSAGE "ERROR: Failed to find or register KBase IDs for the following '$SeedDB' codon usage(s):\n";
            foreach ( @MissingIds2 ) { print MESSAGE "    $_\n" }
            print MESSAGE "\n";
        }
    }

    #
    #  Filter the data down to those that have good KBase IDs and add the
    #  KBase_CUId to the records. Format is:
    #
    #  [ $seed_cuid, $KBase_cuid, $kbtype, $subtype, $freq, $gencode, $kb_gid ]
    #

    @usages = map  { ( $_->[1] = $KBaseCUIds->{$_->[0]} ) ? $_ : () }
              grep { ! $BadKBaseCUId{ $_->[0] } }
              @usages;

    if ( @usages )
    {
        #
        #  Create the output directory, chdir to it, and open the output filed
        #
        #  CodonUsageExchange.tab
        #
        #     kb-cu-id      (string; will be a unique KBase id: 'kb|cu.XXXXX')
        #     frequencies   (long-string; codon usage freqs with comma between synonymous codons and vertical bar between amino acids)
        #     genetic-code  (int; NCBI genetic code number for these relative codon usage frequencies)
        #     type          (string; nature of the particular set: average, modal, high-expression, nonnative, ...)
        #     subtype       (string; further qualification of the type: 0, 1 or 2 for high-expression types)
        #     kb-g-id       (string; KBase genome id
        #

        -d $dir or mkdir( $dir ) or die "Could not make output directory '$dir'.";

        my $ori_dir = Cwd::getcwd();
        chdir( $dir ) or die "Could not chdir to '$dir'.";

        open( EXCH, '>', $exch_file ) or die "Could not open output file '$exch_file";
        foreach ( @usages )
        {
            my ( $seed_cuid, $kb_cuid, $type, $subtype, $freq, $gencode, $kb_gid ) = @$_;
            print MESSAGE "Processing $seed_cuid\n" if $verbose;
            print EXCH join( "\t", $kb_cuid, $freq, $gencode, $type, $subtype, $kb_gid ), "\n";
            print MESSAGE "\n" if $verbose;
        }
        close( EXCH );
        chdir( $ori_dir );
    }
    else
    {
        print MESSAGE "No codon usages to export.\n\n";
    }

    close( MESSAGE );
    return 1;
}


sub verify_exchange_file
{
    my $params = $_[0] && ref( $_[0] ) eq 'HASH' ? shift
               : @_ && ( @_ % 2 ) == 0           ? { @_ }
               :                                   {};

    my $exch_file   = $params->{ -exchange_file } ||= $params->{ -file } || 'CodonUsageExchange.tab';

    my $dir         = $params->{ -directory } ||= $params->{ -dir } || '.';

    my $debug_mode  = exists( $params->{ -debug_mode } ) ? $params->{ -debug_mode } : 0;

    my $quiet       = exists( $params->{ -quiet } ) ? $params->{ -quiet } : undef;

    my $verbose     = exists( $params->{ -verbose } ) ? $params->{ -verbose }
                    : defined( $quiet )               ? ! $quiet
                    :                                   1;

    my $log         = exists( $params->{ -log } ) ? $params->{ -log } : \*STDOUT;

    if ( ref($log) eq 'GLOB' ) { open( MESSAGE, '>&', $log ) }
    else                       { open( MESSAGE, '>',  $log ) }

    my $file = -f $exch_file ? $exch_file : -f "$dir/$exch_file" ? "$dir/$exch_file" : '';
    open( EXCH, '<', $file ) or die "Could not open '$exch_file";

    my $error = 0;
    my $line = 0;
    foreach ( <EXCH> )
    {
        $line++;
        chomp;
        my ( $kb_cuid, $freq, $gencode, $type, $subtype, $kb_gid ) = split /\t/;
        print MESSAGE "Verifying $kb_cuid\n" if $verbose;
        defined( $kb_gid )           or ( $error = 1, print MESSAGE "Line $line: Too few fields.\n" and next );
        $kb_cuid =~ /^kb\|cu\.\d+$/  or ( $error = 1, print MESSAGE "Line $line: Malformed KBase codon usage id: $kb_cuid\n" );
        valid_freq( $freq )          or ( $error = 1, print MESSAGE "Line $line: Malformed codon usage frequencies: $freq\n" );
        $gencode =~ /^[1-9][0-9]?$/  or ( $error = 1, print MESSAGE "Line $line: Malformed genetic code number: $gencode\n" );
        $type    =~ /./              or ( $error = 1, print MESSAGE "Line $line: No type given.\n" );
        $kb_gid  =~ /^kb\|g\.\d+$/   or ( $error = 1, print MESSAGE "Line $line: Malformed KBase genome id: $kb_gid\n" );
        print MESSAGE "\n" if $verbose;
    }
    close( EXCH );
    close( MESSAGE );

    return ! $error;
}


sub exchange_to_load_tables
{
    my $params = $_[0] && ref( $_[0] ) eq 'HASH' ? shift
               : @_ && ( @_ % 2 ) == 0           ? { @_ }
               :                                   {};

    my $exch_file   = $params->{ -exchange_file } ||= $params->{ -file } || 'CodonUsageExchange.tab';

    my $dir         = $params->{ -directory } ||= $params->{ -dir } || '.';

    my $debug_mode  = exists( $params->{ -debug_mode } ) ? $params->{ -debug_mode } : 0;

    my $quiet       = exists( $params->{ -quiet } ) ? $params->{ -quiet } : undef;

    my $test_mode   = $params->{ -test_mode } || 0;    # Number of entries to process

    my $verbose     = exists( $params->{ -verbose } ) ? $params->{ -verbose }
                    : defined( $quiet )               ? ! $quiet
                    :                                   1;

    my $log         = exists( $params->{ -log } ) ? $params->{ -log } : \*STDOUT;

    if ( ref($log) eq 'GLOB' ) { open( MESSAGE, '>&', $log ) }
    else                       { open( MESSAGE, '>',  $log ) }

    #
    #  Create the output directory, chdir to it, and open the output files
    #
    #      CodonUsage
    #      Submitted
    #

    my $file = -f $exch_file ? $exch_file : -f "$dir/$exch_file" ? "$dir/$exch_file" : '';
    open( EXCH, '<', $file ) or die "Could not open '$exch_file";

    -d $dir or mkdir( $dir ) or die "Could not make output directory '$dir'.";

    my $ori_dir = Cwd::getcwd();
    chdir( $dir ) or die "Could not chdir to '$dir'.";

    open( CU,   '>', 'CodonUsage.tab' ) or die "Could not open 'CodonUsage.tab";
    open( USES, '>', 'UsesCodons.tab' ) or die "Could not open 'Submitted.tab";

    foreach ( <EXCH> )
    {
        chomp;
        my ( $kb_cuid, $freq, $gencode, $type, $subtype, $kb_gid ) = split /\t/;
        print MESSAGE "Processing $kb_cuid\n" if $verbose;
        print CU   join( "\t", $kb_cuid, $freq, $gencode, $type, $subtype ), "\n";
        print USES join( "\t", $kb_gid, $kb_cuid ), "\n";
        print MESSAGE "\n" if $verbose;
        last if --$test_mode == 0;
    }

    close( CU );
    close( SUBMITTED );
    close( EXCH );
    close( MESSAGE );

    chdir( $ori_dir );

    return;
}


sub valid_freq
{
    $_[0] or return 0;
    my @parts = split /[|,]/, $_[0];
    @parts >= 59 && @parts <= 64 or return 0;
    grep { ! ( /^[01](?:\.[0-9]+)$/ && $_ <= 1 ) } @parts ? 0 : 1;
}


1;
