package SaplingAlignmentPsiBLAST;

use strict;
use AlignsAndTreesServer;
use SAPserver;
use SeedUtils;
use gjoseqlib;
use gjoalignment;
use BlastInterface;
use Data::Dumper;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
                  search_prot_with_Sapling_align
                );

my $notes = <<'End_of_Notes';

perl -e 'use Data::Dumper; use SaplingAlignmentPsiBLAST; print STDERR Dumper( SaplingAlignmentPsiBLAST::search_prot_with_Sapling_align( "00000008", "/Volumes/AlienSeed/FIGdisk/FIG/Data/Global/seed.nr", {max_sim => 0.99} ) )'

perl -e 'use Data::Dumper; use SaplingAlignmentPsiBLAST; foreach ( SaplingAlignmentPsiBLAST::search_prot_with_Sapling_align( "00000008", "/Volumes/AlienSeed/FIGdisk/FIG/Data/Global/seed.nr", {max_sim => 0.99} ) ) { printf "%s\t%d-%d/%d\t%s\t%d-%d/%d\t%.3f\t%s\n", @$_[3,18,19,5,0,15,16,2], $_->[11]/$_->[10], $_->[1] }'

perl -e 'use Data::Dumper; use SaplingAlignmentPsiBLAST; foreach ( SaplingAlignmentPsiBLAST::search_prot_with_Sapling_align( "00000582", "/Volumes/AlienSeed/FIGdisk/FIG/Data/Organisms/83333.1/Features/peg/fasta", {max_sim => 0.99} ) ) { printf "%s\t%d-%d/%d\t%s\t%d-%d/%d\t%.3f\t%s\n", @$_[3,18,19,5,0,15,16,2], $_->[11]/$_->[10], $_->[1] }'

perl -e 'use Data::Dumper; use SaplingAlignmentPsiBLAST; foreach ( SaplingAlignmentPsiBLAST::search_prot_with_Sapling_align( "00000582", "/vol/public-pseed/FIGdisk/FIG/Data/Organisms/83333.1/Features/peg/fasta", {max_sim => 0.90} ) ) { printf "%s\t%d-%d/%d\t%s\t%d-%d/%d\t%.3f\t%s\n", @$_[3,18,19,5,0,15,16,2], $_->[11]/$_->[10], $_->[1] }'

End_of_Notes

#==============================================================================
#  Get data on alignments with a protein:
#
#  Sequences that significantly match a Sapling alignment:
#
#   @hsps = matches_to_Sapling_align( $alignID, $db, \%opts );
#
#  Return hsps for 5 top matching sequences in alignment:
#
#   @hsps = search_prot_with_Sapling_align( $alignID, $db, \%opts );
#
#  Return psiblast results (parts of database that match the alignment:
#
#   @hsps = search_prot_with_alignment( $alignment, $db, \%opts );
#
#==============================================================================
#
#  Find sequences in an alignment that match a Sapling alignment, returning
#  alignment data.
#
# time perl -e 'use Data::Dumper; use SaplingAlignmentPsiBLAST; print STDERR Dumper( SaplingAlignmentPsiBLAST::matches_to_Sapling_align( "00000008", "/Volumes/AlienSeed/FIGdisk/FIG/Data/Global/seed.nr", {max_sim => 0.90} ) )
#
#------------------------------------------------------------------------------

sub matches_to_Sapling_align
{
    my ( $alignID, $db, $opts ) = @_;
    $alignID && -f $db && -s $db
        or return undef;

    $opts ||= {};
    my $verbose = $opts->{ verbose };

    my ( $align, $align_meta ) = AlignsAndTreesServer::md5_alignment_by_ID( $alignID, $opts );
    $align && @$align or return undef;

    print STDERR "@{[scalar @$align]} sequences in alignment\n" if $verbose;

    if ( $opts->{ max_sim } )
    {
        @$align = gjoalignment::representative_alignment( $align, $opts );

        print STDERR "@{[scalar @$align]} rep sequences in profile\n" if $verbose;
    }

    my $search_opts = { %$opts };
    $search_opts->{ as_fasta }      = 0;
    # $search_opts->{ pseudo_master } = 1;

    my @db_hits = search_prot_with_alignment( $align, $db, $search_opts );

    print STDERR "@{[scalar @db_hits]} db hits\n" if $verbose;

    #  Find the best matching alignment sequences

    my @hsps;
    # my $min_sim = $opts->{ min_sim } || 0.20;
    foreach my $db_hit ( @db_hits )
    {
        extract_columns( $db_hit, $opts->{ columns } ) if $opts->{ columns };
        push @hsps, $db_hit;
    }

    wantarray ? @hsps : \@hsps;
}


