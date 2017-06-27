#
# Copyright (c) 2003-2006 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
# 
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License. 
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#

package PersistentSets;;

use FIG;
use FileHandle;
use strict;
use Data::Dumper;
my $fig = new FIG;
my $dbh = $fig->seed_global_dbh();

1;

sub new {
  
  my ( $class, $self ) = @_;
  bless( $self, $class );

  return $self;
}

sub create_set {

  my ($type, $name, $owner, $desc, $validate ) = @_;

  my $cmd = "INSERT INTO feature_set (set_name, owner, set_type, description) VALUES('$name', '$owner', '$type', '$desc')";
  
  my $response;
  eval {
  	$response = $dbh->SQL($cmd);	 
  };

  if ($@ =~ /Duplicate/i) {
	return;
  } else {
	return $name;
  }
}

sub enumerate_sets_by_owner
{
    my($owner) = @_;
    my $cmd = "SELECT set_name from feature_set where owner = \'$owner\'"; 
    my $res = $dbh->SQL($cmd);
    my @sets;
    for my $set (@$res) {
	push (@sets, $set->[0]);
    }
    return \@sets;
}

sub type_of_set
{
    my($name, $owner) = @_;
    my $cmd = "SELECT set_type FROM feature_set where set_name = \'$name\' and owner = \'$owner\'";
    my $res = $dbh->SQL($cmd);
    return (@$res == 1) ? $res->[0]->[0] : undef;

    #
    # Return type, or undef if doesn't exist
    #
}



sub put_to_set {
	my ($name, $owner, $items, $validate) = @_;


        my $res;
	foreach my $id (@$items) {
		my $cmd = "INSERT INTO feature_set_entry (set_name, owner, feature_id) VALUES('$name', '$owner', '$id')";
		eval {
			$res = $dbh->SQL($cmd);
	        };
		if ($@ =~ /foreign key constraint fails/) {
			return;
		}
	}
	return 1;
}

sub delete_from_set {
	my ($name, $owner, $items, $validate) = @_;


        my $res;
	foreach my $id (@$items) {
		my $cmd = "DELETE FROM feature_set_entry WHERE set_name = \'$name\' and owner = \'$owner\' and feature_id = \'$id\'"; 
		eval {
			$res = $dbh->SQL($cmd);
	        };
		if ($@ =~ /foreign key constraint fails/) {
			return;
		}
	}
	return 1;
}
sub get_set {
	my ($name, $owner) = @_;

	my $res = $dbh->SQL("SELECT feature_id FROM feature_set_entry WHERE set_name = \'$name\' and owner = \'$owner\'");
        my @fids;
	for my $id (@$res) {
		push (@fids, $id->[0]);
	}
	return \@fids;
}
	
	
sub delete_set {
	my ($name, $owner) = @_;
        my $ret = "";

	eval {
		my $res = $dbh->SQL("DELETE from feature_set_entry WHERE set_name = \'$name\' and owner = \'$owner\'");
	};

	my $res = $dbh->SQL("DELETE from feature_set WHERE set_name = \'$name\' and owner = \'$owner\'");
	return $ret;
}		
