#!/usr/bin/perl -w
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


package MergeTransactions;

    use TransactionProcessor;
    @ISA = ('TransactionProcessor');

    use strict;
    use Tracer;
    use PageBuilder;
    use FIG;

=head1 Merge Transactions

=head2 Special Note

THIS MODULE HAS NOT BEEN IMPLEMENTED. IT IS SAVED FOR POSSIBLE FUTURE USE.

=head2 Introduction

This is a TransactionProcessor subclass that updates the C<peg.synonyms> and C<NR> files
to take into account transaction changes. Our goal is to re-constitute the PEG synonyms
table and then rebuild the NR file from it.

To understand this process, we must first understand the concept of a PEG synonym.
Two PEGs are considered I<pseudo-equivalent> if the shorter matches the tail of
the longer, and the shorter is no less than 70% the length of the longer. A pair
of PEGs are considered I<synonyms> if they are both pseudo-equivalent to the same
longer PEG.

The concept of I<synonym> is almost an equivalence relation. We can, however,
partition PEGs into a set of classes which have the property that each PEG
in the class is pseudo-equivalent to a single PEG of maximal length, called
the I<principal synonym>. If so, similarities between principal synonyms will
usually imply similarity between each pair of PEGs in the principal synonyms'
partitions. That is, if principal synonym C<A> is similar to principal synonym
C<B>, then each PEG in C<A>'s partition is probably similar to each PEG in
C<B>'s partition.

The C<NR> file contains the translation for each principal synonym, in FASTA
form. It is this file that is used to generate similarities.

When transactions come through, they will delete some PEGs, add new PEGs, and
replace old PEGs with new ones. For the purposes of this algorithm, we will
treat the transactions as a set of deletes and a set of insertions. The
merge process then involves three steps.

=over 4

=item Collect

Collect the IDs of the inserted PEGs. These will be output to a file
containing the PEG ID and their reversed translations. The file
will be sorted by translation for the purposes of the merge step.

=item Reduce

Remove the deleted PEGs from the C<peg.synonyms> file. We will assume
that a PEG has been deleted if it is either marked for deletion or we
cannot find it in the SEED database. This process will also output a
file containing the principal synonyms, their reversed translations,
and the PEGs in their equivalence clases. This file will also be sorted by
translation for the purposes of the merge step.

=item Merge

Merge the inserted PEGs into the C<peg.synonyms> file and re-create
the NR file. This involves going through the two output files from
the previous steps to determine whether the new PEGs belong in a
new class, will be ther new principal synonym of an existing class,
or merely the member of an existing class.

=back

=head2 Methods

=head3 new

    my $xprc = MergeTransactions->new(\%options, $command, $directory, $idFile);

Construct a new MergeTransactions object.

=over 4

=item options

Reference to a hash table containing the command-line options.

=item command

Command specified on the B<TransactFeatures> command line. This command determines
which TransactionProcessor subclass is active.

=item directory

Directory containing the transaction files.

=item idFile

Name of the ID file (if needed).

=back

=cut

sub new {
    # Get the parameters.
    my ($class, $options, $command, $directory, $idFile) = @_;
    # Construct via the subclass.
    return TransactionProcessor::new($class, $options, $command, $directory, $idFile);
}

=head3 Setup

    $xprc->Setup();

Set up to apply the transactions. This includes reading the ID file.

=cut
#: Return Type ;
sub Setup {
    # Get the parameters.
    my ($self) = @_;
    # Read the ID hash from the ID file.
    $self->ReadIDHash();
    # TODO
}

=head3 SetupGenome

    $xprc->SetupGenome();

Set up for processing this genome. This involves opening the output file
for the transaction trace. The transaction trace essentially contains the
incoming transactions with the pseudo-IDs replaced by real IDs.

=cut
#: Return Type ;
sub SetupGenome {
    # Get the parameters.
    my ($self) = @_;
    my $fig = $self->FIG();
    # TODO
}

=head3 TeardownGenome

    $xprc->TeardownGenome();

Clean up after processing this genome. This involves closing the transaction
trace file and optionally committing any updates.

=cut
#: Return Type ;
sub TeardownGenome {
    # Get the parameters.
    my ($self) = @_;
    my $fig = $self->FIG();
    # TODO
}

=head3 Add

    $xprc->Add($newID, $locations, $translation);

Add a new feature to the data store.

=over 4

=item newID

ID to give to the new feature.

=item locations

Location of the new feature, in the form of a comma-separated list of location
strings in SEED format.

=item translation (optional)

Protein translation string for the new feature. If this field is omitted and
the feature is a peg, the translation will be generated by normal means.

=back

=cut

sub Add {
    my ($self, $newID, $locations, $translation) = @_;
    my $fig = $self->{fig};
    # Extract the feature type and ordinal number from the new ID.
    my ($ftype, $ordinal, $key) = $self->ParseNewID($newID);
    # TODO
}

=head3 Change

    $xprc->Change($fid, $newID, $locations, $aliases, $translation);

Replace a feature to the data store. The feature will be marked for deletion and
a new feature will be put in its place.

This is a much more complicated process than adding a feature. In addition to
the add, we have to create new aliases and transfer across the assignment and
the annotations.

=over 4

=item fid

ID of the feature being changed.

=item newID

New ID to give to the feature.

=item locations

New location to give to the feature, in the form of a comma-separated list of location
strings in SEED format.

=item aliases (optional)

A new list of alias names for the feature.

=item translation (optional)

New protein translation string for the feature. If this field is omitted and
the feature is a peg, the translation will be generated by normal means.

=back

=cut

sub Change {
    my ($self, $fid, $newID, $locations, $aliases, $translation) = @_;
    my $fig = $self->{fig};
    # Extract the feature type and ordinal number from the new ID.
    my ($ftype, $ordinal, $key) = $self->ParseNewID($newID);
    # TODO
}

=head3 Delete

    $xprc->Delete($fid);

Delete a feature from the data store. The feature will be marked as deleted,
which will remove it from consideration by most FIG methods. A garbage
collection job will be run later to permanently delete the feature.

=over 4

=item fid

ID of the feature to delete.

=back

=cut

sub Delete {
    my ($self, $fid) = @_;
    my $fig = $self->{fig};
    # TODO
}

1;
