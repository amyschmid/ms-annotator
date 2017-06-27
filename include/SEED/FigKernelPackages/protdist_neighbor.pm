package protdist_neighbor;

#===============================================================================
#  A perl interface to the protdist and neighbor programs in the PHYLIP
#  program package
#
#     $tree = protdist_neighbor( \@alignment, \%options )
#     $tree = protdist_neighbor( \@alignment,  %options )
#     $tree = protdist_neighbor( \%options )   # alignment must be included as option
#     $tree = protdist_neighbor(  %options )   # alignment must be included as option
#
#     [ [ dist11, dist12, ... ], [ dist21, dist22, ... ], ... ] = protdist( \@alignment, \%options )
#     [ [ dist11, dist12, ... ], [ dist21, dist22, ... ], ... ] = protdist( \@alignment,  %options )
#     [ [ dist11, dist12, ... ], [ dist21, dist22, ... ], ... ] = protdist( \%options )
#     [ [ dist11, dist12, ... ], [ dist21, dist22, ... ], ... ] = protdist(  %options )
#
#     @alignment = array of id_seq pairs, or id_definition_seq triples
#
#===============================================================================
#
#  options:
#
#    For protdist:
#      alignment    => \@alignment    the way to supply the alignment as an option, rather than first param
#      alpha        => float          alpha parameter of gamma distribution (0.5 - inf)
#      categories   => [ [ rates ], site_categories ]
#      coef_of_var  => float          1/sqrt(alpha) for gamma distribution (D = 0)
#      invar_frac   => 0 - 1          fraction of site that are invariant
#      model        => model          evolution model JTT (D) | PMB | PAM
#      persistance  => float          persistance length of rate category
#      rate_hmm     => [ [ rates ], [ probabilies ] ]
#      weights      => site_weights
#
#    For neighbor (not really):
#      jumble_seed  => odd int        jumble random seed
#
#    Other:
#      keep_duplicates => bool        do not remove duplicate sequences (D = false) [NOT IMPLIMENTED]
#      protdist     => protdist       allows fully defined path
#      neighbor     => neighbor       allows fully defined path
#      tmp          => directory      directory for tmp_dir (D = /tmp or .)
#      tmp_dir      => directory      directory for temporary files (D = $tmp/protdist_neighbor.$$)
#      tree_format  => overbeek | gjo | fig  format of output tree
#
#  tmp_dir is created and deleted unless its name is supplied, and it already
#  exists.
#
#===============================================================================


use strict;
use gjonewicklib qw( gjonewick_to_overbeek
                     newick_is_unrooted
                     newick_relabel_nodes
                     newick_tree_length
                     overbeek_to_gjonewick
                     parse_newick_tree_str
                     strNewickTree
                     uproot_newick
                   );


