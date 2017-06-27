package ComparedRegions;

1;

use strict;
use warnings;

use Tracer;
use BasicLocation;

sub get_compared_regions {
  my ($params) = @_;

  # check parameters
  my $fig = $params->{fig} || return undef;
  my $peg = $params->{id} || return undef;
  my $is_sprout = $params->{is_sprout} || 0;
  my $region_size = $params->{region_size} || 16000;
  my $number_of_genomes = $params->{number_of_genomes} || 5;

  # initialize data variable
  my $data = [];

  # get the n pegs closest to the one passed
  my @closest_pegs = &get_closest_pegs($fig, $peg, $is_sprout, $number_of_genomes);
  unshift(@closest_pegs, $peg);
  
  # iterate over the returned pegs
  foreach my $peg (@closest_pegs) { 
    my $loc = $fig->feature_location($peg);
    my $genome = $fig->genome_of($peg);
    my ($contig,$beg,$end) = $fig->boundaries_of($loc);
    if ($contig && $beg && $end) {
      my $mid = int(($beg + $end) / 2);
      my $min = int($mid - ($region_size / 2));
      my $max = int($mid + ($region_size / 2));
      my $features = [];
      my $feature_ids = $fig->all_features_detailed($genome, $min, $max, $contig);
      # "feature_ids" now contains a list of tuples. Each tuple consists of nine
      # elements: (0) the feature ID, (1) the feature location (as a comma-delimited
      # list of location specifiers), (2) the feature aliases (as a comma-delimited
      # list of named aliases), (3) the feature type, (4) the leftmost index of the
      # feature's leftmost location, (5) the rightmost index of the feature's
      # rightmost location, (6) the current functional assignment, (7) the user who
      # made the assignment, and (8) the quality of the assignment (which is usually a space).
      foreach my $featureTuple (@$feature_ids) {
	my $floc = $featureTuple->[1];
	my ($contig1,$beg1,$end1) = $fig->boundaries_of($floc);
	$beg1 = &in_bounds($min,$max,$beg1);
	$end1 = &in_bounds($min,$max,$end1);
	push(@$features, { 'start' => $beg1,
			   'stop' => $end1,
			   'id' => $featureTuple->[0] });
      }
      push(@$data, { 'features' => $features,
		     'contig' => $contig,
		     'offset' => $mid - 8000 });
    }
  }

  # return the data
  return $data;
}

sub get_scan_for_matches_pattern {
    my($params) = @_;
    # get scan_for_matches pattern from the 'fasta' file

    # parse input file name
    my $file = $params->{'file'} || return undef;
    if ($file =~ /^([a-z0-9]+)$/ or $file =~ /^tmp_([a-z0-9]+)\.cache$/) { 
	$file = 'tmp_' . $1 . '.fasta';
    } else {
	return undef;
    }

    # add path
    $file = "$FIG_Config::temp/$file";
    # check if file exists
    (-e $file) || return undef;

    my $pattern = '';
    my $line;

    open(PAT, "<$file") or die "could not open file '$file': $!";
    while (defined($line = <PAT>)) {
	#chomp $line;
	$pattern .= $line;
    }
    close(PAT) or die "could not close file '$file': $!";

    return $pattern;
}

sub get_scan_for_matches_hits {
    my($params) = @_;
    # get Bruce's hit locations

    my $fig  = $params->{'fig'}  || return undef;
    my $file = $params->{'file'} || return undef;

    # parse input file name
    if ($file =~ /^[a-z0-9]+$/) {
	$file = 'tmp_' . $file . '.cache';
    }

    # add path
    $file = "$FIG_Config::temp/$file";
    # check if file exists
    (-e $file) || return undef;
    my($line, %locations);
    Open(\*HITS, "<$file");
    $line = <HITS>;  # ignore column header line
    while (defined($line = <HITS>)) {
	my($hit) = split(/\s+/, $line);
        Trace("Hit string is $hit.") if T(3);
        my $locObject = BasicLocation->new($hit);
        my $object = $locObject->Contig;
	if ($object =~ /^fig\|/) {
	    # output from protein sequence scan
	    my($org_id, $offset, $ln) = ($fig->genome_of($object), $locObject->Begin, $locObject->Length);

	    my $fid = $object;
	    my $loc = $fig->feature_location($fid);

	    if (not $fig->is_deleted_fid($fid))
	    {
		my($contig,$beg,$end) = $fig->boundaries_of($loc);
		
		my($hit_beg, $hit_end);
		
		if ( $beg <= $end ) {
		    $hit_beg = $beg + ($offset * 3);
		    $hit_end = $hit_beg + ($ln * 3);
		} else {
		    $hit_beg = $beg - ($offset * 3);
		    $hit_end = $hit_beg - ($ln * 3);
		}
		
		push @{$locations{$org_id}{$contig}}, [$hit_beg, $hit_end];
	    }
	} else {
	    # output from DNA scan
	    # this will need to be cleaned up depending on the format Bruce puts the output in
	    my($org_id) = split(":", $hit);
	    my($contig, $beg, $end) = ($locObject->Contig, $locObject->Begin, $locObject->EndPoint);
	    push @{$locations{$org_id}{$contig}}, [$beg, $end];
	}
    }
    close(HITS) or Confess("could not close file '$file': $!");
    return \%locations;
}

