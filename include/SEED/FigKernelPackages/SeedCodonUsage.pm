#
#  SeedCodonUsage.pm
#
package SeedCodonUsage;

use strict;
use FIG;
use DBKernel;
use gjocodonlib;
use gjonativecodonlib;
use gjoseqlib;
use Data::Dumper;

#===============================================================================
#  SEED support for codon usages. Nothing is exported because the functions
#  are parallel to those for the Sapling and KBase.
#===============================================================================
#  Get coding sequences from the local SEED.
#
#   @seqs = coding_sequences( $gid, \%opts )
#  \@seqs = coding_sequences( $gid, \%opts )
#
#  Get codon usage counts for genes from the a local SEED.
#
#   @cnts = labeled_counts( $gid, \%opts )
#  \@cnts = labeled_counts( $gid, \%opts )
#
#  Get available codon usages for a genome from a local SEED. The data are
#  sought from the DBMS, genome director, or calculated de novo, in that order.
#  Higher priority data are updated when values are found in lower priority
#  ways.
#
#     @usages = genome_codon_usages( $gid, \%opts );
#    \@usages = genome_codon_usages( $gid, \%opts );
#
#     @axes = genome_axes( $gid, \%opts );
#    \@axes = genome_axes( $gid, \%opts );
#
#-------------------------------------------------------------------------------
#  Get a SEED FIG object
#
#   $fig = fig_object( \%opts )
#
#  Options:
#
#    fig => $figObject  # This will be used if it already exists.
#
#-------------------------------------------------------------------------------
sub fig_object
{
    my $opts = $_[ 0] && ref($_[ 0]) eq 'HASH' ? shift :
               $_[-1] && ref($_[-1]) eq 'HASH' ? pop   : {};

    my $fig = $opts->{ fig };
    is_fig( $fig ) ? $fig : ( $opts->{ fig } = FIG->new() );
}


sub is_fig
{
    my $self = shift or return '';
    return eval { $self->isa( 'FIG'  ) } ? 'FIG'  :
           eval { $self->isa( 'FIGV' ) } ? 'FIGV' :
                                           '';
}