sub protdist_neighbor
{
    my $align;
    if ( ref( $_[0] ) eq 'ARRAY' )
    {
        $align = shift @_;
        ( $align && ( ref( $align ) eq 'ARRAY' ) )
           || ( ( print STDERR "protdist_neighbor::protdist_neighbor() called without alignment\n" )
                && ( return () )
              );
    }

    my %options;
    if ( $_[0] )
    {
        %options = ( ref( $_[0]) eq 'HASH' ) ? %{ $_[0] } : @_;
    }

    #---------------------------------------------------------------------------
    #  Work on a copy of the alignment.  Id is always first, seq is always last
    #---------------------------------------------------------------------------

    $align ||= $options{ alignment } || $options{ align };

    my ( $seq, $id );
    my %id;
    my %local_id;
    my $local_id = 'seq0000000';
    my @align = map { $id = $_->[0];
                      $local_id++;
                      $id{ $local_id } = $id;
                      $local_id{ $id } = $local_id;
                      $seq = $_->[-1];
                      $seq =~ s/[BJOUZ]/X/gi;  # Bad letters go to X
                      $seq =~ s/[^A-Z]/-/gi;   # Anything else becomes -
                      [ $local_id, $seq ]
                    } @$align;

    #---------------------------------------------------------------------------
    #  Process protdist_neighbor options:
    #---------------------------------------------------------------------------

    my $categories   = $options{ categories };  # [ [ cat_rates ], site_cats ]
    if ( $categories )
    {
        if ( ref( $categories ) ne 'ARRAY'
          || ! ( ( @$categories == 2 ) || ( ( @$categories == 3 ) && ( shift @$categories ) ) )
          || ref( $categories->[0] ) ne 'ARRAY'
           )
        {
            print STDERR "proml::proml categories option value must be [ [ cat_rate1, ... ], site_categories ]\n";
            return ();
        }

        #  Rate values cannot have very many decimal places or proml can't read it:

        @{$categories->[0]} = map { sprintf "%.6f", $_ } @{$categories->[0]};
    }

    my $coef_of_var  = $options{ coef_of_var }
                  || ( $options{ alpha } && ( $options{ alpha } > 0) && ( 1 / sqrt( $options{ alpha } ) ) )
                  ||  0;
    if ( $coef_of_var < 0 )
    {
        print STDERR "protdist_neighbor::protdist_neighbor coef_of_var option value must be >= 0\n";
        return ();
    }

    my $invar_frac   = $options{ invar_frac } || 0;
    if ( $invar_frac && ( $invar_frac < 0 || $invar_frac >= 1 ) )
    {
        print STDERR "protdist_neighbor::protdist_neighbor invar_frac option value must be >= 0 and < 1\n";
        return ();
    }

    my $jumble_seed = int( $options{ jumble_seed } ) || 0;
    if ( $jumble_seed && ( ( $jumble_seed < 0)  || ( $jumble_seed % 2 != 1 ) ) )
    {
        print STDERR "protdist_neighbor::protdist_neighbor jumble_seed option value must be an odd number > 0\n";
        return ();
    }

    my $model        = ( $options{ model } =~ m/PAM/i      ) ? 'PAM'
                     : ( $options{ model } =~ m/Dayhoff/i  ) ? 'PAM'
                     : ( $options{ model } =~ m/PMB/i      ) ? 'PMB'
                     : ( $options{ model } =~ m/Henikoff/i ) ? 'PMB'
                     : ( $options{ model } =~ m/Tillier/i  ) ? 'PMB'
                     : ( $options{ model } =~ m/JTT/i      ) ? 'JTT'
                     : ( $options{ model } =~ m/Jones/i    ) ? 'JTT'
                     : ( $options{ model } =~ m/Taylor/i   ) ? 'JTT'
                     : ( $options{ model } =~ m/Thornton/i ) ? 'JTT'
                     : ( $options{ model } =~ m/Kimura/i   ) ? 'Kimura'
                     :                                         'JTT';

    my $persistance  = $options{ persistance } || 0;
    if ( $persistance && ( $persistance <= 1 ) )
    {
        print STDERR "protdist_neighbor::protdist_neighbor persistance option value must be > 1\n";
        return ();
    }

    my $weights      = $options{ weights };


    #---------------------------------------------------------------------------
    #  Options that are not protdist_neighbor options per se:
    #---------------------------------------------------------------------------

    my $protdist    = $options{ protdist } || 'protdist';

    my $neighbor    = $options{ neighbor } || 'neighbor';

    my $tmp         = $options{ tmp };

    my $tmp_dir     = $options{ tmp_dir };

    my $tree_format = $options{ tree_format } =~ m/overbeek/i ? 'overbeek'
                    : $options{ tree_format } =~ m/gjo/i      ? 'gjonewick'
                    : $options{ tree_format } =~ m/fig/i      ? 'fig'
                    :                                           'overbeek'; # Default

    my $save_tmp    = $tmp_dir && -d $tmp_dir;
    if ( $tmp_dir )
    {
        if ( -d $tmp_dir ) { $save_tmp = 1  }
        else               { mkdir $tmp_dir }
    }
    else
    {
        $tmp = $tmp && -d  $tmp  ?  $tmp
             :         -d '/tmp' ? '/tmp'
             :                     '.';
	my $int = int( 1000000000 * rand);
        $tmp_dir = "$tmp/protdist_neighbor.$$.$int";
        mkdir $tmp_dir;
    }

    #---------------------------------------------------------------------------
    #  Write the files and run the program:
    #---------------------------------------------------------------------------

    my $cwd = $ENV{ cwd } || `pwd`;
    chomp $cwd;
    chdir $tmp_dir;

    unlink 'outfile' if -f 'outfile';  # Just checking
    unlink 'outtree' if -f 'outtree';  # ditto

    #  protdist 3.66 has a serious bug when weights and categories are both
    #  used.  So we pack our own data for this combination.  Seems to be
    #  ineffectual.

    if ( $categories && $weights )
    {
        my $mask = $weights;
        $mask =~ tr/0/\177/c;  #  Everything except 0 becomes X'FF'
        $mask =~ tr/0/\000/;   #  0 becomes X'FF'
        @align = map { my ( $id, $seq ) = @$_;
                       [ $id, pack_by_mask( $seq, $mask ) ]
                     }
                 @align;
        # Make a copy so that we do not clobber the calling program's copy
        $categories = [ @$categories ];
        $categories->[1] = pack_by_mask( $categories->[1], $mask );
        $weights = undef;
    }

    &write_infile( @align ) or print STDERR "protdist_neighbor::protdist_neighbor: Could write infile\n"
                               and chdir $cwd
                               and return ();

    open( PROTD, ">protdist_cmd" ) or print STDERR "protdist_neighbor::protdist_neighbor: Could not open command file for $protdist\n"
                                      and chdir $cwd
                                      and return ();


    #  Start writing optoins for protdist:

    if ( $categories )
    {
        &write_categories( $categories->[1] ) or print STDERR "protdist_neighbor::protdist_neighbor: Could not write categories\n"
                                                 and chdir $cwd
                                                 and return ();
        print PROTD "C\n",
                    scalar @{$categories->[0]}, "\n",
                    join( ' ', map { sprintf( "%.6f", $_ ) } @{ $categories->[0] } ), "\n";
    }

    if ( $invar_frac || $coef_of_var )
    {
        print PROTD "G\n";
        print PROTD "G\n" if $invar_frac;
        print PROTD "A\n", "$persistance\n" if $persistance;
    }

    print PROTD "P\n"       if $model =~ m/PMB/i;
    print PROTD "P\nP\n"    if $model =~ m/PAM/i;
    print PROTD "P\nP\nP\n" if $model =~ m/Kimura/i;

    if ( $weights )
    {
        &write_weights( $weights ) or print STDERR "protdist_neighbor::protdist_neighbor: Could not write weights\n"
                                      and chdir $cwd
                                      and return ();
        print PROTD "W\n";
    }

    #  All the options are written, try to lauch the run:

    print PROTD "Y\n";

    #  Becuase of the options interface, these values have to be supplied after
    #  the Y:

    if ( $invar_frac || $coef_of_var )
    {
        print PROTD "$coef_of_var\n";
        print PROTD "$invar_frac\n" if $invar_frac;
    }

    close PROTD;

    system "$protdist < protdist_cmd > /dev/null; /bin/mv -f outfile infile";
    # system "$protdist < protdist_cmd > /dev/null"; chdir $cwd; return;
    # system "$protdist < protdist_cmd > /dev/null; /bin/cp infile protdist.infile; /bin/mv -f outfile infile";

    #  Move on to neighbor:

    open( NEIGH, ">neigh_cmd" ) or print STDERR "protdist_neighbor::protdist_neighbor: Could not open neighbor command file\n"
                                and chdir $cwd
                                and return ();


    #  Start sending optoins ot program:

    print NEIGH "J\n", "$jumble_seed\n" if $jumble_seed;

    #  All the options are written, try to launch the run:

    print NEIGH "Y\n";

    close NEIGH;

    system "$neighbor < neigh_cmd > /dev/null";

    my ( $tree ) = gjonewicklib::read_newick_tree( 'outtree' );
    $tree or print STDERR "protdist_neighbor::protdist_neighbor: Could read neighbor outtree file\n"
             and chdir $cwd
             and return ();

    #  We are done, go back to the original directory:

    chdir $cwd;

    #  Returned trees have our labels:

    gjonewicklib::newick_relabel_nodes( $tree, \%id );

    if ( $tree_format =~ m/overbeek/i )
    {
        $tree = gjonewicklib::gjonewick_to_overbeek( $tree );
    }

    system "/bin/rm -r $tmp_dir" if ! $save_tmp;

    return $tree;
}

