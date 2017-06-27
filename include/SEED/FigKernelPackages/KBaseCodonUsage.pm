#
#  KBaseCodonUsage.pm
#
package KBaseCodonUsage;

use strict;
use Bio::KBase;
use gjocodonlib;
use gjonativecodonlib;
use gjoseqlib;
use Data::Dumper;

#===============================================================================
#  KBase support for codon usages. Nothing is exported because the functions
#  are parallel to those for the SEED and Sapling.
#===============================================================================
#  Get coding sequences.
#
#   @seqs = coding_sequences( $gid, \%opts )
#  \@seqs = coding_sequences( $gid, \%opts )
#
#  Get codon usage counts for genes.
#
#   @cnts = labeled_counts( $gid, \%opts )
#  \@cnts = labeled_counts( $gid, \%opts )
#
#  Get available codon usages for a genome.
#
#     @usages = genome_codon_usages( $gid, \%opts );
#    \@usages = genome_codon_usages( $gid, \%opts );
#
#     @axes = genome_axes( $gid, \%opts );
#    \@axes = genome_axes( $gid, \%opts );
#
#-------------------------------------------------------------------------------
#  Get a KBase client object
#
#   $KBaseObject = kbase_object( \%opts )
#
#  Options:
#
#    kbase => $KBaseObject  # This will be used if it already exists.
#
#-------------------------------------------------------------------------------
sub kbase_object
{
    my $opts = $_[ 0] && ref($_[ 0]) eq 'HASH' ? shift :
               $_[-1] && ref($_[-1]) eq 'HASH' ? pop   : {};

    my $kbase = $opts->{ kbase };
    is_kbase( $kbase ) ? $kbase : ( $opts->{ kbase } = Bio::KBase->central_store() );
}


sub is_kbase
{
    my $self = shift;
    eval { $self && $self->isa( 'Bio::KBase::CDMI::Client' ) } ? 'Bio::KBase::CDMI::Client' : '';
}


#-------------------------------------------------------------------------------
#  Get codon usage counts for genes from the KBase server.
#  Requires Bio::KBase.pm, or a Bio::KBase::CDMI::Client object.
#
#   @cnts = labeled_counts( $gid, \%opts )
#  \@cnts = labeled_counts( $gid, \%opts )
#
#  Options:
#
#    gid   => $gid          # Alternative to supplying the gid in arg list
#    kbase => $KBaseClient  # Supply the client object
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
#    gid    =>   $gid          # Alternative to supplying the gid in arg list
#    kbase  =>   $KBaseClient  # Supply the client object
#    region =>   $fid          # +/- 10,000 nt
#    region => [ $fid ]        # +/- 10,000 nt
#    region => [ $fid, $regsize ]   # regsize centered on feature midpoint
#    region => [ $fid, $nt_before, $nt_after ]
#
#-------------------------------------------------------------------------------
sub coding_sequences
{
    my $opts = $_[ 0] && ref($_[ 0]) eq 'HASH' ? shift :
               $_[-1] && ref($_[-1]) eq 'HASH' ? pop   : {};

    my $kbase = kbase_object( $opts ) or return wantarray ? () : [];

    my $gid = $opts->{ gid } ||= shift || '';
    $gid = "kb|$gid" if $gid =~ /^g\.\d+$/;

    my @fids;
    if ( $opts->{ region } )
    {
        my $region = $opts->{ region };
        my ( $fid, $arg2, $arg3 ) = ref($region) eq 'ARRAY' ? @$region
                                                            : ( $region );

        $fid ||= '';
        $fid = "kb\|$fid" if $fid =~ /^g\.\d+\./;

        my ( $gid2 ) = $fid =~ /^(kb\|g\.\d+)\..+$/;
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

        my $locH = $kbase->fids_to_locations( [ $fid ] ) || {};
        my $loc  = $locH->{ $fid };
        $loc
            or print STDERR qq(coding_sequences: Could not find location of '$fid'.\n)
                and return wantarray ? () : [];
        my ( $c, $l, $r ) = boundaries_of( $loc );
        defined( $c )
            or print STDERR qq(coding_sequences: Could not parse location of '$fid'.\n)
                and return wantarray ? () : [];

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
        my $len  = $r - $l + 1;
        my $locS = "${c}_$l+$len";

        my $fidsH = $kbase->locations_to_fids( [$locS] ) || {};
        my $fids  = $fidsH->{ $locS } || [];
        @fids = grep { kbase_ftr_type( $_ ) eq 'CDS'
                    || kbase_ftr_type( $_ ) eq 'peg'
                     } @$fids;
    }
    else
    {
        $gid or return wantarray ? () : [];

        my $fidsH = $kbase->genomes_to_fids( [$gid], ['CDS'] ) || {};
        @fids = @{ $fidsH->{ $gid } || [] };
    }
    @fids or return wantarray ? () : [];

    my $funcH = $kbase->fids_to_functions( \@fids ) || {};

    my $seqH  = $kbase->fids_to_dna_sequences( \@fids ) || {};

    my $locH  = $kbase->fids_to_locations( \@fids ) || {};

    my @seqs = map  { $seqH->{$_} ? [ $_, $funcH->{$_} || '', $seqH->{$_} ] : () }
               map  { $_->[0] }
               sort { lc $a->[1] cmp lc $b->[1] || $a->[2] <=> $b->[2] }
               map  { my @mid = midpoint_of( $locH->{$_} ); @mid ? [ $_, @mid ] : () }
               keys %$locH;

    wantarray ? @seqs : \@seqs;
}


