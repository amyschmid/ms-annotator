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

package Quality;

use strict;
use FIG;
use FIG_Config;

use Carp;
use File::Basename;

=head1 Routines for Quality Assessment and Repair

=head3 assess_assembly_quality

    &Quality::assess_assembly_quality($org_dir);

    &Quality::assess_assembly_quality($org_dir, $estimated_read_length);

Makes an I<extremely> crude and rather conservative estimate of assembly
coverage-depth and percent completeness, based on Lander-Waterman theory.

The "Skeleton OrgDir" directory-path argument C<$org_dir> is mandatory,
and does not default to a directory in the SEED organism hierarchy.

The routine assumes a read-length of 500 bp unless told otherwise;
set the optional argument C<$estimated_read_length> to C<100> for genomes
sequenced using the "454" technology.

Returns a list of two strings on success, C<($depth, $completness)>,
and an empty list on failure.

=cut

sub assess_assembly_quality {
    my ($org_dir, $estimated_read_length) = @_;

    if (!-d $org_dir) {
	warn "OrgDir $org_dir does not exist";
	return ();
    }

    if (not defined($estimated_read_length)) {
	$estimated_read_length = 500;
    }

    my $depth = 10.0;
    my $completeness;
    if (!-s "$org_dir/contigs") {
	warn "Contigs file $org_dir/contigs does not exist";
	return ();
    }
    else {
	my $summary = `sequence_length_histogram -null $org_dir/contigs 2>&1`;
	if ($summary =~ m/There are (\d+) chars in (\d+) seq.*mean length = (\d+)/so) {
	    my ($chars, $num_seqs, $expect) = ($1, $2, $3);
	    if ($num_seqs == 1) {
		return (10.0, 0.999954);
	    }

	    my $size  = $chars;
	    my $eff_read_len = $estimated_read_length - 50;
	    for (my $i=0; $i < 500; ++$i) {
		my $last      = $depth;
		my $n_reads   = $depth * $size / $eff_read_len;
		my $n_single  = exp(-$depth) * ( ($n_reads - 2) * exp(-$depth) + 2.0 );

		$depth        = log( 1.0 + $depth * ($size / $eff_read_len) / ($num_seqs + $n_single - 1) );
		$completeness = (1.0 - exp(-$depth));
		$size         = $chars / $completeness;

		if ($completeness > 0.999955) {
		    $completeness = 0.999955;
		    $depth = 10.0;
		    last;
		}

		last if ($depth == $last);
	    }
	}
	else {
	    warn "Could not parse sequence_length_histogram summary: $summary";
	}
    }

    $depth        = sprintf "%.1f", $depth;
    $completeness = sprintf "%.2f", (100.0 * $completeness);

    return ($depth, $completeness);
}



=head3 assess_gene_call_quality

    &Quality::assess_gene_call_quality($org_dir);

This routine is a wrapper for the command-line tool C<assess_gene_call_quality>,
which catches some of the more common fatal errors and warnings for a genome
skeleton directory.

The "Skeleton OrgDir" directory-path argument C<$org_dir> is mandatory,
and does not default to a directory in the SEED organism hierarchy.

On success, the routine returns a list of pointers to two hashes, C<($fatal, $warnings)>,
whose keys are the type of error in each class, and whose values are the
number of features having that type of error; on failure, it returns the empty list.

As a side-effect, this routine creates three files in the skeleton OrgDir:

=over 4

=item * C<quality.report>, which is a tab-seperated three-column file
output by the command-line tool C<assess_gene_call_quality>,
with entry format C<< KEY_TYPE\tKEY_NAME\tVALUE\n >>. The report is
headed by one or more "human-readable" comment lines beginning with the
'#' character, and terminated by the end-of-record indicator C<< //\n >>.

=item * C<overlap.report>, which is a detailed, human-readable
(but not easily machine-parsible!) report that is output by the
command-line tool C<make_overlap_report>; this tool finds embedded or
overlapping feature pairs exceeding a set of user-definable thresholds,
as well as PEGs with invalid START or STOP codons, etc.
(The default thresholds are set to values that we consider unacceptable
for a SEED genome)

=item * C<overlap.summary>, which is a short human-readbale summary
of the number of problematic features found by C<make_overlap_report>.