#===============================================================================
#  $distances = protdist( \@align, \%options )
#===============================================================================
sub protdist
{
    my $align;
    if ( ref( $_[0] ) eq 'ARRAY' )
    {
        $align = shift @_;
        ( $align && ( ref( $align ) eq 'ARRAY' ) )
           || ( ( print STDERR "protdist_neighbor::protdist_neighbor() called without alignment\n" )
                && ( return undef )
              );
    }

    my %options;
    if ( $_[0] )
    {
        %options = ( ref( $_[0]) eq 'HASH' ) ? %{ $_[0] } : @_;
    }

    #---------------------------------------------------------------------------
    #  Work on a copy of the alignment.  Id is always first, seq is always last
    #---------------------------------------------------------------------------

    $align ||= $options{ alignment } || $options{ align };

    my ( $seq, $id );
    my %id;
    my %local_id;
    my $local_id = 'seq0000000';
    my @align = map { $id = $_->[0];
                      $local_id++;
                      $id{ $local_id } = $id;
                      $local_id{ $id } = $local_id;
                      $seq = $_->[-1];
                      $seq =~ s/[BJOUZ]/X/gi;  # Bad letters go to X
                      $seq =~ s/[^A-Z]/-/gi;   # Anything else becomes -
                      [ $local_id, $seq ]
                    } @$align;

    #---------------------------------------------------------------------------
    #  Process protdist options:
    #---------------------------------------------------------------------------

    my $categories   = $options{ categories };  # [ [ cat_rates ], site_cats ]
    if ( $categories )
    {
        if ( ref( $categories ) ne 'ARRAY'
          || ! ( ( @$categories == 2 ) || ( ( @$categories == 3 ) && ( shift @$categories ) ) )
          || ref( $categories->[0] ) ne 'ARRAY'
           )
        {
            print STDERR "proml::proml categories option value must be [ [ cat_rate1, ... ], site_categories ]\n";
            return undef;
        }

        #  Rate values cannot have very many decimal places or proml can't read it:

        @{$categories->[0]} = map { sprintf "%.6f", $_ } @{$categories->[0]};
    }

    my $coef_of_var  = $options{ coef_of_var }
                  || ( $options{ alpha } && ( $options{ alpha } > 0) && ( 1 / sqrt( $options{ alpha } ) ) )
                  ||  0;
    if ( $coef_of_var < 0 )
    {
        print STDERR "protdist_neighbor::protdist_neighbor coef_of_var option value must be >= 0\n";
        return undef;
    }

    my $invar_frac   = $options{ invar_frac } || 0;
    if ( $invar_frac && ( $invar_frac < 0 || $invar_frac >= 1 ) )
    {
        print STDERR "protdist_neighbor::protdist_neighbor invar_frac option value must be >= 0 and < 1\n";
        return undef;
    }

    my $model        = ( $options{ model } =~ m/PAM/i      ) ? 'PAM'
                     : ( $options{ model } =~ m/Dayhoff/i  ) ? 'PAM'
                     : ( $options{ model } =~ m/PMB/i      ) ? 'PMB'
                     : ( $options{ model } =~ m/Henikoff/i ) ? 'PMB'
                     : ( $options{ model } =~ m/Tillier/i  ) ? 'PMB'
                     : ( $options{ model } =~ m/JTT/i      ) ? 'JTT'
                     : ( $options{ model } =~ m/Jones/i    ) ? 'JTT'
                     : ( $options{ model } =~ m/Taylor/i   ) ? 'JTT'
                     : ( $options{ model } =~ m/Thornton/i ) ? 'JTT'
                     : ( $options{ model } =~ m/Kimura/i   ) ? 'Kimura'
                     :                                         'JTT';

    my $persistance  = $options{ persistance } || 0;
    if ( $persistance && ( $persistance <= 1 ) )
    {
        print STDERR "protdist_neighbor::protdist_neighbor persistance option value must be > 1\n";
        return undef;
    }

    my $weights      = $options{ weights };


    #---------------------------------------------------------------------------
    #  Options that are not protdist_neighbor options per se:
    #---------------------------------------------------------------------------

    my $protdist    = $options{ protdist } || 'protdist';

    my $neighbor    = $options{ neighbor } || 'neighbor';

    my $tmp         = $options{ tmp };

    my $tmp_dir     = $options{ tmp_dir };

    my $tree_format = $options{ tree_format } =~ m/overbeek/i ? 'overbeek'
                    : $options{ tree_format } =~ m/gjo/i      ? 'gjonewick'
                    : $options{ tree_format } =~ m/fig/i      ? 'fig'
                    :                                           'overbeek'; # Default

    my $save_tmp    = $tmp_dir && -d $tmp_dir;
    if ( $tmp_dir )
    {
        if ( -d $tmp_dir ) { $save_tmp = 1  }
        else               { mkdir $tmp_dir }
    }
    else
    {
        $tmp = $tmp && -d  $tmp  ?  $tmp
             :         -d '/tmp' ? '/tmp'
             :                     '.';
	my $int = int( 1000000000 * rand);
        $tmp_dir = "$tmp/protdist_neighbor.$$.$int";
        mkdir $tmp_dir;
    }

    #---------------------------------------------------------------------------
    #  Write the files and run the program:
    #---------------------------------------------------------------------------

    my $cwd = $ENV{ cwd } || `pwd`;
    chomp $cwd;
    chdir $tmp_dir;

    unlink 'outfile' if -f 'outfile';  # Just checking
    unlink 'outtree' if -f 'outtree';  # ditto

    #  protdist 3.66 has a serious bug when weights and categories are both
    #  used.  So we pack our own data for this combination.  Seems to be
    #  ineffectual.

    if ( $categories && $weights )
    {
        my $mask = $weights;
        $mask =~ tr/0/\177/c;  #  Everything except 0 becomes X'FF'
        $mask =~ tr/0/\000/;   #  0 becomes X'FF'
        @align = map { my ( $id, $seq ) = @$_;
                       [ $id, pack_by_mask( $seq, $mask ) ]
                     }
                 @align;
        # Make a copy so that we do not clobber the calling program's copy
        $categories = [ @$categories ];
        $categories->[1] = pack_by_mask( $categories->[1], $mask );
        $weights = undef;
    }

    &write_infile( @align ) or print STDERR "protdist_neighbor::protdist_neighbor: Could write infile\n"
                               and chdir $cwd
                               and return undef;

    open( PROTD, ">protdist_cmd" ) or print STDERR "protdist_neighbor::protdist_neighbor: Could not open command file for $protdist\n"
                                      and chdir $cwd
                                      and return undef;


    #  Start writing optoins for protdist:

    if ( $categories )
    {
        &write_categories( $categories->[1] ) or print STDERR "protdist_neighbor::protdist_neighbor: Could not write categories\n"
                                                 and chdir $cwd
                                                 and return undef;
        print PROTD "C\n",
                    scalar @{$categories->[0]}, "\n",
                    join( ' ', map { sprintf( "%.6f", $_ ) } @{ $categories->[0] } ), "\n";
    }

    if ( $invar_frac || $coef_of_var )
    {
        print PROTD "G\n";
        print PROTD "G\n" if $invar_frac;
        print PROTD "A\n", "$persistance\n" if $persistance;
    }

    print PROTD "P\n"       if $model =~ m/PMB/i;
    print PROTD "P\nP\n"    if $model =~ m/PAM/i;
    print PROTD "P\nP\nP\n" if $model =~ m/Kimura/i;

    if ( $weights )
    {
        &write_weights( $weights ) or print STDERR "protdist_neighbor::protdist_neighbor: Could not write weights\n"
                                      and chdir $cwd
                                      and return undef;
        print PROTD "W\n";
    }

    #  All the options are written, try to lauch the run:

    print PROTD "Y\n";

    #  Becuase of the options interface, these values have to be supplied after
    #  the Y:

    if ( $invar_frac || $coef_of_var )
    {
        print PROTD "$coef_of_var\n";
        print PROTD "$invar_frac\n" if $invar_frac;
    }

    close PROTD;

    system "$protdist < protdist_cmd > /dev/null";

    my $distances = read_distances();
    $distances or print STDERR "protdist_neighbor::protdist: Could not read 'outfile'\n"
               and chdir $cwd
               and return undef;

    #  We are done, go back to the original directory:

    chdir $cwd;

    system "/bin/rm -r $tmp_dir" if ! $save_tmp;

    return $distances;
}


