package compare_coding;

use strict;
use gjoseqlib;
use gjoparseblast;         #  next_blast_subject()
use gjoalignment;          #  align_with_clustal
use gjocolorlib;
use Contigs;
use SeedAware;
use Data::Dumper;

require Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( scored_protein_starts
                  align_coding_for_compare
                  score_alignment
                  score_aligned_dna
                  score_aligned_initiators
                  propose_starts_from_scored_alignment
                  display_scored_dna
                );

#-------------------------------------------------------------------------------
#
#  @scored_pegs = scored_protein_starts( $contigs_file, $prot_seq,      $opts );
#  @scored_pegs = scored_protein_starts( $contigs_file, $prot_entry,    $opts );
#  @scored_pegs = scored_protein_starts( $contigs_file, \@prot_entries, $opts );
#
#     $scored_peg = [ $type, $location, $score, \%extra ]
#
#     $type     = 'peg'
#     $location = join( '_', $contig, $begin, $end )
#     $score    = log2 support score
#
#  \%details =
#     {
#         n_complete => bool,   # Starts with init?
#         n_delta    => int,    # Approx nt from high-scoring start to proposed n-term
#         c_complete => bool,   # Ends with term?
#         c_delta    => int,    # Approx nt from high-scoring end to proposed c-term
#         query      => qid,    # Query id
#         orig_id    => orig_id # Id of sequence in alignment
#         html       => \$html  # Ref to html page of compartive score data (optional)
#     }
#
#  Options:
#
#     alignment_dir  => dir_name           # Directory to write fasta alignments
#     scored_ali_dir => dir_name           # Directory to write scored alignments
#     html_dir       => dir_name           # Directory to write html alignment pages
#     max_exp        => e_value            # Max contig match e-value for inclusion
#     max_expect     => e_value            # Max contig match e-value for inclusion
#     max_score_drop => fraction           # Largest drop in blast score for 2nd match in contig or genome
#     max_term       => int                # Maximum terminators in match to include
#     max_termin     => int                # Maximum terminators in match to include
#     min_id         => fraction_identity  # Identity required to include contig match
#     min_ident      => fraction_identity  # Identity required to include contig match
#     return_align   => boolean            # Include reference to a scored alignment
#     return_html    => boolean            # Include reference to an html alignment
#     verbose        => boolean            # Print some progress info to STDERR
#
#  Options passed to called functions:
#
#     blastall => blastall_executable   # D = blastall
#     formatdb => formatdb_executable   # D = formatdb
#     init_scr => { codon => score, ... }
#     pad      => n_triplets            # padding at both ends
#     pad3     => n_triplets            # padding at 3' end, D = 10
#     pad5     => n_triplets            # padding at 5' end, D = 15
#     tmp      => temporary_directory   # D = SeedAware::location_of_tmp()
#
#-------------------------------------------------------------------------------

