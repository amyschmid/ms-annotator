# -*- perl -*-
########################################################################
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
########################################################################

package BinarySearch;

sub binary_search {
    my($xL,$x) = @_;

    my $l   = 0;
    my $h   = @$xL - 1;

    while ($l < $h)
    {
	$m = int(($l+$h)/2);
	if ($xL->[$m] >= $x)
	{
	    $h = $m;
	}
	else
	{
	    $l = $m+1;
	}
    }
    return $l;
}

1;