sub add_hits_in_regions {
    my($fig, $regions, $patscan_hits) = @_;
    # find scan_for_matches hits (from $patscan_hits) which overlap the regions 
    # containing the closest pegs (from $peg_regions)
    my @regionKeys = keys %$regions;
    Trace("Adding hits for " . scalar(@regionKeys) . " regions.") if T(3);
    # Keep in here a list of the organisms that had hits.
    my %hitOrgs = ();
    # should probably sort regions and perform search intelligently
    foreach my $org_id (@regionKeys) {
        Trace("Finding hits for $org_id.") if T(3);
	foreach my $contig (keys %{$regions->{$org_id}}) {
            Trace("Finding hits for $contig.") if T(3);
	    if (exists $patscan_hits->{$org_id} and exists $patscan_hits->{$org_id}{$contig}) {
                Trace("Hits found on $contig.") if T(3);
                $hitOrgs{$org_id}{$contig} = 1;
		foreach my $region (@{$regions->{$org_id}{$contig}}) {
		    my($reg_beg, $reg_end) = ($region->{'reg_beg'}, $region->{'reg_end'});
		    # build up list of hits which overlap the region
		    my $overlapping_hits = [];
		    foreach my $hit (@{$patscan_hits->{$org_id}{$contig}}) {
			my($hit_beg, $hit_end) = @$hit;
			if (FIG::between($reg_beg, $hit_beg, $reg_end) or FIG::between($reg_beg, $hit_end, $reg_end)) {
			    push @$overlapping_hits, [$hit_beg, $hit_end];
			}
		    }
                    Trace(scalar(@$overlapping_hits) . " overlapping hits found between $reg_beg and $reg_end.") if T(3);
		    if (@$overlapping_hits) {
			# add the overlapping hits in the region
			$region->{'hits'} = $overlapping_hits;
		    }
		}
	    }
	}
    }
    # Now delete the unused genomes and contigs.
    for my $org_id (@regionKeys) {
        if (! exists $hitOrgs{$org_id}) {
            delete $regions->{$org_id};
        } else {
            my $contigHash = $regions->{$org_id};
            my @contigKeys = keys %{$contigHash};
            for my $contig (@contigKeys) {
                if (! exists $hitOrgs{$org_id}->{$contig}) {
                    delete $contigHash->{$contig};
                }
            }
        }
    }
    return $regions;
}

sub add_features_in_regions {
    my($fig, $regions) = @_;
    # add features in region to data structure containing closest pegs
    my @regionList = keys %$regions;
    Trace("Looking for features in " . scalar(@regionList) . " regions.") if T(3);
    foreach my $org_id (@regionList) {
        Trace("Processing genome $org_id.") if T(3);
	foreach my $contig (keys %{$regions->{$org_id}}) {
            Trace("Processing contig $contig.") if T(3);
	    foreach my $region (@{$regions->{$org_id}{$contig}}) {
		# get closest peg and boundaries of region
		my $peg = $region->{'peg'};
		my $min = $region->{'reg_beg'};
		my $max = $region->{'reg_end'};
                Trace("Region of interest is with $peg from $min to $max.") if T(3);
		# get list of features which fall in this region
		my($feature_ids) = $fig->genes_in_region($fig->genome_of($peg),$contig,$min,$max);

		# make up a list of all these features
		my $features = [];
		foreach my $fid (@$feature_ids) {
		    my $floc = $fig->feature_location($fid);
		    my ($contig1,$beg1,$end1) = $fig->boundaries_of($floc);
		    $beg1 = &in_bounds($min,$max,$beg1);
		    $end1 = &in_bounds($min,$max,$end1);
		    push(@$features, { 'feat_beg' => $beg1,
				       'feat_end' => $end1,
				       'feat_id'  => $fid });
		}
                Trace(scalar(@$features) . " features found in region of interest.") if T(3);
		# add the feature data to the region
		$region->{'features'} = $features;
	    }
	}
    }
    Trace("Completed features-in-regions process.") if T(3);
    return $regions;
}