#-------------------------------------------------------------------------------
#  Get coding sequences for a genome. The genome id can be a parameter, an
#  option, or supplied implicitly by the fid of a region option.
#
#   @seqs = coding_sequences( $gid, \%opts )
#  \@seqs = coding_sequences( $gid, \%opts )
#   @seqs = coding_sequences(       \%opts )
#  \@seqs = coding_sequences(       \%opts )
#
#  Options:
#
#    fig    =>   $figObject  # This will be used if set
#    gid    =>   $gid        # Alternative to supplying the gid in arg list
#    region =>   $fid        # +/- 10,000 nt
#    region => [ $fid ]      # +/- 10,000 nt
#    region => [ $fid, $regsize ]   # regsize centered on feature midpoint
#    region => [ $fid, $nt_before, $nt_after ]
#
#-------------------------------------------------------------------------------
sub coding_sequences
{
    my $opts = $_[ 0] && ref($_[ 0]) eq 'HASH' ? shift :
               $_[-1] && ref($_[-1]) eq 'HASH' ? pop   : {};

    my $gid = $opts->{ gid } ||= shift || '';
    $gid =~ s/^fig\|//;

    my $fig = fig_object( $opts ) or return wantarray ? () : [];

    my @fids;
    if ( $opts->{ region } )
    {
        my $region = $opts->{ region };
        my ( $fid, $arg2, $arg3 ) = ref($region) eq 'ARRAY' ? @$region
                                                            : ( $region );

        $fid ||= '';
        $fid =~ s/^\d+\.\d+\..*$/fig|$fid/;
        my $gid2 = $fig->genome_of( $fid );
        $fid && $gid2
            or print STDERR qq(coding_sequences: Invalid fid supplied with region option.\n)
                and return wantarray ? () : [];

        if ( $gid )
        {
            ( $gid eq $gid2 )
                or print STDERR qq(coding_sequences: Genome id '$gid' conflicts with region fid '$fid'.\n)
                    and return wantarray ? () : [];
        }
        else
        {
            $gid = $gid2;
        }

        my $loc = $fig->feature_location( $fid );
        $loc
            or print STDERR qq(coding_sequences: Could not find location of '$fid'.\n)
                and return wantarray ? () : [];
        $loc =~ s/\s+//g;
        my @parts = split /,/, $loc;
        my ( $c1, $b1 ) = $parts[ 0] =~ /^(\S+)_(\d+)_\d+$/;
        my ( $c2, $e2 ) = $parts[-1] =~ /^(\S+)_\d+_(\d+)$/;
        $b1 && $e2 && ( $c1 eq $c2 )
            or print STDERR qq(coding_sequences: Could not parse location of '$fid'.\n)
                and return wantarray ? () : [];

        my ( $l, $r ) = $b1 <= $e2 ? ( $b1, $e2 ) : ( $e2, $b1 );
        if ( ! defined $arg2 )
        {
            $l -= 10000;
            $r += 10000;
        }
        elsif ( ! defined $arg3 )
        {
            my $mid   = int( 0.5 * ( $l + $r ) );
            my $delta = int( 0.5 * ( $arg2 + 1 ) );
            $l = $mid - $delta;
            $r = $mid + $delta;
        }
        else
        {
            $l -= abs( $arg2 );
            $r +=      $arg3;
        }
        $l = 1 if $l <= 0;

        my ( $fids, undef, undef ) = $fig->genes_in_region( $gid, $c1, $l, $r );
        @fids = grep { $fig->ftype( $_ ) eq 'peg' } @$fids;
    }
    else
    {
        $gid or return wantarray ? () : [];
        @fids = $fig->all_features( $gid, 'peg' );
    }
    @fids or return wantarray ? () : [];

    my $funcH = $fig->function_of_bulk( \@fids ) || {};

    #
    #  Separate locations by contig. For each contig, the list elements are
    #  [ $fid, $loc, $midpoint ]
    #
    my %locH;
    foreach ( $fig->feature_location_bulk( \@fids ) )
    {
        my ( $contig, $midpoint ) = midpoint( $_->[1] );
        push @{ $locH{ $contig } }, [ @$_, $midpoint ] if $midpoint;
    }

    #
    #  Get sequences, one contig at a time
    #
    my @seqs;
    foreach my $contig ( sort { lc $a cmp lc $b } keys %locH )
    {
        my $len = $fig->contig_ln( $gid, $contig )        or next;
        my $seq = $fig->get_dna( $gid, $contig, 1, $len ) or next;

        #
        #  Get the fid sequences, sorted by midpoint
        #
        foreach ( sort { $a->[2] <=> $b->[2] } @{ $locH{ $contig } } )
        {
            my $fid = $_->[0];
            my @subseq = map { [ /^(.+)_(\d+)_(\d+)$/ ] } split /,/, $_->[1];
            next if grep { $_->[0] ne $contig } @subseq;

            my @parts;
            foreach ( @subseq )
            {
                push @parts, gjoseqlib::DNA_subseq( \$seq, $_->[1], $_->[2] );
            }
            push @seqs, [ $fid, ($funcH->{$fid} || ''), join('', @parts) ];
        }
    }

    wantarray ? @seqs : \@seqs;
}


#-------------------------------------------------------------------------------
#  Get codon usage counts for genes.
#
#   @cnts = labeled_counts( $gid, \%opts )
#  \@cnts = labeled_counts( $gid, \%opts )
#
#  Options:
#
#    fig => $figObject  # This will be used if set
#    gid => $gid        # Alternative to supplying the gid in arg list
#
#-------------------------------------------------------------------------------
sub labeled_counts
{
    my $opts = $_[ 0] && ref($_[ 0]) eq 'HASH' ? shift :
               $_[-1] && ref($_[-1]) eq 'HASH' ? pop   : {};

    my $gid = $opts->{ gid } ||= shift or return wantarray ? () : [];

    my @seqs = coding_sequences( $gid, $opts );
    my @cnts = gjocodonlib::entry_labeled_codon_count_package( @seqs );

    $opts->{ dna }    = \@seqs;
    $opts->{ counts } = \@cnts;
    wantarray ? @cnts : \@cnts;
}


