#
#  CodonUsageTable.pm
#
package CodonUsageTable;

use strict;
use gjocodonlib;
use gjocolorlib;
use gjoseqlib;
use Data::Dumper;


#===============================================================================
#  Produce an WWW page, or tab delimited table of the the match of a set of
#  genes to codon usages.
#
#     $html = codon_usage_match_table( \%options )
#
#  Options:
#
#      de_novo  =>  $bool      # Calculate codon usages de_novo from source
#      ffn      =>  $fasta     # Sequences for genes and codon usage
#      format   =>  $format    # html | page | tab
#      gid      =>  $gid       # Kbase or SEED genome id, as appropriate
#      g_gid    =>  $gid       # Kbase or SEED genome id for genes
#      g_ffn    =>  $fasta     # Sequences for genes
#      g_seq    => \@seqs      # Gene sequences
#      g_source =>  $keyword   # Source of genes: KBase | Sapling | SEED
#      source   =>  $keyword   # Source of data: KBase | Sapling | SEED
#      title    =>  $title     # title for HTML page (D is from genome name)
#      u_gid    =>  $gid       # Kbase or SEED genome id for codon usages
#      u_ffn    =>  $fasta     # Sequences for codon usage
#      u_seq    => \@seqs      # Gene sequences for codon usage
#      u_source =>  $keyword   # Source of codon usages: KBase | Sapling | SEED
#
#  Layout:
#
#    \@column_list = [ column_set_1, column_set_2, ... ]
#
#  Column set:
#
#    [ 'column_group', $title, \@column_list ]
#
#    [ 'axis_match',  \@cnts,  \%param ]
#    [ 'freq_match',  \@cnts,  \%param ]
#    [ 'space',        $nrow,   $width ]
#    [ 'user_data,    \@rows,  \%param ]
#
#  Parameters for 'axis_match' and 'freq_match':
#
#    f       =>  $freqs
#    f0      =>  $freqs
#    f1      =>  $freqs
#    title   =>  $title   # RowSpan is 1 for axis_match, but 2 for freq_match
#    xmin    =>  $xmin    # D = -0.1
#
#  Parameters for 'user_data':
#
#    align   =>  $align  # left, center or right (D = left)
#    class   =>  $class  # add as Class attribute
#    colspan =>  $cols   # D = 1; colspan > 1 implies is_html and no added <TD> tags
#    is_html =>  $bool   # do not do html escaping
#    is_text =>  $bool   # needs to be html escaped (D = 1)
#    style   =>  $style  # add as Style attribute
#    title   =>  $title  # gets RowSpan=2
#
#  These can all be handled by conversion to user_data:
#
#    ftr_id
#    ftr_def
#    ftr_len
#    ftr_ss
#
#
#  If separate sources are supplied for codon usages and genes to be matched
#  to them, the g_ and u_ forms should be used for both parameters. Otherwise
#  the behavior is not assured to be stable in the future.
#
#  Output formats:
#
#      html   ( $style_text, $table_text )
#      html   $style_text . $table_text
#      page   $html_page
#      tab    $tab_separated_text
#
#===============================================================================

sub codon_usage_match_table
{
    my $opts = shift;
    $opts && ref( $opts ) eq 'HASH'
        or print STDERR qq(codon_usage_match_table called with invalid options hash.\n)
            and return '';

    my $format = $opts->{ format } || 'html';
    my %formats = map { $_ => 1 } qw( html page tab );
    $formats{ $format }
        or print STDERR qq(codon_usage_match_table called with invalid format '$format'.\n)
            and return '';

    my $title = $opts->{ title } || '';

    my @cnts;
    {
        #  Put the sequence data in a bare block; at some point we might want
        #  to support direct access to counts.

        my $g_seq = gather_coding_sequences( $opts );
        $g_seq && @$g_seq
            or print STDERR qq(codon_usage_match_table failed to get sequences to be analyzed.\n)
                and return '';

        @cnts = gjocodonlib::entry_labeled_codon_count_package( @$g_seq );
    }

    my ( $gname,
         $mode,      $md_type,
         $high_expr, $he_type,
         $nonnative, $nn_type ) = gather_codon_usage_data( $opts );

    my $u_gid = $opts->{ u_gid } || $opts->{ gid } || 'Unidentified genome';

    #  Output data:

    my $table_styles = '';
    my @table_html   = ();

    #  Arrays for per gene data:

    my ( @id_def, @modal, @native, @nonnative );
    if ( $mode )
    {
        my $show_modal = 1;
        my $md_opt = { %$opts, label => 'Genome<BR />mode<BR />P-value' };
        @modal = $show_modal ? freq_match_table_column( \@cnts, $mode, $md_opt ) : ('') x (@cnts+2);

        my $he_opt = { %$opts, xmin => -0.1, hue1 => 2.00, hue2 => -0.50, label => 'Native axis<BR />match' };
        @native    = $he_type   ? axis_match_table_columns( \@cnts, $mode, $high_expr, $he_opt ) : ('') x (@cnts+2);

        my $nn_opt = { %$opts, xmin => -0.1, hue1 => 2.00, hue2 =>  4.50, label => 'Nonnative<BR />axis match' };
        @nonnative = $nonnative ? axis_match_table_columns( \@cnts, $mode, $nonnative, $nn_opt ) : ('') x (@cnts+2);

        $opts->{ id_proc } = \&fid_link;
        @id_def = id_def_table_columns( [ map{$_->[1]} @cnts ], $opts );

        if ( $format eq 'tab' )
        {
            my @table;
            push @table, join( "\t", ( $show_modal ?   'Genome mode P-value'                                      : () ),
                                     ( $he_type    ? ( 'Native axis match x',    'Native axis match P-value' )    : () ),
                                     ( $nonnative  ? ( 'Nonnative axis match x', 'Nonnative axis match P-value' ) : () ),
                                                     ( 'ID',                     'Definition' )
                             ),
                  "\n";
            for ( my $i = 0; $i < @cnts; $i++ )
            {
                push @table, join( "\t", ( $show_modal ?    $modal[$i]       : () ),
                                         ( $he_type    ? @{ $native[$i] }    : () ),
                                         ( $nonnative  ? @{ $nonnative[$i] } : () ),
                                                         @{ $id_def[$i] }
                                 ),
                             "\n";
            }

            return join( '', @table );
        }
        push @table_html, "<A Name=Codon_usage_table_top></A>\n",
                          codon_usage_columns_to_html( \@modal, \@native, \@nonnative, \@id_def ),
                          <<Table_Suffix;

<A Name=Codon_usage_table_explanation></A>
<A HRef=#Codon_usage_table_top>Top of table</A>
<BR />
<BR />
@{[codon_usage_table_explanation()]}
<BR />
<A HRef=#Codon_usage_table_top>Top of table</A>

Table_Suffix

        $table_styles = codon_usage_table_styles();
    }
    elsif ( $format eq 'tab' )
    {
        print STDERR "No codon usage data available for genome '$u_gid'.\n";
        print STDERR "Try -d flag for de novo calculation of native codon usage.\n";
        return '';
    }
    else
    {
        push @table_html, "<H3>No codon usage data available for genome '$u_gid'.</H3>\n",
                          "Try -d flag for de novo calculation of native codon usage.\n";
    }

    $title ||= $gname ? "$gname codon usage matches"
                      : 'Gene codon usage matches';

    #  HTML returns are:
    #
    #      ( $style, $table )
    #      $style . $table
    #      $html_page
    #
    return $format eq 'html' && wantarray ? ( $table_styles, join('', @table_html) )
         : $format eq 'html'              ? join( '', $table_styles, @table_html )
         :                                  <<"End_of_Page";
<HTML>
<HEAD>
<META http-equiv="Content-Type" content="text/html;charset=UTF-8" />
<TITLE>$title</TITLE>
$table_styles
</HEAD>
<BODY>
<H2>$title</H2>
@table_html
</BODY>
</HTML>
End_of_Page
}


