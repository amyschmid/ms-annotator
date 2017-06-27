#
# Package to retrieve accession numbers
#


package MapIDs;

use Carp;
use Data::Dumper;
use strict;
use warnings;

use FIG;


    

=head3 get_gi

get a gi number for a given peg id
returns -1 or -2,-3,-4 if no gi number is found or results are amibgious

=cut


sub get_gi_extended{
  my ($fig,$peg,$org) = @_;

  my $error = 0;
  my $error_code = 0;
  my $msg = "";
  my $gi_list = [];
  my @return_values = ( $error , $gi_list, $msg , $error_code );

  # initialize gi number, returns 
  # -1 no gi number found
  # -2 too many matched gis
  # -3 no gi in corresponding organism
  # -4 gi found but length is unequal


  # get all synonyms for a given id
  my $pid = $fig->maps_to_id($peg);
  my @mapped = $fig->mapped_prot_ids($pid);

  # get organism for peg
  my ($genome_id, $peg_number) = $fig->genome_and_peg_of($peg);


  # get all gi numbers from synonym list and map to organism
  my @gis;  # list of all gi synonyms for a given peg
  my @pegs; # list of all peg synonyms for a given peg
  my $synonyms = {};
  foreach my $map ( @mapped ){
    push ( @gis, $map->[0] )  if ( $map->[0] =~ m/^gi\|/ );
    push ( @pegs, $map->[0] )  if ( $map->[0] =~ m/^fig\|$genome_id/ );
    $synonyms->{ $map->[0] } = $map->[1];

  }

    
  if  ( scalar(@gis) > 0){
    
    
    # sort gis by organism
    my $org_name = {};
    foreach my $gi (@gis){
      
      if ( $org_name->{ $fig->org_of($gi) } or  $org_name->{ unknown }){

	if  ( $fig->org_of($gi) ){
	  push @{$org_name->{ $fig->org_of($gi) }} ,$gi;
	}
	else{
	  push @{$org_name->{ unknown }} ,$gi;
	}


      }
      else{

	# in different genomes
	if  ( $fig->org_of($gi) ) {
	  $org_name->{ $fig->org_of($gi) } = [$gi];
	}
	else{
	  $org_name->{ unknown } = [$gi];
	}
      }
    }


    # check genome name
    # hope that fig genome name match genome name from refseq/genbank

    my $hits = [ ] ;
    $hits = $org_name->{ $fig->genus_species( $genome_id) }  if ( defined $fig->genus_species( $genome_id) );

    if ( ref $hits and scalar @$hits ){
      
      # check for hit counts
      # resolve if more than one hit per organism

      #print scalar @$hits," hit(s): ", @$hits, "\n" ;
      
      if ( scalar @$hits > 1 ){
 
	# paralog within the same genome
	# do some magic stuff to resolve
	
	# 1. compare by length
	# 2. compare by sequence 
	# 3. compare by start and stop / position in genome



	my $pid = $fig->maps_to_id($peg);
	my @mapped = $fig->mapped_prot_ids($pid);
	
	my ($genome_id, $peg_number) = $fig->genome_and_peg_of($peg);

	
	my @gis;  # list of all gi synonyms for a given peg
	my @pegs; # list of all peg synonyms for a given peg


	
	# compare length of peg with length of hits
	my $same_length = [];
	foreach my $hit ( @$hits ){
	   
	  if ( $synonyms-> {$hit} ){  
	    push ( @$same_length, $hit) if ( $synonyms-> {$hit} == $synonyms-> {$peg} );
	  }
	  else{
	    print STDERR "ERROR, shouldn't be here\n";
	    die;
	  }
		
	}

	if ( scalar @$same_length == 1){
	  #$gi_number = $same_length->[0];
	  $error = 1;
	  @return_values = ( $error , 
			     $same_length , 
			     "gi  found for $peg in $genome_id", 1 );
	}
	elsif ( scalar @$same_length > 1){
	  $error = 0;
	  @return_values =  ( $error , $same_length , "multiple gi's with same length found for $peg" , -2 );
	  
	  # need some magic to resolve

	}
	else{
	  # hits but length is not matching
	  $error = 0;

	  @return_values =  ( $error , $hits , "no gi's length is matching $peg" , -4 );
	}


      }
      elsif( scalar @$hits == 1){
	$gi_list = $hits; 
	$return_values[1] = $gi_list; 

	if ( _compare_length($fig, $peg, $hits->[0], $synonyms) ){
	  $return_values[3] = 1;
	}
	else{
	  $error = 0;
	  @return_values =  ( $error , $hits , "gi found for $peg and $genome_id, but length does not match" , -4 ) ;
	  # return -4;
	}
      }
      else{
	print STDERR "ERROR, shoudn't be here \n";
	exit;
      }
      
    }
    elsif ( ref $hits ){
      print STDERR scalar @$hits," hit(s): ",$hits, "\n" 
    }
    else{
      print STDERR "no gi for $peg in ".$fig->genus_species( $genome_id)." \n";
      $return_values[2] = "no gi found for $peg in $genome_id";
      $return_values[3] = -3; 
      #$gi_number = -3;
    }
    
  }
  else{
    $return_values[2] = "no gi's found for $peg at all";
    $return_values[3] = -1;
    #print STDERR "no gis for $peg \n";
  }

  return  @return_values;
}



