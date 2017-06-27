package TBLstuff;

use Data::Dumper;
use Carp;

sub current_features_of {
    my($fig,$genome,@types) = @_;

    if (! @types) { @types = ('peg','rna') }
    my @curr_features = ();
    foreach my $type (@types)
    {
	foreach my $fid ($fig->all_features($genome,$type))
	{
	    my $loc = $fig->feature_location($fid);
	    my @aliases = $fig->feature_aliases($fid);
	    push(@curr_features,[$type,$loc,{ id => $fid, aliases => \@aliases }]);
	}
    }
    return wantarray ? @curr_features : \@curr_features;
}

sub flat_tbl_to_features {
    my(@files) = @_;

    my @features = ();
    foreach my $file (@files)
    {
	if (open(TMP,"<$file"))
	{
	    while (defined($_ = <TMP>))
	    {
		chomp;
		my($fid,$loc,@aliases) = split(/\t/,$_);
		if ($fid && ($fid =~ /^fig\|\d+\.\d+\.([a-zA-Z]+)/))
		{
		    push(@features,[$1,$loc,{ id => $fid, aliases => \@aliases }]);
		}
	    }
	    close(TMP);
	}
    }
    return wantarray ? @features : \@features;
}

sub compare_sets_of_features {
    my($fig,$set1,$set2) = @_;

    my @set1 = map { my($contig,$beg,$end) = $fig->boundaries_of($_->[1]);
		     my($left,$right) = sort { $a <=> $b } ($beg,$end);
		     [1,$_,$contig,$beg,$end,$left,$right,&frame($_->[0],$beg,$end)] } @$set1;

    my @set2 = map { my($contig,$beg,$end) = $fig->boundaries_of($_->[1]);
		     my($left,$right) = sort { $a <=> $b } ($beg,$end);
		     [2,$_,$contig,$beg,$end,$left,$right,&frame($_->[0],$beg,$end)] } @$set2;

    my @merged = sort { ($a->[1]->[0] cmp $b->[1]->[0]) or  # type
                        ($a->[2] cmp $b->[2]) or            # contig
			($a->[7] <=> $b->[7]) or            # frame
			($a->[5] <=> $b->[5])               # left coord
                      } (@set1,@set2);

    my @output;
    my $x = shift @merged;
    while ($x)
    {
#	print STDERR "Looking at ",&Dumper($x);

	if (! (@merged && &comparable($x,$merged[0])))
	{
#	    print STDERR "not comparable\n";
	    push(@output,['',
			  $x->[2],             # contig
			  $x->[3] + $x->[4],   # mid*2
			  ($x->[0] == 1) ? ($x,undef) : (undef,$x)
		         ]
		 );
	    $x = shift @merged;
	}
	else
	{
	    my $y = shift @merged;
#	    print STDERR "comparable",&Dumper($y);

	    if ($x->[1]->[0] eq 'peg')
	    {
		if ($x->[4] == $y->[4])       # if ends match
		{
		    my $relation = ($x->[3] == $y->[3]) ? 'same' : 'diff-start';
		    push(@output,[$relation,
				  $x->[2],             # contig
				  $x->[3] + $x->[4],   # mid*2
				  ($x->[0] < $y->[0]) ? ($x,$y) : ($y,$x) # entries
				 ]);
		    $x = shift @merged;
		}
		else
		{
		    ($x,$y) = ($y,$x) if ($x->[6] > $y->[6]);  # flip if $y is longer

		    push(@output,['',
				  $x->[2],             # contig
				  $x->[3] + $x->[4],   # mid*2
				  ($x->[0] == 1) ? ($x,undef) : (undef,$x)
				 ]
			 );
		    $x = $y;
		}
	    }
	    elsif (&correspond($x,$y))
	    {
		my $relation = (($x->[3] == $y->[3]) && ($x->[4] == $y->[4])) ? 'same' : 'diff-ends';
		push(@output,[$relation,
			      $x->[2],             # contig
			      $x->[3] + $x->[4],   # mid*2
			      ($x->[0] < $y->[0]) ? ($x,$y) : ($y,$x) # entries
			      ]);
		$x = shift @merged;
	    }
	    else
	    {
		($x,$y) = ($y,$x) if ($x->[6] > $y->[6]);  # flip if $y is longer
		
		push(@output,['',
			      $x->[2],             # contig
			      $x->[3] + $x->[4],   # mid*2
			      ($x->[0] == 1) ? ($x,undef) : (undef,$x)
			      ]
		     );
		$x = $y;
	    }
	}
    }
    return wantarray ? @output : \@output;
}

sub comparable {
    my($x,$y) = @_;

    return (($x->[0] != $y->[0]) &&             # diff sets
	    ($x->[1]->[0] eq $y->[1]->[0]) &&   # same type
	    ($x->[2] eq $y->[2]) &&             # same contig
	    ($x->[7] == $y->[7]));              # same frame
}

sub correspond {
    my($x,$y) = @_;    # testing if two non-pegs overlap enough

    my $overlap = 1 + &FIG::min($x->[6],$y->[6]) - 
	              &FIG::max($x->[5],$y->[5]);
    my $maxln = &FIG::max(($x->[6] - $x->[5])+1, (($y->[6] - $y->[5])+1));
    return ($overlap >= (0.8 * $maxln));
}

sub frame {
    my($type,$beg,$end) = @_;

    if ($type eq 'peg')
    {
	return (($end % 3)+1) * ($end <=> $beg);
    }
    else
    {
	return ($end <=> $beg);
    }
}

1;
