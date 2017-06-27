package collect_related_sequences;

use strict;
use gjoseqlib;
use gjoparseblast;
use SeedAware;

#===============================================================================
#  Given a sequence database (fasta file) and a list of exemplars, find the
#  database sequences related to the exemplar(s), and return those database
#  sequences, trimmed to the region of match, plus a little extra.
#
#    \@sequences = collect_related_sequences( $seq_db, \@exemplars, \%options );
#     @sequences = collect_related_sequences( $seq_db, \@exemplars, \%options );
#
#  $seq_db is path to a sequence database file.  In the SEED environment, the
#     option nr =>1 can be used to specify use of the SEED nr instead.  The
#     parameter can also be replaced by the 'seq_db' option.
#
#  Exemplars are pairs or triples: [ id, sequence ] or [ id, defintion, sequence ]
#     In the SEED environment, the fids option can be used to supply exemplars
#     by their id.  The parameter can also be replaced by the 'exemplars' option.
#
#  Sequences are returned triples: [ id, definition, sequence ].  They are
#     trimmed to exceed the length of an exemplar by no more than "extra_ends"
#     residues (D = 10).  If they are trimmed, the returned definition ends
#     with the location returned in the form "[id_start_end]".
#
#  Options:
#
#      exemplars    => \@sequences     # Exemplars supplied in options
#      extra_ends   =>  $extra_ends    # Sequence beyond match to retain (D = 10)
#      fids         => \@fids          # fid sequences as exemplars           
#      max_e_value  =>  $max_e_value   # (D =  0.001)
#      max_sequence =>  $max_sequence  # Max returned sequences (D = 10,000)
#      min_coverage =>  $min_coverage  # (D =  0.80)
#      min_identity =>  $min_identity  # (D =  0.25)
#      no_merge     =>  1              # Do not merge exemplars with match sequences
#      nr           =>  1              # Use SEED nr (D = use seq_db)
#      seq_db       =>  $file          # Seq_db supplied as in options
#      stderr       =>  $file          # File for blast stderr (D = /dev/stderr)
#      tmp          =>  $directory     # Directory for temporary file
#
#      tmp_dir      =>  $temporary_dir # Obsolete (ignored)
#
#===============================================================================