#------------------------------------------------------------------------------
#
#  Find sequences in an alignment that match a Sapling alignment, returning
#  alignment data.
#
# time perl -e 'use Data::Dumper; use SaplingAlignmentPsiBLAST; print STDERR Dumper( SaplingAlignmentPsiBLAST::matches_to_Sapling_align( "00000008", "/Volumes/AlienSeed/FIGdisk/FIG/Data/Global/seed.nr", {max_sim => 0.90} ) )
#
#------------------------------------------------------------------------------

sub extract_columns
{
    my ( $hsp, $columns ) = @_;
    ref( $hsp ) eq 'ARRAY' && ref( $columns ) eq 'ARRAY'
        or return undef;

    my $colmin = $hsp->[15];
    my $colmax = $hsp->[16];
    my $qseq   = $hsp->[17];
    my $sseq   = $hsp->[20];

    my @qcol = ();
    my @scol = ();

    my %res;
    my @cols = sort { $a <=> $b } @$columns;
    my $col0 = 0;
    foreach my $col ( @cols )
    {
        next if $col < $colmin;
        last if $col > $colmax;
        $col -= $colmin;
        if 
    }

    my ( $align, $align_meta ) = AlignsAndTreesServer::md5_alignment_by_ID( $alignID, $opts );
    $align && @$align or return undef;

    print STDERR "@{[scalar @$align]} sequences in alignment\n" if $verbose;

    if ( $opts->{ max_sim } )
    {
        @$align = gjoalignment::representative_alignment( $align, $opts );

        print STDERR "@{[scalar @$align]} rep sequences in profile\n" if $verbose;
    }

    my $search_opts = { %$opts };
    $search_opts->{ as_fasta }      = 0;
    # $search_opts->{ pseudo_master } = 1;

    my @db_hits = search_prot_with_alignment( $align, $db, $search_opts );

    print STDERR "@{[scalar @db_hits]} db hits\n" if $verbose;

    #  Find the best matching alignment sequences

    my @hsps;
    # my $min_sim = $opts->{ min_sim } || 0.20;
    foreach my $db_hit ( @db_hits )
    {
        push @hsps, $db_hit;
    }

    wantarray ? @hsps : \@hsps;
}


#==============================================================================
#  Get data on alignments with a protein
#
#  Return hsps for 5 top matching sequences in alignment:
#
#   @hsps = search_prot_with_Sapling_align( $alignID, $db, \%opts );
#
#  Return psiblast results (parts of database that match the alignment:
#
#   @hsps = search_prot_with_alignment( $alignment, $db, \%opts );
#
#==============================================================================

sub search_prot_with_Sapling_align
{
    my ( $alignID, $db, $opts ) = @_;
    $alignID && -f $db && -s $db
        or return undef;

    $opts ||= {};
    my $verbose = $opts->{ verbose };

    my ( $align, $align_meta ) = AlignsAndTreesServer::md5_alignment_by_ID( $alignID, $opts );
    $align && @$align or return undef;

    print STDERR "@{[scalar @$align]} sequences in alignment\n" if $verbose;

    my $sap = $opts->{ sap } ||= SAPserver->new();
    my %row_data;
    my $gid_name;
    {
        my %md5s = map { $_->[0] => 1 } values %$align_meta;
        my $pegIDs_of_md5 = AlignsAndTreesServer::md5s_to_pegs( $sap, keys %md5s );

        # $metadata->{$seqID} = [ $md5ID, $peg_len, $trim_beg, $trim_end, $range_string ]

        %row_data = map { my ( $md5, $len, $loc ) = ( @{ $align_meta->{$_} } )[0,1,4];
                          my $pegs = $pegIDs_of_md5->{$md5} || [];
                          @$pegs ? ( $_ => [ $pegs, $len, $loc ] ) : ()
                        }
                    map { $_->[0] }  # Alignment row (sequence) ids
                    @$align;

        my %gids  = map { SeedUtils::genome_of( $_ ) => 1 }
                    map { @{ $_->[0] } }
                    values %row_data;

        $gid_name = $sap->genome_names( { -ids => [ keys %gids ] } );

        foreach my $row_id ( keys %row_data )
        {
            my @pegs = grep { $gid_name->{ SeedUtils::genome_of($_) } }
                       @{ $row_data{ $row_id }->[0] };

            if ( @pegs ) { $row_data{ $row_id }->[0] = $pegs[0] }
            else         { $row_data{ $row_id } = undef }
        }
    }

    #  Only keep alignment rows for which we have peg data.

    @$align = grep { $row_data{ $_->[0] } } @$align;

    print STDERR "@{[scalar @$align]} sequences with peg data\n" if $verbose;

    if ( $opts->{ max_sim } )
    {
        @$align = gjoalignment::representative_alignment( $align, $opts );

        print STDERR "@{[scalar @$align]} rep sequences in profile\n" if $verbose;
    }

    my $search_opts = { %$opts };
    $search_opts->{ as_fasta } = 0;
    my @db_hits = search_prot_with_alignment( $align, $db, $search_opts );

    print STDERR "@{[scalar @db_hits]} db hits\n" if $verbose;

    #  Find the best matching alignment sequences

    my @hsps;
    my $min_sim = $opts->{ min_sim } || 0.20;
    foreach my $db_hit ( @db_hits )
    {
        my $sseq = gjoseqlib::pack_seq( $db_hit->[20] );

        # Alignment of database sequence against all sequences in the profile:
        my @aln2 = gjoalignment::add_to_alignment_v2( [ '==UserDBSeq==', '', $sseq ], $align, {} );

        # Pull the database sequence out of the resulting alignment:
        my $i  = 0;
        foreach ( @aln2 ) { last if $_->[0] eq '==UserDBSeq=='; $i++ }
        my $db_seq = splice @aln2, $i, 1;
        $db_seq->[0] = $db_hit->[3];

        # Create hsp records for each of the component alignments:
        my @db_hsps;
        foreach ( @aln2 )
        {
            push @db_hsps, make_hsp( $db_hit, $db_seq, $_, \%row_data );
        }

        my ( $nmat, $nid );
        my @db_hsps = map  { $_->[0] }
                      sort { $b->[1] <=> $a->[1] }
                      map  { ($nmat,$nid) = @$_[10,11];
                             $nmat && $nid/$nmat >= $min_sim ? [ $_, $nid/$nmat ] : ();
                           }
                      @db_hsps;
        splice @db_hsps, 5;

        push @hsps, @db_hsps;
    }

    my $assigns;
    {
        my %pegs  = map { $row_data{ $_->[0] }->[0] => 1 } @hsps;
        my @pegs  = keys %pegs;
        $assigns  = $sap->ids_to_functions( { -ids => \@pegs } );
    }

    foreach ( @hsps ) { fix_hsp_query( $_, \%row_data, $assigns, $gid_name ) }

    wantarray ? @hsps : \@hsps;
}