sub scored_protein_starts
{
    my ( $contigs_file, $protein, $opts ) = @_;

    $opts ||= {};
    ref $opts eq 'HASH'
        or print STDERR "scored_protein_starts called with bad options hash.\n"
        and return ();

    my $min_id = defined $opts->{ min_ident } ? $opts->{ min_ident }
               : defined $opts->{ min_id    } ? $opts->{ min_id    }
               : 0.5;
    $opts->{ min_ident } = $min_id;

    my $max_expect = defined $opts->{ max_expect } ? $opts->{ max_expect }
                   : defined $opts->{ max_exp    } ? $opts->{ max_exp    }
                   : 1e-5;
    $opts->{ max_expect } = $max_expect;

    #  Retain multiple matches if better than:
    my $max_scr_drop = $opts->{ max_score_drop } ||= 0.9;

    my $max_term = defined $opts->{ max_termin } ? $opts->{ max_termin }
                 : defined $opts->{ max_term   } ? $opts->{ max_term   }
                 : 3;
    $opts->{ max_termin } = $max_term;

    $opts->{ verbose } = 0 if ! defined $opts->{ verbose };
    my $verbose = $opts->{ verbose };

    #  Process basic options

    -f $contigs_file
          or print STDERR "Contigs file '$contigs_file' not found.\n"
          and exit;

    my $alignment_dir = $opts->{ alignment_dir } ||= '';
    if ( $alignment_dir )
    {
        mkdir $alignment_dir if ( ! -d $alignment_dir );
        -d $alignment_dir
             or print STDERR "Alignments directory '$alignment_dir' not created.\n"
             and exit;
    }

    my $scored_ali_dir = $opts->{ scored_ali_dir } ||= '';
    if ( $scored_ali_dir )
    {
        mkdir $scored_ali_dir if ( ! -d $scored_ali_dir );
        -d $scored_ali_dir
             or print STDERR "Scored alignments directory '$scored_ali_dir' not created.\n"
             and exit;
    }

    my $html_dir = $opts->{ html_dir } ||= '';
    if ( $html_dir )
    {
        mkdir $html_dir if ( ! -d $html_dir );
        -d $html_dir
             or print STDERR "HTML directory '$html_dir' not created.\n"
             and exit;
    }

    if ( ! $protein )
    {
        print STDERR "scored_protein_starts called without a protein.\n";
        return ();
    }
    elsif ( ! ref $protein )
    {
        #  Take a scalar as a bare sequence
        $protein = [ 'scored_peg_query', '', $protein ];
    }
    elsif ( ref $protein ne 'ARRAY' )
    {
        print STDERR "scored_protein_starts called with a bad protein entry format.\n";
        return ();
    }
    elsif ( ! @$protein )
    {
        print STDERR "scored_protein_starts called with an empty protein list.\n";
        return ();
    }

    my $tmp    = SeedAware::location_of_tmp( $opts );  #  Place for temporary files
    my $q_file = SeedAware::new_file_name( "$tmp/protein_starts", 'query' );
    gjoseqlib::print_alignment_as_fasta( $q_file, $protein );

    my $blastall = SeedAware::exectuable_for( $opts->{blastall} || 'blastall' );
    my @cmd = ( $blastall,
                -p => 'tblastn',
                -d => $contigs_file,
                -i => $q_file,
                -F => 'f',
                -e => $max_expect,
                -a => 2
              );

    my $redirect = { stderr => '/dev/null' };
    my $blastFH = SeedAware::read_from_pipe_with_redirect( @cmd, $redirect )
        or print STDERR "Could not open pipe from blast command:\n", join( ' ', @cmd ), "\n"
            and exit;

    my $contigs = Contigs->new( $contigs_file );
    my $query_result;
    my @results;
    my @needs;

    while ( $query_result = gjoparseblast::next_blast_query( $blastFH ) )
    {
        my ( $qid, $qdef, $qlen, $query_hits ) = @$query_result;
        print STDERR "Analyzing $qid\n" if $verbose;
        my $subj_result;
        my @seqs;  #  List of matches
        my %scrs;  #  Best match by genome or contig
        foreach $subj_result ( @$query_hits )
        {
            my ( $sid, $hsps ) = @$subj_result[ 0, 3 ];
            next if ! $hsps || ! @$hsps;
            #
            # hsp_data:
            #    0    1    2    3     4     5    6     7     8   9   10   11   12  13   14
            # [ scr, exp, p_n, pval, nmat, nid, nsim, ngap, dir, q1, q2, qseq, s1, s2, sseq ]
            #
            #  Sort by leftmost overlap in query, then highest score
            #
            my ( $gen_id ) = $sid =~ /^([^:]+)/;
            my ( $scr, $qseq, $s1, $s2, $sseq ) = ( @{$hsps->[0]} )[0,11,12,13,14];
            $scrs{ $gen_id } = $scr if ! $scrs{ $gen_id };
            next if $scr < $max_scr_drop * $scrs{ $gen_id };  #  Within 90% of best score in genome or contig?
            my $frac_id = fraction_identity( $qseq, $sseq );
            next if $frac_id < $min_id;
            my $nterm = number_of_terminators( $sseq );
            next if ( $nterm > $max_term );
            my $loc = join( '_', $sid, $s1, $s2 );
            # printf STDERR "    %.3f indentity to %s\n", $frac_id, $loc;
            $sseq =~ s/-+//g;              #  No gaps
            push @seqs, [ $loc, "best match of $qid in $gen_id", $sseq ];
        }

        print STDERR "    @{[scalar @seqs]} similar sequences found.\n" if $verbose;

        if ( @seqs > 1 )
        {
            my %locs = map { $_->[0] => $_->[0] } @seqs;
            $opts->{ alignment_file } = "$alignment_dir/$qid.fasta_ali" if $alignment_dir;
            my ( $align, $locs ) = align_coding_for_compare( $contigs, \@seqs, \%locs, $opts );

            $opts->{ scored_ali_file } = "$scored_ali_dir/$qid.scr_ali" if $scored_ali_dir;
            $opts->{ html_file } = "$html_dir/$qid.html" if $html_dir;
            my ( $scores, $init_scrs ) = score_alignment( $align, $locs, $opts );

            my %labels = ( query => $qid );
            $labels{ html } = $opts->{ html } if $opts->{ html };
            $labels{ alignment } = [ $align, $scores, $init_scrs ] if $opts->{ return_align };
            push @results, propose_starts_from_scored_alignment( $contigs, $align, $scores, $init_scrs, $opts, \%labels );
        }
    }

    close( $blastFH );
    unlink $q_file;
                           
    wantarray ? @results : \@results;
}


sub score_alignment
{
    my ( $align, $locs, $opts ) = @_;

    $opts ||= {};
    my $ali_file  = $opts->{ scored_ali_file } ||= '';
    my $html      = $opts->{ return_html }     ||= '';
    my $html_file = $opts->{ html_file }       ||= '';

    my $scores = score_aligned_dna( $align );
    # print STDERR Dumper( $align, $scores, $locs );

    my $init_scrs = score_aligned_initiators( $align );
    # print STDERR Dumper( $init_scrs );

    if ( $html || $html_file )
    {
        my $page = join( "\n", display_scored_dna( $align, $locs, $scores, $init_scrs, $opts ), '' );
        $opts->{ html } = \$page if $html;  # Pass back page to caller

        if ( $html_file )
        {
            open HTML, ">$html_file"
                 or print STDERR "Unable to open file for writing HTML: $html_file\n"
                    and exit;
            print HTML $page;
            close HTML;
        }
    }

    if ( $ali_file )
    {
        open ALI, ">$ali_file"
             or print STDERR "Unable to open file for writing alignment: $ali_file\n"
                  and exit;
        foreach (@$align) { print ALI join("\t",@$_),"\n" }
        print ALI join("\t",map { sprintf("%.3f",$_) } @$scores),"\n";
        print ALI join("\t",map { sprintf("%.3f",$_) } @$init_scrs),"\n";
        close ALI;
    }

    return ( $scores, $init_scrs );
}


sub propose_starts_from_scored_alignment
{
    my ( $contigs, $align, $scores, $init_scrs, $opts, $labels ) = @_;
    $opts   ||= {};
    $labels ||= {};

    my @starts = propose_peg_starts( $contigs, $align, $scores, $init_scrs, $opts );
    foreach ( @starts )
    {
        $_->[2] = sprintf( '%.3f', $_->[2] );       #  Scores to fixed digits
        foreach my $key ( keys %$labels ) { $_->[3]->{ $key } = $labels->{ $key } }
    }

    wantarray ? @starts : \@starts;
}


#   @column_scores = score_aligned_dna(  @dna_align );
#   @column_scores = score_aligned_dna( \@dna_align );
#  \@column_scores = score_aligned_dna(  @dna_align );
#  \@column_scores = score_aligned_dna( \@dna_align );
#
#   $score = score_aligned_codons(  @codons )
#   $score = score_aligned_codons( \@codons )
#
#   $html_table = display_scored_dna( $align, $locs, $scores, $init_scrs, $opts )
#   $html_table = display_scored_dna( $align, $locs, $scores )

