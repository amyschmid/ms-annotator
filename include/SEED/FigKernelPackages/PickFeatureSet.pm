package PickFeatureSet;

use Data::Dumper;
use Carp;

# Candidates are the features we are considering.  The idea is to pick
# an optimal set.
#
# Scored features look like
#
#     $scored_fid  = [ $type, $location, $score, \%extra ]
#


sub pick_feature_set {
    my($candidates,$opt) = @_;

    if (ref($candidates) ne 'ARRAY')
    {
	confess 'You need to pass candidates as an array';
    }
    $opt ||= {};

    #  Score the spacing between two orfs:

    my $max_sp_scr  = $opt->{max_sp_scr}  ||= 3.0;    # peak bonus for optimal spacing
    my $max_overlap = $opt->{max_overlap} ||= 60;     # maximum overlapping nt
    my $sp_decay    = $opt->{sp_decay}    ||= 100;    # decay constant for too great a spacing

    $opt->{min_scr} = 5 if ! defined($opt->{min_scr});
    my $min_scr     = $opt->{min_scr};                # we just do not like things less than this scr

    # $orf = [ $type, $id, $loc, $scr, $contig, $dir, $l, $r ]
 
    my @ftrs = sort { $a->[2] cmp $b->[2] || $a->[4] <=> $b->[4] }   # sort by contig and left end
               grep { ( $_->[5] - $_->[4] > $max_overlap )  # Exclude very short ...
                   || ( $_->[1] > 10 )                      #                .... unless high score
	            }
               map  { my ( $type, $loc, $scr, $extra ) = @$_;   # extra is a hash of extra stuff
                      my ( $c, $b, $e ) = &boundaries_of($loc);
                      my $dir = ( $e <=> $b );
                      my ( $l, $r ) = ( $b < $e ) ? ( $b, $e ) : ( $e, $b );
                      [ $_, $scr, $c, $dir, $l, $r ]
                    }
               grep { $_->[2] >= $min_scr }
               @$candidates;

    my @called = ();
    my @current = ();
    my $c0 = '';

    foreach my $ftr ( @ftrs )
    {
	my ( $data, $scr, $c, $dir, $l, $r ) = @$ftr;
	if ( $c ne $c0 )
	{
	    record( \@called, \@current );
	    @current = ( [ undef, 0, $c, 1, -100000, -99999, undef, 0 ] );
	    $c0 = $c;
	}

        #  Find best total score so far that is completed to the left of $l:

	my ( $best_ttl ) = sort { $b <=> $a }
	                   map  { $_->[7] }
                           grep { $_->[5] < $l }
                           @current;

	#  Remove current end points that are to the left of $l, and with a
	#  score less than $best_ttl + $max_sp_scr (these can never be productively
	#  extended):

	if ( $best_ttl )
	{
	    @current = grep { $_->[5] >= $l
                           || $_->[7] + $max_sp_scr >= $best_ttl
		            }
	               @current;
	}

	#  Find scores for adding to each possible predacessor.  Record as:
	#  [ [ $type, $loc, $scr, $extra ], $scr, $contig, $dir, $l, $r, $prefix, $ttl_scr ]
	#                 0                   1      2       3    4   5     6         7

	my ( $place ) = sort { $b->[7] <=> $a->[7] }  #  A high-scoring position
                        map  { my $sp_scr = spacer_score( $_->[3], $_->[5], $dir, $l, $max_sp_scr, $max_overlap, $sp_decay );
                               [ @$ftr, $_, $_->[7] + $sp_scr + $scr ];
                             }
	                grep { $_->[5] - $max_overlap <= $ftr->[4] }  # excess overlap?
                        @current;

	push @current, $place;
    }
    
    &record( \@called, \@current );
    
    #  Print type, id, location, score

    my @to_return = map { $_->[0] } @called;
    return wantarray ? @to_return : \@to_return;
}

#===============================================================================
#  Subroutines below
#===============================================================================

sub boundaries_of {
    my($loc) = @_;
    
    my @locs = split(/,/,$loc);
    my($contig,$beg) = ($locs[0] =~ /^(\S+)_(\d+)_\d+$/);
    $locs[-1] =~ /_(\d+)$/;
    return ($contig,$beg,$1);
}

#  Find the last member of the chain of orfs that led to the best score:

sub record
{
    my ( $called, $current ) = @_;
    my ( $best_set ) = sort { $b->[7] <=> $a->[7] } @$current;
    record1( $called, $best_set );
}

#  Backtrach through chain of orfs that led to best total score:

sub record1
{
    my ( $called, $tail ) = @_;
    return if ! $tail->[0];      # End of chain (well, start actually )
    record1( $called, $tail->[6] ) if $tail->[6];
    push @$called, $tail;
}


#  Calculate spacer score

sub spacer_score
{
    my ( $fr1, $r1, $fr2, $l2, $max_sp_scr, $max_overlap, $sp_decay ) = @_;

    my $space = ( $l2 - $r1 ) - 1;
    my ( $min_opt, $max_opt );   #  Range of optimal gene spacings

    #  Convergent
    if    ( $fr1 > 0 && $fr2 < 0 )
    {
	$min_opt =  20;
        $max_opt = 120;
    }
    #  Divergent
    elsif ( $fr1 < 0 && $fr2 > 0 )
    {
	$min_opt =  50;
	$max_opt = 150;
    }
    #  Same direction
    else
    {
	$min_opt =  -4;
	$max_opt = 150;
    }

    if    ( $space < $min_opt )
    {
        return $max_sp_scr * ( 1 - ( $min_opt - $space ) / $max_overlap );
    }
    elsif ( $space > $max_opt )
    {
        return $max_sp_scr * exp( ( $max_opt - $space ) / $sp_decay );
    }
    else
    {
        return $max_sp_scr;
    }
}

1;