#-------------------------------------------------------------------------------
#  Auxiliary functions:
#-------------------------------------------------------------------------------

sub pack_by_mask
{
    my ( $seq, $mask ) = @_;
    $seq &= $mask;         #  Mask the string
    $seq  =~ tr/\000//d;   #  Compress out X'00'
    $seq;
}


sub write_infile
{
    open( INFILE, '>infile' ) or return 0;
    print INFILE scalar @_, ' ', length( $_[0]->[1] ), "\n";
    foreach ( @_ ) { printf INFILE "%-10s  %s\n", @$_ }
    close( INFILE );
}


sub write_categories
{
    my $categories = shift;
    open( CATEGORIES, '>categories' ) or return 0;
    print CATEGORIES "$categories\n";
    close( CATEGORIES );
}


sub write_weights
{
    my $weights = shift;
    open( WEIGHTS, '>weights' ) or return 0;
    print WEIGHTS "$weights\n";
    close( WEIGHTS );
}


sub read_distances
{
    my @distances;
    open( DISTS, '<outfile' ) or return undef;
    local $_;
    defined( $_ = <DISTS> ) or return undef;
    my ( $ndist ) = $_ =~ m/(\d+)/;
    for ( my $i = 0; $i < $ndist; $i++ )
    {
        defined( $_ = <DISTS> ) or return undef;
        my ( undef, @row ) = split;
        while ( @row < $ndist )
        {
            defined( $_ = <DISTS> ) or return undef;
            push @row, split;
        }

        push @distances, \@row;
    }
    close( DISTS );
    \@distances;
}

1;