#-------------------------------------------------------------------------------
#  Auxiliary function for ordering coding sequences from Sapling or SEED
#
#  ( $contig, $midpoint ) = midpoint( $seed_or_sap_location )
#
#-------------------------------------------------------------------------------
sub midpoint
{
    $_[0] or return ();
    my $c;
    my @ends = sort { $a <=> $b }
               map  { ( $c ||= $_->[0] ) eq $_->[0] ? @$_[1,2] : () }
               map  { /^(.+)_(\d+)\_(\d+)$/ ? [ $1, $2, $3        ] :
                      /^(.+)_(\d+)\+(\d+)$/ ? [ $1, $2, $2+($3-1) ] :
                      /^(.+)_(\d+)\-(\d+)$/ ? [ $1, $2, $2-($3-1) ] : ()
                    }
               ref($_[0]) eq 'ARRAY' ? @{$_[0]} : split /,/, $_[0];

    $c && @ends ? ( $c, 0.5*( $ends[0] + $ends[-1] ) ) : ();
}


#-------------------------------------------------------------------------------
#  Get available codon usages for a genome. The data are sought from the DBMS,
#  genome director, or calculated de novo, in that order. Higher priority data
#  are updated when values are found in lower priority ways.
#
#     @usages = genome_codon_usages( $gid, \%opts );
#    \@usages = genome_codon_usages( $gid, \%opts );
#
#     @axes = genome_axes( $gid, \%opts );
#    \@axes = genome_axes( $gid, \%opts );
#
#  Return values:
#
#     @usages = ( [ $gid, $gname, $type, $subtype, $freqs, $gencode ], ... )
#
#     @axes = ( $gname, $modal,     $md_subtype,
#                       $high_expr, $he_subtype,
#                       $nonnative, $nn_subtype
#             )
#
#  Options:
#
#     de_novo =>  $bool    # Recalculate de novo (same as update)
#     dna     => \@dna     # DNA sequences in case de novo calculation is needed
#     gid     =>  $gid     # Instead of supplying as first argument
#     update  =>  $bool    # Recalculate de novo
#
#  Tests:
#
#  Recompute the usage data
#
#    perl -e 'use Data::Dumper; use SeedCodonUsage; print Dumper( SeedCodonUsage::genome_codon_usages( "198804.1", {update=>1} ) )'
#
#  Get from dbms
#
#    perl -e 'use Data::Dumper; use SeedCodonUsage; print Dumper( SeedCodonUsage::genome_codon_usages( "198804.1", {} ) )'
#
#  Get from genome directory by deleting dbms copy
#
#    perl -e 'use FIG; $dbh = FIG->new()->db_handle(); print $dbh->SQL(q(DELETE FROM CodonUsage WHERE gid = "198804.1")), "\n"'
#    perl -e 'use Data::Dumper; use SeedCodonUsage; print Dumper( SeedCodonUsage::genome_codon_usages( "198804.1", {} ) )'
#
#  View axes:
#
#    perl -e 'use Data::Dumper; use SeedCodonUsage; print Dumper( SeedCodonUsage::genome_axes( "198804.1", {} ) )'
#
#-------------------------------------------------------------------------------
sub genome_codon_usages
{
    my $opts = $_[ 0] && ref($_[ 0]) eq 'HASH' ? shift :
               $_[-1] && ref($_[-1]) eq 'HASH' ? pop   : {};

    my $gid = shift || $opts->{ gid } or return wantarray ? () : [];
    $opts->{ gid } = $gid;

    my $fig = $opts->{ fig } ||= FIG->new()
        or return wantarray ? () : [];

    #  Valid SEED or RAST genome?

    my $in_seed = $fig->is_genome( $gid );
    my $is_rast = ( ! $in_seed ) && ( ( $fig->{ _genome } || '' ) eq $gid );
    $in_seed || $is_rast
        or return wantarray ? () : [];

    my $gname = $opts->{ gname } || $opts->{ genus_species }
                                 || $fig->genus_species( $gid );
    my @usages;   # [ $gid, $gname, $cutype, $cusubtype, $freqs, $gencode ]
    my $from = '';

    #  Are the codon usages in the dbms?

    my $dbh = $fig->db_handle;
    my $try_dbms = $dbh && $in_seed && ! $opts->{ update };
    if ( $try_dbms )
    {
        @usages = genome_codon_usages_from_db( $fig, $gid );
        $from = 'dbms' if @usages;
    }

    #  Are the codon usages in the genome directory?

    if ( ( ! @usages ) && ( ! $opts->{ update } ) )
    {
        @usages = codon_usages_from_genome_dir( $fig, $gid );
        $from = 'file' if @usages;
    }

    #  Do we need to compute them de novo?

    if ( ! @usages )
    {
        @usages = compute_genome_codon_usages( $gid, $opts );
        $from = 'de novo' if @usages;
    }

    #  Should we put the codon usages into the dbms?

    if ( $dbh && $in_seed && @usages && $from ne 'dbms' )
    {
        my $n = genome_codon_usages_to_db( $fig, @usages );
    }

    $opts->{ from } = $from;
    # print STDERR "$from\n";
    wantarray ? @usages : \@usages;
}


