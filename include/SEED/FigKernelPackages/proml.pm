package proml;

#===============================================================================
#  A perl interface to the proml program in the PHYLIP program package
#
#     @tree_likelihood_pairs = proml( \@alignment, \%options )
#     @tree_likelihood_pairs = proml( \@alignment,  %options )
#     @tree_likelihood_pairs = proml( \%options )   # alignment must be included as option
#     @tree_likelihood_pairs = proml(  %options )   # alignment must be included as option
#
#     @alignment = array of id_seq pairs, or id_definition_seq triples
#
#-------------------------------------------------------------------------------
#  A perl interface for using proml to estimate site-specific rates of change
#
#     ( $categories, $weights ) = estimate_protein_site_rates( \@align, $tree, proml_opts )
#
#     $categories = [ [ $rate1, ... ], $site_categories ];
#
#===============================================================================
#
#  A perl interface to the proml program in the PHYLIP program package
#
#     @tree_likelihood_pairs = proml( \@alignment, \%options )
#     @tree_likelihood_pairs = proml( \@alignment,  %options )
#     @tree_likelihood_pairs = proml( \%options )   # alignment must be included as option
#     @tree_likelihood_pairs = proml(  %options )   # alignment must be included as option
#
#     @alignment = array of id_seq pairs, or id_definition_seq triples
#
#  options:
#
#    For proml:
#      alignment    => \@alignment    the way to supply the alignment as an option, rather than first param
#      alpha        => float          alpha parameter of gamma distribution (0.5 - inf)
#      categories   => [ [ rate1, ... ], site_categories ]
#      coef_of_var  => float          1/sqrt(alpha) for gamma distribution (D = 0)
#      gamma_bins   => int            number of rate categories used to approximate gamma (D=5)
#      global       => bool           global rearrangements
#      invar_frac   => 0 - 1          fraction of site that are invariant
#      jumble_seed  => odd int        jumble random seed
#      model        => model          evolution model JTT (D) | PMB | PAM
#      n_jumble     => int            number of jumbles
#      persistance  => float          persistance length of rate category
#      rate_hmm     => [ [ rate, prior_prob ] ... ]   # not implimented
#      rearrange    => [ trees ]      rearrange user trees
#      slow         => bool           more accurate but slower search (D = 0)
#      user_lengths => bool           use supplied branch lengths
#      user_trees   => [ trees ]      user trees
#      weights      => site_weights
#
#    Other:
#      keep_duplicates => bool        do not remove duplicate sequences (D = false) [NOT IMPLIMENTED]
#      program      => program        allows fully defined path
#      tmp          => directory      directory for tmp_dir (D = SeedAware::location_of_tmp())
#      tmp_dir      => directory      directory for temporary files (D = SeedAware::temporary_directory())
#      tree_format  => overbeek | gjo | fig  format of output tree
#
#  tmp_dir is created and deleted unless its name is supplied, and it already
#  exists.
#
#
#  Options that do not require other data:
#    G (global search toggle)
#    L (user lengths toggle)
#    P (JTT / PMB / PAM cycle)
#    S (slow and accurate)
#    U (requires intree file)
#    W (requires weights file)
#
#  Some option data input orders:
#
#  J
#  Seed
#  N reps
#  Y
#
#  R
#  Y
#  Coefficient of variation
#  Rate categories
#  Spurious random seed
#
#  R
#  R
#  Y
#  Coefficient of variation
#  Gamma rate categories + 1
#  Fraction invariant
#  Spurious random seed
#
#  C (requires categories file)
#  N cat
#  Rate values (n of them)

use SeedAware;
use Data::Dumper;

use strict;
use gjonewicklib qw( gjonewick_to_overbeek
                     newick_is_unrooted
                     newick_relabel_nodes
                     newick_rescale_branches
                     newick_tree_length
                     overbeek_to_gjonewick
                     parse_newick_tree_str
                     strNewickTree
                     uproot_newick
                   );