sub kbase_ftr_type { ( ($_[0] || '') =~ /^kb\|g\.\d+\.([^.]+)\./ )[0] }


#-------------------------------------------------------------------------------
#  Function for finding boundaries of a SEED, Sapling or KBase location
#
#  ( $contig, $min, $max, $dir ) = boundaries_of( $location )
#
#-------------------------------------------------------------------------------
sub boundaries_of
{
    my $locs = location_to_cbed( @_ );
    $locs && @$locs
        or return wantarray ? () : undef;
    my ( $c1, $b1, $d1 ) = @{$locs->[ 0]}[0,1,3];
    my ( $c2, $e2, $d2 ) = @{$locs->[-1]}[0,2,3];
    $b1 && $e2 && ( $c1 eq $c2 ) && ( $d1 eq $d2 )
        or return wantarray ? () : undef;
    my @ans = ( $c1, min_max( $b1, $e2 ), $d1 );

    wantarray ? @ans : \@ans;
}


sub min_max { $_[0] <= $_[1] ? @_[0,1] : @_[1,0] }


#-------------------------------------------------------------------------------
#  Function for finding midpoint of a SEED, Sapling or KBase location
#
#  ( $contig, $midpoint ) = midpoint_of( $location )
#
#-------------------------------------------------------------------------------
sub midpoint_of
{
    my $locs = location_to_cbed( @_ );
    $locs && @$locs
        or return wantarray ? () : undef;
    my ( $c1, $b1, $d1 ) = @{$locs->[ 0]}[0,1,3];
    my ( $c2, $e2, $d2 ) = @{$locs->[-1]}[0,2,3];
    $b1 && $e2 && ( $c1 eq $c2 ) && ( $d1 eq $d2 )
        or return wantarray ? () : undef;
    my @ans = ( $c1, 0.5*($b1+$e2) );

    wantarray ? @ans : \@ans;
}