sub collect_related_sequences
{
    my $seq_db;
    my $exemplars = [];
    my $options   = {};

    foreach ( @_ )
    {
        if ( ref( $_ ) eq 'ARRAY' )
        {
            $exemplars = $_;
        }
        elsif ( ref( $_ ) eq 'HASH' )
        {
            $options = $_;
        }
        elsif ( $_ )
        {
            $seq_db = $_;
            -f $seq_db
                 or print STDERR "collect_related_sequences called with invalid sequence file\n"
                 and return undef;
        }
    }

    #  Canonical form of options is lowercase, no underscores,
    #  and no terminal 's'.

    foreach my $key ( keys %$options )
    {
        $options->{ canonical_key( $key ) } = $options->{ $key };
    }

    #  Alternative method for passing parameters:

    $exemplars = $options->{ exemplar } if $options->{ exemplar };
    $seq_db    = $options->{ seqdb }    if $options->{ seqdb };

    #  Other options:

    my $extra_ends   = $options->{ extraend }    || 10;
    my $fids         = $options->{ fid };
    my $max_e_value  = $options->{ maxevalue }   || 0.001;
    my $max_sequence = $options->{ maxsequence } || $options->{ maxseq } || 10000;
    my $merge        = $options->{ nomerge } ? 0 : 1;
    my $min_coverage = $options->{ mincoverage } || 0.80;
    my $min_identity = $options->{ minidentity } || 0.25;
    my $nr           = $options->{ nr };
    my $stderr       = $options->{ stderr };

    #  Let an explicit database override the nr option:

    $nr = '' if $seq_db && $nr;

    my $fig;
    if ( $nr || $fids )
    {
        $SeedAware::in_SEED
            or print STDERR "collect_related_sequences nr and fids options require the SEED environment\n"
                and return undef;
        eval { require FIG; $fig = new FIG };
        $fig or print STDERR "collect_related_sequences failed to make new FIG.\n"
             and return undef;
    }

    if ( $nr )
    {
        $FIG_Config::global
             or print STDERR "collect_related_sequences nr option requires FIG_Config::global\n"
                 and return undef;
        $seq_db = "$FIG_Config::global/nr";
    }

    -f $seq_db
         or print STDERR "collect_related_sequences could not locate sequence database $seq_db\n"
             and return undef;

    #  Verify that the blast database exisits:

    verify_protein_db( $seq_db )
         or print STDERR "collect_related_sequences could not create protein blast database for:\n$seq_db\n"
             and return undef;

    #  There are two sources of exemplars, the supplied list, or a supplied
    #  list of fids (we are very lax, it can be a list, or a delimited string).

    if ( $fids )
    {
        foreach my $fid ( ref( $fids ) eq 'ARRAY' ? @$fids
                                                  : split /[,\s]+/, $fids
                        )
        {
            my $seq = $fig->get_translation( $fid );
            push @$exemplars, [ $fid, '', $seq ] if $seq;
        }
    }

    my @exemplars = sort { length( $b->[2] ) <=> length( $a->[2] ) }
                    map  { @$_ == 2 ? [ $_->[0], '', $_->[1] ]
                         : @$_ == 3 ? $_
                         : ()
                         }
                    @$exemplars;

    @exemplars
        or print STDERR "collect_related_sequences called with no valid exemplar sequences\n"
            and return undef;

    #  Put the longest exemplar in a file:

    my $tmp = SeedAware::location_of_tmp( $options );
    $tmp or print STDERR "Could not locate directory for temporary file.\n"
        and return undef;

    my $query_file = SeedAware::new_file_name( "$tmp/collect_related_seq" );
    $query_file or print STDERR "Could not get a name for temporary file.\n"
        and return undef;

    gjoseqlib::print_alignment_as_fasta( $query_file, [ $exemplars[0] ] );

    my $cmd = SeedAware::executable_for( 'blastall' );
    my @arg = ( '-p', 'blastp',            # blastp
                '-d', $seq_db,
                '-i', $query_file,
                '-e', $max_e_value,
                '-b', $max_sequence + 10,
                '-v', $max_sequence + 10,
                '-F', 'f',                 # no low complexity filter
                '-a',  2,                  # two cpus
                '-M', 'BLOSUM80'
              );

    my $optH = {};
    $optH->{ stderr } = $stderr if $stderr;

    # my $output = run_blast( 'blastp', $seq_db, $query_file,
    #                         "-e $max_e_value -b 10000 -v 10000 -F f -a 2 -M BLOSUM80"
    #                       );

    my $fh = SeedAware::read_from_pipe_with_redirect( $cmd, @arg, $optH );
    my $output = gjoparseblast::structured_blast_output( $fh );
    close $fh;

    unlink $query_file;

    my ( $qid, $qdef, $qlen, $matches ) = @{ $output->[0] };  #  Only one query
    my %desired_seq;

    foreach my $subject ( @$matches )
    {
        my ( $sid, $sdef, $slen, $hsps ) = @$subject;
        my ( $scr, $e_val, $n_mat, $n_id, $n_pos, $n_gap, $dir, $q1, $q2, $qseq, $s1, $s2, $sseq ) = join_blast_hsps( $hsps );
        #  Filter:

        next if $e_val > $max_e_value;
        next if ( $q2 - $q1 + 1 ) / $qlen < $min_coverage;
        next if ($n_id / $n_mat) < $min_identity;

        #  Okay.  We have a match, lets trim it.  For now will trim on the
        #  longest.  In the longer run we might blast each against all
        #  exemplars, and take the longest match at each end.
        #
        #         1    q1                          q2    qlen
        #         |     |                           |      |
        #         ------=============================-------
        #     ----------=============================-----------
        #     |         |                           |          |
        #     1        s1                          s2         slen

        my ( $beg, $end );
        $beg = $s1 - ( $q1   -   1 ) - $extra_ends;
        $beg = 1 if $beg < 1;
        $end = $s2 + ( $qlen - $q2 ) + $extra_ends;
        $end = $slen if $end > $slen;

        if ( $beg > 1 || $end < $slen )
        {
            $sdef .= ' ' if $sdef;
            $sdef .= "[${sid}_${beg}_${end}]";  # SEED format; might change?
        }

        $desired_seq{ $sid } = [ $sdef, $beg, $end ];
    }

    #  Return if no matches:

    if ( ! scalar keys %desired_seq )
    {
        return $merge ? ( wantarray ? @exemplars : \@exemplars )
                      : ( wantarray ? ()         : []          );
    }

    #  Otherwise we must fetch and trim sequences, and, in the case of the
    #  SEED, fix the ids:

    open( FH, "<$seq_db" )
           or print STDERR "Could not read sequence file $seq_db\n"
           and return wantarray ? () : undef;

    #  If merge, then start with the exemplars, otherwise start with nothing.

    my @trimmed_seqs = $merge ? @exemplars : ();
    my %seen = map { $_->[0] => 1 } @trimmed_seqs;

    my @ids;
    my $seq_entry;
    while ( $seq_entry = read_next_fasta_seq( \*FH ) )
    {
        next if ! $desired_seq{ $seq_entry->[0] };
        my ( $id, undef, $seq ) = @$seq_entry;
        my ( $def, $beg, $end ) = @{ $desired_seq{ $id } };

        if ( ( $beg > 1 ) || ( $end < length( $seq ) ) )
        {
            $seq = substr( $seq, $beg-1, $end-$beg+1 );
        }

        #  If nr, then we must fix ids, otherwise just use original:

        @ids = $nr ? $fig->recast_ids( 'fig\|', [ $id ] ) : ( $id );

        push @trimmed_seqs, map { [ $_, $def, $seq ] }  # Save entry
                            grep { ! $seen{ $_ }++ }    # Remove duplicates
                            @ids;
    }

    close FH;

    wantarray ? @trimmed_seqs : \@trimmed_seqs;
}


