package SaplingGenomeData;

use strict;
use SAPserver;
use SaplingCodonUsage;
use Data::Dumper;


#-------------------------------------------------------------------------------
#  Get a Sapling server object
#
#   $sapObject = sap_object( \%opts )
#
#  Options:
#
#    sap => $sapObject  # This will be used if it already exists.
#
#-------------------------------------------------------------------------------
sub sap_object
{
    my $opts = $_[ 0] && ref($_[ 0]) eq 'HASH' ? shift :
               $_[-1] && ref($_[-1]) eq 'HASH' ? pop   : {};

    my $sap = $opts->{ sap };
    is_sap( $sap ) ? $sap : ( $opts->{ sap } = SAPserver->new() );
}


sub is_sap
{
    my $self = shift;
    eval { $self && $self->isa( 'SAPserver' ) } ? 'SAPserver' : '';
}


#-------------------------------------------------------------------------------
#  Support for fid -> md5 conversion:
#
#   \%md5s_of_fids = pegs_to_md5(              @fids );  # One or more fids
#   \%md5s_of_fids = pegs_to_md5( $SAPserverO, @fids );
#
#-------------------------------------------------------------------------------
sub pegs_to_md5
{
    my $SapO;
    $SapO = shift if eval { $_[0]->isa( 'SAPserver' ) };

    my @fids = @_;
    return wantarray ? () : {} if ! @fids;

    $SapO ||= SAPserver->new() or die "Could not get a new SAPserver\n";
    my $md5H = $SapO->fids_to_proteins( -ids => \@fids ) || {};

    wantarray ? %$md5H : $md5H;
}


#-------------------------------------------------------------------------------
#  Support for fid -> md5 conversion:
#
#    @peg_data = all_genome_peg_data( \%opts )
#   \@peg_data = all_genome_peg_data( \%opts )
#
#  Output:
#
#    [ $gid, $fid, $md5, $gid, $contig, $cont_len, $beg, $end, $mid, $index, $n_peg ]
#
#-------------------------------------------------------------------------------
sub all_genome_peg_data
{
    my $opts = shift || {};

    #  Get the genomes and their contig lists
    my @gid_data = filtered_genome_contigs( $opts );

    #  Get the contig lengths
    my @contigs = map { @{ $_->[1] } } @gid_data;
    my $lenH = sap_object( $opts )->contig_lengths( { -ids => \@contigs } ) || {};
    $opts->{ contig_len } = $lenH;

    #  Eliminate gids that are missing any contig lengths
    # my @gids = map { $_->[0] }
    #            grep { ! grep { ! $lenH->{ $_ } } @{ $_->[1] } }
    #            @gid_data;

    my @gids;
    foreach ( @gid_data )
    {
        my ( $gid, $contigs ) = @$_;
        my $okay = 1;
        foreach ( @$contigs )
        {
            if ( ! $lenH->{ $_ } ) { $okay = 0; last }
        }
        push @gids, $gid  if $okay;
    }

    my @peg_data = map { genome_peg_data( $_, $opts ) } @gids;
}


#-------------------------------------------------------------------------------
#  Get Sapling genomes, possibly filtered
#
#   @gid_data = filtered_genome_contigs( \%opts )
#  \@gid_data = filtered_genome_contigs( \%opts )
#
#   $datum = [ $gid, \@contigs ]
#
#-------------------------------------------------------------------------------
sub filtered_genome_contigs
{
    my $opts = shift || {};
    my $max_contig = $opts->{ max_contig }
                  || $opts->{ maxcontig }
                  || 10;

    my $SapO = sap_object( $opts );
    my $genH = $SapO->all_genomes( { -complete => 1, -prokaryotic => 1 } ) || {};
    my @gids = keys %$genH;
    my $contigH = $SapO->genome_contigs( { -ids => \@gids } );

    my @data = map { my $c = $contigH->{$_} || [];
                     @$c && ( @$c <= $max_contig ) ? [ $_, $c ] : ()
                   }
               @gids;

    wantarray ? @data : \@data;
}


#-------------------------------------------------------------------------------
#  Get genome, possibly filtered (just for testing, I think)
#
#   @gid_data = genome_contigs( $gid, \%opts )
#  \@gid_data = genome_contigs( $gid, \%opts )
#
#   $datum = [ $gid, \@contigs ]
#
#-------------------------------------------------------------------------------
sub genome_contigs
{
    my ( $gid, $opts ) = @_;
    $opts ||= {};

    my $max_contig = $opts->{ max_contig }
                  || $opts->{ maxcontig }
                  || 10;

    my $SapO = sap_object( $opts );
    my $contigH = $SapO->genome_contigs( { -ids => [ $gid ] } );

    my @data = map { my $c = $contigH->{$_} || [];
                     @$c && ( @$c <= $max_contig ) ? [ $_, $c ] : ()
                   }
               $gid;

    wantarray ? @data : \@data;
}


