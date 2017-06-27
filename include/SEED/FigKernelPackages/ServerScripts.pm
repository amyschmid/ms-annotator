#!/usr/bin/perl -w
use strict;

=head1 List of Server Scripts

All scripts read from the standard input and write to the standard output. File names
are never specified on the command line. In general, they accept as input a tab-delimited
file and operate on the last column of the input. This allows multiple commands to
be strung together using a pipe.

=over 4

=item L<svr_ach_lookup.pl>

Find protein assertions from the Annotation Clearinghouse.

=item L<svr_aliases_of.pl>

Find aliases for protein-encoding genes.

=item L<svr_all_features.pl>

List all genes in a genome.

=item L<svr_all_figfams.pl>

List all genes in all FIGfams.

=item L<svr_all_genomes.pl>

List all genomes and their names.

=item L<svr_all_subsystems.pl>

List all subsystems.

=item L<svr_assign_to_dna_using_figfams.pl>

Assign functions to DNA sequences using FIGfams technology.

=item L<svr_assign_using_figfams.pl>

Assign functions to proteins using FIGfams technology.

=item L<svr_fasta.pl>

Produce FASTA strings for genes.

=item L<svr_figfam_fasta.pl>

Produce FASTA strings for FIGfams.

=item L<svr_function_of.pl>

Get functions of protein-encoding genes

=item L<svr_gene_data.pl>

Get data (e.g. functional assignment, genome name, evidence codes) about each
specified gene.

=item L<svr_ids_to_figfams.pl>

List the FIGfams for each specified gene ID.

=item L<svr_ids_to_subsystems.pl>

List the subsystems for each specified gene ID.

=item L<svr_in_runs.pl>

Make sequences of genes into operons.

=item L<svr_metabolic_reconstruction.pl>

Get a metabolic reconstruction from a set of functional roles.

=item L<svr_neighbors_of.pl>

Get neighbors of a protein-encoding genes.

=item L<svr_pegs_in_subsystems.pl>

Return all genes in one or more subsystems found in one or more genomes.

=item L<svr_protein_assertions.pl>

List the Annotation Clearinghouse assertions for each specified protein ID.

=item L<svr_similar_to.pl>

Get similarities for a gene.

=item L<svr_summarize_MG_output.pl>

Summarize functions and OTUs detected by L<svr_assign_to_dna_using_figfams.pl>

=item L<svr_upstream.pl>

Retrieve upstream regions for the specified genes.

=back

=cut

1;
