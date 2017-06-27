package find_tRNAs;

#
#  perl -e 'use find_tRNAs; find_tRNAs::test()'
#  perl -e 'use find_tRNAs; find_tRNAs::test("243232.1.dna")'
#
use strict;
use BlastInterface;  #  valid_fasta(), this should be moved somewhere else
use Data::Dumper;

#
#  \@tRNAs = run_tRNAscan(  $file, \%opts )
#  \@tRNAs = run_tRNAscan( \*FH,   \%opts )
#  \@tRNAs = run_tRNAscan( \@seq,  \%opts )
#
#  Options:
#
#     domain   => $key   #  Bacteria | Archaea | Eucarya (flexible matching)
#     foldfile => $file  #  Write tRNAscan folding output to this file, and do not delete it.
#     outfile  => $file  #  Write tRNAscan output to this file, and do not delete it.
#     tmp_dir  => $dir   #  location for temporary files
#
#  tRNAs are output as:
#
#    [ $loc, $aa, $ac, $ac_loc, $ac_beg_end, $scr, $seq, $fold, $intron, $pseudo ]
#
#    $loc        = [ [ $contig, $beg, $dir, $len ] ]     #  genome coordinates
#    $aa                                                 #  amino acid in 3 letter code
#    $ac                                                 #  anticodon sequence
#    $ac_loc     = [ [ $contig, $beg, $dir, $len ] ]     #  anticodon genome coordinates
#    $ac_beg_end = [ $beg, $end ]                        #  anticodon tRNA coordinates
#    $scr                                                #  total of HMM and Cov scores
#    $seq                                                #  DNA sequence of the tRNA
#    $fold                                               #  representation of pairs
#    $intron     = [ [ [ $contig, $beg, $dir, $len ] ],  #  intron genome coordinates
#                    [ $beg, $end ]                      #  intron tRNA coordinates
#                  ]
#    $pseudo     = [ $HMM_scr, $Cov_scr ]
#
sub test
{
    print Dumper( run_tRNAscan( $_[0] || '83333.1.dna', $_[1] ) );
}


sub run_tRNAscan
{
    my ( $dna, $opts ) = @_;
    $dna or die "run_tRNAscan() called without valid DNA source.";
    $opts ||= {};

    my $dna_file = BlastInterface::valid_fasta( $dna, $opts )
        or die "run_tRNAscan failed to find or create a DNA sequence file";

    #  Reserve output file names

    my $outfile  = $opts->{ outfile }  || $opts->{ out_file };
    my $foldfile = $opts->{ foldfile } || $opts->{ fold_file };
 
    if ( ! ( $outfile && $foldfile ) )
    {
        eval { require File::Temp; }
            or die "Could not require File::Temp.";
        my $tmpdir   = $opts->{ tmp_dir };

        if ( ! $outfile )
        {
            my $fh;
            my $template = "tRNA.out.XXXXXXXX";
            ( $fh, $outfile ) = $tmpdir ? File::Temp::tempfile( $template, UNLINK => 1, DIR => $tmpdir )
                                        : File::Temp::tempfile( $template, UNLINK => 1, TMPDIR => 1 );
            close( $fh );
        }

        if ( ! $foldfile )
        {
            my $fh;
            my $template = "tRNA.fold.XXXXXXXX";
            ( $fh, $foldfile ) = $tmpdir ? File::Temp::tempfile( $template, UNLINK => 1, DIR => $tmpdir )
                                         : File::Temp::tempfile( $template, UNLINK => 1, TMPDIR => 1 );
            close( $fh );
        }
    }

    my $domval  = $opts->{ domain } || 'Bacteria';
    my $domflag = $domval =~ /^A/i   ? '-A'
                : $domval =~ /^B/i   ? '-B'
                : $domval =~ /^Eub/i ? '-B'
                : $domval =~ /^Env/i ? '-B'
                : $domval =~ /^E/i   ? '-E'
                :                      '-B';

    system( 'tRNAscan-SE',
               $domflag,
               -o => $outfile,
               -f => $foldfile,
               '-q',
               '-Q',
               $dna_file
          )
        and die "Failed to run tRNAscan-SE.";

    read_fold_file( $foldfile );
}