#===============================================================================
#  Gather the coding sequences for a codon usage analysis.
#
#     \@seqs = gather_coding_sequences( \%options )
#
#  Options:
#
#      ffn      =>  $fasta     # Sequences for genes and codon usage
#      gid      =>  $gid       # Kbase or SEED genome id, as appropriate
#      g_gid    =>  $gid       # Kbase or SEED genome id for genes
#      g_ffn    =>  $fasta     # Sequences for genes
#      g_seq    => \@seqs      # Gene sequences
#      g_source =>  $keyword   # Source of genes: KBase | Sapling | SEED
#      seq      => \@seqs      # Gene sequences
#      source   =>  $keyword   # Source of data: KBase | Sapling | SEED
#
#      region   =>   $fid      # +/- 10,000 nt
#      region   => [ $fid ]    # +/- 10,000 nt
#      region   => [ $fid, $regsize ]   # Stated region size centered on fid
#      region   => [ $fid, $nt_before, $nt_after ]
#
#===============================================================================
sub gather_coding_sequences
{
    my $opts = shift;
    $opts && ref( $opts ) eq 'HASH'
        or print STDERR "gather_coding_sequences() called with invalid options hash.\n"
           and return undef;

    #
    #  All counts currently come from the DNA seqs, so we need to get dna:
    #
    my $g_ffn    = $opts->{ g_ffn }    || $opts->{ ffn }    || '';
    my $g_gid    = $opts->{ g_gid }    || $opts->{ gid }    || '';
    my $g_seq    = $opts->{ g_seq }    || $opts->{ seq };
    my $g_source = $opts->{ g_source } || $opts->{ source } || '';
    if ( $g_source && $g_source !~ m/KBase/i
                   && $g_source !~ m/SEED/i
                   && $g_source !~ m/Sapling/i
       )
    {
        print STDERR "gather_coding_sequences: invalid data source '$g_source'.\n"
            and return undef; 
    }

    if ( $g_seq && ref( $g_seq ) eq 'ARRAY' )
    {
        @$g_seq
            or print STDERR "gather_coding_sequences() failed to get coding sequences from options."
                and return undef;
    }
    elsif ( $g_ffn && -f $g_ffn )
    {
        $g_seq = gjoseqlib::read_fasta( $g_ffn );
        $g_seq && @$g_seq
            or print STDERR "gather_coding_sequences() failed to get coding sequences from '$g_ffn'.\n"
                and return undef;
    }
    elsif ( $g_gid )
    {
        $g_gid =~ s/^g\./kb|g./;   # add kb| to KBase genome id
        $g_gid =~ s/^fig\|//;      # remove fig| from fig genome id

        if ( $g_gid !~ /^kb\|g\.\d+$/ && $g_gid !~ /^\d+\.\d+$/ )
        {
            print STDERR "gather_coding_sequences() could not interpret genome id '$g_gid'.\n"
                and return undef; 
        }

        if ( $g_source )
        {
            if ( ( $g_gid =~ /^kb\|g\.\d+$/ && $g_source !~ m/KBase/i )
              || ( $g_gid =~ /^\d+\.\d+$/ && $g_source !~ m/Sapling/i && $g_source !~ m/SEED/i )
               )
            {
                print STDERR "gather_coding_sequences: genome id '$g_gid' is not compatible with coding sequence source '$g_source'.\n"
                    and return undef; 
            }
            
        }

        if ( $g_gid =~ /^kb\|g\.\d+$/ )
        {
            eval { require KBaseCodonUsage; }
                and $g_seq = KBaseCodonUsage::coding_sequences( $g_gid, $opts );
        }
        else
        {
            if ( ! $g_source || $g_source =~ /^SEED$/i )
            {
                eval { require SeedCodonUsage; }
                    and $g_seq = SeedCodonUsage::coding_sequences( $g_gid, $opts );
                $opts->{ g_source } = 'SEED' if $g_seq && @$g_seq;
            }

            if ( ! $g_seq && ( ! $g_source || $g_source =~ /^Sapling$/i ) )
            {
                eval { require SaplingCodonUsage; }
                    and $g_seq = SaplingCodonUsage::coding_sequences( $g_gid, $opts );
                $opts->{ g_source } = 'Sapling' if $g_seq && @$g_seq;
            }
        }

        $g_seq && @$g_seq
            or print STDERR "gather_coding_sequences() failed to get coding sequences for '$g_gid'.\n"
                and return undef; 
    }
    else
    {
        print STDERR "gather_coding_sequences() called without valid source of coding sequences.\n"
            and return undef; 
    }

    wantarray ? @$g_seq : $g_seq;
}


#===============================================================================
#  Gather codon usage data for a given genome.
#
#      @axes = gather_codon_usage_data( \%options )
#     \@axes = gather_codon_usage_data( \%options )
#
#  Options:
#
#      de_novo  =>  $bool      # Calculate codon usages de_novo from source
#      ffn      =>  $fasta     # Sequences for genes and codon usage
#      gid      =>  $gid       # Kbase or SEED genome id, as appropriate
#      seq      => \@seqs      # Gene sequences for codon usage
#      source   =>  $keyword   # Source of data: KBase | Sapling | SEED
#      u_gid    =>  $gid       # Kbase or SEED genome id for codon usages
#      u_ffn    =>  $fasta     # Sequences for codon usage
#      u_seq    => \@seqs      # Gene sequences for codon usage
#      u_source =>  $keyword   # Source of codon usages: KBase | Sapling | SEED
#
#===============================================================================

sub gather_codon_usage_data
{
    my ( $opts ) = @_;
    $opts && ref( $opts ) eq 'HASH' or return undef;

    my $de_novo  = $opts->{ de_novo };
    my $u_ffn    = $opts->{ u_ffn }    || $opts->{ ffn }    || '';
    my $u_gid    = $opts->{ u_gid }    || $opts->{ gid }    || '';
    my $u_seq    = $opts->{ u_seq }    || $opts->{ seq };
    my $u_source = $opts->{ u_source } || $opts->{ source } || '';
    if ( $u_source && $u_source !~ m/^KBase/i
                   && $u_source !~ m/^SEED/i
                   && $u_source !~ m/^Sapling/i
       )
    {
        print STDERR "gather_codon_usage_data: invalid data source '$u_source'.\n"
            and return undef; 
    }


    #
    #  Axes are: ( $gname, $mode,      $md_type,
    #                      $high_expr, $he_type,
    #                      $nonnative, $nn_type
    #            )
    #
    my @axes;

    $u_gid =~ s/\s+//g;
    if ( $u_gid )
    {
        $u_gid =~ s/^g\./kb|g./;   # add kb| to KBase genome id
        $u_gid =~ s/^fig\|//;      # remove fig| from fig genome id

        if ( $u_gid !~ /^kb\|g\.\d+$/ && $u_gid !~ /^\d+\.\d+$/ )
        {
            print STDERR "gather_codon_usage_data() could not interpret genome id '$u_gid'.\n"
                and return undef; 
        }

        if ( $u_source )
        {
            if ( ( $u_gid =~ /^kb\|g\.\d+$/ && $u_source !~ m/KBase/i )
              || ( $u_gid =~ /^\d+\.\d+$/   && $u_source !~ m/Sapling/i && $u_source !~ m/SEED/i )
               )
            {
                print STDERR "gather_codon_usage_data: genome id '$u_gid' is not compatible with codon usage source '$u_source'.\n"
                    and return undef; 
            }
            
        }
    }

    if ( $u_gid && ! $de_novo )
    {
        my $cu_opt = { %$opts };
        if    ( $u_gid =~ /^kb\|g\.\d+$/ )
        {
            eval { require KBaseCodonUsage; }
                and @axes = KBaseCodonUsage::genome_axes( $u_gid, $cu_opt );

            $opts->{ u_source } = 'KBase' if @axes;
        }
        elsif ( $u_gid =~ /^\d+\.\d+$/ )
        {
            if ( ! $u_source || $u_source =~ /^SEED$/i )
            {
                eval { require SeedCodonUsage; }
                    and @axes = SeedCodonUsage::genome_axes( $u_gid, $cu_opt );

                $opts->{ u_source } = 'SEED' if @axes;
            }

            if ( ( ! @axes ) && ( ( ! $u_source ) || $u_source =~ /^Sapling$/i ) )
            {
                eval { require SaplingCodonUsage; }
                    and @axes = SaplingCodonUsage::genome_axes( $u_gid, $cu_opt );

                $opts->{ u_source } = 'Sapling' if @axes;
            }
        }

        if ( ! @axes )
        {
            if ( defined $de_novo )
            {
                print STDERR "gather_codon_usage_data: could not obtain codon usages for '$u_gid'.\n"
                    and return undef; 
            }

            $de_novo = 1;
        }
    }

    if ( ! @axes && $de_novo )
    {
        if ( $u_seq && ref( $u_seq ) eq 'ARRAY' )
        {
            @$u_seq
                or print STDERR "gather_codon_usage_data() failed to get coding sequences from option hash."
                    and return undef;
        }
        elsif ( $u_ffn && -f $u_ffn )
        {
            $u_seq = gjoseqlib::read_fasta( $u_ffn );
            $u_seq && @$u_seq
                or print STDERR "gather_codon_usage_data() failed to get coding sequences from '$u_ffn'.\n"
                    and return undef;
        }
        else
        {
            if ( $u_gid =~ /^kb\|g\.\d+$/ )
            {
                eval { require KBaseCodonUsage; }
                    and $u_seq = KBaseCodonUsage::coding_sequences( $u_gid, $opts );

                $opts->{ u_source } = 'KBase' if $u_seq;
            }
            elsif ( $u_gid =~ /^\d+\.\d+$/ )
            {
                if ( ! $u_source || $u_source =~ /^SEED$/i )
                {
                    eval { require SeedCodonUsage; }
                        and $u_seq = SeedCodonUsage::coding_sequences( $u_gid, $opts );

                    $opts->{ u_source } = 'SEED' if $u_seq;
                }

                if ( ( ! $u_seq ) && ( ( ! $u_source ) || $u_source =~ /^Sapling$/i ) )
                {
                    eval { require SaplingCodonUsage; }
                        and @axes = SaplingCodonUsage::coding_sequences( $u_gid, $opts );

                    $opts->{ u_source } = 'Sapling' if $u_seq;
                }
            }

            $u_seq && @$u_seq
                or print STDERR "gather_codon_usage_data() failed to get coding sequences for '$u_gid'.\n"
                    and return undef; 
        }

        #  Is there a request of the sequence data?

        $opts->{   seq } = $u_seq if $opts->{   seq } && ref $opts->{   seq } ne 'ARRAY';
        $opts->{ u_seq } = $u_seq if $opts->{ u_seq } && ref $opts->{ u_seq } ne 'ARRAY';

        eval { require gjonativecodonlib; }
            or print STDERR "gather_codon_usage_data() failed in require gjonativecodonlib.\n"
               and return undef;

        @axes = gjonativecodonlib::genome_axes_from_seqs( $u_seq, $opts );
    }

    wantarray ? @axes : \@axes;
}