sub proml
{
    my $align;
    if ( ref( $_[0] ) eq 'ARRAY' )
    {
        $align = shift @_;
        ( $align && ( ref( $align ) eq 'ARRAY' ) )
           || ( ( print STDERR "proml::proml() called without alignment\n" )
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
    #  Process proml options:
    #---------------------------------------------------------------------------

    #  [ [ cat_rate1, ... ], site_categories ]
    #  Original format expected first field to be number of categories (which
    #  is redundant).  Handling that form is what the shift if all about.

    my $categories   = $options{ categories };  # [ [ cat_rate1, ... ], site_categories ]
    if ( $categories )
    {
        if ( ref( $categories ) ne 'ARRAY'
          || ! ( ( @$categories == 2 ) || ( ( @$categories == 3 ) && ( shift @$categories ) ) )
          || ref( $categories->[0] ) ne 'ARRAY'
           )
        {
            print STDERR "proml::proml() categories option value must be [ [ cat_rate1, ... ], site_categories ]\n";
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
        print STDERR "proml::proml() coef_of_var option value must be >= 0\n";
        return ();
    }

    my $gamma_bins   = int( $options{ gamma_bins } || ( $coef_of_var ? 5 : 2 ) );
    if ( ( $gamma_bins < 2 )  || ( $gamma_bins > 9 ) )
    {
        print STDERR "proml::proml() gamma_bins option value must be > 1 and <= 9\n";
        return ();
    }

    my $global       = $options{ global } || 0;

    my $invar_frac   = $options{ invar_frac } || 0;
    if ( $invar_frac && ( $invar_frac < 0 || $invar_frac >= 1 ) )
    {
        print STDERR "proml::proml() invar_frac option value must be >= 0 and < 1\n";
        return ();
    }

    my $n_jumble     = int( $options{ n_jumble }    || ( $options{ jumble_seed } ? 1 : 0) );
    if ( $n_jumble < 0 )
    {
        print STDERR "proml::proml() n_jumble option value must be >= 0\n";
        return ();
    }

    my $jumble_seed  = int( $options{ jumble_seed } || 4 * int( 499999999 * rand() ) + 1 );
    if ( ( $jumble_seed <= 0)  || ( $jumble_seed % 2 != 1 ) )
    {
        print STDERR "proml::proml() jumble_seed option value must be an odd number > 0\n";
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
                     :                                         'JTT';

    my $persistance  = $options{ persistance } || 0;
    if ( $persistance && ( $persistance <= 1 ) )
    {
        print STDERR "proml::proml() persistance option value must be > 1\n";
        return ();
    }

    my $rearrange    = $options{ rearrange };

    my $slow         = $options{ slow };

    my $user_lengths = $options{ user_lengths };

    my $user_trees   = $options{ user_trees } || $rearrange;

    if ( $user_trees )
    {
        if ( ( ref( $user_trees ) ne 'ARRAY' ) || ( ! @$user_trees ) )
        {
            $user_trees = undef;                      # No trees
        }
        elsif ( ref( $user_trees->[0] ) ne 'ARRAY' )  # First element not tree
        {
            print STDERR "proml::proml() user_trees or rearrange option value must be reference to list of trees\n";
            return ();
        }
    }

    my $weights      = $options{ weights };

    #---------------------------------------------------------------------------
    #  Options that are not proml options per se:
    #---------------------------------------------------------------------------

    my $program     = $options{ program } || SeedAware::executable_for( 'proml', \%options );

    my $tree_format = $options{ tree_format } =~ m/overbeek/i ? 'overbeek'
                    : $options{ tree_format } =~ m/gjo/i      ? 'gjonewick'
                    : $options{ tree_format } =~ m/fig/i      ? 'fig'
                    :                                           'overbeek'; # Default

    my ( $tmp_dir, $save_tmp ) = SeedAware::temporary_directory( \%options );

    #---------------------------------------------------------------------------
    #  Prepare data:
    #---------------------------------------------------------------------------
    #
    #  For simplicity, we will convert overbeek trees to gjo newick trees.
    #
    #      gjonewick tree node:  [ \@desc, $label, $x, \@c1, \@c2, \@c3, \@c4, \@c5 ]
    #
    #      overbeek tree node:   [ Label, DistanceToParent,
    #                              [ ParentPointer, ChildPointer1, ... ],
    #                              [ Name1\tVal1, Name2\tVal2, ... ]
    #                            ]
    #  Root node of gjonewick always has a descendent list.  If the first
    #  field of the first tree is not an array reference, they are overbeek
    #  trees.

    my @user_trees = ();
    if ( @$user_trees )
    {
        if ( ref( @$user_trees[0]->[0] ) ne 'ARRAY' )  # overbeek trees
        {
            @user_trees = map { gjonewicklib::overbeek_to_gjonewick( $_ ) }
                          @$user_trees;
        }
        else
        {
            @user_trees = map { gjonewicklib::copy_newick_tree( $_ ) }
                          @$user_trees;
        }

        # Relabel and make sure trees are unrooted:

        @user_trees = map { gjonewicklib::newick_is_unrooted( $_ ) ? $_
                                                                   : gjonewicklib::uproot_newick( $_ )
                          }
                      map { gjonewicklib::newick_relabel_nodes( $_, \%local_id ); $_ }
                      @user_trees;
    }

    #---------------------------------------------------------------------------
    #  Write the files and run the program:
    #---------------------------------------------------------------------------

    my $cwd = $ENV{ cwd } || `pwd`;
    chomp $cwd;
    chdir $tmp_dir;

    unlink 'outfile' if -f 'outfile';  # Just checking
    unlink 'outtree' if -f 'outtree';  # ditto

    &write_infile( @align ) or print STDERR "proml::proml: Could not write infile\n"
                               and chdir $cwd
                               and return ();

    open( PROML, ">params" ) or print STDERR "proml::proml: Could not open command file for $program\n"
                                and chdir $cwd
                                and return ();


    #  Start writing options for program:

    if ( $categories )
    {
        &write_categories( $categories->[1] ) or print STDERR "proml::proml: Could not write categories\n"
                                                 and chdir $cwd
                                                 and return ();
        print PROML "C\n",
                    scalar @{$categories->[0]}, "\n",
                    join( ' ', @{ $categories->[0] } ), "\n";
    }

    if ( $invar_frac || $coef_of_var )
    {
        print PROML "R\n";
        print PROML "R\n" if $invar_frac;
        print PROML "A\n", "$persistance\n" if $persistance;

    }

    print PROML "G\n" if $global;

    print PROML "J\n", "$jumble_seed\n", "$n_jumble\n" if $n_jumble;

    print PROML "P\n"    if $model =~ m/PMB/i;
    print PROML "P\nP\n" if $model =~ m/PAM/i;

    if ( @user_trees )
    {
        &write_intree( @user_trees ) or print STDERR "proml::proml: Could not write intree\n"
                                        and chdir $cwd
                                        and return ();
        print PROML "U\n";
        print PROML "V\n" if $rearrange || $global;
        print PROML "L\n" if $user_lengths && ! $rearrange && ! $global;
    }
    elsif ( $slow )  # Slow and user trees are mutually exclusive
    {
        print PROML "S\n";
    }

    if ( $weights )
    {
        &write_weights( $weights ) or print STDERR "proml::proml: Could not write weights\n"
                                      and chdir $cwd
                                      and return ();
        print PROML "W\n";
    }

    #  All the options are written, try to launch the run:

    print PROML "Y\n";

    #  Becuase of the options interface, these values have to be supplied after
    #  the Y:

    if ( $invar_frac || $coef_of_var )
    {
        if ( $invar_frac )
        {
            if ( $coef_of_var ) { $gamma_bins++ if ( $gamma_bins < 9 ) }
            else                { $gamma_bins = 2 }
        }
        print PROML "$coef_of_var\n";
        print PROML "$gamma_bins\n";
        print PROML "$invar_frac\n"    if $invar_frac;
    }

    if ( $user_trees )
    {
        print PROML "13\n";     #  Random number seed of unknown use
    }

    close PROML;

    my $redirects = { stdin  => 'params',
                      stdout => '/dev/null'
                    };
    SeedAware::system_with_redirect( $program, $redirects )
        and print STDERR "proml::proml: Failed to run '$program'.\n"
        and reurn ();

    my @likelihoods = &read_outfile();

    my @trees = gjonewicklib::read_newick_trees( 'outtree' );
    @trees or print STDERR "proml::proml: Could not read proml outtree file\n"
              and chdir $cwd
              and return ();

    #  We are done, go back to the original directory:

    chdir $cwd;

    #  Returned trees have our labels, and branch lengths that are in % change,
    #  not the more usual expected number per position:

    @trees = map { gjonewicklib::newick_relabel_nodes( $_, \%id ) } @trees;

    if ( $tree_format =~ m/overbeek/i )
    {
        @trees = map { gjonewicklib::gjonewick_to_overbeek( $_ ) } @trees;
    }

    system( '/bin/rm', -r => $tmp_dir ) if ! $save_tmp;

    return map { [ $_, shift @likelihoods ] } @trees;
}


#-------------------------------------------------------------------------------
#  A perl interface for using proml to estimate site-specific rates of change
#
#     ( $categories, $weights ) = estimate_protein_site_rates( \@align, $tree,  %proml_opts )
#     ( $categories, $weights ) = estimate_protein_site_rates( \@align, $tree, \%proml_opts )
#
#     $categories = [ [ $rate1, ... ], $site_categories ];
#
#  $alignment = [ [ id, def, seq ], ... ]
#             or
#               [ [ id, seq ], ... ]
#
#  $tree = overbeek tree or gjonewick tree
#
#  proml_opts is list of key value pairs, or reference to a hash
#-------------------------------------------------------------------------------

sub estimate_protein_site_rates
{
    my ( $align, $tree, @proml_opts ) = @_;

    my ( $seq, $id );
    my %local_id;
    my $local_id = 'seq0000000';
    my @align = map { $id = $_->[0];
                      $local_id{ $id } = ++$local_id;
                      $seq = $_->[-1];
                      $seq =~ s/[BJOUZ]/X/gi;  # Bad letters go to X
                      $seq =~ s/[^A-Z]/-/gi;   # Anything else becomes -
                      [ $local_id, $seq ]
                    } @$align;

    #  Make the tree a gjonewick tree, uproot it, and change to the local ids.

    if ( ref( $tree->[0] ) ne 'ARRAY' )   # overbeek tree
    {
        $tree = gjonewicklib::overbeek_to_gjonewick( $tree );
    }
    else
    {
        $tree = gjonewicklib::copy_newick_tree( $tree );
    }

    $tree = gjonewicklib::uproot_newick( $tree ) if ! gjonewicklib::newick_is_unrooted( $tree );

    gjonewicklib::newick_relabel_nodes( $tree, \%local_id );

    #  The minimum rate will be 1/2 change per total tree branch length.
    #  This needs to be checked for proml.  The intent is that he optimal
    #  rate for a site with one amino acid change is twice this value.

    my $kmin = 1 / ( gjonewicklib::newick_tree_length( $tree ) || 1 );

    #  Generate "rate variation" by rescaling the supplied tree.  We could use a
    #  finer grain estimator, then categorize the inferred values.  This might
    #  work slightly better (this is what DNArates currently does).

    my $f = exp( log( 2 ) / 1 );                        # Interval of 2
    my @rates = map { $kmin * $f**$_ } ( 0 .. 16 );     # kmin .. 65000 * kmin in 17 bins
    my @cat_vals = ( 1 .. 17 );
    my @trees;
    my $rate;
    foreach $rate ( @rates )
    {
        my $tr = gjonewicklib::copy_newick_tree( $tree );
        gjonewicklib::newick_rescale_branches( $tr, $rate ); # Rescales in place
        push @trees, $tr;
    }

    #  Adjust (a copy of) the proml opts:

    my %proml_opts = ( ref( $proml_opts[0] ) eq 'HASH' ) ? %{ $proml_opts[0] } : @proml_opts;

    $proml_opts{ user_lengths } =  1;
    $proml_opts{ user_trees   } = \@trees;
    $proml_opts{ tree_format  } = 'gjo';

    delete $proml_opts{ alpha       } if exists $proml_opts{ alpha       };
    delete $proml_opts{ categories  } if exists $proml_opts{ categories  };
    delete $proml_opts{ coef_of_var } if exists $proml_opts{ coef_of_var };
    delete $proml_opts{ gamma_bins  } if exists $proml_opts{ gamma_bins  };
    delete $proml_opts{ invar_frac  } if exists $proml_opts{ invar_frac  };
    delete $proml_opts{ jumble_seed } if exists $proml_opts{ jumble_seed };
    delete $proml_opts{ n_jumble    } if exists $proml_opts{ n_jumble    };
    delete $proml_opts{ rearrange   } if exists $proml_opts{ rearrange   };

    #  Work throught the sites, finding their optimal rates/categories:

    my @categories;
    my @weights;
    my $imax = length( $align[0]->[-1] );
    for ( my $i = 0; $i < $imax; $i++ )
    {
        my $inform = 0;
        my @align2 = map { my $c = substr( $_->[-1], $i, 1 );
                           $inform++ if ( $c =~ m/[ACDEFGHIKLMNPQRSTVWY]/i );
                           [ $_->[0], $c ]
                         }
                     @align;

        #  Only analyze the rate if there are 4 or more informative sequences:

        if ( $inform >= 4 )
        {
            my @results = proml::proml( \@align2, \%proml_opts );

            my ( $best ) = sort { $b->[1] <=> $a->[1] }
                           map  { [ $_, @{ shift @results }[1] ] }  # get the likelihoods
                           @cat_vals;

#           printf STDERR "%6d  %2d => %12.4f\n", $i+1, @$best; ## DEBUG ##
            push @categories, $best->[0];
            push @weights,    1;
        }
        else
        {
            push @categories, 9;
            push @weights,    0;
        }
    }

    #  Find the minimum category value to appear:

    my ( $mincat ) = sort { $a <=> $b } @categories;
    my $adjust = $mincat - 1;

    @categories = map { min( $_ - $adjust, 9 ) } @categories;
    @rates = @rates[ $adjust .. ( $adjust+8 ) ];

    #  Return category and weight data:

    ( [ \@rates, join( '', @categories ) ], join( '', @weights ) )
}


#-------------------------------------------------------------------------------
#  Auxiliary functions:
#-------------------------------------------------------------------------------

sub min { $_[0] < $_[1] ? $_[0] : $_[1] }


sub write_infile
{
    open( INFILE, '>infile' ) or return 0;
    print INFILE scalar @_, ' ', length( $_[0]->[1] ), "\n";
    foreach ( @_ ) { printf INFILE "%-10s  %s\n", @$_ }
    close( INFILE );
}


sub write_intree
{
    open( INTREE, '>intree' ) or return 0;
    print INTREE scalar @_, "\n";
    foreach ( @_ ) { print INTREE gjonewicklib::strNewickTree( $_ ), "\n" }
    close( INTREE );
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


sub read_outfile
{
    open( OUTFILE, '<outfile' ) or return ();
    my @likelihoods = map  { chomp; s/.* //; $_ }
                      grep { /^Ln Likelihood/ }
                      <OUTFILE>;
    close( OUTFILE );
    return @likelihoods;
}


1;