sub get_gi{
  my ($fig,$peg,$org) = @_;

  # initialize gi number, returns 
  # -1 no gi number found
  # -2 too many matched gis
  # -3 no gi in corresponding organism
  # -4 gi found but length is unequal

  my $gi_number = -1;

  # get all synonyms for a given id
  my $pid = $fig->maps_to_id($peg);
  my @mapped = $fig->mapped_prot_ids($pid);

  # get organism for peg
  my ($genome_id, $peg_number) = $fig->genome_and_peg_of($peg);


  # get all gi numbers from synonym list and map to organism
  my @gis;  # list of all gi synonyms for a given peg
  my @pegs; # list of all peg synonyms for a given peg
  my $synonyms = {};
  foreach my $map ( @mapped ){
    push ( @gis, $map->[0] )  if ( $map->[0] =~ m/^gi\|/ );
    push ( @pegs, $map->[0] )  if ( $map->[0] =~ m/^fig\|$genome_id/ );
    $synonyms->{ $map->[0] } = $map->[1];

  }

    
  if  ( scalar(@gis) > 0){
    
    
    # sort gis by organism
    my $org_name = {};
    foreach my $gi (@gis){
      
      if ( $org_name->{ $fig->org_of($gi) } or  $org_name->{ unknown }){

	if  ( $fig->org_of($gi) ){
	  push @{$org_name->{ $fig->org_of($gi) }} ,$gi;
	}
	else{
	  push @{$org_name->{ unknown }} ,$gi;
	}


      }
      else{

	# in different genomes
	if  ( $fig->org_of($gi) ) {
	  $org_name->{ $fig->org_of($gi) } = [$gi];
	}
	else{
	  $org_name->{ unknown } = [$gi];
	}
      }
    }


    # check genome name
    # hope that fig genome name match genome name from refseq/genbank

    my $hits = [ ] ;
    $hits = $org_name->{ $fig->genus_species( $genome_id) }  if ( defined $fig->genus_species( $genome_id) );

    if ( ref $hits and scalar @$hits ){
      
      # check for hit counts
      # resolve if more than one hit per organism

      #print scalar @$hits," hit(s): ", @$hits, "\n" ;
      
      if ( scalar @$hits > 1 ){
 
	# paralog within the same genome
	# do some magic stuff to resolve
	
	# 1. compare by length
	# 2. compare by sequence 
	# 3. compare by start and stop / position in genome



	my $pid = $fig->maps_to_id($peg);
	my @mapped = $fig->mapped_prot_ids($pid);
	
	my ($genome_id, $peg_number) = $fig->genome_and_peg_of($peg);

	
	my @gis;  # list of all gi synonyms for a given peg
	my @pegs; # list of all peg synonyms for a given peg


	
	# compare length of peg with length of hits
	my $same_length = [];
	foreach my $hit ( @$hits ){
	   
	  if ( $synonyms-> {$hit} ){  
	    push ( @$same_length, $hit) if ( $synonyms-> {$hit} == $synonyms-> {$peg} );
	  }
	  else{
	    print STDERR "ERROR, shouldn't be here\n";
	    die;
	  }
		
	}

	if ( scalar @$same_length == 1){
	  $gi_number = $same_length->[0];
	}
	else{
	  # more magic stuff
	  return -2 ;
	}


      }
      elsif( scalar @$hits == 1){
	if ( _compare_length($fig, $peg, $hits->[0], $synonyms) ){
	  $gi_number = $hits->[0];
	}
	else{
	  return -4;
	}
      }
      else{
	print STDERR "ERROR, shoudn't be here \n";
	exit;
      }
      
    }
    elsif ( ref $hits ){
      print STDERR scalar @$hits," hit(s): ",$hits, "\n" 
    }
    else{
      print STDERR "no gi for $peg in ".$fig->genus_species( $genome_id)." \n";
      $gi_number = -3;
    }
    
  }
  else{
    print STDERR "no gis for $peg \n";
  }

  return $gi_number;
}





sub _compare_length{
  my ($fig, $peg, $gi, $synonyms) = @_;
  
  if (defined $synonyms and ref $synonyms) {
     return $synonyms->{ $peg } if ( $synonyms->{ $peg } == $synonyms->{ $gi } );
  }
  else{

    my $pid = $fig->maps_to_id($peg);
    my @mapped = $fig->mapped_prot_ids($pid);
	
    my ($genome_id, $peg_number) = $fig->genome_and_peg_of($peg);

    my $synonyms = {};
    
    foreach my $map ( @mapped ){
      $synonyms->{ $map->[0] } = $map->[1];
    }
    
    return $synonyms->{ $peg } if ( $synonyms->{ $peg } == $synonyms->{ $gi } );

  }
  return -1
}

1;