sub genome_axes
{
    gjocodonlib::genome_axes_from_usages( genome_codon_usages( @_ ) );
}


#-------------------------------------------------------------------------------
#  Compute the genome codon usages for a SEED genome and write the results to
#  the genome directory.
#
#     @usages = compute_genome_codon_usages( $gid, \%opts );
#     $n_done = compute_genome_codon_usages( $gid, \%opts );
#
#  Return values:
#
#     @usages = ( [ $gid, $gname, $type, $subtype, $freqs, $gencode ], ... )
#
#  Options:
#
#     dna           => \@dna     # Use supplied coding sequences
#     dna           =>  1        # Return coding sequences in option hash
#     genus_species =>  $gs      # Genome name (D = $fig->genus_species())
#     gid           =>  $gid     # Instead of supplying as first argument
#     load          =>  $bool    # Also enter them in the SEED dbms
#     noload        =>  $bool    # Do not write to the SEED dbms
#     nowrite       =>  $bool    # Do not write to the genome directory
#     seq           => \@dna     # Use supplied coding sequences
#     seq           =>  1        # Return coding sequences in option hash
#
#  Note that supplying the coding sequences is frowned upon. If the wrong
#  sequences are supplied, it can corrupt the stored codon usages associated
#  with the genome id.
#
#  Codon usages are written to the SEED dbms if noload is false and either load
#  is true or nowrite is false.
#-------------------------------------------------------------------------------
sub compute_genome_codon_usages
{
    my $opts = $_[ 0] && ref($_[ 0]) eq 'HASH' ? shift :
               $_[-1] && ref($_[-1]) eq 'HASH' ? pop   : {};

    my $gid = shift || $opts->{ gid } or return wantarray ? () : 0;
    $opts->{ gid } = $gid;

    my $fig = $opts->{ fig } ||= FIG->new()
        or return wantarray ? () : 0;

    #  Valid SEED or RAST genome?

    my $in_seed = $fig->is_genome( $gid );
    my $is_rast = ( ! $in_seed ) && ( ( $fig->{ _genome } || '' ) eq $gid );
    $in_seed || $is_rast
        or return wantarray ? () : 0;

    my $gname = $opts->{ gname } || $opts->{ genus_species }
                                 || $fig->genus_species( $gid );

    my $orgdir = $fig->{ _orgdir }
              || "$FIG_Config::organisms/$gid"
              || '';

    ( $orgdir && -d $orgdir )
        or return wantarray ? () : 0;

    my $cufile = "$orgdir/CODON_USAGES";

    # Check whether the coding sequences are supplied

    my $dna_opt  = $opts->{ dna } || $opts->{ seq } || '';
    my $have_dna = ( ref($dna_opt) eq 'ARRAY' ) && @$dna_opt;
    my $seqs = $have_dna ? $dna_opt
                         : coding_sequences( $gid, { fig => $fig } );

    #  Have the coding sequences been requested by the caller?

    if ( $dna_opt && ! $have_dna )
    {
        $opts->{ dna } = $seqs if $opts->{ dna };
        $opts->{ seq } = $seqs if $opts->{ seq };
    }

    my $title = $opts->{ genome_title } ||= "$gid $gname";
    my $usage_opts = { average      => 1,
                       gid          => $gid,
                       genome_title => $title
                     };
    my @usages = gjonativecodonlib::codon_usages_from_seqs( $seqs, $usage_opts );

    if ( ! $opts->{ nowrite } )
    {
        gjocodonlib::write_genome_codon_usages( $cufile, @usages );
    }

    if ( $in_seed && ! $opts->{ noload } && ( $opts->{ load } || ! $opts->{ nowrite } ) )
    {
        genome_codon_usages_to_db( $fig, @usages );
    }

    wantarray ? @usages : scalar @usages;
}


