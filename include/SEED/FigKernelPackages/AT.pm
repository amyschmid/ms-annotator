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
package AT;

use strict;

use ERDB;
use Tracer;

use gjoalignment;

use AlignTree;
use SeedUtils;
use ServerThing;

sub new {
    my ($class) = @_;
    # Create the sapling object.
    # my $at = ERDB::GetDatabase('AT');

    # Create the server object.
    # my $retVal = { db => $at };
    my $retVal = { };

    # Bless and return it.
    bless $retVal, $class;
    return $retVal;
}

use constant METHODS => [qw(
                            align_seqs
                            trim_ali
                            psiblast_search
                            make_tree
                            blast
                           )];

sub methods {
    my ($self) = @_;
    return METHODS;
}

sub align_seqs {
    my ($self, $opts) = @_;
    my $ali = AlignTree::align_sequences($opts);
    return { rv => $ali };
}

sub trim_ali {
    my ($self, $opts) = @_;
    my $trim = AlignTree::trim_alignment($opts);
    return { rv => $trim }; 
}

sub psiblast_search {
    my ($self, $opts) = @_;
    my ($trim, $report, $history) = AlignTree::psiblast_search($opts);
    return { rv => $trim, report => $report, history => $history };
}

sub blast {
    my ($self, $opts) = @_;
    my $out = AlignTree::blast($opts);
    return { rv => $out };
}

sub make_tree {
    my ($self, $opts) = @_;
    my ($tree, $stats) = AlignTree::make_tree($opts);
    return { rv => $tree, stats => $stats };
}

1;