sub sort_regions {
    my($fig, $regions) = @_;

    # sort regions based on location on the contig, regardless of strand
    # i.e. sort on the 'left-most' location of the region on the contig
    foreach my $org_id (keys %$regions) {
	foreach my $contig (keys %{$regions->{$org_id}}) {
	    my $contig_regions = $regions->{$org_id}{$contig};

	    if (@$contig_regions > 1) {
		my @sorted_regions = map {$_->[0]} 
		                       sort {$a->[1] <=> $b->[1]} 
		                         map {[$_, $fig->min($_->{'reg_beg'}, $_->{'reg_end'})]} 
		                           @$contig_regions;

		$regions->{$org_id}{$contig} = \@sorted_regions;
	    }
	}
    }

    return $regions;
}

sub collapse_regions {
    my($fig, $regions, $window_size) = @_;
    # collapse regions which display regions which show basically the same information
    # if two (or more) regions:
    # a. overlap by more than half the region size, and
    # b. the pattern match is located entirely within the overlap,
    # only one of the regions will be retained for display. 
    # since the regions are centred on the 'close' peg, this should give a reasonable 
    # neighborhood. 
    # if regions get collapsed, the region displayed is the 'left-most' on the contig.

    my $half_region = 0.5 * $window_size;

    foreach my $org_id (keys %$regions) {
	foreach my $contig (keys %{$regions->{$org_id}}) {
	    my $contig_regions = $regions->{$org_id}{$contig};

	    if (@$contig_regions > 1) {
		# hash for index of regions which should not be displayed
		my %discard;
		for (my $i = 0; $i < @$contig_regions; $i++) {
		    for (my $j = ($i+1); $j < @$contig_regions; $j++) {
			my $overlap = &regions_overlap($contig_regions->[$i], $contig_regions->[$j]);

			if ($overlap and
			    ($overlap > $half_region) and 
			    &all_hits_overlap_region($contig_regions->[$i], $contig_regions->[$j]{'hits'})) 
			{
			    # region i display contains all relevant details from region j,
			    # region j can be discarded.

			    $discard{$j} = 1;
			}
			else
			{
			    # region i display does not contain all relevant details from region j,
			    # region j needs to be kept.
			    # next value of $i needs to be $j
			    $i = $j - 1;
			    # set $j so that we exit second loop
			    $j = @$contig_regions;
			}
		    }
		}

		my @keep = grep {not exists $discard{$_}} (0..$#{$contig_regions});
		$regions->{$org_id}{$contig} = [@$contig_regions[@keep]];
	    }
	}
    }
    return $regions;
}

sub all_hits_overlap_region {
    my($region, $hits) = @_;
    # Check whether ALL hits overlap the region, if yes return 1, if no return 0
    # Return 1 if no hits present
    # This will have problems for hits which are longer than the region displayed
    
    my($reg_beg, $reg_end) = ($region->{'reg_beg'}, $region->{'reg_end'});
    
    foreach my $hit (@$hits) {
	my($hit_beg, $hit_end) = sort {$a <=> $b} @$hit;
	# get length of hit
	my $hit_ln = $hit_end - $hit_beg + 1;
	if (&overlap($reg_beg, $reg_end, $hit_beg, $hit_end) < $hit_ln) {
	    # overlap is less than length of hit
	    return 0;
	}
    }

    # all hits overlap the region
    return 1;
}

sub regions_overlap {
    my($r1, $r2) = @_;
    # return overlap in bp between two regions
    return &overlap($r1->{'reg_beg'}, $r1->{'reg_end'}, $r2->{'reg_beg'}, $r2->{'reg_end'}); 
}

sub overlap {
    my($x1, $x2, $y1, $y2) = @_;
    # return 1 if regions [$x1,$x2] and [$y1,$y2] overlap, otherwise return 0

    my $overlap = 0;
    ($x1, $x2) = sort {$a <=> $b} ($x1, $x2);
    ($y1, $y2) = sort {$a <=> $b} ($y1, $y2);

    if (($x2 < $y1) or ($y2 < $x1)) {
	$overlap = 0;
    } elsif ($x1 <= $y1) {
	if ($y2 <= $x2) {
	    $overlap = $y2 - $y1 + 1;
	} else {
	    $overlap = $x2 - $y1 + 1;
	}
    } elsif ($y1 <= $x1) {
	if ($x2 <= $y2) {
	    $overlap = $x2 - $x1 + 1;
	} else {
	    $overlap = $y2 - $x1 + 1;
	}
    }

    return $overlap;
}

sub closest_peg_regions {
    my($params) = @_;

    # check parameters
    my $fig          = $params->{'fig'} || return undef;
    my $closest_pegs = $params->{'closest_pegs'} || return undef;
    my $window_size  = $params->{'window_size'} || return undef;
    my $half_region  = int($window_size/2);

    # initialize data variable
    my $regions = {};
    Trace(scalar(@$closest_pegs) . " closest pegs coming in.") if T(3);
    # iterate over the pegs
    foreach my $peg (@$closest_pegs) {
	# get location of peg
	my $loc = $fig->feature_location($peg);
	my($peg_contig,$peg_beg,$peg_end) = $fig->boundaries_of($loc);
	if ($peg_contig && $peg_beg && $peg_end) {
	    # get organism ID
	    my $org_id;
	    if ($peg =~ /^fig\|([^\|]+)\|/) {
		$org_id = $1;
	    } else {
		my $org_name = $fig->org_of($peg);
		$org_id      = $fig->orgid_of_orgname($org_name);
	    }

	    # find mid-point of peg
	    my $mid = int(($peg_beg + $peg_end)/2);
		
	    # add peg, peg location and region location to hash
	    push @{ $regions->{$org_id}{$peg_contig} }, {'peg'     => $peg,
							 'peg_beg' => $peg_beg,
							 'peg_end' => $peg_end,
							 'reg_beg' => ($mid - $half_region),
							 'reg_end' => ($mid + $half_region)};
	}
    }
	
    Trace(scalar(keys %$regions) . " regions found.") if T(3);
    # return regions data
    return $regions;
}

sub get_closest_pegs {
    my ($params) = @_;
    # returns the n closest pegs, sorted by taxonomy
    # check parameters
    my $fig       = $params->{'fig'} || return undef;
    my $peg       = $params->{'id'}  || return undef;
    my $n         = $params->{'number_of_genomes'} || 50000; # return ALL closest pegs
    Trace("Looking for closest peg to $peg in $n genomes.") if T(3);
    # Create a hash of legal genomes.
    my %genomeIDs = map { $_ => 1 } $fig->genomes();
    
    # get the n pegs closest to the one passed

    my($id2,$d,$peg2,$i);
    
    my @closest;
    @closest = map { $id2 = $_->id2; ($id2 =~ /^fig\|/) ? $id2 : () } $fig->sims($peg,&FIG::max(20,$n*4),1.0e-20,"fig",&FIG::max(20,$n*4));
    
    if (@closest >= ($n-1)) { 
	$#closest = $n-2 ;
    }
    my %closest = map { $_ => 1 } @closest;
    
    my $g1 = $fig->genome_of($peg);
    # there are dragons flying around...
    Trace("Checking pins.") if T(3);
    my @pinned_to = grep { ($_ ne $peg) && (! $closest{$_}) && $genomeIDs{$fig->genome_of($_)} } $fig->in_pch_pin_with($peg);
    Trace("Mapping by distance.") if T(3);
    @pinned_to = map {$_->[1] } sort { $a->[0] <=> $b->[0] } map { $peg2 = $_; $d = $fig->crude_estimate_of_distance($g1,$fig->genome_of($peg2)); [$d,$peg2] } @pinned_to;
    Trace("computing pin stuff.") if T(3);
    if (@closest == ($n-1)) {
	$#closest = ($n - 2) - &FIG::min(scalar @pinned_to,int($n/2));
	for ($i=0; ($i < @pinned_to) && (@closest < ($n-1)); $i++) {
	    if (! $closest{$pinned_to[$i]}) {
		$closest{$pinned_to[$i]} = 1;
		push(@closest,$pinned_to[$i]);
	    }
	}
    }
#    Trace("Checking for extensions.") if T(3);
#    if ($fig->possibly_truncated($peg)) {
#	push(@closest, &possible_extensions($fig, $peg, \@closest));
#    }
    Trace("Sorting by taxonomy.") if T(3);
    @closest = $fig->sort_fids_by_taxonomy(@closest);
    
    unshift(@closest, $peg);
    Trace("Returning " . scalar(@closest) . " close pegs.") if T(3);
    return \@closest;
}

sub in_bounds {
    my($min,$max,$x) = @_;

    if     ($x < $min)     { return $min }
    elsif  ($x > $max)     { return $max }
    else                   { return $x   }
}

sub possible_extensions {
  my($fig, $peg,$closest_pegs) = @_;
  my($g,$sim,$id2,$peg1,%poss);
  
  $g = &FIG::genome_of($peg);
  
  foreach $peg1 (@$closest_pegs) {
      if ($g ne $fig->genome_of($peg1)) {
	  foreach $sim ($fig->sims($peg1,500,1.0e-5,"all")) {
	      $id2 = $sim->id2;
	      if (($id2 ne $peg) && ($id2 =~ /^fig\|$g\./) && $fig->possibly_truncated($id2)) {
		  $poss{$id2} = 1;
	      }
	  }
      }
  }
  return keys(%poss);
}