#-------------------------------------------------------------------------------
#  Load codon usages from one or more genome directories into the dbms. Existing
#  data for the genome(s) are removed.
#
#     $n_done = load_genome_codon_usages( @gids,      \%opts );
#     $n_done = load_genome_codon_usages( 'all',      \%opts );
#     $n_done = load_genome_codon_usages( 'complete', \%opts );
#     $n_done = load_genome_codon_usages(             \%opts );
#
#  Options:
#
#     fig           =>  $fig     # FIG object
#     gid           =>  $gid     # Instead of supplying as argument
#     gids          => \@gids    # Instead of supplying as arguments
#
#-------------------------------------------------------------------------------
sub load_genome_codon_usages
{
    my $opts = $_[ 0] && ref($_[ 0]) eq 'HASH' ? shift
             : $_[-1] && ref($_[-1]) eq 'HASH' ? pop
             :                                   {};

    my $fig = $opts->{ fig } ||= FIG->new()
        or return 0;

    my $dbh = $fig->db_handle
        or return 0;

    my @gids = @_;
    if ( ! @gids )
    {
        my ( $key ) = grep { $opts->{$_} } qw( gids gid );
        if ( $key )
        {
            my $gids = $opts->{ $key };
            @gids = ref $gids eq 'ARRAY' ? @$gids
                  : ! ref $gids          ? ( $gids )
                  :                        ();
        }
    }
    elsif ( $gids[0] eq 'all' )
    {
        @gids = $fig->genomes();
    }
    elsif ( $gids[0] eq 'complete' )
    {
        @gids = $fig->genomes( 1 );
    }

    #  Valid SEED genome(s) (RAST does not go into the database)

    my %seen;
    @gids = grep { ( ! $seen{ $_ }++ ) && $fig->is_genome( $_ ) } @gids;
    @gids or return 0;

    my $n = 0;
    foreach my $gid ( @gids )
    {
        #  Get codon usages from the genome directory
        #  [ $gid, $gname, $cutype, $cusubtype, $freqs, $gencode ]
        #  The $gid check should never fail.
        #  The $gname from the file will be ignored.

        my @usages = grep { $_->[0] eq $gid }
                     codon_usages_from_genome_dir( $fig, $gid );
        @usages && $usages[0]
            or next;

        #  Put the codon usages into the dbms

        $n += genome_codon_usages_to_db_clean( $fig, @usages );
    }

    $n;
}


#-------------------------------------------------------------------------------
#  Read the codon usages from a genome directory.
#
#     @usages = codon_usages_from_genome_dir( $fig, $gid );
#
#-------------------------------------------------------------------------------
sub codon_usages_from_genome_dir
{
    my ( $fig, $gid ) = @_;
    $fig && $gid or return wantarray ? () : [];

    my $orgdir = $fig->{ _orgdir }
              || "$FIG_Config::organisms/$gid"
              || '';
    my $cufile = ( $orgdir && -d $orgdir ) ? "$orgdir/CODON_USAGES" : '';

    my @usages = -s $cufile ? gjocodonlib::read_genome_codon_usages( $cufile ) : ();

    wantarray ? @usages : \@usages;
}


#===============================================================================
#  SEED dbms support for codon usages:
#===============================================================================
#
#   @codon_usages = genome_codon_usages_from_db( $fig, @gids )
#   $n_written    = genome_codon_usages_to_db( $fig, @usages )
#   $n_written    = genome_codon_usages_to_db_clean( $fig, @usages )
#
#                   create_codon_usage_table( $dbh )
#                   drop_codon_usage_table( $dbh )
#
#  Each usage is [ $gid, $gname, $type, $subtype, $freqs, $gencode ]
#
#  The database table is:
#
#    CodonUsage
#        cuid       VARCHAR( 128) UNIQUE NOT NULL   #  "$gid:$type:$subtype"
#        gid        VARCHAR(  32) NOT NULL          #   genome id
#        cutype     VARCHAR(  64) NOT NULL          #   codon usage type
#        cusubtype  VARCHAR(  64) DEFAULT ''        #   codon usage subtype
#        freqs      VARCHAR(1024) NOT NULL          #   codon usage freq string
#        gencode    INT           DEFAULT 1         #   genetic code
#
#-------------------------------------------------------------------------------
#  Get the codon usage data from the database.
#
#-------------------------------------------------------------------------------
sub genome_codon_usages_from_db
{
    my ( $fig, @gids ) = @_;
    $fig && @gids
        or return wantarray ? () : [];

    my $dbh = $fig->db_handle;
    $dbh && $dbh->table_exists( 'CodonUsage' )
        or return wantarray ? () : [];

    my $sublist = join( ', ', '?' x @gids );
    my $cuL = $dbh->SQL( 'SELECT gid, cutype, cusubtype, freqs, gencode'
                       . '    FROM CodonUsage'
                       . "    WHERE gid IN ( $sublist )", '', @gids
                       )
           || [];

    my %gname;
    my @usages;
    foreach ( @$cuL )
    {
        my ( $gid, $type, $subtype, $freqstr, $gencode ) = @$_;
        my $gname = $gname{ $gid } ||= $fig->genus_species( $gid ) || '';
        my $freqs = gjocodonlib::split_frequencies( $freqstr );
        $freqs && @$freqs or next;
        push @usages, [ $gid, $gname, $type, $subtype, $freqs, $gencode ];
    }

    wantarray ? @usages : \@usages;
}