#
#  We want to align and highlight the DNA sequences in the vicinity of a start site.
#  
#  Given set of (usually closely) related proteins (@fids).
#      Blast one against the others to find longest on left.
#      Blast longest against the others to fine tune length difference.
#      Extend all to the longest plus 10 codons, using extra sequence from contigs.
#      Align proteins and contert to DNA (or align DNA).
#      Display aligned DNA (or protein), 
#         Ribosome binding sites
#         Start codons
#         Stop codons
#         Synonymous changes
#         Nonsynonymous changes
#
#
#  ( $align, $locs ) = align_coding_for_compare( $contigs, $prots, $locs, $opts )
#
#     $prots = [ [ id, def, seq ], [ id, def, seq ], ... ]
#     $locs  = { id => loc, id => loc , ... }
#
#  opts:
#
#     blastall => blastall_executable   # D = blastall
#     formatdb => formatdb_executable   # D = formatdb
#     pad      => n_triplets            # padding at both ends
#     pad3     => n_triplets            # padding at 3' end, D = 10
#     pad5     => n_triplets            # padding at 5' end, D = 15
#     tmp      => temporary_directory   # D is from SeedAware::location_of_tmp()
#

sub align_coding_for_compare
{
        my ( $contigs, $prots, $locs, $opts ) = @_;
        ref $prots eq 'ARRAY'
            or print STDERR "align_coding_for_compare called with bad first argument.\n"
            and return undef;

        $opts ||= {};
        ref $opts eq 'HASH'
            or print STDERR "align_coding_for_compare called with bad options hash.\n"
            and return undef;

        @$prots > 1
            or print STDERR "align_coding_for_compare requires more than one translatable sequence.\n"
            and return undef;

        my ( $padded_prots, $padded_locs, $padded_dna ) = pad_protein_starts( $contigs, $prots, $locs, $opts );

        my @prot_align = gjoalignment::align_with_clustal( $padded_prots );

        my @dna_align = map { my $id = $_->[0];
                              [ $id,
                                $padded_locs->{ $id },
                                expand_nt_by_aa( $_->[-1], $padded_dna->{ $id }->[-1] )
                              ]
                            }
                        @prot_align;

        my $ali_file = $opts->{ alignment_file };
        gjoseqlib::print_alignment_as_fasta( $ali_file, \@dna_align ) if $ali_file;

        ( \@dna_align, $padded_locs )
}


#
#  Take a set of proteins and adjust the starts to be approximately the same,
#  padding with sequence drived from contigs.
#
#    \@new_prots                          = pad_protein_starts( $contigs, $prots, $locs, $opts )
#  ( \@new_prots, \%new_locs, \%new_dna ) = pad_protein_starts( $contigs, $prots, $locs, $opts )
#

sub pad_protein_starts
{
    my ( $contigs, $prots, $locs, $opts ) = @_;
    ref $prots eq 'ARRAY'
        or print STDERR "pad_protein_starts called with bad proteins list.\n"
        and return undef;

    ref $locs eq 'HASH'
        or print STDERR "pad_protein_starts called with bad locations argument.\n"
        and return undef;

    $opts ||= {};
    ref $opts eq 'HASH'
        or print STDERR "pad_protein_starts called with bad second argument.\n"
        and return undef;

    #  Set default 5' and 3' end padding (in triplets):

    my $pad  = $opts->{ pad };
    $opts->{ pad5 } = ( defined $pad ? $pad : 15 ) if ! defined $opts->{ pad5 };
    my $pad5 = $opts->{ pad5 };
    $opts->{ pad3 } = ( defined $pad ? $pad : 10 ) if ! defined $opts->{ pad3 };
    my $pad3 = $opts->{ pad3 };

    @$prots > 1
        or print STDERR "pad_protein_starts requires more than one translatable sequence.\n"
        and return undef;

    my @prots = sort { length $b->[-1] <=> length $a->[-1] }    #  Long to short
                @$prots;

    #  Index the proteins

    my %prots = map { $_->[0] => $_ } @prots;
    my @ids   = map { $_->[0] } @prots;

    my $prot_db = make_prot_db( \@prots, $opts );
    $prot_db
        or print STDERR "pad_protein_starts could not create blast database.\n"
            and return undef;

    my @needs = sort { $a->[1] <=> $b->[1] }   # Sort needs least to most
                find_relative_starts( $prots[0], $prot_db );
    @needs
        or print STDERR "pad_protein_starts could not run blastp.\n"
        and return undef;

    #  If any sequence needs < 0, then it is not longest on left end.
    #  Repeat the blast with query that extended most to left.

    if ( $needs[0]->[1] < 0 )
    {
        @needs = find_relative_starts( $prots{$needs[0]->[0]} , $prot_db, $opts );
        @needs
            or print STDERR "pad_protein_starts could not run blastp.\n"
            and return undef;

    }

    unlink( map { "$prot_db$_" } '', qw( .phd .pin .psq ) );

    my @new_prot;
    my %new_loc;
    my %new_dna;
    my ( $med_need ) = (sort { $a <=> $b } map { $_->[1] } @needs)[int(@needs/2)];
    foreach ( @needs )
    {
        my ( $id, $need ) = @$_;
        next if ( $need > ( $med_need + 20 ) );    #  Very big adjustment
        my $delta_beg = 3 * ( $need + $pad5 );
        my $delta_end = 3 * $pad3;
        my $new_loc = adjust_location( $contigs, $locs->{$id}, $delta_beg, $delta_end, 1 );
        my $new_dna = join( '', map { $contigs->subseq( /^(.+)_(\d+)_(\d+)$/ ) }
                                split /,/, $new_loc
                          );
        my $new_prot = gjoseqlib::translate_seq( $new_dna );
        # $new_prot =~ s/\*$//;
        push @new_prot, [ $id, $new_prot ];
        $new_dna{ $id } = [ $id, "padded with $delta_beg nucleotides", $new_dna ];
        $new_loc{ $id } = $new_loc;
    }

    wantarray ? ( \@new_prot, \%new_loc, \%new_dna ) : \@new_prot;
}


#  $db_file = make_prot_db( \@seqs, \%opts );