#
#  The input hsp is from psiblast, in which query is a profile.
#
#  Query is the profile.
#
#  Subject is from the supplied database, trimmed by its psiblast match (hsp_in s1 & s2).
#
#  alnseq is a particular sequence from the psiblast profile, aligned with the subject
#  sequence.
#
#  dbseq is the original subject sequence from the psiblast alignment, aligned with
#  the particular alignment sequence.
#
#  We will set the qid to the alignment row id for the alignment sequence.
#  We will set the qlen to that of the parent of the alignment sequence.
#  We will leave bit score and e-values unchanged (the psiblast values)
#  We will fix the alignment length, the identities, the positives, the
#      gaps to match the pairwise alignment.
#  We will adjust the endpoints to match those of the pairwise alignment.
#  We will replace the sequences with those of the pairwise alignment.
#
sub make_hsp
{
    my ( $hsp_in, $dbseq, $alnseq, $row_data ) = @_;

    # Copy the psiblast hsp

    my $hsp = [ @$hsp_in ];

    # Fix the query information

    my $qid = $alnseq->[0];
    $hsp->[0] = $qid;    # This will get refined to a peg and a description added, later

    my ( undef, $qlen, $loc ) = @{ $row_data->{$qid} };
    $hsp->[2] = $qlen;

    my @packed = gjoseqlib::pack_alignment( ['q', '', $alnseq->[2]],
                                            ['s', '', $dbseq->[2]]
                                          );
    my ( $qseq, $sseq, $nmat, $nid, $ngap, $nr1b, $nr1e, $nr2b, $nr2e )
                        = interpret_abstracted_aa_align( map{$_->[2]} @packed );

    @$hsp[10..13] = ( $nmat, $nid, $nid, $ngap );
    my ( $q1, $q2 ) = find_q1_q2( $loc, $nr1b, $nr1e );
    @$hsp[15..17] = ( $q1, $q2, $qseq );

    my ( $s1, $s2 ) = @$hsp[18,19];
    $s1 += $nr2b;
    $s2 -= $nr2e;
    @$hsp[18..20] = ( $s1, $s2, $sseq );

    $hsp;
}


#
#  The input hsp is assembled from psiblast and the add_to_alignment data. We will
#  now convert the alignment row id to a peg id and give if a function and genome.
#
sub fix_hsp_query
{
    my ( $hsp, $row_data, $assigns, $gid_name ) = @_;

    my $qid = $hsp->[0];
    my $peg = $row_data->{$qid}->[0];

    my $func = $assigns->{$peg} || 'undefined function';
    my $gen  = $gid_name->{ SeedUtils::genome_of($peg) } || 'unknown genome';
    my $def  = "$func [$gen]";

    @$hsp[0,1] = ( $peg, $def );

    $hsp;
}