#===============================================================================
#  Produce an WWW page, or tab delimited table of the the match of a set of
#  genes to codon usages.
#
#     $html = match_to_axes( \%options )
#
#  Options:
#
#      de_novo  =>  $bool      # Calculate codon usages de_novo from source
#      ffn      =>  $fasta     # Sequences for genes and codon usage
#      format   =>  $format    # html | page | tab
#      gid      =>  $gid       # Kbase or SEED genome id, as appropriate
#      g_gid    =>  $gid       # Kbase or SEED genome id for genes
#      g_ffn    =>  $fasta     # Sequences for genes
#      g_seq    => \@seqs      # Gene sequences
#      g_source =>  $keyword   # Source of genes: KBase | Sapling | SEED
#      source   =>  $keyword   # Source of data: KBase | Sapling | SEED
#      title    =>  $title     # title for HTML page (D is from genome name)
#      u_gid    =>  $gid       # Kbase or SEED genome id for codon usages
#      u_ffn    =>  $fasta     # Sequences for codon usage
#      u_seq    => \@seqs      # Gene sequences for codon usage
#      u_source =>  $keyword   # Source of codon usages: KBase | Sapling | SEED
#
#  If separate sources are supplied for codon usages and genes to be matched
#  to them, the g_ and u_ forms should be used for both parameters. Otherwise
#  the behavior is not assured to be stable in the future.
#
#  Output formats:
#
#      html   ( $style_text, $table_text )
#      html   $style_text . $table_text
#      page   $html_page
#      tab    $tab_separated_text
#
#===============================================================================