#-------------------------------------------------------------------------------
#  For now, we will take the top hsp as the joined hsps:
#
#  [ $scr, $e_val, $n_mat, $n_id, $n_pos, $n_gap, $dir, $q1, $q2, $qseq, $s1, $s2, $sseq ] = join_blast_hsps( \@hsps )
#
#  HSP structure:
#
#  [ $scr, $e_val, undef, undef, $n_mat, $n_id, $n_pos, $n_gap, $dir, $q1, $q2, $qseq, $s1, $s2, $sseq ]
#-------------------------------------------------------------------------------
sub join_blast_hsps
{
    my $hsps = shift;
    @{ $hsps->[0] }[ 0, 1, 4 .. 14 ];
}


#===============================================================================
#  Utility functions:
#===============================================================================
#  Remove uppercase, underscores and terminal 's' from options keys:
#
#      $key = canonical_key( $key );
#-------------------------------------------------------------------------------
sub canonical_key
{
    my $key = lc shift;
    $key =~ s/_//g;
    $key =~ s/s$//;  #  This is dangerous if an s is part of a word!
    return $key;
}


#-------------------------------------------------------------------------------
#  Verify that protein blast database exists, or create it.
#
#     verify_protein_db( $db_filename )
#
#-------------------------------------------------------------------------------
sub verify_protein_db
{
    my ( $db ) =  @_;

    return 1 if ( -f "$db.psq" || -f "$db.00.psq" );  # Exists
    return 0 if ! -f $db;  # Source file does not exist

    my $prog  = SeedAware::executable_for( 'formatdb' );
    my @args  = ( '-p', 'T', '-i', $db );
    my $redir = { stderr => '/dev/null' };
    my $exit  = SeedAware::system_with_redirect( $prog, @args, $redir );

    if ( $exit )
    {
        my $cmd = join( ' ', $prog, @args );
        print STDERR "'$cmd' exit code $exit.\n";
        return 0;
    }

    -f "$db.psq" || -f "$db.00.psq"
}


#-------------------------------------------------------------------------------
#  Fork a process to run blast (without a shell), and structure the output.
#
#    $output = run_blast( $prog, $db_file, $query_file, $blast_opts )
#    @output = run_blast( $prog, $db_file, $query_file, $blast_opts )
#
#  Output is clustered heirarchically by query, by subject and by hsp.  The
#  highest level is query records:
#
#  [ qid, qdef, qlen, [ [ sid, sdef, slen, [ hsp_data, hsp_data, ... ] ],
#                       [ sid, sdef, slen, [ hsp_data, hsp_data, ... ] ],
#                       ...
#                     ]
#  ]
#
#  hsp_data:
#
#  [ scr, exp, p_n, pval, nmat, nid, nsim, ngap, dir, q1, q2, qseq, s1, s2, sseq ]
#     0    1    2    3     4     5    6     7     8   9   10   11   12  13   14
#-------------------------------------------------------------------------------
sub run_blast
{
    my( $prog, $db_file, $query_file, $blast_opts ) = @_;

    #  Sanity (safety) check of blast options:

    $blast_opts =~ s/(^|\s+)-[moORT]\s*\S+//g;

    #  This tedious approach allows file names with blanks, tabs, and newlines
    #  (sorry, but it was too much to resist):

    my @command = ( 'blastall', '-p', $prog, '-d', $db_file, '-i', $query_file );
    push @command, split( " ", $blast_opts ) if $blast_opts =~ /\S/;

    my $bfh;
    my $pid = open( $bfh, '-|' );
    if ( $pid == 0 )               #  The forked process does the blast ...
    {
        exec( @command );
        #  We should never get here:
        die "exec '@{[join(' ',@command)]}' failed:\n$!";
    }

    # ... and we read the output:

    my $output = gjoparseblast::structured_blast_output( $bfh );
    close $bfh;
    $output;
}


1;