#-------------------------------------------------------------------------------
#  Functions listing components of a location string or structure:
#
#   @contig_beg_end_dir_list = location_to_cbed( $location )
#  \@contig_beg_end_dir_list = location_to_cbed( $location )
#
#   @contig_beg_dir_len_list = location_to_cbdl( $location )
#  \@contig_beg_dir_len_list = location_to_cbdl( $location )
#
#      SEED string    = 'contig_beg_end,...'
#      Sapling string = 'contig_beg±len,...'
#      KBase string   = 'contig_beg±len,...'
#      Sapling API    = [ 'contig_beg±len', ... ]
#      KBase API      = [ [ contig, beg, dir, len ], ... ]
#
#-------------------------------------------------------------------------------
sub location_to_cbed
{
    my @locs = map  { ref($_) eq 'ARRAY'    ? [ @$_[0,1], 
                                                $_->[1] + ( $_->[2] eq '+' ? $_->[3]-1 : -($_->[3]-1) ),
                                                $_->[2]
                                              ]                                    #  KBase API
                    : /^(.+)_(\d+)\+(\d+)$/ ? [ $1, $2, $2+($3-1), '+' ]           #  KBase or Sapling string
                    : /^(.+)_(\d+)\-(\d+)$/ ? [ $1, $2, $2-($3-1), '-' ]           #  KBase or Sapling string
                    : /^(.+)_(\d+)\_(\d+)$/ ? [ $1, $2, $3, $2 <= $3 ? '+' : '-' ] #  SEED string
                    : ()
                    }
               ref($_[0] || '') eq 'ARRAY' ? @{$_[0]}                   #  KBase or Sapling API
                                           : split /,/, ($_[0] || '');  #  string

    wantarray ? @locs : \@locs;
}


sub location_to_cbdl
{
    my @locs = map  { ref($_) eq 'ARRAY'        ?   $_                  #  KBase API
                    : /^(.+)_(\d+)([-+])(\d+)$/ ? [ $1, $2, $3, $4 ]    #  KBase or Sapling string
                    : /^(.+)_(\d+)_(\d+)$/      ? [ $1, $2,
                                                    $2 <= $3 ? '+' : '-',
                                                    abs($3-$2)+1
                                                  ]                     #  SEED string
                    : ()
                    }
               ref($_[0] || '') eq 'ARRAY' ? @{$_[0]}                   #  KBase or Sapling API
                                           : split /,/, ($_[0] || '');  #  string

    wantarray ? @locs : \@locs;
}


#-------------------------------------------------------------------------------
#  Get available genome codon usages. There is no fallback to computing on the
#  fly as is done in the SEED.
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
#     @axes = ( $gname, $modal, $md_subtype,
#                       $high_expr, $he_subtype,
#                       $nonnative, $nn_subtype
#             )
#
#  Options:
#
#     gid    => $gid
#     update => $bool    # Recalculate de novo
#
#-------------------------------------------------------------------------------
sub genome_codon_usages
{
    my $opts = $_[ 0] && ref($_[ 0]) eq 'HASH' ? shift :
               $_[-1] && ref($_[-1]) eq 'HASH' ? pop   : {};

    my $gid = shift || $opts->{ gid } or return wantarray ? () : [];

    my $kbase = kbase_object( $opts ) or return wantarray ? () : [];

    my $usagesL = $kbase->get_relationship_UsesCodons( [ $gid ],
                                                       [ 'scientific_name' ],
                                                       [],
                                                       [ 'frequencies', 'type', 'subtype' ]
                                                     )
               || [];

    my @usages;
    foreach ( @$usagesL )
    {
        my $gname   = $_->[0]->{ scientific_name } || '';
        my $cu      = $_->[2];
        my $type    = $cu->{ type } or next;
        $type = 'high_expr' if $type =~ /^high-expr/; 
        my $subtype = $cu->{ subtype } || '';
        my $freq = scalar gjocodonlib::split_frequencies( $cu->{ frequencies } || next );
        push @usages, [ $gid, $gname, $type, $subtype, $freq, '' ];
    }

    wantarray ? @usages : \@usages;
}


#-------------------------------------------------------------------------------
#  Get available codon usages for a genome from KBase server
#
#     @usages = genome_axes( $gid, \%opts );
#    \@usages = genome_axes( $gid, \%opts );
#
#-------------------------------------------------------------------------------

sub genome_axes
{
    gjocodonlib::genome_axes_from_usages( genome_codon_usages( @_ ) );
}


1;