sub read_fold_file
{
    my ( $file ) = @_;
    my @tRNAs;
    if ( open( FOLD, '<', $file ) )
    {
        my $contig;
        my ( $loc, $aa, $ac, $ac_loc, $ac_beg_end, $scr, $seq, $fold, $intron, $pseudo );

        #  0 - Next tRNA
        #  1 - Type?
        #  2 - Possible intron | Possible pseudo | sequence scale bar
        #  3 - Seq?
        #  4 - Str?

        my $state = 0;
        while ( <FOLD> )
        {
            chomp;
            if   ( ! /\S/ )
            {
                $state = 0;
                next;
            }
            elsif ( $state == 0 )
            {
                if ( /^(\S+)\.trna\d+ +\((\d+)-(\d+)\)/ )
                {
                    $contig = $1;
                    $loc    = [ [ $1, be_2_bdl( $2, $3 ) ] ];
                    $state  = 1;
                }
                else
                {
                    print STDERR "Failed to parse in state 0:\n$_\n\n";
                }
            }
            elsif ( $state == 1 )
            {
                #      Type: Gln	Anticodon: CTG at 33-35 (695695-695693)	Score: 75.83
                if ( /^Type:\s+(\S+)\s+Anticodon:\s+(\S+) at (\S+)-(\S+) \((\S+)-(\S+)\)\s+Score:\s+(\S+)/ )
                {
                    ( $aa, $ac, $scr ) = ( $1, $2, $7 );
                    $ac_loc     = [ [ $contig, be_2_bdl( $5, $6 ) ] ];
                    $ac_beg_end = [ $3, $4 ];
                    $intron     = undef;
                    $pseudo     = undef;
                    $state      = 2;
                }
                else
                {
                    print STDERR "Failed to parse in state 1:\n$_\n\n";
                }
            }
            elsif ( $state == 2 )
            {
                if    ( /^Possible intron: (\d+)-(\d+) \((\d+)-(\d+)\)/ )
                {
                    #  [ $loc, $beg_end ]
                    $intron = [ [ [ $contig, be_2_bdl( $3, $4 ) ] ], [ $1, $2 ] ];
                }
                elsif ( /^Possible pseudogene: +HMM Sc=(\S+)\s+Sec struct Sc=(\S+)/ )
                {
                    #  [ $HMM_scr, $Cov_scr ]
                    $pseudo = [ $1, $2 ];
                }
                elsif ( /^[ *|]+$/ )
                {
                    $state = 3;
                }
                else
                {
                    print STDERR "Failed to parse in state 2:\n$_\n\n";
                }
            }
            elsif ( $state == 3 )
            {
                if    ( /^Seq: (\S+)/ )
                {
                    $seq   = $1;
                    $state = 4;
                }
                else
                {
                    print STDERR "Failed to parse in state 2:\n$_\n\n";
                }
            }
            elsif ( $state == 4 )
            {
                if    ( /^Str: (\S+)/ )
                {
                    my $fold = $1;
                    push @tRNAs, [ $loc, $aa, $ac, $ac_loc, $ac_beg_end, $scr, $seq, $fold, $intron, $pseudo ];
                    $state = 0;
                }
                else
                {
                    print STDERR "Failed to parse in state 2:\n$_\n\n";
                }
            }
        }

        close( FOLD );  
    }
    else
    {
        die "Failed to open folds file '$file'.";
    }

    wantarray ? @tRNAs : \@tRNAs;
}


