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
# Guts of quality control for a genome based on assignments of
# ribosoma proteins
#

package RiboProtQC;
use SeedEnv;
use strict;
use Data::Dumper;

sub what_is_it {
    my($assignments) = @_;

    my @classes = ('bacterial','archaeal');

    my @bacterial = (
                   'SSU ribosomal protein S10p (S20e)',
                   'SSU ribosomal protein S11p (S14e)',
                   'SSU ribosomal protein S12p (S23e)',
                   'SSU ribosomal protein S13p (S18e)',
                   'SSU ribosomal protein S15p (S13e)',
                   'SSU ribosomal protein S16p',
                   'SSU ribosomal protein S17p (S11e)',
#                  'SSU ribosomal protein S18p',
                   'SSU ribosomal protein S19p (S15e)',
                   'SSU ribosomal protein S20p',
                   'SSU ribosomal protein S2p (SAe)',
                   'SSU ribosomal protein S3p (S3e)',
                   'SSU ribosomal protein S4p (S9e)',
                   'SSU ribosomal protein S5p (S2e)',
                   'SSU ribosomal protein S6p',
                   'SSU ribosomal protein S7p (S5e)',
                   'SSU ribosomal protein S8p (S15Ae)',
                   'SSU ribosomal protein S9p (S16e)',
                   'LSU ribosomal protein L10p (P0)',
                   'LSU ribosomal protein L11p (L12e)',
                   'LSU ribosomal protein L13p (L13Ae)',
                   'LSU ribosomal protein L14p (L23e)',
                   'LSU ribosomal protein L15p (L27Ae)',
                   'LSU ribosomal protein L16p (L10e)',
                   'LSU ribosomal protein L17p',
                   'LSU ribosomal protein L18p (L5e)',
                   'LSU ribosomal protein L19p',
                   'LSU ribosomal protein L1p (L10Ae)',
                   'LSU ribosomal protein L20p',
                   'LSU ribosomal protein L21p',
                   'LSU ribosomal protein L22p (L17e)',
                   'LSU ribosomal protein L23p (L23Ae)',
                   'LSU ribosomal protein L24p (L26e)',
                   'LSU ribosomal protein L27p',
                   'LSU ribosomal protein L29p (L35e)',
                   'LSU ribosomal protein L2p (L8e)',
                   'LSU ribosomal protein L34p',
                   'LSU ribosomal protein L35p',
                   'LSU ribosomal protein L3p (L3e)',
                   'LSU ribosomal protein L4p (L1e)',
                   'LSU ribosomal protein L5p (L11e)',
                   'LSU ribosomal protein L6p (L9e)',
                   'LSU ribosomal protein L7/L12 (P1/P2)',
                   'LSU ribosomal protein L9p'
    );
    my %bacterial = map { $_ => 1 } @bacterial;
    my @archaeal = (
                   'SSU ribosomal protein S11e (S17p)',
                   'SSU ribosomal protein S13e (S15p)',
                   'SSU ribosomal protein S14e (S11p)',
                   'SSU ribosomal protein S15Ae (S8p)',
                   'SSU ribosomal protein S15e (S19p)',
                   'SSU ribosomal protein S16e (S9p)',
                   'SSU ribosomal protein S17e',
                   'SSU ribosomal protein S18e (S13p)',
                   'SSU ribosomal protein S19e',
                   'SSU ribosomal protein S20e (S10p)',
                   'SSU ribosomal protein S23e (S12p)',
                   'SSU ribosomal protein S24e',
                   'SSU ribosomal protein S27e',
                   'SSU ribosomal protein S28e',
                   'SSU ribosomal protein S29e (S14p)',
                   'SSU ribosomal protein S2e (S5p)',
                   'SSU ribosomal protein S3Ae',
                   'SSU ribosomal protein S3e (S3p)',
                   'SSU ribosomal protein S4e',
                   'SSU ribosomal protein S5e (S7p)',
                   'SSU ribosomal protein S6e',
                   'SSU ribosomal protein S8e',
                   'SSU ribosomal protein S9e (S4p)',
                   'SSU ribosomal protein SAe (S2p)',
                   'LSU ribosomal protein L10Ae (L1p)',
                   'LSU ribosomal protein L10e (L16p)',
                   'LSU ribosomal protein L11e (L5p)',
                   'LSU ribosomal protein L13Ae (L13p)',
                   'LSU ribosomal protein L15e',
                   'LSU ribosomal protein L17e (L22p)',
                   'LSU ribosomal protein L18e',
                   'LSU ribosomal protein L19e',
                   'LSU ribosomal protein L1e (L4p)',
                   'LSU ribosomal protein L21e',
                   'LSU ribosomal protein L23Ae (L23p)',
                   'LSU ribosomal protein L23e (L14p)',
                   'LSU ribosomal protein L24e',
                   'LSU ribosomal protein L26e (L24p)',
                   'LSU ribosomal protein L27Ae (L15p)',
                   'LSU ribosomal protein L31e',
                   'LSU ribosomal protein L32e',
                   'LSU ribosomal protein L35e (L29p)',
                   'LSU ribosomal protein L37Ae',
                   'LSU ribosomal protein L37e',
                   'LSU ribosomal protein L39e',
                   'LSU ribosomal protein L3e (L3p)',
                   'LSU ribosomal protein L40e',
                   'LSU ribosomal protein L44e',
                   'LSU ribosomal protein L5e (L18p)',
                   'LSU ribosomal protein L7e (L30p)',
                   'LSU ribosomal protein L7Ae',
                   'LSU ribosomal protein L8e (L2p)',
                   'LSU ribosomal protein L9e (L6p)'
    );
    my %archaeal  = map { $_ => 1 } @archaeal;

    my @just_assignments = map { ($_ =~ /(\S[^\t]*\S)$/) ? ($1 => 1) : () } @$assignments;
    my @scores;
    foreach my $class (@classes)
    {
	my %hits;
	foreach my $func (@just_assignments)
	{
	    my @roles = SeedUtils::roles_of_function($func);
	    foreach my $role (@roles)
	    {
		if ((($class eq 'bacterial') && $bacterial{$role}) ||
		    (($class eq 'archaeal') && $archaeal{$role}))
		{
		    $hits{$role}++;
		}
	    }
	}

	my $sum = 0;
	foreach my $role (keys(%hits))
	{
	    $sum += $hits{$role};
	}
	my $ratio = $sum / (($class eq 'bacterial') ? @bacterial : @archaeal);
	push(@scores,[$class,$ratio]);
    }
    @scores = sort { (abs($a->[1] - 1.0)) <=> (abs($b->[1] - 1.0)) } @scores;
    return \@scores;
}

1;