sub match_to_axes
{
    my $opts = shift;
    $opts && ref( $opts ) eq 'HASH'
        or print STDERR "match_to_axes() called with invalid options hash.\n"
           and return '';

    my $de_novo = $opts->{ de_novo };
    my $format  = lc( $opts->{ format } || 'html' );
    my $title   = $opts->{ title } || '';

    #
    #  All counts currently come from the DNA seqs:
    #
    my $g_ffn = $opts->{ g_ffn } || $opts->{ ffn } || '';
    my $g_gid = $opts->{ g_gid } || $opts->{ gid } || '';
    my $g_seq = $opts->{ g_seq } || $opts->{ seq };

    my $g_source = '';
    if ( $g_seq && ref( $g_seq ) eq 'ARRAY' )
    {
        @$g_seq
            or print STDERR "match_to_axes() failed to get coding sequences from options."
                and return '';
    }
    elsif ( $g_ffn && -f $g_ffn )
    {
        $g_seq = gjoseqlib::read_fasta( $g_ffn );
        $g_seq && @$g_seq
            or print STDERR "match_to_axes() failed to get coding sequences from '$g_ffn'.\n"
                and return '';
    }
    elsif ( $g_gid )
    {
        $g_source = $opts->{ g_source }              ? $opts->{ g_source }
                  : $opts->{ source }                ? $opts->{ source }
                  : $g_gid =~ /^(?:kb\|)?g\.\d+$/    ? 'KBase'
                  : $g_gid =~ /^(?:fig\|)?\d+\.\d+$/ ? 'Sapling'
                  : '';
        if ( $g_source =~ /^KBase$/i )
        {
            $g_gid =~ s/^g\./kb|g./;   # add kb| to KBase genome id
            eval { require KBaseCodonUsage; }
                and $g_seq = KBaseCodonUsage::coding_sequences( $g_gid, $opts );
        }
        elsif ( $g_source =~ /^Sapling$/i )
        {
            $g_gid =~ s/^fig\|//;      # remove fig from fig genome id
            eval { require SaplingCodonUsage; }
                and $g_seq = SaplingCodonUsage::coding_sequences( $g_gid, $opts );
        }
        elsif ( $g_source =~ /^SEED$/i )
        {
            $g_gid =~ s/^fig\|//;      # remove fig from fig genome id
            eval { require SeedCodonUsage; }
                and $g_seq = SeedCodonUsage::coding_sequences( $g_gid, $opts );
        }
        else
        {
            print STDERR "match_to_axes() called with invalid source of coding sequences.\n"
                and return ''; 
        }

        $g_seq && @$g_seq
            or print STDERR "match_to_axes() failed to get coding sequences for '$g_gid' from '$g_source'.\n"
                and return ''; 
    }
    else
    {
        print STDERR "match_to_axes() called without valid source of coding sequences.\n"
            and return ''; 
    }

    my $seed_ids = grep { $_->[0] =~ /^fig\|\d+\.\d+\.peg\.\d+$/ } @$g_seq;

    my $u_ffn = $opts->{ u_ffn } || $opts->{ ffn } || '';
    my $u_gid = $opts->{ u_gid } || $opts->{ gid } || '';
    my $u_seq = $opts->{ u_seq } || $opts->{ seq };
    my $u_source = '';

    #
    #  Axes are: ( $gname, $mode,      $md_type,
    #                      $high_expr, $he_type,
    #                      $nonnative, $nn_type
    #            )
    #
    my @axes;
    if ( $u_seq && ref( $u_seq ) eq 'ARRAY' )
    {
        @$u_seq
            or print STDERR "match_to_axes() failed to get coding sequences from options."
                and return '';
        $de_novo = 1;
    }
    elsif ( $u_ffn && -f $u_ffn )
    {
        $u_seq = ( $u_ffn eq $g_ffn ) ? $g_seq : gjoseqlib::read_fasta( $u_ffn );
        $u_seq && @$u_seq
            or print STDERR "match_to_axes() failed to get coding sequences from '$u_ffn'.\n"
                and return '';
        $de_novo = 1;
    }
    elsif ( $u_gid )
    {
        $u_source = $opts->{ u_source }              ? $opts->{ u_source }
                  : $opts->{ source }                ? $opts->{ source }
                  : $u_gid =~ /^(?:kb\|)?g\.\d+$/    ? 'KBase'
                  : $u_gid =~ /^(?:fig\|)?\d+\.\d+$/ ? 'Sapling'
                  : '';

        if ( $u_source =~ /^KBase$/i )
        {
            $u_gid =~ s/^g\./kb|g./;   # add kb| to KBase genome id
        }
        elsif ( $u_source =~ /^Sapling$/i || $u_source =~ /^SEED$/i )
        {
            $u_gid =~ s/^fig\|//;      # remove fig from fig genome id
        }
        else
        {
            print STDERR "match_to_axes() called with invalid source of codon usages.\n"
                and return ''; 
        }

        #  If de novo, we need the coding sequences

        if ( $de_novo )
        {
            if ( $u_source eq $g_source && $u_gid eq $g_gid )
            {
                $u_seq = $g_seq;
            }
            elsif ( $u_source =~ /^KBase$/i )
            {
                eval { require KBaseCodonUsage; }
                    and $u_seq = KBaseCodonUsage::coding_sequences( $u_gid, $opts );
            }
            elsif ( $u_source =~ /^Sapling$/i )
            {
                eval { require SaplingCodonUsage; }
                    and $u_seq = SaplingCodonUsage::coding_sequences( $u_gid, $opts );
            }
            elsif ( $u_source =~ /^SEED$/i )
            {
                eval { require SeedCodonUsage; }
                    and $u_seq = SeedCodonUsage::coding_sequences( $u_gid, $opts );
            }

            $u_seq && @$u_seq
                or print STDERR "match_to_axes() failed to get coding sequences for '$u_gid' from '$u_source'.\n"
                    and return ''; 
        }
        else
        {
            #  We might have the sequences, and they might be useful if the
            #  usage is not yet calculated. Current behavior in KBase and
            #  Sapling is to fail if the usages do not exist, but we might
            #  change this, so:

            my $cu_opt = { %$opts };
            if ( ( $u_source eq $g_source ) && ( $u_gid eq $g_gid ) )
            {
                $cu_opt->{ dna } = $g_seq;
            }

            if ( $u_source =~ /^KBase$/i )
            {
                eval { require KBaseCodonUsage; }
                    and @axes = KBaseCodonUsage::genome_axes( $u_gid, $cu_opt );
            }
            elsif ( $u_source =~ /^Sapling$/i )
            {
                eval { require SaplingCodonUsage; }
                    and @axes = SaplingCodonUsage::genome_axes( $u_gid, $cu_opt );
            }
            elsif ( $u_source =~ /^SEED$/i )
            {
                eval { require SeedCodonUsage; }
                    and @axes = SeedCodonUsage::genome_axes( $u_gid, $cu_opt );
            }

            @axes
                or print STDERR "match_to_axes() failed to get genome axes for '$u_gid' from '$u_source'.\n"
                    and return ''; 
        }
    }
    else
    {
        print STDERR "match_to_axes() called without valid source of codon usages.\n"
            and return ''; 
    }

    #
    #  Labeled counts are: ( [ $counts, $label ], ... )
    #
    my @cnts;
    if ( $de_novo )
    {
        if ( $u_source =~ /^SEED/i )
        {
            my $cu_opt = { %$opts, dna => $u_seq, update => 1 };
            eval { require SeedCodonUsage; }
                and @axes = SeedCodonUsage::genome_axes( $u_gid, $cu_opt );
            if ( ( $u_seq eq $g_seq ) && $cu_opt->{counts} && @{$cu_opt->{counts}} )
            {
                @cnts = @{$cu_opt->{counts}};
            }
        }
        else
        {
            eval { require gjonativecodonlib; }
                or print STDERR "match_to_axes() failed in require gjonativecodonlib.\n"
                   and return '';
            @axes = gjonativecodonlib::genome_axes_from_seqs( $u_seq, $opts );
            @cnts = @{ $opts->{counts} || [] } if ( $u_source eq $g_source ) && ( $u_seq eq $g_seq );
        }
    }

    @cnts = gjocodonlib::entry_labeled_codon_count_package( @$g_seq ) if ! @cnts;

    # splice @cnts, 10;

    my ( $gname,
         $mode,      $md_type,
         $high_expr, $he_type,
         $nonnative, $nn_type ) = @axes;

    #  Output data:

    my $table_styles = '';
    my @table_html   = ();

    #  Arrays for per gene data:

    my ( @id_def, @modal, @native, @nonnative );
    if ( $mode )
    {
        my $show_modal = 1;
        my $md_opt = { %$opts, label => 'Genome<BR />mode<BR />P-value' };
        @modal = $show_modal ? freq_match_table_column( \@cnts, $mode, $md_opt ) : ('') x (@cnts+2);

        my $he_opt = { %$opts, xmin => -0.1, hue1 => 2.00, hue2 => -0.50, label => 'Native axis<BR />match' };
        @native    = $he_type   ? axis_match_table_columns( \@cnts, $mode, $high_expr, $he_opt ) : ('') x (@cnts+2);

        my $nn_opt = { %$opts, xmin => -0.1, hue1 => 2.00, hue2 =>  4.50, label => 'Nonnative<BR />axis match' };
        @nonnative = $nonnative ? axis_match_table_columns( \@cnts, $mode, $nonnative, $nn_opt ) : ('') x (@cnts+2);

        $opts->{ id_proc } = \&fid_link;
        @id_def = id_def_table_columns( [ map{$_->[1]} @cnts ], $opts );

        if ( $format eq 'tab' )
        {
            my @table;
            push @table, join( "\t", ( $show_modal ?   'Genome mode P-value'                                      : () ),
                                     ( $he_type    ? ( 'Native axis match x',    'Native axis match P-value' )    : () ),
                                     ( $nonnative  ? ( 'Nonnative axis match x', 'Nonnative axis match P-value' ) : () ),
                                                     ( 'ID',                     'Definition' )
                             ),
                  "\n";
            for ( my $i = 0; $i < @cnts; $i++ )
            {
                push @table, join( "\t", ( $show_modal ?    $modal[$i]       : () ),
                                         ( $he_type    ? @{ $native[$i] }    : () ),
                                         ( $nonnative  ? @{ $nonnative[$i] } : () ),
                                                         @{ $id_def[$i] }
                                 ),
                             "\n";
            }

            return join( '', @table );
        }

        push @table_html, "<A Name=Codon_usage_table_top></A>\n",
                          $seed_ids ? codon_usage_table_link_select_1() : (),
                          codon_usage_columns_to_html( \@modal, \@native, \@nonnative, \@id_def ),
                          $seed_ids ? codon_usage_table_link_select_2() : (),
                          <<Table_Suffix;

<A Name=Codon_usage_table_explanation></A>
<A HRef=#Codon_usage_table_top>Top of table</A>
<BR />
<BR />
@{[codon_usage_table_explanation()]}
<BR />
<A HRef=#Codon_usage_table_top>Top of table</A>

Table_Suffix

        $table_styles  = codon_usage_table_styles();
        $table_styles .= codon_usage_table_scripts() if $seed_ids;
    }
    elsif ( $format eq 'tab' )
    {
        print STDERR "No codon usage data available for genome '$u_gid'.\n";
        print STDERR "Try -d flag for de novo calculation of native codon usage.\n";
        return '';
    }
    else
    {
        push @table_html, "<H3>No codon usage data available for genome '$u_gid'.</H3>\n",
                          "Try -d flag for de novo calculation of native codon usage.\n";
    }

    $title ||= $gname ? "$gname codon usage matches"
                      : 'Gene codon usage matches';

    #  HTML returns are:
    #
    #      ( $style, $table )
    #      $style . $table
    #      $html_page
    #
    return $format eq 'html' && wantarray ? ( $table_styles, join('', @table_html) )
         : $format eq 'html'              ? join( '', $table_styles, @table_html )
         :                                  <<"End_of_Page";
<HTML>
<HEAD>
<META http-equiv="Content-Type" content="text/html;charset=UTF-8" />
<TITLE>$title</TITLE>
$table_styles
</HEAD>
<BODY>
<H2>$title</H2>
@table_html
</BODY>
</HTML>
End_of_Page
}


sub fid_link
{
    local $_ = shift;
    /^fig\|\d+\.\d+\.peg\.\d+$/ ? qq(<A HRef="JavaScript: link_to_seed('$_'); false">$_</A>)
                                : html_esc( $_ );
}