#-------------------------------------------------------------------------------
#  Interpret an alignment of two protein sequences that has been abstracted
#  from a multiple sequence alignment. This means that several properties that
#  are normally taken for granted might not be true. Not only do we remove
#  shared gaps, but terminal regions in which either or both sequences have
#  a gap. This changes the number of residues in the alignment, and hence the
#  sequence numbering of the residues that remain.
#
#     ( $seq1, $seq2, $nmat, $nid, $ngap, $nr1b, $nr1e, $nr2b, $nr2e )
#                              = interpret_abstracted_aa_align( $seq1, $seq2 )
#
#  $nmat = total aligned positons (= $nid + $ndif + $ngap)
#  $nid  = number of positions with identical amino acids (ignoring case)
#  $ngap = number of positions with gap in one sequence but not the other
#  $nr1b = number of residues removed from beg of seq1
#  $nr1e = number of residues removed from end of seq1
#  $nr2b = number of residues removed from beg of seq2
#  $nr2e = number of residues removed from end of seq2
#
#-------------------------------------------------------------------------------
sub interpret_abstracted_aa_align
{
    defined( $_[0] ) && defined( $_[1] ) or return ();

    #  Figure out the end trimming:

    my $m1 = my $s1 = uc shift;
    my $m2 = my $s2 = uc shift;
    my $m1 = $s1; $m1 =~ tr/-.~/\000/; $m1 =~ tr/\000/\377/c;
    my $m2 = $s2; $m2 =~ tr/-.~/\000/; $m2 =~ tr/\000/\377/c;
    $m1 &= $m2;    #  \000 for gap in either sequence
    $m1 =~ /^(\000*).*\377(\000*)$/ or return ();
    my $cdel_beg = length( $1 );
    my $cdel_end = length( $2 );

    my $nr1b = $cdel_beg ? ( substr( $s1, 0, $cdel_beg ) =~ tr/-.~//c ) : 0;
    my $nr2b = $cdel_beg ? ( substr( $s2, 0, $cdel_beg ) =~ tr/-.~//c ) : 0;
    my $nr1e = $cdel_end ? ( substr( $s1, -$cdel_end )   =~ tr/-.~//c ) : 0;
    my $nr2e = $cdel_end ? ( substr( $s2, -$cdel_end )   =~ tr/-.~//c ) : 0;

    my $len = length( $s1 ) - ( $cdel_beg + $cdel_end );
    $s1 = substr( $s1, $cdel_beg, $len );
    $s2 = substr( $s2, $cdel_beg, $len );

    #  Compute similarity of remaining alignment:

    my ( $nmat, $nid, undef, $ngap ) = gjoseqlib::interpret_aa_align( $s1, $s2 );

    ( $s1, $s2, $nmat, $nid, $ngap, $nr1b, $nr1e, $nr2b, $nr2e );
}


#
#  Alignment sequences come with a string defining the intervals abstracted from
#  the original protein sequence. The alignment of this on another sequence may
#  lead to additional trimming at the beginning and/or end of the protein. Our
#  challenge is to find the final aligned region.
#
sub find_q1_q2
{
    my ( $loc, $nr_beg, $nr_end ) = @_;

    my @range = map { [ /(\d+)-(\d+)$/ ] } split /,/, $loc;

    my $r_end;

    my $q1 = $range[0]->[0] + $nr_beg;
    $r_end = $range[0]->[1];
    while ( $q1 > $r_end && @range )
    {
        $q1 += $range[1]->[0] - $r_end - 1;
        shift @range;
        $r_end = $range[0]->[1];
    }

    my $q2 = $range[-1]->[1] - $nr_end;
    $r_end = $range[-1]->[0];
    while ( $q2 < $r_end && @range )
    {
        $q2 -= $r_end - $range[-1]->[1] - 1;
        pop @range;
        $r_end = $range[-1]->[0];
    }

    ( $q1, $q2 );
}


sub search_prot_with_alignment
{
    my ( $align, $db, $opts ) = @_;
    $opts ||= {};

    my $blast_opt = { evalue         =>  1e-5,
                      num_iterations =>  1,
                      num_threads    =>  $opts->{ num_threads } || 1
                    };

    $blast_opt->{ outForm } = $opts->{ as_fasta } ? 'hsp' : $opts->{ outForm } || 'hsp';

    my @db_hits = BlastInterface::psiblast( $align, $db, $blast_opt );

    if ( $opts->{ as_fasta } )
    {
        @db_hits = map { my ( $sid, $sdef, $slen, $s1, $s2, $sseq ) = @$_[3,4,5,18,19,20];
                         my $sloc = "$s1-$s2/$slen";
                         [ "$sid:$sloc", $sdef, gjoseqlib::pack_seq($sseq) ]
                       }
                  @db_hits;
    }

    wantarray ? @db_hits : \@db_hits;
}


1;

