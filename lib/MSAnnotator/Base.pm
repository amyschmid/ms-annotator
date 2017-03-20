package MSAnnotator::Base;
use v5.10;
use strict;
use warnings;
use Carp;
use Data::Dumper;

sub import {
  strict->import;
  warnings->import;
  feature->import(':5.10');

  # Auto import Dumper, get the importing package name
  my $caller = caller(0);

  do {
    no strict 'refs';
    *{"$caller\:\:Dumper"} = *{"Data\:\:Dumper\:\:Dumper"};
    *{"$caller\:\:croak"} = *{"Carp\:\:croak"};
    *{"$caller\:\:carp"} = *{"Carp\:\:carp"};
    $| ++;
  };
}

1;