#===============================================================================
#  Support for producing a table with codon usage match data. The table has
#  two header rows (in case other columns are to be merged with the columns
#  produced here).
#
#      $style_html = codon_usage_table_styles();
#      $html = codon_usage_columns_to_html( @columns );
#      @html = codon_usage_columns_to_html( @columns );
#
#  where each "column" is a reference to the output of one of the
#  following three routines:
#
#      @html = axis_match_table_columns( \@cnt_sets, $f0, $f1, \%opts );
#     \@html = axis_match_table_columns( \@cnt_sets, $f0, $f1, \%opts );
#
#      @html = freq_match_table_column( \@cnt_sets, $freq, \%opts );
#     \@html = freq_match_table_column( \@cnt_sets, $freq, \%opts );
#
#      @html = id_def_table_columns( \@id_def, \%opts )
#     \@html = id_def_table_columns( \@id_def, \%opts )
#
#  All of the column routines return @cnt_sets+2 rows of data: two header
#  rows and @cnt_sets data rows. All of the column routines return lines
#  of tab delimited text if $opts->{tab} is true.
#===============================================================================

sub codon_usage_table_styles
{
    return <<'End_of_Table_Styles';
<STYLE>
   /* codon usage table styles */
   TH.cut   {text-align: center; white-space: nowrap; vertical-align: text-bottom; } /* heading */
   TH.cutl  {text-align: left;   white-space: nowrap; vertical-align: text-bottom; } /* heading left */
   TD.cutp  {text-align: center; white-space: nowrap; }                              /* p-value */
   TD.cutx  {text-align: right;  white-space: nowrap; }                              /* x */
   TD.cutid {                    white-space: nowrap; }                              /* id */
</STYLE>

End_of_Table_Styles
}


sub codon_usage_table_scripts
{
    return <<'End_of_Table_Scripts';
<!-- JavaScript support for SEED links -->
<SCRIPT Language="JavaScript">
    var SEED_name = new Array;
    var SEED_url  = new Array;
    var SEED_cnt  = -1;
    // These can be reordered to suit:
    SEED_cnt++; SEED_name[SEED_cnt] = 'Pub SEED';         SEED_url[SEED_cnt] = 'http://pubseed.theseed.org';
    SEED_cnt++; SEED_name[SEED_cnt] = 'Core SEED';        SEED_url[SEED_cnt] = 'http://core.theseed.org/FIG';
    SEED_cnt++; SEED_name[SEED_cnt] = 'Open SEED';        SEED_url[SEED_cnt] = 'http://open.theseed.org/FIG';
    SEED_cnt++; SEED_name[SEED_cnt] = 'U. Chicago SEED';  SEED_url[SEED_cnt] = 'http://theseed.uchicago.edu/FIG';
    SEED_cnt++; SEED_name[SEED_cnt] = 'P SEED';           SEED_url[SEED_cnt] = 'http://pseed.theseed.org';
    SEED_cnt++; SEED_name[SEED_cnt] = 'GJO Sandbox SEED'; SEED_url[SEED_cnt] = 'http://bioseed.mcs.anl.gov/~golsen/FIG';
    SEED_cnt++; SEED_name[SEED_cnt] = '**Annotator SEED'; SEED_url[SEED_cnt] = 'http://anno-3.nmpdr.org/anno/FIG';
    SEED_cnt++; SEED_name[SEED_cnt] = '**Alien SEED';     SEED_url[SEED_cnt] = 'http://alien.life.uiuc.edu/FIG';

    function initialize_seed_menus()
    {
        var sel_1 = document.SEED_picker_1.SEED_list_1;
        var sel_2 = document.SEED_picker_2.SEED_list_2;
        for ( var i = 0; i <= SEED_cnt; i++ )
        {
            var sel = i == 0;
            sel_1.options[i] = new Option( SEED_name[i], SEED_url[i], sel, sel );
            sel_2.options[i] = new Option( SEED_name[i], SEED_url[i], sel, sel );
        }
        set_seed( 0 );
    }

    function set_seed( ind )
    {
        document.SEED_picker_1.SEED_list_1.options[ind].selected = true;
        document.SEED_picker_2.SEED_list_2.options[ind].selected = true;
        document.UsageTableForm.action = SEED_url[ind] + "/seedviewer.cgi";
    }

    function link_to_seed( fid )
    {
        var form = document.UsageTableForm;
        form.feature.value = fid;
        form.submit();
    }
</SCRIPT>
<!-- JavaScript support for SEED links -->

End_of_Table_Scripts
}


sub codon_usage_table_link_select_1
{
    return <<'End_of_Link_Select_1';

<!-- Pop-up menu to select SEED for links -->
<FORM Name="SEED_picker_1">
Direct links to the following SEED:<BR />
<SELECT Name="SEED_list_1" OnChange="set_seed(this.selectedIndex); return false"></SELECT>
<SPAN Style='font-size:75%'>SEEDs marked with ** might not be available.</SPAN><BR />
</FORM>
<BR />

<!-- UsageTableForm, which is used for the submit() -->
<!-- The Action=URL is filled in by JavaScript      -->
<FORM  Name="UsageTableForm" Target="_blank">
<INPUT Type="hidden" Name="page"    Value="Annotation" />
<INPUT Type="hidden" Name="feature" Value="fig|83333.1.peg.1" />

End_of_Link_Select_1
}


sub codon_usage_table_link_select_2
{
    return <<'End_of_Link_Select_2';
</FORM>  <!-- UsageTableForm, which is used for the submit() -->

<!-- Pop-up menu to select SEED for links -->
<FORM Name="SEED_picker_2">
Direct links to the following SEED:<BR />
<SELECT Name="SEED_list_2" OnChange="set_seed(this.selectedIndex); return false"></SELECT>
<SPAN Style='font-size:75%'>SEEDs marked with ** might not be available.</SPAN><BR />
</FORM>

<!-- Initialize the selection menus -->

<SCRIPT>initialize_seed_menus();</SCRIPT>

End_of_Link_Select_2
}


sub codon_usage_columns_to_html
{
    my ( @columns ) = @_;
    @columns && $columns[0] && ref( $columns[0] ) eq 'ARRAY' && @{$columns[0]} or return ();

    my @html;
    push @html, <<"End_of_Head";
<TABLE Class=cut>
  <CAPTION>
    Gene to Codon Usage Matches<BR />
    <A HRef=#Codon_usage_table_explanation Style="font-size: smaller; font-style: normal">(explanation of the table and background colors)</A>
  </CAPTION>
  <TABLEBODY>
End_of_Head

    push @html, join( '', "    <TR>", ( map { $_->[0] } @columns ), "</TR>\n" );
    push @html, join( '', "    <TR>", ( map { $_->[1] } @columns ), "</TR>\n" );

    my $nrow = @{ $columns[0] };
    for ( my $i = 2; $i < $nrow; $i++ )
    {
        push @html, join( '', '    <TR>', ( map { $_->[$i] } @columns ), "</TR>\n" );
    }

    push @html, <<"End_of_Tail";
  </TABLEBODY>
</TABLE>

End_of_Tail

    wantarray ? @html : join( '', @html );
}