=back

B<TODO:> C<assess_gene_call_quality> does not yet catch all the errors
that will be flagged as "FATAL" by the command-line tool C<verify_genome_directory>.

=cut

sub assess_gene_call_quality {
    my ($org_dir) = @_;

    if (!-d $org_dir) {
	warn "OrgDir $org_dir does not exist\n";
	return ();
    }
    my $parent   = basename($org_dir) || confess "Could not extract parent of $org_dir";

    my $fatal    = {};
    my $warnings = {};
    if (system("assess_gene_call_quality --meta=$parent/meta.xml  $org_dir > $org_dir/quality.report 2>&1")) {
	warn "FAILED: assess_gene_call_quality $org_dir > $org_dir/quality.report 2>&1";
	return ();
    }

    my @report = `cat $org_dir/quality.report`;
    %$fatal    = map { m/^\S+\t(\S+)\t(\S+)/; $1 => $2
		       } grep {
			   m/^FATAL/
			   } @report;

    %$warnings = map { m/^\S+\t(\S+)\t(\S+)/; $1 => $2
		       } grep {
			   m/^WARNING/
			   } @report;

    return ($fatal, $warnings);
}


=head3 remove_rna_overlaps

    &Quality::remove_rna_overlaps($org_dir);

    &Quality::remove_rna_overlaps($org_dir, $max_overlap);

This routine is a wrapper for the command-line tool C<remove_rna_overlaps>,
which removes any PEGs from the file C<< $org_dir?features/peg/tbl >>
that overlap an RNA feature by more than some threshold, and then rebuilds
the PEG-translation FASTA file C<< $org_dir?features/peg/fasta >>.

The "Skeleton OrgDir" directory-path argument C<$org_dir> is mandatory,
and does not default to a directory in the SEED organism hierarchy.

The optional argument C<$max_overlap> resets the maximum number of base-pairs
that a PEG is allowed to overlap an RNA feature before it will be rejected.
(The default maximum overlap is 10 bp.)

Returns C<1> on success, and C<undef> on failure.

B<TODO:> The command-line tool C<remove_rna_overlaps> needs to be
re-written to only remove PEGs that overlap RNAs "non-removably," and
just re-call the STARTs for those PEGs that have "removable" overlaps.

=cut

sub remove_rna_overlaps {
    my ($org_dir, $max_overlap) = @_;

    if (!-d $org_dir) {
        warn "OrgDir $org_dir does not exist\n";
        return undef;
    }

    $max_overlap = $max_overlap ? qq(-max=$max_overlap) : qq();
    if (system("remove_rna_overlaps $max_overlap $org_dir")) {
	warn "FAILED: remove_rna_overlaps $max_overlap $org_dir";
	return undef;
    }

    &assess_gene_call_quality($org_dir) || confess "Could not re-assess call quality of $org_dir";
    return 1;
}



=head3 remove_embedded_pegs

    &Quality::remove_embedded_pegs($org_dir);

This routine is a wrapper for the command-line tool C<remove_embedded_pegs>,
which removes any PEGs from the file C<< $org_dir?features/peg/tbl >>
that are embedded inside other pegs, and then rebuilds the PEG-translation
FASTA file C<< $org_dir?features/peg/fasta >>.

The "Skeleton OrgDir" directory-path argument C<$org_dir> is mandatory,
and does not default to a directory in the SEED organism hierarchy.

The optional argument C<$max_overlap> resets the maximum number of base-pairs
that a PEG is allowed to overlap an RNA feature before it will be rejected.
(The default maximum overlap is 10 bp.)

Returns C<1> on success, and C<undef> on failure.

B<TODO:> The command-line tool C<remove_embedded_pegs> needs to be
re-written to remove PEGs more intelligently, based on which PEG
has less comparative support.

=cut

sub remove_embedded_pegs {
    my ($org_dir) = @_;

    if (!-d $org_dir) {
        warn "OrgDir $org_dir does not exist\n";
        return undef;
    }

    if (system("remove_embedded_pegs $org_dir")) {
	warn "FAILED: remove_embedded_pegs $org_dir";
	return undef;
    }

    &assess_gene_call_quality($org_dir) || confess "Could not re-assess call quality of $org_dir";
    return 1;
}

1;