#-------------------------------------------------------------------------------
#  Get coding sequences
#
#   @peg_info = genome_peg_data( $gid, \%opts )
#  \@peg_info = genome_peg_data( $gid, \%opts )
#
#  Return values:
#
#   [ $fid, $md5, $gid, $contig, $contig_len, $beg, $end, $mid, $index, $n_peg ]
#
#  Options:
#
#    gid => $gid        # Alternative to supplying the gid in arg list
#    sap => $SAPserver  # Supply the server object
#
#-------------------------------------------------------------------------------
sub genome_peg_data
{
    my $opts = $_[ 0] && ref($_[ 0]) eq 'HASH' ? shift :
               $_[-1] && ref($_[-1]) eq 'HASH' ? pop   : {};

    my $SapO = sap_object( $opts ) or return wantarray ? () : [];

    my $gid  = shift || $opts->{ gid } or return wantarray ? () : [];

    # [ $fid, $contig, $beg, $end, $mid ]
    my @peg_pos = ordered_pegs( $gid, $opts );

    #  If we are missing a contig length, get them all
    my $lenH = $opts->{ contig_len } || {};
    my %cont = map { $_->[1] => 1 } @peg_pos;
    my @cont = keys %cont;
    my @okay = grep { $lenH->{$_} } @cont;
    if ( @okay != @cont )
    {
        $lenH = $SapO->contig_lengths( { -ids => \@cont } ) || {};
    }

    #  Get md5s
    my @fids = map { $_->[0] } @peg_pos;
    my $fid2md5 = pegs_to_md5( $SapO, @fids );

    #  Build the output data
    my %index;
    my %n_peg;
    foreach ( @cont )    { $index{ $_ } = 0; $n_peg{ $_ } = 0 }
    foreach ( @peg_pos ) { $n_peg{ $_->[1] }++ }

    my @data = map { my ( $fid, $c, $b, $e, $m ) = @$_;
                     [ $fid, $fid2md5->{$fid},
                       $gid,
                       $c, $lenH->{$c},
                       $b, $e, $m,
                       ++$index{$c}, $n_peg{$c}
                     ]
                   }
               @peg_pos;

    wantarray ? @data : \@data;
}


#-------------------------------------------------------------------------------
#  Get coding sequences
#
#   @peg_pos = ordered_pegs( $gid, \%opts )
#  \@peg_pos = ordered_pegs( $gid, \%opts )
#
#  Return values:
#
#   [ $fid, $contig, $beg, $end, $mid ]
#
#  Options:
#
#    gid => $gid        # Alternative to supplying the gid in arg list
#    sap => $SAPserver  # Supply the server object
#
#-------------------------------------------------------------------------------
sub ordered_pegs
{
    my $opts = $_[ 0] && ref($_[ 0]) eq 'HASH' ? shift :
               $_[-1] && ref($_[-1]) eq 'HASH' ? pop   : {};

    my $gid  = shift || $opts->{ gid } or return wantarray ? () : [];

    my $SapO = sap_object( $opts ) or return wantarray ? () : [];

    my $fidH = $SapO->all_features( { -ids => [ $gid ], -type => [ 'peg' ] } );
    my @fids = @{ $fidH->{ $gid } || [] };
    my $locH = $SapO->fid_locations( { -ids => \@fids } );

    my @pegs = sort { lc $a->[1] cmp lc $b->[1] || $a->[4] <=> $b->[4] }
               map  { my @mid = midpoint( $locH->{$_} ); @mid ? [ $_, @mid ] : () }
               keys %$locH;

    wantarray ? @pegs : \@pegs;
}


#-------------------------------------------------------------------------------
#  Auxiliary function for ordering coding sequences from Sapling or SEED
#
#  ( $contig, $beg, $end, $mid ) = midpoint( $seed_or_sap_location )
#
#-------------------------------------------------------------------------------
sub midpoint
{
    $_[0] or return ();
    my $c;
    my @ends = map  { ( $c ||= $_->[0] ) eq $_->[0] ? @$_[1,2] : () }
               map  { /^(.+)_(\d+)\_(\d+)$/ ? [ $1, $2, $3        ] :
                      /^(.+)_(\d+)\+(\d+)$/ ? [ $1, $2, $2+($3-1) ] :
                      /^(.+)_(\d+)\-(\d+)$/ ? [ $1, $2, $2-($3-1) ] : ()
                    }
               ref($_[0]) eq 'ARRAY' ? @{$_[0]} : split /,/, $_[0];

    $c && @ends ? ( $c, $ends[0], $ends[-1], 0.5*( $ends[0] + $ends[-1] ) ) : ();
}


1;