sub make_prot_db
{
    my ( $seqs, $opts ) = @_;
    ref $opts eq 'HASH' or $opts = {};

    my $tmp  = SeedAware::location_of_tmp( $opts );
    my $file = SeedAware::new_file_name( "$tmp/compare_coding" );
    gjoseqlib::print_alignment_as_fasta( $file, $seqs );

    my $formatdb = SeedAware::exectuable_for( $opts->{formatdb} || 'formatdb' );
    system( $formatdb, -i => $file, -p => 't' );

    return $file;
}

#
#
#   @id_end_offset_pairs = find_relative_starts( \@prots, $db_file )
#   $id_end_offset_pairs = find_relative_starts( \@prots, $db_file )
#
#   @prots = ( [ id, seq ], [ id, seq ], ... )
#         or ( [ id, def, seq ], [ id, def, seq ], ... )

sub find_relative_starts
{
    my ( $prot, $db, $opts ) = @_;
    ref $opts eq 'HASH' or $opts = {};

    my $tmp    = SeedAware::location_of_tmp( $opts );  #  Place for temporary files
    my $q_file = SeedAware::new_file_name( "$tmp/find_relative_starts", 'query' );
    gjoseqlib::print_alignment_as_fasta( $q_file, $prot );

    my $results;
    my @needs;

    my $blastall = SeedAware::exectuable_for( $opts->{blastall} || 'blastall' );
    my @cmd = ( $blastall,
                -p => 'blastp',
                -d => $db,
                -i => $q_file,
                -e => 0.01,
                -F => 'f',
                -a => 2
              );

    my $redirect = { stderr => '/dev/null' };
    my $blastFH = SeedAware::read_from_pipe_with_redirect( @cmd, $redirect )
        or print STDERR "Could not open pipe from blast command:\n", join( ' ', @cmd ), "\n"
            and exit;

    while ( $results = gjoparseblast::next_blast_subject( $blastFH, 1 ) )
    {
        my ( $sid, $hsps ) = @$results[ 3, 6 ];
        #
        # hsp_data:
        #    0    1    2    3     4     5    6     7     8   9   10   11   12  13   14
        # [ scr, exp, p_n, pval, nmat, nid, nsim, ngap, dir, q1, q2, qseq, s1, s2, sseq ]
        #
        #  Sort by leftmost overlap in query, then highest score
        #
        my ( $needs ) = map  { $_->[9] - $_->[12] }
                        sort { $a->[9] <=> $b->[9] || $b->[0] <=> $a->[0] }
                        @$hsps;
        push @needs, [ $sid, $needs ];
    }

    close( $blastFH );
    unlink $q_file;

    wantarray ? @needs : \@needs;
}


#
#  Add or remove nucleotides from the beginning and/or end of a location.
#
#     $loc = adjust_location( $contigs, $loc, $delta_beg, $delta_end, $frame )
#
#     positive deltas increase length; negative deltas decrease length
#     When $frame is true, frame will be presereved.
#
#  $contigs is an object the includes the function $contigs->length( $contig )
#

sub adjust_location
{
    my ( $contigs, $loc, $delta_beg, $delta_end, $frame ) = @_;
    my @loc = map { my ( $c, $b, $e ) = /^(.+)_(\d+)_(\d+)$/;
                    [ $c, $b, $e, $e <=> $b, abs($e-$b)+1 ]  # c, b, e, dir, len
                  }
              split /,/, $loc;

    if ( $delta_beg )
    {
        #  Fix frame if necessary
        if ( $frame )
        {
            if ( $delta_beg > 0 ) { $delta_beg -=   $delta_beg  % 3 }
            else                  { $delta_beg += (-$delta_beg) % 3 }
        }

        #  Does shortening remove a whole segment?
        while ( @loc && ( $loc[0]->[4] + $delta_beg <= 0 ) )
        {
            $delta_beg += $loc[0]->[4];
            shift @loc;
        }
        return undef if ! @loc;

        #  Does addition run off the contig?
        if ( $delta_beg > 0 )
        {
            if ( $loc[0]->[3] > 0 )
            {
                if ( $delta_beg >= $loc[0]->[1] )
                {
                    $delta_beg  = $loc[0]->[1] - 1;
                    $delta_beg -= $delta_beg%3 if $frame;
                }
            }
            else
            {
                my $c_len = $contigs->length( $loc[0]->[0] );
                if ( $loc[0]->[1] + $delta_beg > $c_len )
                {
                    $delta_beg  = $c_len - $loc[0]->[1];
                    $delta_beg -= $delta_beg%3 if $frame;
                }
            }
        }
        $loc[0]->[1] -= $delta_beg * $loc[0]->[3];
    }

    if ( $delta_end )
    {
        #  Does it remove whole segment?
        while ( @loc && ( $loc[-1]->[4] + $delta_end <= 0 ) )
        {
            $delta_end += $loc[-1]->[4];
            pop @loc;
        }
        return undef if ! @loc;

        if ( $delta_end > 0 )
        {
            if ( $loc[-1]->[3] > 0 )
            {
                my $c_len = $contigs->length( $loc[-1]->[0] );
                $delta_end = $c_len - $loc[-1]->[2] if ( $loc[-1]->[2] + $delta_end > $c_len );
            }
            else
            {
                $delta_end = $loc[-1]->[2] - 1 if ( $delta_end >= $loc[-1]->[2] );
            }
            $delta_end -= $delta_end%3 if $frame;
        }

        $loc[-1]->[2] += $delta_end * $loc[0]->[3];
    }

    join ',', map { join '_', @$_[0..2] } @loc;
}


sub upstream_location
{
    my ( $contigs, $loc, $length, $frame ) = @_;

    $loc =~ s/,.+$//;
    my ( $c, $b, $e ) = $loc =~ /^(.+)_(\d+)_(\d+)$/;
    if ( $e > $b )
    {
        $length  = $b - 1 if ( $length >= $b );
        $length -= $length%3 if $frame;
        return undef if $length < 1;
        $e  = $b - 1;
        $b -= $length;
    }
    else
    {
        my $c_len = $contigs->length( $c );
        $length  = $c_len - $b if ( $b + $length > $c_len );
        $length -= $length%3 if $frame;
        return undef if $length < 1;
        $e  = $b + 1;
        $b += $length;
    }

    join '_', $c, $b, $e;
}