#-------------------------------------------------------------------------------
#  Put codon usage data into the dbms. The "_clean" version removes all data
#  for the genomes, whereas the first version only replaces exactly matching
#  types.
#
#   $n_written = genome_codon_usages_to_db(       $fig, @usages )
#   $n_written = genome_codon_usages_to_db_clean( $fig, @usages )
#
#-------------------------------------------------------------------------------
sub genome_codon_usages_to_db
{
    my ( $fig, @usages ) = @_;
    $fig && @usages
        or return 0;

    my $dbh = $fig->db_handle or return 0;
    create_codon_usage_table( $dbh ) if ! $dbh->table_exists( 'CodonUsage' );
    return 0 if ! $dbh->table_exists( 'CodonUsage' );

    my $n = 0;
    foreach ( @usages )
    {
        my ( $gid, undef, $type, $subtype, $freqs, $gencode ) = @$_;
        $gid && $type && $freqs or next;
        $subtype = '' unless defined $subtype;
        $gencode =  1 unless         $gencode;
        my $freqstr = gjocodonlib::frequencies_as_string( $freqs )
            or next;
        my $cuid = "$gid:$type:$subtype";

        #  Note an UPDATE of zero records returns '0E0', which is true in perl
        $n += $dbh->SQL( 'UPDATE CodonUsage'
                       . '    SET freqs = ?, gencode = ?'
                       . '    WHERE cuid = ?', '',
                         $freqstr, $gencode, $cuid
                       ) + 0
           || $dbh->SQL( 'INSERT INTO CodonUsage'
                       . '    ( cuid, gid, cutype, cusubtype, freqs, gencode )'
                       . '    VALUES ( ?, ?, ?, ?, ?, ? )', '',
                         $cuid, $gid, $type, $subtype, $freqstr, $gencode
                       ) + 0
           || 0;

        #  I never got this form working correctly, so the two step approach above.
        #
        # $n += $dbh->SQL( 'INSERT INTO CodonUsage ( cuid, gid, cutype, cusubtype, freqs, gencode )'
        #                . '       VALUES ( ?, ?, ?, ?, ?, ? )'
        #                . '       ON DUPLICATE KEY UPDATE freqs = ?, gencode = ?', '',
        #                  $cuid, $gid, $type, $subtype, $freqstr, $gencode, $freqstr, $gencode
        #                );
    }

    $n;
}


sub genome_codon_usages_to_db_clean
{
    my ( $fig, @usages ) = @_;
    $fig && @usages
        or return 0;

    my $dbh = $fig->db_handle or return 0;
    create_codon_usage_table( $dbh ) if ! $dbh->table_exists( 'CodonUsage' );
    return 0 if ! $dbh->table_exists( 'CodonUsage' );

    #  The ides of "clean" is to remove all data for the given genome(s):

    my %gids    = map { $_->[0] => 1 } @usages;
    my $sublist = join( ', ', '?' x keys %gids );
    $dbh->SQL( "DELETE CodonUsage WHERE gid IN ( $sublist )", '', keys %gids );

    #  Build s hash of the new data, ensuring uniqueness

    my %data;
    foreach ( @usages )
    {
        my ( $gid, undef, $type, $subtype, $freqs, $gencode ) = @$_;
        $gid && $type && $freqs or next;
        $subtype = '' unless defined $subtype;
        $gencode =  1 unless         $gencode;
        my $freqstr = gjocodonlib::frequencies_as_string( $freqs )
            or next;
        my $cuid = "$gid:$type:$subtype";
        $data{ $cuid } = [ $cuid, $gid, $type, $subtype, $freqstr, $gencode ];
    }

    my $n = 0;
    foreach my $cuid ( keys %data )
    {
        #  Note an INSERT of zero records returns '0E0', which is true in perl
        $n += $dbh->SQL( 'INSERT INTO CodonUsage'
                       . '    ( cuid, gid, cutype, cusubtype, freqs, gencode )'
                       . '    VALUES ( ?, ?, ?, ?, ?, ? )', '',
                         @{ $data{ $cuid } }
                       ) + 0
           || 0;
    }

    $n;
}


