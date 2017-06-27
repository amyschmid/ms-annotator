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

#
# Package of simple fig utility fns. Names exported to calling namespace.
#

package FIGUtilities;

use base 'Exporter';

@EXPORT = qw(
	     max
	     min
	     ftype
	     genome_of
	    );


sub max {
    my(@x) = @_;
    my($max,$i);

    (@x > 0) || return undef;
    $max = $x[0];
    for ($i=1; ($i < @x); $i++) {
        $max = ($max < $x[$i]) ? $x[$i] : $max;
    }
    return $max;
}

sub min {
    my(@x) = @_;
    my($min,$i);

    (@x > 0) || return undef;
    $min = $x[0];
    for ($i=1; ($i < @x); $i++) {
        $min = ($min > $x[$i]) ? $x[$i] : $min;
    }
    return $min;
}
sub ftype {
    my($feature_id) = @_;

    if ($feature_id =~ /^fig\|\d+\.\d+\.([^\.]+)/) {
        return $1;
    }
    return undef;
}

sub genome_of {
    my $prot_id = (@_ == 1) ? $_[0] : $_[1];

    if ($prot_id =~ /^fig\|(\d+\.\d+)/) { return $1; }
    return undef;
}


1;