sub downstream_location
{
    my ( $contigs, $loc, $length ) = @_;

    $loc =~ s/^.+,//;
    my ( $c, $b, $e ) = $loc =~ /^(.+)_(\d+)_(\d+)$/;
    if ( $e > $b )
    {
        $b = $e + 1;
        my $c_len = $contigs->length( $c );
        return undef if ( $b > $c_len );
        $e += $length;
        $e  = $c_len if ( $e > $c_len );
    }
    else
    {
        $b = $e - 1;
        return undef if ( $b < 1 );
        $e -= $length;
        $e  = 1 if ( $e < 1 );
    }

    join '_', $c, $b, $e;
}


#   $length = location_length( $location )

sub location_length
{
    $_[0] or return undef;
    my $len = 0;
    foreach ( split /,/, $_[0] )
    {
        /^.+_(\d+)_(\d+)$/ or return undef;
        $len += abs( $2 - $1 ) + 1;
    }
    return $len;
}


#  Take a protein sequence with alignment gaps and expand corresponding
#  DNA to match.  Assumes that there are no gaps in the DNA to start!

sub expand_nt_by_aa
{
    my ( $prot, $dna ) = @_;

    return undef if ! same_length( $prot, $dna );
    my @dna = $dna =~ m/.../g;
    my $i = 0;
    join '', map { $_ eq '-' ? '---' : $dna[$i++] } split //, $prot;
}