#  tRNAs are output as:
#
#        0    1    2      3        4          5      6     7       8       9
#    [ $loc, $aa, $ac, $ac_loc, $ac_beg_end, $scr, $seq, $fold, $intron, $pseudo ]
#
#    $loc        = [ $contig, $beg, $dir, $len ]     #  genome coordinates
#    $aa                                             #  amino acid in 3 letter code
#    $ac                                             #  anticodon sequence
#    $ac_loc     = [ $contig, $beg, $dir, $len ]     #  anticodon genome coordinates
#    $ac_beg_end = [ $beg, $end ]                    #  anticodon tRNA coordinates
#    $scr                                            #  total of HMM and Cov scores
#    $seq                                            #  DNA sequence of the tRNA
#    $fold                                           #  representation of pairs
#    $intron     = [ [ $contig, $beg, $dir, $len ],  #  intron genome coordinates
#                    [ $beg, $end ]                  #  intron tRNA coordinates
#                  ]
#    $pseudo     = [ $HMM_scr, $Cov_scr ]
#
sub remove_intron
{
    my @tRNAs;
    foreach ( @_ )
    {
        if ( $_->[8] )
        {
            my ( $loc, $aa, $ac, $ac_loc, $ac_beg_end, $scr, $seq, $fold, $intron, $pseudo ) = @$_;

            my ( $contig, $beg,  $dir,   $len ) = @{ $loc->[0] };
            my ( undef, $i_beg, undef, $i_len ) = @{ $intron->[0]->[0] };
            if ( $dir eq '+' )
            {
                #      |<------------len------------>|
                #      |         |<-i_len->|         |
                #     beg      i_beg     i_end      end
                #  ----|---------|---------|---------|----
                #  ----|--------|-----------|--------|----
                #     beg1     end1        beg2     end2
                #      |<-len1->|           |<-len2->|
                #
                my $end1 = $i_beg - 1;
                my $beg2 = $i_beg + $i_len;
                my $end2 = $beg + $len - 1;
                $loc = [ [ $contig, $beg,  $dir, $end1 - $beg  + 1 ],
                         [ $contig, $beg2, $dir, $end2 - $beg2 + 1 ]
                       ];
            }
            else
            {
                #      |<------------len------------>|
                #      |         |<-i_len->|         |
                #     end      i_end     i_beg      beg
                #  ----|---------|---------|---------|----
                #  ----|--------|-----------|--------|----
                #     end2     beg2        end1     beg1
                #      |<-len2->|           |<-len1->|
                #
                my $end1 = $i_beg + 1;
                my $beg2 = $i_beg - $i_len;
                my $end2 = $beg - $len + 1;
                $loc = [ [ $contig, $beg,  $dir, $beg  - $end1 + 1 ],
                         [ $contig, $beg2, $dir, $beg2 - $end2 + 1 ]
                       ];
            }

            my ( $int_beg, $int_end ) = @{ $intron->[1] };
            my $int_len = $int_end - $int_beg + 1;
            my ( $ac_beg, $ac_end ) = @$ac_beg_end;

            $ac_beg_end = [ splice_map_in_tRNA( $ac_beg, $int_beg, $int_end, $int_len ),
                            splice_map_in_tRNA( $ac_end, $int_beg, $int_end, $int_len )
                          ];
            substr( $seq,  $int_beg-1, $int_len ) = '';
            substr( $fold, $int_beg-1, $int_len ) = '';

            #  Currently, I do not see any splice junctions in the anticodon,
            #  but this should be revisited.  In the meanwhile, the fixed
            #  description becomes:

            my $tRNA = [ $loc, $aa, $ac, $ac_loc, $ac_beg_end, $scr, $seq, $fold, undef, $pseudo ];
            push @tRNAs, $tRNA;
        }
        else
        {
            push @tRNAs, $_;
        }
    }

    @tRNAs;
}


sub splice_map_to_genome
{
    my ( $coord, $i_beg, $i_end, $i_len, $beg, $dir, ) = @_;
    if ( $dir eq '+' )
    {
        my $pos0 = $beg + $coord - 1;
        return $coord <  $i_beg ? $pos0
             : $coord <= $i_end ? undef
             :                    $pos0 - $i_len;
    }
    else
    {
        my $pos0 = $beg - $coord + 1;
        return $coord <  $i_beg ? $pos0
             : $coord <= $i_end ? undef
             :                    $pos0 + $i_len;
    }
}


sub splice_map_in_tRNA
{
    my ( $coord, $i_beg, $i_end, $i_len ) = @_;
    $coord < $i_beg ? $coord : $coord <= $i_end ? undef : $coord - $i_len;
}


#
#  Convert begin-end to begin-dir-len, and vice versa
#
sub be_2_bdl
{
    my ( $beg, $end, $dir ) = @_;

    $dir = $end > $beg  ? '+'
         : $end < $beg  ? '-'
         : ! $dir       ? '+'
         : $dir =~ /^-/ ? '-'
         :                '+';

    my $len = $dir eq '+' ? $end - $beg + 1 : $beg - $end + 1;

    wantarray ? ( $beg, $dir, $len ) : [ $beg, $dir, $len ];
}


sub bdl_2_be
{
    my ( $beg, $dir, $len ) = @_;

    my $end = $dir eq '+' ? $beg + $len - 1
                          : $beg - $len + 1;

    wantarray ? ( $beg, $end ) : [ $beg, $end ];
}


1;