#-------------------------------------------------------------------------------
#  create_codon_usage_table( $dbh )
#-------------------------------------------------------------------------------
sub create_codon_usage_table
{
    my $dbh = shift
        or return 0;

    $dbh->create_table( tbl  => 'CodonUsage',
                        flds => 'cuid       VARCHAR( 128) UNIQUE NOT NULL, '
                              . 'gid        VARCHAR(  32) NOT NULL, '
                              . 'cutype     VARCHAR(  64) NOT NULL, '
                              . 'cusubtype  VARCHAR(  64) DEFAULT "", '
                              . 'freqs      VARCHAR(1024) NOT NULL, '
                              . 'gencode    INT           DEFAULT 1'
                      );

    $dbh->create_index( tbl  => 'CodonUsage',
                        idx  => 'CodonUsageCUID',
                        flds => 'cuid',
                        kind => 'PRIMARY'
                      );

    $dbh->create_index( tbl  => 'CodonUsage',
                        idx  => 'CodonUsageGID',
                        flds => 'gid'
                      );

    $dbh->create_index( tbl  => 'CodonUsage',
                        idx  => 'CodonUsageType',
                        flds => 'cutype'
                      );

    return 1;
}


#-------------------------------------------------------------------------------
#  drop_codon_usage_table( $dbh )
#-------------------------------------------------------------------------------
sub drop_codon_usage_table
{
    my $dbh = shift
        or return 0;

  # $dbh->drop_index( tbl => 'CodonUsage', idx => 'CodonUsageCUID' );
  # $dbh->drop_index( tbl => 'CodonUsage', idx => 'CodonUsageGID' );
  # $dbh->drop_index( tbl => 'CodonUsage', idx => 'CodonUsageType' );
    $dbh->drop_table( tbl => 'CodonUsage' );

    return 1;
}


#-------------------------------------------------------------------------------
#  Create or update SEED genome codon usages
#
#      $ndone = initialize_usages( \%opts )
#
#  Options:
#
#       eucarya =>  $bool  # include include Eucarya (default is only "prok")
#       gid     =>  $gid   # just this gid
#       gids    => \@gids  # just listed gids
#       partial =>  $bool  # include incomplete (default is only complete)
#       update  =>  $bool  # update existing value (default is only add missing)
#
#  If explicit gids are supplied, these are forced to update
#
#  perl -e 'use SeedCodonUsage; print SeedCodonUsage::initialize_usages( { verbose => 1 } ), " done\n"'
#
#-------------------------------------------------------------------------------
sub initialize_usages
{

    my $opts = shift || {};
    my $fig  = fig_object( $opts )
        or return 0;

    my $complete = ! $opts->{ partial };   # All incomplete genomes
    my $eukkey   = ( ( grep { m/^eu[ck]ary/i } keys %$opts ), '' )[0];
    my $eucarya  = $eukkey ? $opts->{ $eukkey } : '';

    my @gids     = ();
    if ( $opts->{ gid } )
    {
        push @gids, $opts->{ gid };
    }
    if ( $opts->{ gids } && ref( $opts->{ gids } ) eq 'ARRAY' )
    {
        push @gids, @{ $opts->{ gids } };
    }

    my $update = @gids || $opts->{ update };

    if ( @gids )
    {
        @gids = grep { $fig->is_genome( $_ ) } @gids;
    }
    else
    {
        @gids = $fig->genomes( $complete );
        @gids = grep { $fig->is_prokaryotic( $_ ) } @gids if ! $eucarya;
    }

    my $ndone = 0;

    foreach my $gid ( @gids )
    {
        print STDERR "$gid ... " if $opts->{ verbose };
        genome_axes( $gid, $opts );
        $ndone += 1 if $opts->{ from } eq 'de novo';
        print STDERR "$opts->{from}\n" if $opts->{ verbose };
    }

    $ndone;
}


1;