sub same_length
{
    my ( $prot, $dna ) = @_;
    $prot =~ s/-+//g;
    return 1 if ( length( $dna ) == 3 * length( $prot ) );

    print STDERR "Bad alignment:\n";
    print STDERR "Protein length = @{[length $prot]}, DNA length = @{[length $dna]}\n";
    print STDERR join( '', map { " $_ " } split //, $prot ), "\n";
    print STDERR "$dna\n";
    return 0;
}


#===============================================================================
#  Functions for scoring and displaying the aligned codons
#===============================================================================
#
#  Chances of changing a codon or not with random changes
#  -----------------------------
#    nt     same    diff    n
#   diff     aa      aa    pair
#  ----------------------------
#     1    0.255   0.745    526
#     2    0.018   0.982   1568
#     3    0.008   0.992   1566
#  ----------------------------
#
#  Alternative, not used
#  -------------------------------------
#    nt     same    pos              n
#   diff     aa    score   other   pair
#  -------------------------------------
#     1    0.255   0.202   0.544    526
#     2    0.018   0.145   0.837   1568
#     3    0.008   0.026   0.967   1566
#  -------------------------------------

# my @p_same_code = ( 0.999, 0.500, 0.350, 0.200 );  #  Totally made up
my @p_same_code = ( 0.999, 0.500, 0.200, 0.100 );  #  Totally made up
my @p_same_rand = ( 0.999, 0.255, 0.018, 0.008 );  #  From table above
my $p_term_code = 1 / 200;
my $p_term_rand = 3 /  64;

my @same_scr;
my @diff_scr;
my $log2 = log( 2 );
for ( my $nd = 1; $nd <= 3; $nd++ )
{
    my $p_same_code = $p_same_code[ $nd ];
    my $p_diff_code = 1 - $p_same_code;
    my $p_same_rand = $p_same_rand[ $nd ];
    my $p_diff_rand = 1 - $p_same_rand;
    $same_scr[ $nd ] = log( $p_same_code / $p_same_rand ) / $log2;
    $diff_scr[ $nd ] = log( $p_diff_code / $p_diff_rand ) / $log2;
}

my $term_scr = log( $p_term_code / $p_term_rand ) / $log2;
my $extn_scr = 0.04;

my @nuc = qw( A C G T );

my @triplets = map { my $s2 = $_; map { $s2 . $_ } @nuc }
               map { my $s1 = $_; map { $s1 . $_ } @nuc }
               @nuc;

my %aa = map { $_ => translate_codon( $_ ) } @triplets;

my @coding = grep { $aa{ $_ } ne '*' } @triplets;


#-------------------------------------------------------------------------------
#   @column_scores = score_aligned_dna(  @dna_align );
#   @column_scores = score_aligned_dna( \@dna_align );
#  \@column_scores = score_aligned_dna(  @dna_align );
#  \@column_scores = score_aligned_dna( \@dna_align );
#-------------------------------------------------------------------------------

sub score_aligned_dna
{
    my @scores;
    ref $_[0] or return wantarray ? @scores : \@scores;
    my @entries = ( ref $_[0]->[0] eq 'ARRAY' ) ? @{ $_[0] } : @_;
    my @triples = map { [ $_->[-1] =~ m/.../g ] } @entries;
    my $nmax = @{ $triples[0] };
    for ( my $n = 0; $n < $nmax; $n++ )
    {
        push @scores, score_aligned_codons( map { $_->[ $n ] } @triples )
    }

    wantarray ? @scores : \@scores
}


#-------------------------------------------------------------------------------
#  $score = score_aligned_codons(  @codons )
#  $score = score_aligned_codons( \@codons )
#
#  2009-04-10 -- Filter out terminator codons, and score for all remaining.
#-------------------------------------------------------------------------------

sub score_aligned_codons
{
    my $t;
    my %triplets = map { ( $t = uc ) =~ tr/U/T/;
                         $t =~ /^[ACGT][ACGT][ACGT]$/ ? ( $t => 1 ): ()
                       }
                   ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_;

    my @triplets = grep { $aa{ $_ } ne '*'  } keys %triplets;
    if ( @triplets < 2 ) { return $extn_scr }

    #  Score with each triplet as reference, and then average:

    my $score = 0;
    my $ntriples = @triplets;
    my ( $t1, $t2 );
    while ( $t1 = shift @triplets )
    {
        foreach $t2 ( @triplets ) { $score += score_2_codons( $t1, $t2 ) }
    }
    $score *= 2 / $ntriples;

    return $score;
}


# sub score_2_codons
# {
#     my ( $t1, $t2 ) = @_;
#     my $aa1 = $aa{ $t1 };
#     return $term_scr  if ( $aa1 eq '*' );
#     my $aa2 = $aa{ $t2 };
#     return ( $aa2 eq '*' )  ? $term_scr
#          : ( $aa1 eq $aa2 ) ? $same_scr[ ndiff( $t1, $t2 ) ]
#          :                    $diff_scr[ ndiff( $t1, $t2 ) ];
# }

#  There are now no terminators:

sub score_2_codons
{
    my ( $t1, $t2 ) = @_;
    my $ndiff = ndiff( $t1, $t2 );
    return ( $aa{ $t1 } eq $aa{ $t2 } ) ? $same_scr[ $ndiff ]
                                        : $diff_scr[ $ndiff ];
}


sub ndiff { local $_ = $_[0] ^ $_[1]; tr/\0//c }


#-------------------------------------------------------------------------------
#   @column_scores = score_aligned_initiators( \@dna_align, \%opts );
#  \@column_scores = score_aligned_initiators( \@dna_align, \%opts );
#-------------------------------------------------------------------------------

sub score_aligned_initiators
{
    my ( $align, $opts ) = @_;

    $opts ||= {};

    #  Initiator codon scores:

    if ( ! $opts->{ init_scr } )
    {
        my %init_scr = map { @$_, lc $_->[0] => $_->[1] }
                       ( [ 'ATG', 5 ], [ 'GTG', 4 ], [ 'TTG', 2 ],
                         [ 'AUG', 5 ], [ 'GUG', 4 ], [ 'UUG', 2 ]
                       );
        $opts->{ init_scr } = \%init_scr;
    }
    my $init_scr = $opts->{ init_scr };

    my @scores;
    my @triples = map { [ $_->[-1] =~ m/.../g ] } @$align;
    my $nmax = @{ $triples[0] };

    my @seq_init_scr = map { &per_seq_init_scr( $_, $init_scr ) } @triples;

    for ( my $n = 0; $n < $nmax; $n++ )
    {
        push @scores, &avg( map { $_->[ $n ] } @seq_init_scr )
    }

    wantarray ? @scores : \@scores
}


sub avg
{
    my $tot = 0;
    foreach $_ ( @_ ) { $tot += $_ }
    return ( @_ > 0 ) ? ( $tot / @_ ) : undef;
}


sub per_seq_init_scr
{
    my ( $triples, $init_scr ) = @_;

    my @s0   = map { $_ = uc $_; s/U/T/g; $init_scr->{ $_ } || 0} @$triples;
    my $last = 0;
    my @s1   = map { $last *= 0.8; $last = ($_ > $last) ? $_ : $last } @s0;
    $last    = 0;
    my @s2   = reverse map { $last *= 0.8; $last = ($_ > $last) ? $_ : $last } reverse @s1;
    return \@s2;
}


#===============================================================================
#
#  @proposals = propose_peg_starts( $contigs, $aligned, \@scores, \@init_scores, \%opts )
#
#===============================================================================
sub propose_peg_starts
{
    my ( $contigs, $aligned, $scores, $init_scores, $opts ) = @_;
    $opts ||= {};
    $opts->{ warn }  =  0 if ! defined $opts->{ warn };
    $opts->{ decay } = 25 if ! defined $opts->{ decay };
    $opts->{ min_scr } = 0 if ! defined $opts->{ min_scr };

    my $warn     = $opts->{ warn };      #  Warn if no start found
    my $decay    = $opts->{ decay };     #  Report alternatives with 25 of max
    my $pattern  = $opts->{ filter };    #  Filter by regexp
    my $c_filter = $opts->{ contigs };   #  Filter by contig
    my $min_scr  = $opts->{ min_scr };   #  Keep only those with at least this score

    #  Initiator codon scores:

    if ( ! $opts->{ init_scr } )
    {
        my %init_scr = map { @$_, lc $_->[0] => $_->[1] }
                       ( [ 'ATG', 5 ], [ 'GTG', 4 ], [ 'TTG', 2 ],
                         [ 'AUG', 5 ], [ 'GUG', 4 ], [ 'UUG', 2 ]
                       );
        $opts->{ init_scr } = \%init_scr;
    }
    my $init_scr = $opts->{ init_scr };

    #  Terminator codons:

    if ( ! $opts->{ is_term } )
    {
        my %is_term = map { $_ => 1 }
                      map { ( $_, lc $_ ) }
                      qw( TAA TAG TGA UAA UAG UGA );
        $opts->{ is_term } = \%is_term;
    }
    my $is_term = $opts->{ is_term };

    my @results;
    my ( $max_scr, $i1, $i2 ) = high_scoring_region( $scores );
    foreach ( @$aligned )
    {
        my ( $id, $loc, $dna ) = @$_;
        my ( $c, $beg, $end ) = $loc =~ /^(.+)_(\d+)_(\d+)$/;
        next if $pattern  && $c !~ $pattern;
        next if $c_filter && ! $c_filter->{ $c };
        my @proposals = propose_peg_starts_2( $contigs, $c, $beg, $end, $dna, $i1, $i2, $scores, $init_scores, $init_scr, $is_term );

        if ( ! @proposals )
        {
            print STDERR "Warning: no proposed start sites for '$id'.\n" if $warn;
            next;
        }
        # print STDERR Dumper( @proposals );
        my ( $high_score ) = sort { $b <=> $a } map { $_->[3] } @proposals;
        my $min_scr2 = &max($min_scr,$high_score - $decay);
        foreach ( reverse @proposals )
        {
            my ( $c, $b, $e, $s, $details ) = @$_;
            next if ($s < $min_scr2);
            my $loc = join( '_', $c, $b, $e );
	    $details->{ orig_id } = $id;
            push @results, [ 'peg', $loc, $s, $details ];
            # printf "%s\t%s\t%s\t%.2f\n", 'peg', $loc, $loc, $s;
        }
    }

    @results;
}


sub max { $_[0] > $_[1] ? $_[0] : $_[1] }


#  Returns [ $contig, $beg, $end, $score, \%details ]
#
#  Details:
#
#     n_complete => bool  # Starts with init?
#     c_complete => bool  # Ends with term?
#     n_delta    => int   # Approx nt from high-scoring start to proposed n-term
#     c_delta    => int   # Approx nt from high-scoring end to proposed c-term


sub propose_peg_starts_2
{
    my ( $contigs, $c, $beg, $end, $dna, $i1, $i2, $scores, $init_scores, $init_scr, $is_term ) = @_;
    #  $beg and $end are the contig coordinates of my aligned DNA.
    my $dir = ( $end <=> $beg );
    my @triplets = $dna =~ m/.../g;

    #  Start at midpoint of high-scoring region, and work to terminus.
    #  $i are left set at last nonterminator codon.
    #  $orf_beg is left on terminator codon or off the end.
    #  Does not handle in-frame terminators; we should check

    my $orf_beg = undef;
    my $orf_end = undef;
    my $n_complete;   # Starts with init?
    my $c_complete;   # Ends with term?
    my $n_delta;  # Distance from high-scoring start to proposed n-term
    my $c_delta;  # Distance from high-scoring end to proposed c-term
    my $i = int( 0.5 * ( $i1 + $i2 ) );  # $i is index into triplets array
    my $done = 0;
    while ( ! $done )
    {
        #  If out of triplets, try to extend:
        if ( $i >= @triplets )
        {
            #  Ask for 300 more nt:
            my $newdna = $contigs->subseq( $c, $end+$dir, $end+(300*$dir) );
            my $extra = 3 * int( length( $newdna ) / 3 );
            $newdna = substr( $newdna, 0, $extra ) if $extra != length( $newdna );
            $end = $end + $extra*$dir;
            push @triplets, $newdna =~ m/.../g if length($newdna) >= 2; 
        }

        if ( $i < @triplets )
        {
            if ( $is_term->{ $triplets[$i] } )
            {
                #  Find actual nt number.  Count unused nt.
                my $unused = $i+1 < @triplets ? join( '', @triplets[$i+1 .. @triplets-1] )
                                              : '';
                my $n_unused = $unused =~ tr/-//c;  #  nongap chars
                $orf_end = $end - $n_unused*$dir;
                $orf_beg = $orf_end - 2*$dir;
                $i--;                         #  Move $i back to non-terminator
                $c_complete = 1;              #  Ends with terminator
                $c_delta = 3 * ( $i - $i2 );  #  ~ c_delta nt past high-score
                $done = 1;
            }
            else
            {
                $i++;
            }
        }
        else
        {
            $i--;                         #  Point at last valid triplet
            $orf_end = $end;
            $orf_beg = $orf_end + $dir;   #  Off the end
            $c_complete = 0;              #  Ends without terminator
            $c_delta = 3 * ( $i - $i2 );  #  Includes c_delta nt past high-score
            $done = 1;
        }
    }

    #  Start at end and work back proposing start sites and scores:

    $done = 0;
    my $scr  = 0;
    my @proposals;
    my %used;
    while ( ! $done )
    {
        if ( $i < 0 )
        {
            #  This might be a problem, but allows running off a contig:
            if ( ! $used{ $orf_beg } )  # If initiator, it's already recorded
            {
                push @proposals, [ $c, $orf_beg, $orf_end, $scr,
                                   { n_complete => 0,
                                     c_complete => $c_complete,
                                     n_delta    => 3 * ( $i1 - $i + 1 ),  # approx
                                     c_delta    => $c_delta
                                   }
                                 ];
            }
            $done = 1;
            last;
        }

        my $trip = $triplets[ $i ];
        if ( $trip eq '---' )
        {
            $scr += $scores->[ $i ];
            $i--;
        }
        elsif ( $init_scr->{ $trip } )
        {
            $orf_beg -= 3*$dir;

            my $i_score = $scr + $init_scr->{ $trip };

            if (($i >= 0) && ($i < @$init_scores))
            {
                $i_score += $init_scores->[$i];
                $scr += $scores->[ $i ];
            }
            push @proposals, [ $c, $orf_beg, $orf_end, $i_score,
                               { n_complete => 1,
                                 c_complete => $c_complete,
                                 n_delta    => 3 * ( $i1 - $i ),  # approx
                                 c_delta    => $c_delta
                               }
                             ];
            $used{ $orf_beg }++;
            $i--;
        }
        elsif ( $is_term->{ $trip } )
        {
            $done = 1;
        }
        else
        {
            $orf_beg -= 3*$dir;
            $scr += $scores->[ $i ] if (($i >= 0) && ($i < @$scores));
            $i--;
        }
    }

    wantarray ? @proposals : \@proposals;
}


my %codon_color;
{
    my $start = '#80FF80';
    my $stop  = '#FF8080';
    %codon_color = ( ATG => $start, GTG => $start, TTG => $start,
                     TAA => $stop,  TAG => $stop,  TGA => $stop
                   );
}

my %marked_color;
{
    my $start = '#60C060';
    my $stop  = '#C06060';
    %marked_color = ( ATG => $start, GTG => $start, TTG => $start,
                      TAA => $stop,  TAG => $stop,  TGA => $stop
                    );
}


#===============================================================================
#
#  $html = display_scored_dna( $align, $locs, $scores, $init_scrs, $opts )
#
#===============================================================================
sub display_scored_dna
{
    my ( $align, $locs, $scores, $init_scrs, $opts ) = @_;

    $opts ||= {};

    my $loc1 = $opts->{ loc1 };
    my $show_def = 0;
    if ( @{$align->[0]} == 3 )
    {
        for ( my $i = 0; $i < @$align; $i++ )
        {
            my ( $id, $def, undef ) = @{ $align->[$i] };
            if ( $def && ($def ne $locs->{$id}) ) { $show_def = 1; last } 
        }
    }

    my ( $color, $c_str );
    my @html;

    push @html, "<TABLE>\n";
    foreach ( @$align )
    {
        my $id = $_->[0];
        push @html, "<TR Align=center>\n";
        push @html, "  <TD Align=left>$id</TD>\n";
        push @html, "  <TD Align=left>$_->[1]</TD>\n" if $show_def;
        push @html, "  <TD Align=left>$locs->{$id}</TD>\n";

        my ( $mark, $t1, $t2 );
        if ( $loc1 && $loc1->{ $id } && $loc1->{ $id } !~ /,/ )
        {
            my ( $c1, $b1, $e1 ) = $locs->{ $id } =~ /^(.+)_(\d+)_(\d+)$/;
            $c1 =~ s/^\d+\.\d+\://;
	    my $d1 = $e1 <=> $b1;
            my ( $l1, $r1 ) = minmax( $b1, $e1 );
            my ( $c2, $b2, $e2 ) = $loc1->{ $id } =~ /^(.+)_(\d+)_(\d+)$/;
            $c2 =~ s/^\d+\.\d+\://;
            my $d2 = $e2 <=> $b2;
            my ( $l2, $r2 ) = minmax( $b2, $e2 );
            if ( ($c1 eq $c2) && ($d1 == $d2) && ($l1 <= $r2) && ($l2 <= $r1) && ($b1 % 3 == $b2 % 3) )
            {
                $mark = 1;
                $t1 = $d1 * (   $b2           - $b1 ) / 3;  # First marked
                $t2 = $d1 * ( ( $e2 - 2*$d1 ) - $b1 ) / 3;  # Last marked
#		print STDERR "t1=$t1 t2=$t2\n";
            }
        }


        my @triples = $_->[-1] =~ m/.../g;
        my $t = 0;
        foreach ( @triples )
        {
            $_ = uc $_;
            if ( $mark && ( $t >= $t1 ) && ( $t <= $t2 ) )
            {
                $color = $marked_color{ $_ } || '#C0C0C0';
            }
            else
            {
                $color = $codon_color{ $_ };
            }
            $c_str = $color ? " BgColor=$color" : '';
            push @html, "  <TD$c_str>$_</TD>\n";

            $t++ if /[ACGT]/;
        }
        push @html, "</TR>\n";
    }

    my $colspan = $show_def ? 3 : 2;
    if ($init_scrs)
    {
        push @html, "<TR Align=center>\n";
        push @html, "  <TD Align=left ColSpan=$colspan>Initiator scores</TD>\n";
        foreach ( @$init_scrs )
        {
            push @html, sprintf "  <TD NoWrap BgColor=%s>%.2f</TD>\n", init_score_color($_), $_;
        }
        push @html, "</TR>\n";
    }

    push @html, "<TR Align=center>\n";
    push @html, "  <TD Align=left ColSpan=$colspan>Comparative scores</TD>\n";
    foreach ( @$scores )
    {
        push @html, sprintf "  <TD NoWrap BgColor=%s>%.2f</TD>\n", score_color($_), $_;
    }
    push @html, "</TR>\n";

    my ( $smax, $i1, $i2 ) = high_scoring_region( $scores );
    if ( $smax > 0 )
    {
        $smax = sprintf "%.2f", $smax;
        my $span1 = $i1;
        my $span2 = $i2 - $i1 + 1;
        my $span3 = @$scores - $i2 - 1;
        push @html, "<TR Align=center>\n";
        push @html, "  <TD Align=left ColSpan=$colspan>High-scoring region</TD>\n";
        push @html, "  <TD ColSpan=$span1></TD>\n" if $span1;
        push @html, "  <TD ColSpan=$span2 BgColor=SkyBlue>$smax</TD>\n";
        push @html, "  <TD ColSpan=$span3></TD>\n" if $span3;
        push @html, "</TR>\n";
    }

    push @html, "</TABLE>\n\n";

    join '', @html;
}


sub high_scoring_region
{
    my ( $scores ) = @_;

    my ( $i, $i1, $i2, $s, $smax );
    $s  = $i = $smax = 0;
    $i1 = -1;
    my $max = [ 0, -1, 0 ];  # max_score, $start, $end

    foreach ( @$scores )
    {
        $s += $_;
        if ( $_ >= 0 )
        {
            $i1 = $i if $i1 < 0;
            if ( $s >= $smax ) { $i2 = $i; $smax = $s }
        }
        elsif ( $s < 0 )
        {
            record( $max, $smax, $i1, $i2 );
            $s  =  0;
            $i1 = -1;
        }
        $i++;
    }
    record( $max, $smax, $i1, $i2 );

    @$max;
}


sub high_scoring_starts
{
    my ( $scores, $init_scrs, $aligned ) = @_;

    my ( $i, $i1, $i2, $s, $smax );
    $s  = $i = $smax = 0;
    $i1 = -1;
    my $max = [ 0, -1, 0 ];  # max_score, $start, $end

    foreach ( @$scores )
    {
        $s += $_;
        if ( $_ >= 0 )
        {
            $i1 = $i if $i1 < 0;
            if ( $s >= $smax ) { $i2 = $i; $smax = $s }
        }
        elsif ( $s < 0 )
        {
            record( $max, $smax, $i1, $i2 );
            $s  =  0;
            $i1 = -1;
        }
        $i++;
    }
    record( $max, $smax, $i1, $i2 );

    @$max;
}


sub record
{
      my ( $max, $smax ) = @_;
      @$max = @_[1..3] if ( $smax > $max->[0] );
      $max;
}


sub codon_color { $codon_color{ uc $_[0] } || 'white' }


sub score_color
{
    my $s = shift;
    $s  = -8 if $s < -8;
    $s  =  8 if $s >  8;
    $s *= 0.125;
    rgb2html( hsb2rgb( $s < 0 ? 0 : 2/3, abs( $s ), 1 ) )
}


sub init_score_color
{
    my $s = shift;
    $s  =  0 if $s < 0;
    $s  =  8 if $s > 8;
    $s *= 0.125;
    rgb2html( hsb2rgb( 1/3, abs( $s ), 1 ) )
}


sub fraction_identity
{
    my ( $s1, $s2 ) = @_;
    my $d = uc $s1 ^ uc $s2;
    ( $d =~ tr/\0// ) / length( $d );
}


sub number_of_terminators { local $_ = shift; tr/*// }


sub nongap { $_[0] =~ tr/-//c }


sub minmax { $_[0] < $_[1] ? @_[0,1] : @_[1,0] }


1;