sub codon_usage_table_explanation
{
    <<'End_of_Explanation_Table';
<TABLE Style='vertical-align: top;'>
  <CAPTION Style="text-align: left;">Codon usage table explanations and references</CAPTION>
  <TABLEBODY>
    <TR>
      <TD Style="font-weight: bold">General</TD>
      <TD>The values in the table are based on the match between the observed codon usage of each gene and one, two or three sets of expected codon usage frequencies.</TD>
    </TR>
    <TR>
      <TD>Codon usage<BR />(P-value)</TD>
      <TD>In the case of a single set of codon usage frequencies, the match is represented by the P-value from a chi-square test against the expected frequencies. The test is described in more detail in Davis & Olsen, 2010 (1). We use this measure in defining the modal codon usage, the expected codon usage frequencies with the largest number of genes not significantly different (1).</TD>
    </TR>
    <TR>
      <TD>Codon usage axis<BR />(P-value and x)</TD>
      <TD>In the case of two sets of codon usage frequencies, an axis (a line) is constructed such that it passes from the first set of frequencies through the second set of frequencies. The first set of frequencies is parameterized as <I>x</I> = 0; the second set for frequencies is parameterized as <I>x</I> = 1. The concept is described and applied to highly-expressed genes in Davis & Olsen, 2011 (2). An individual gene is evaluated in terms of the <I>x</I> coordinate on the axis that best matches its observed codon usage, and the P-value of its match to the frequencies at that value of <I>x</I>. In many analyses, the value of <I>x</I> is constrained to limit negative values. This was used with the modal codon usage and an estimate of the codon usage of highly expressed genes to define a native codon usage axis for genomes(2).<BR />
      Genes acquired by horizontal gene transfer often have a significantly different codon usage, and hence differ significantly from all native codon usages. In many genomes, the modal codon usage of the genes that do not match the native codon usage axis can be used to identify a nonnative codon usage (3), and thus a nonnative codon usage axis extending from the modal codon usage through the nonnative codon usage. A less generally applicable (but more reliable) method for identifying the codon usage of horizontally acquired genes is to examine genes present in only one of a set of closely related genomes, which we refer to as unique genes (3). This can also be used to construct an axis.</TD>
    </TR>
    <TR>
      <TD Style="font-weight: bold">Background colors</TD>
      <TD>The match of each gene to a codon usage (or to a codon usage axis) is given a background color that reflects characteristics of the match.</TD>
    </TR>
    <TR>
      <TD Style="white-space: nowrap;"><B>Luma</B><BR />(perceptual brightness)</TD>
      <TD>Matches with a higher P-value are shown on a lighter background, and the background darkens as the P-value of the match becomes lower (a worse match). In the case of a match to a single codon usage (e.g., the modal codon usage), the best matches are on a white background. In the case of an axis, the best matches are darker, so that color can be used.</TD>
    </TR>
    <TR>
      <TD><B>Hue</B></TD>
      <TD>In the case of the match to a codon usages axis, the hue reflects the coordinate of the best matching codon usage on the axis. By default, a match to the origin of the axis (normally the modal codon usage) is green. In the case of the native codon usage axis, as the match shifts toward the high expression codon usage, hue becomes redder, or even bluish red. In the case of the nonnative codon usage axis, as the match shifts toward the nonnative ("alien") codon usage, the hue becomes bluer, or even reddish blue.</TD>
    </TR>
    <TR>
      <TD><B>Saturation</B></TD>
      <TD>This is used to provide a qualitative sense of the significance of the axis position value. When the position along the axis is better defined, the color is more saturated; when the position along the axis is uncertain, the color is less saturated.</TD>
    </TR>
    <TR>
      <TD ColSpan=2 Style="font-weight: bold">References</TD>
    </TR>
    <TR>
      <TD Style='text-align: right;'>1.</TD>
      <TD>Davis, J. J., and Olsen, G. J.  2010.  Modal codon usage: Assessing the typical codon usage of a genome.  <I>Mol. Biol. Evol.</I> <B>27</B>: 800–810. [Epub ahead of print Dec. 17, 2009] (doi: 10.1093/molbev/msp281; <A HRef="http://www.ncbi.nlm.nih.gov/pubmed/20018979">PubMed</A>; <A HRef=http://www.ncbi.nlm.nih.gov/pmc/articles/PMC2839124/>PubMed Central<!-- PMC2839124 --></A>; <A HRef=http://mbe.oxfordjournals.org/content/27/4/800.full.pdf>MBE OpenAccess</A>)</TD>
    </TR>
    <TR>
      <TD Style='text-align: right;'>2.</TD>
      <TD>Davis, J. J., and Olsen, G. J.  2011.  Characterizing the native codon usages of a genome: An axis projection approach.  <I>Mol. Biol. Evol.</I> <B>28</B>: 211–221. [Epub ahead of print Aug. 2, 2010] (doi: 10.1093/molbev/msq185; <A HRef="http://www.ncbi.nlm.nih.gov/pubmed/20679093">PubMed</A>; <A HRef=http://www.ncbi.nlm.nih.gov/pmc/articles/PMC3002238/>PubMed Central<!-- PMC3002238 --></A>; <A HRef=http://mbe.oxfordjournals.org/cgi/pmidlookup?view=long&pmid=20679093>MBE OpenAccess</A>)</TD>
    </TR>
    <TR>
      <TD Style='text-align: right;'>3.</TD>
      <TD>Karberg, K. A., Olsen, G. J., and Davis, J. J. 2011. Similarity of genes horizontally acquired by <I>Escherichia coli</I> and <I>Salmonella enterica</I> is evidence of a supraspecies pangenome. <I>Proc. Natl. Acad. Sci. USA</I> <B>108</B>: 20154-20159. [Epub ahead of print Nov. 29, 2011] (doi: 10.1073/pnas.1109451108; <A HRef="http://www.ncbi.nlm.nih.gov/pubmed/22128332">PubMed</A>; <A HRef=http://www.ncbi.nlm.nih.gov/pmc/articles/PMC3250135/>PubMed Central<!-- PMC3250135 --></A>; <A HRef=http://www.pnas.org/content/108/50/20154.long>PNAS</A>)</TD>
    </TR>
  </TABLEBODY>
</TABLE>
End_of_Explanation_Table
}


#===============================================================================
#  Functions to build table columns for codon count matches to a codon usage
#  axis.
#
#      @html = axis_match_table_columns( \@cnt_sets, $f0, $f1, \%opts )
#
#  Options:
#
#      hue1    => $hue1    # hue at x = xmin (range = 0-6, 0 = red) (D = 1.80, yellowish green)
#      hue2    => $hue2    # hue at x = xmax (range = 0-6, 0 = red) (D = 4.80, bluish magenta)
#      label   => $label   # html description for the axis match columns
#      lmax    => $lmax    # lightness at pmax (D = 0.60)
#      lmin    => $lmin    # lightness at pmin (D = 0.10)
#      maxlen  => $maxlen  # limit the sequence length when calculating P-values
#      pmax    => $pmax    # upper bound of p, where lightness is ymin (D =  0.20)
#      pmin    => $pmin    # lower bound of p, where lightness is ymax (D =  0.0001)
#      xmax    => $xmax    # upper bound of x, where color is hue2 (D =  1.80)
#      xmin    => $xmin    # lower bound of x, where color is hue1 (D = -0.20)
#
#-------------------------------------------------------------------------------

sub axis_match_table_columns
{
    my ( $cnts, $f0, $f1, $opts ) = @_;
    $cnts && ref( $cnts ) eq 'ARRAY' && @$cnts or return ();
    $f0 && ref( $f0 ) eq 'ARRAY' or return ();
    $f1 && ref( $f1 ) eq 'ARRAY' or return ();
    $opts ||= {};

    my $label = defined $opts->{label} ? $opts->{label} : 'Match<BR />to axis';
    my @matches = count_sets_axis_matches( $cnts, $f0, $f1, $opts );

    my @output;
    if ( $opts->{ tab } )
    {
        @output = map { my $x = sprintf( '%.2f', $_->[0] );
                        my $p = sprintf( '%.2e', $_->[1] );
                        $p =~ s/e\+00//;
                        $p =~ s/e-0/e-/;
                        [ $x, $p ]
                      } @matches;
    }
    else
    {
        @output = ( "<TH Class=cut ColSpan=2>$label</TH><TH>&nbsp;</TH>",
                    "<TH Class=cut>x</TH><TH Class=cut>P-value</TH><TH>&nbsp;</TH>",
                    map { axis_match_table_cells( $_, $opts ) } @matches
                  );
    }

    wantarray ? @output : \@output;
}

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Match codon counts to an axis, best matching x, P(x), P(0), P(1), and
#  a label. The concept of giving p-values at 0 and 1 is that it provides
#  a qualitative sense of the 
#
#   @matches = count_sets_axis_matches( \@cnts, $freq0, $freq1, \%opts )
#  \@matches = count_sets_axis_matches( \@cnts, $freq0, $freq1, \%opts )
#
#       $match = [ $x, $p, $p_0, $p_1, $label ]
#
#  Options:
#
#      maxlen  => $maxlen  # limit the sequence length when calculating P-values
#      xmax    => $xmax    # constrain the maximum value of x
#      xmin    => $xmin    # constrain the minimum value of x
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub count_sets_axis_matches
{
    my $opts = $_[ 0] && ref($_[ 0]) eq 'HASH' ? shift :
               $_[-1] && ref($_[-1]) eq 'HASH' ? pop   : {};

    my ( $cnts, $f0, $f1 ) = @_;
    $cnts && ref( $cnts ) eq 'ARRAY' && @$cnts or return wantarray ? () : [];
    $f0   && ref( $f0 )   eq 'ARRAY' && @$f0   or return wantarray ? () : [];
    $f1   && ref( $f1 )   eq 'ARRAY' && @$f1   or return wantarray ? () : [];

    my $maxlen = $opts->{ max_len } || $opts->{ maxlen } || $opts->{ max_length }  || $opts->{ maxlength } || 0;

    my @cnt = ( @{$cnts->[0]} == 2 ) ? map { $_->[0] } @$cnts : @$cnts;
    my $lbl = 'gene000000';
    my @lbl = ( @{$cnts->[0]} == 2 ) ? map { $_->[1] } @$cnts : map { ++$lbl } @$cnts;

    my $axis_opt = {};
    $axis_opt->{ xmax }   = $opts->{ xmax } if defined $opts->{ xmax };
    $axis_opt->{ xmin }   = $opts->{ xmin } if defined $opts->{ xmin };
    $axis_opt->{ maxlen } = $maxlen;

    my @xp = gjocodonlib::codon_counts_x_and_p( $f0, $f1, $axis_opt, \@cnt );
    my @p0 = map { gjocodonlib::count_vs_freq_p_value( $_, $f0, $maxlen ) } @cnt;
    my @p1 = map { gjocodonlib::count_vs_freq_p_value( $_, $f1, $maxlen ) } @cnt;

    my @matches = map { [ @{$xp[$_]}, $p0[$_], $p1[$_], $lbl[$_] ] } ( 0 .. @$cnts-1 );

    wantarray ? @matches : \@matches;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  HTML table cells for an axis p-value.
#
#      $html_p_x_cells = axis_table_cells( \@x_p_p0_p1, \%opts )
#
#          @x_p_p0_p1 is ( $x, $p_value_at_x, $p_value_at_0, $p_value_at_1 )
#
#  Options: See axis_cell_color()
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub axis_match_table_cells
{
    my ( $x_p_p0_p1, $opts ) = @_;
    $opts ||= {};

    my ( $x, $p ) = @$x_p_p0_p1;
    my $pstr = sprintf( "%.1e", $p );
    foreach ( $pstr ) { s/e\+00//; s/e-0/e-/ }
    my $xstr = defined $x ? sprintf( "%.2f", $x ) : '';
    foreach ( $pstr, $xstr ) { s/-/−/ }   # hyphen to unicode minus sign

    my $clr = axis_match_cell_color( $x_p_p0_p1, $opts );

    "<TD Class=cutx BgColor=$clr>$xstr</TD><TD Class=cutp BgColor=$clr>$pstr</TD><TD>&nbsp</TD>";
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  HTML color spec. for an axis p-value.
#
#      $html_clr = axis_match_cell_color( \@x_p_p0_p1, \%opts )
#
#          @x_p_p0_p1 is ( $x, $p_value_at_x, $p_value_at_0, $p_value_at_1 )
#
#  Options:
#
#      hue1 => $hue1   # hue at x = xmin (range = 0-6, 0 = red) (D = 1.80, yellowish green)
#      hue2 => $hue2   # hue at x = xmax (range = 0-6, 0 = red) (D = 4.80, bluish magenta)
#      lmax => $lmax   # lightness at pmax (D = 0.60)
#      lmin => $lmin   # lightness at pmin (D = 0.10)
#      pmax => $pmax   # upper bound of p, where lightness is ymin (D =  0.20)
#      pmin => $pmin   # lower bound of p, where lightness is ymax (D =  0.0001)
#      xmax => $xmax   # upper bound of x, where color is hue2 (D =  1.80)
#      xmin => $xmin   # lower bound of x, where color is hue1 (D = -0.20)
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub axis_match_cell_color
{
    my ( $x_p_p0_p1, $opts ) = @_;

    $opts ||= {};
    my $hue1 = defined $opts->{hue1} ? $opts->{hue1} :  1.80;
    my $hue2 = defined $opts->{hue2} ? $opts->{hue2} :  4.80;
    my $lmax = defined $opts->{lmax} ? $opts->{lmax} :  0.50;
    my $lmin = defined $opts->{lmin} ? $opts->{lmin} :  0.10;
    my $pmax = defined $opts->{pmax} ? $opts->{pmax} :  0.20;
    my $pmin = defined $opts->{pmin} ? $opts->{pmin} :  0.0001;
    my $xmax = defined $opts->{xmax} ? $opts->{xmax} :  1.90;
    my $xmin = defined $opts->{xmin} ? $opts->{xmin} : -0.10;

    my ( $x, $p, $p0, $p1 ) = @$x_p_p0_p1;
    if ( ! defined $x ) { $p0 = $p1 = $p; $x = 0 }

    my $xval = $x < $xmin ? 0 : $x > $xmax ? 1 : ($x-$xmin) / ($xmax-$xmin);
    my $hue  = $hue1 + ($hue2-$hue1) * $xval;

    my ( $min, undef, $max ) = sort { $a <=> $b } map { $_ > 1e-9 ? $_ : 1e-9 } ( $p, $p0, $p1 );
    my $sat = log( $max/$min ) / log( 100 );
    $sat = 1 if $sat > 1;

    my $pval = $p > $pmax ? 1 : $p < $pmin ? 0 : 1 - log( $p/$pmax ) / log( $pmin/$pmax );
    my $lum  = $lmin + ($lmax-$lmin) * $pval;

    gjocolorlib::rgb2html( gjocolorlib::hsy2rgb( $hue/6, $sat, $lum ) );
}


#-------------------------------------------------------------------------------
#  Functions to build a table column for codon count matches to an expected
#  codon usage.
#
#      @html = freq_match_table_column( \@cnt_sets, $freq, \%opts )
#
#-------------------------------------------------------------------------------

sub freq_match_table_column
{
    my ( $cnts, $freq, $opts ) = @_;
    $cnts && ref( $cnts ) eq 'ARRAY' && @$cnts or return ();
    $freq && ref( $freq ) eq 'ARRAY' or return ();
    $opts ||= {};

    my $label = defined $opts->{label} ? $opts->{label} : 'Codon<BR />usage<BR />P-value';
    my @matches = count_sets_freq_matches( $cnts, $freq, $opts );

    my @output;
    if ( $opts->{ tab } )
    {
        @output = map { my $p = sprintf( '%.2e', $_->[0] );
                        $p =~ s/e\+00//;
                        $p =~ s/e-0/e-/;
                        $p;
                      } @matches;
    }
    else
    {
        @output = ( "<TH RowSpan=2 Class=cutc>$label</TH><TH RowSpan=2>&nbsp;</TH>",
                    '',
                     map { freq_match_table_cell( $_->[0], $opts ) } @matches
                  );
    }

    wantarray ? @output : \@output;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#   @matches = count_sets_freq_matches( \@cnts, $freq, \%opts )
#  \@matches = count_sets_freq_matches( \@cnts, $freq, \%opts )
#
#       $match = [ $p_val, $label ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub count_sets_freq_matches
{
    my $opts = $_[ 0] && ref($_[ 0]) eq 'HASH' ? shift :
               $_[-1] && ref($_[-1]) eq 'HASH' ? pop   : {};

    my ( $cnts, $freq ) = @_;

    $cnts && ref( $cnts ) eq 'ARRAY' && @$cnts or return wantarray ? () : [];
    $freq && ref( $freq ) eq 'ARRAY' && @$freq or return wantarray ? () : [];

    my $max_len = $opts->{ max_len } || $opts->{ maxlen } || $opts->{ max_length }  || $opts->{ maxlength } || 0;

    #  Ensure that we have labeled counts
    my $lbl = 'gene000000';
    $cnts = [ map { [ $_, ++$lbl ] } @$cnts ]  if @{$cnts->[0]} != 2;

    my @matches = map { [ gjocodonlib::count_vs_freq_p_value( $_->[0], $freq, $max_len ), $_->[1] ] }
                  @$cnts;

    wantarray ? @matches : \@matches;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  HTML table cells for a codon usage p-value.
#
#      $html_p_cell = freq_match_table_cell( $p, \%opts )
#
#  Options: See freq_match_cell_color()
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub freq_match_table_cell
{
    my ( $p, $opts ) = @_;
    $opts ||= {};

    my $pstr = sprintf( "%.1e", $p );
    foreach ( $pstr ) { s/e\+00//; s/e-0/e-/ }
    $pstr =~ s/-/−/;      # hyphen to unicode minus sign

    my $clr = freq_match_cell_color( $p, $opts );

    "<TD Class=cutp BgColor=$clr>$pstr</TD><TD>&nbsp</TD>";
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  HTML color spec. for a codon usage p-value.
#
#      $html_clr = freq_match_cell_color( $p, \%opts )
#
#  Options:
#
#      hue  => $hue    # hue of the cell background color (D = 2.00)
#      lmax => $lmax   # lightness at pmax (D = 1.00)
#      lmin => $lmin   # lightness at pmin (D = 0.20)
#      pmax => $pmax   # upper bound of p, where lightness is ymin (D =  0.20)
#      pmin => $pmin   # lower bound of p, where lightness is ymax (D =  0.0001)
#      sat  => $sat    # color saturation (D = 0.00, = gray scale)
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub freq_match_cell_color
{
    my ( $p, $opts ) = @_;

    $opts ||= {};
    my $hue  = defined $opts->{hue}  ? $opts->{hue}  :  2.00;
    my $lmax = defined $opts->{lmax} ? $opts->{lmax} :  1.00;
    my $lmin = defined $opts->{lmin} ? $opts->{lmin} :  0.20;
    my $pmax = defined $opts->{pmax} ? $opts->{pmax} :  0.20;
    my $pmin = defined $opts->{pmin} ? $opts->{pmin} :  0.0001;
    my $sat  = defined $opts->{sat}  ? $opts->{sat}  :  0.00;

    my $pval = $p > $pmax ? 1 : $p < $pmin ? 0 : 1 - log( $p/$pmax ) / log( $pmin/$pmax );
    my $lum  = $lmin + ($lmax-$lmin) * $pval;

    gjocolorlib::rgb2html( gjocolorlib::hsy2rgb( $hue/6, $sat, $lum ) );
}


#-------------------------------------------------------------------------------
#  Table columns for id and definition
#
#      @html = id_def_table_columns( \@id_def, \%opts )
#     \@html = id_def_table_columns( \@id_def, \%opts )
#
#      The elements in @id_def can be strings with id as first word, or array
#      references of the form [$id,$def]
#
#  Options:
#
#      def_proc => \&func   # reference to a function for processing definition
#                           #     strings to html (D = \&html_esc)
#      id_proc  => \&func   # reference to a function for processing identifier
#                           #     strings to html (D = \&html_esc)
#      lbl_proc => \&func   # reference to a function for processing both
#                           #     definition and identifier strings to html.
#                           #     A more specific function (above) takes
#                           #     precedence (D = \&html_esc)
#      no_proc  =>  $bool   # no processing, use the ids and definitions as
#                           #     supplied. Same as (lbl_proc => sub{@_}).
#                           #     Again, more specific requests take precedence.
#
#-------------------------------------------------------------------------------

sub id_def_table_columns
{
    my ( $labels, $opts ) = @_;
    $labels && ref( $labels ) eq 'ARRAY' && @$labels or return ();
    $opts ||= {};

    my @rows = map { ! defined $_         ? [ 'undef', '' ]
                   : ref($_) eq 'ARRAY'   ? [ defined($_->[0]) ? $_->[0] : 'undef',
                                              defined($_->[1]) ? $_->[1] : ''
                                            ]
                   : /^\s*(\S+)\s+(.*\S)/ ? [ $1, $2 ]
                   :                        [ $_, '' ]
                   }
                @$labels;

    return wantarray ? @rows : \@rows  if $opts->{ tab };

    my $lbl_proc = $opts->{ lbl_proc } && ref $opts->{ lbl_proc } eq 'CODE' ? $opts->{ lbl_proc }
                 : $opts->{ no_proc } ? sub { @_ } : \&html_esc;

    my $id_proc  = $opts->{ id_proc }  && ref $opts->{ id_proc }  eq 'CODE' ? $opts->{ id_proc }
                 : $lbl_proc;

    my $def_proc = $opts->{ def_proc } && ref $opts->{ def_proc } eq 'CODE' ? $opts->{ def_proc }
                 : $lbl_proc;

    my @html = ( "<TH>&nbsp;</TH><TH>&nbsp;</TH><TH>&nbsp;</TH>",
                 "<TH>ID</TH><TH>&nbsp;</TH><TH Class=cutl>Definition</TH>",
                 map { "<TD Class=cutid>$_->[0]</TD><TD>&nbsp;</TD><TD>$_->[1]</TD>" }
                     map { [ &$id_proc( $_->[0]), &$def_proc($_->[1] )] }
                     @rows
               );

    wantarray ? @html : \@html;
}


#-------------------------------------------------------------------------------
#  Table column for user-supplied data
#
#      @html = text_table_column( \@data, $title, \%opts )
#     \@html = text_table_column( \@data, $title, \%opts )
#
#      The each datum is a cell value in the table.
#      The title gets two table rows. It is used as is.
#
#  Options:
#
#      class     =>  $class  # html class for the text cells
#      no_proc   =>  $bool   # no processing; use the text string as supplied.
#                            #     Use for special text rendering or links.
#      text_proc => \&func   # reference to a function for processing the text
#                            #     strings to html (D = \&html_esc)
#
#-------------------------------------------------------------------------------

sub text_table_column
{
    my ( $data, $title, $opts ) = @_;
    $data && ref( $data ) eq 'ARRAY' && @$data or return ();
    $opts  ||= {};

    my @rows = map { $_ && ref($_) eq 'ARRAY' ? [$_->[0]] : [defined($_) ? $_ : ''] }
               @$data;

    return wantarray ? @rows : \@rows  if $opts->{ tab };

    my $text_proc = $opts->{ text_proc } && ref $opts->{ text_proc } eq 'CODE' ? $opts->{ text_proc }
                  : $opts->{ no_proc } ? sub { @_ } : \&html_esc;

    my $class = $opts->{ class } ? qq( Class="$opts->{class}") : '';

    $title = 'untitled<BR />datum' if ! defined $title;

    my @html = ( "<TH RowSpan=2>$title</TH>",
                 "",
                 map { qq(<TD$class>$_->[0]</TD>) }
                     map { &$text_proc($_->[0]) }
                     @rows
               );

    wantarray ? @html : \@html;
}


#-------------------------------------------------------------------------------
#  One or more table columns for user-supplied data:
#
#      @html = text_table_columns( \@data, $title, \@subtitles, \%opts )
#     \@html = text_table_columns( \@data, $title, \@subtitles, \%opts )
#
#      Data are [[row1_col1, row1_col2, ...], [row2_col1, row2_col2, ...], ...]
#
#      The main title is centered over the set of columns. The subtitles are
#      one per column.
#
#  Options:
#
#      text_proc => \&func   # reference to a function for processing the text
#                            #     strings to html (D = \&html_esc)
#      no_proc   =>  $bool   # no processing, use the text string as supplied.
#                            #     This is critical for special text rendering
#                            #     or links.
#
#-------------------------------------------------------------------------------

sub text_table_columns
{
    my ( $data, $title, $subtitles, $opts ) = @_;
    $data && ref( $data ) eq 'ARRAY' && @$data or return ();
    $data->[0] && ref( $data->[0] ) eq 'ARRAY' && @{$data->[0]} or return ();
    $opts ||= {};

    my $ncol = @{$data->[0]};
    my @rows;
    foreach ( @$data )
    {
        my @row;
        for ( my $i = 0; $i < $ncol; $i++ )
        {
            push @row, defined($_->[$i] ) ? $_->[$i] : '';
        }
        push @rows, \@row;
    }

    return wantarray ? @rows : \@rows  if $opts->{ tab };

    my $text_proc = $opts->{ text_proc } && ref $opts->{ text_proc } eq 'CODE' ? $opts->{ text_proc }
                  : $opts->{ no_proc } ? sub { @_ } : \&html_esc;

    my $class = $opts->{ class } ? qq( Class="$opts->{class}") : '';

    my $space   = $opts->{ nospace } ? ''    : qq(<TD>&npsp;</TD>);
    my $colspan = $opts->{ nospace } ? $ncol : 2 * $ncol - 1;

    $title = 'untitled' if ! defined $title;

    $subtitles = [ ( 1 .. $ncol ) ] unless $subtitles && ref( $subtitles ) eq 'ARRAY';
    my $subtitle = join( $space, map { qq(<TH>$_</TH>) }
                                 map { defined( $subtitles->[$_] ) ? $subtitles->[$_] : $_+1 }
                                 ( 0 .. $ncol-1 )
                       );
                                
    my @html = ( "<TH ColSpan=$colspan>$title</TH>",
                 $subtitle,
                 map { join( $space, map { qq(<TD$class>$_->[0]</TD>) }
                                     map { &$text_proc($_) }
                                     @$_
                           )
                     } @rows
               );

    wantarray ? @html : \@html;
}


sub html_esc { local $_ = shift; s/\&/&amp;/g; s/\</&lt;/g; s/\>/&gt;/g; $_ }


1;
