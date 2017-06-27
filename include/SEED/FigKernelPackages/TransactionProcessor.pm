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


package TransactionProcessor;

    use strict;
    use Tracer;
    use PageBuilder;
    use FIG;
    use Stats;

=head1 Transaction Processor

=head2 Introduction

This is the base class for a transaction processor. Transaction processors are
used by the B<TransactFeatures> script to process transactions found in feature
transaction files. The script reads through files containing add, delete, and
change transactions for features, and then calls this object's methods to
effect the transactions. A different subclass of this object is used for
each of the possible commands that can be input to B<TransactFeatures>.

The transaction processor subclass must provide five methods.

=over 4

=item Add

Add a new feature.

=item Delete

Delete a feature

=item Change

Replace a feature.

=item Setup

Initialize for processing.

=item SetupGenome

Initialize for processing a genome.

=item TeardownGenome

Terminate processing for a genome.

=item Teardown

Terminate processing.

=back

=cut

#: Constructor TransactionProcessor->new();

=head2 Public Methods

=head3 new

    my $xprc = TransactionProcessor->new(\%options, $command, $idFile);

Construct a new Transaction Processor object.

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
    # Set up tracing.
    my $traceLevel = $options->{trace};
    TSetup("$traceLevel $class Tracer FIG TransactionProcessor", "TEXT");
    # Create the xprc object.
    my $retVal = {
                  fig => FIG->new(),
                  idHash => {},
                  options => $options,
                  command => $command,
                  stats => Stats->new("genomes", "add", "change", "delete"),
                  idFileName => $idFile,
                  directory => $directory,
                  fileName => undef,
                  genomeID => undef,
                  orgStats => undef
                };
    # Bless and return it.
    bless $retVal, $class;
    return $retVal;
}

=head3 FIG

    my $fig = $xprc->FIG;

Return the FIG object used to access and manipulate the data store.

=cut
#: Return Type $%;
sub FIG {
    # Get the parameters.
    my ($self) = @_;
    # Return the result.
    return $self->{fig};
}

=head3 GenomeID

    my $genomeID = $xprc->GenomeID;

Return the ID of the current genome. The current genome is specified by the
L</StartGenome> method.

=cut
#: Return Type $;
sub GenomeID {
    # Get the parameters.
    my ($self) = @_;
    # Return the genome ID.
    return $self->{genomeID};
}

=head3 CurrentFileName

    my $name = $xprc->CurrentFileName;

Return the name of the transaction file currently being read. There is a
difference file for each genome being processed.

=cut
#: Return Type $;
sub CurrentFileName {
    # Get the parameters.
    my ($self) = @_;
    # Return the result.
    return $self->{fileName};
}

=head3 IncrementStat

    $xprc->IncrementStat($name);

Increment the named statistics in the organism statistics object.

=over 4

=item name

Name of the statistic to increment.

=back

=cut
#: Return Type ;
sub IncrementStat {
    # Get the parameters.
    my ($self, $name) = @_;
    # Increment the statistic.
    $self->{orgStats}->Add($name, 1);
}

=head3 AddStats

    $xprc->AddStats($name1, $name2, ... $nameN);

Insure statistics with the specified names exist in the organism statistics
object.

=over 4

=item name1, name2, ..., nameN

Names of the statistics to create.

=back

=cut
#: Return Type ;
sub AddStats {
    # Get the parameters.
    my ($self, @names) = @_;
    # Create the statistics.
    map { $self->{orgStats}->Add($_, 0) } @names;
}

=head3 AddMessage

    $xprc->AddMessage($message);

Add the specified message to the organism statistics object.

=over 4

=item message

Message to put in the statistical object's message queue.

=back

=cut
#: Return Type ;
sub AddMessage {
    # Get the parameters.
    my ($self, $message) = @_;
    # Add the message to the statistics object.
    $self->{orgStats}->AddMessage($message);
}

=head3 StartGenome

    my  = $xprc->StartGenome($genomeID, $orgFileName);

Start processing a particular genome.

=over 4

=item genomeID

ID of the genome for which processing is to begin.

=item

Name of the input file.

=back

=cut
#: Return Type ;
sub StartGenome {
    # Get the parameters.
    my ($self, $genomeID, $orgFileName) = @_;
    # Save the genome ID.
    $self->{genomeID} = $genomeID;
    # Create the statistics object for this organism.
    $self->{orgStats} = Stats->new();
    # Save the file name.
    $self->{fileName} = $orgFileName;
    # Do the subclass setup.
    $self->SetupGenome();
}

=head3 EndGenome

    my $orgStats = $xprc->EndGenome();

Terminate processing for the current genome and return its statistics object.

=cut
#: Return Type $%;
sub EndGenome {
    # Get the parameters.
    my ($self) = @_;
    # Do the subclass teardown.
    $self->TeardownGenome();
    # Get the statistics object.
    my $retVal = $self->{orgStats};
    # Roll it up into the global statistics object.
    $self->{stats}->Accumulate($retVal);
    # Count this genome.
    $self->{stats}->Add("genomes", 1);
    # Return the genome statistics.
    return $retVal;
}

=head3 Option

    my $value = $xprc->Option($optionName);

Return the value of the specified command-line option.

=over 4

=item optionName

Name of the command-line option whose value is desired.

=item RETURN

Value of the desired command-line option, or C<undef> if the option does
not exist.

=back

=cut
#: Return Type $;
sub Option {
    # Get the parameters.
    my ($self, $optionName) = @_;
    # Return the option value.
    return $self->{options}->{$optionName};
}

=head3 GetRealID

    my $realID = $xprc->GetRealID($ftype, $ordinal, $key);

Compute the real ID of a new feature. This involves interrogating the ID hash and
formatting a full-blown ID out of little bits of information.

=over 4

=item controlBlock

Reference to a hash containing data used to manage the transaction process.

=item ordinal

Zero-based ordinal number of this feature. The ordinal number is added to the value
stored in the ID hash to compute the real feature number.

=item key

Key in the ID hash relevant to this feature. The key is composed of the genome ID
followed by the feature type, separated by a period.

=item RETURN

Returns a fully-formatted FIG ID for the new feature.

=back

=cut

sub GetRealID {
    # Get the parameters.
    my ($self, $ordinal, $key) = @_;
    #Declare the return value.
    my $retVal;
    # Get the base value for the feature ID number.
    my $base = $self->{idHash}->{$key};
    # If it didn't exist, we have an error.
    if (! defined $base) {
        Confess("No ID range found for genome ID and feature type $key.");
    } else {
        # Now we have enough data to format the ID.
        my $num = $base + $ordinal;
        $retVal = "fig|$key.$num";
    }
    # Return the result.
    return $retVal;
}

=head3 ParseNewID

    my ($ftype, $ordinal, $key) = $xprc->ParseNewID($newID);

Extract the feature type and ordinal number from an incoming new ID.

=over 4

=item newID

New ID specification taken from a transaction input record. This contains the
feature type followed by a period and then the ordinal number of the ID.

=item RETURN

Returna a three-element list. If successful, the list will contain the feature
type followed by the ordinal number and the key to use in the ID hash to find
the feature's true ID number. If the incoming ID is invalid, the list
will contain three C<undef>s.

=back

=cut

sub ParseNewID {
    # Get the parameters.
    my ($self, $newID) = @_;
    # Declare the return variables.
    my ($ftype, $ordinal, $key);
    # Parse the ID.
    if ($newID =~ /^([a-z]+)\.(\d+)$/) {
        # Here we have a valid ID.
        ($ftype, $ordinal) = ($1, $2);
        $key = $self->GenomeID . ".$ftype";
        # Update the feature type count in the statistics.
        $self->{orgStats}->Add($ftype, 1);
    } else {
        # Here we have an invalid ID.
        $self->{orgStats}->AddMessage("Invalid ID $newID found in line " .
                                      $self->{line} . " for genome " .
                                      $self->GenomeID . ".");
    }
    # Return the result.
    return ($ftype, $ordinal, $key);
}

=head3 CheckTranslation

    my $actualTranslation = $xprc->CheckTranslation($ftype, $locations, $translation);

If we are processing a PEG, insure we have a translation for the peg's locations.

This method checks the feature type and the incoming translation string. If the
translation string is empty and the feature type is C<peg>, it will generate
a translation string using the specified locations for the genome currently
being processed.

=over 4

=item ftype

Feature type (C<peg>, C<rna>, etc.)

=item locations

Comma-delimited list of location strings for the feature in question.

=item translation (optional)

If specified, will be returned to the caller as the result.

=item RETURN

Returns the protein translation string for the specified locations, or C<undef>
if no translation is warranted.

=back

=cut

sub CheckTranslation {
    # Get the parameters.
    my ($self, $ftype, $locations, $translation) = @_;
    my $fig = $self->FIG;
    # Declare the return variable.
    my $retVal;
    if ($ftype eq 'peg') {
        # Here we have a protein encoding gene. Check to see if we already have
        # a translation.
        if (defined $translation) {
            # Pass it back unmodified.
            $retVal = $translation;
        } else {
            # Here we need to compute the translation.
            my $dna = $fig->dna_seq($self->GenomeID, $locations);
            $retVal = FIG::translate($dna);
        }
    }
    # Return the result.
    return $retVal;
}

=head3 ReadIDHash

    $xprc->ReadIDHash();

Read the ID hash data from the ID file.

=cut
#: Return Type ;
sub ReadIDHash {
    # Get the parameters.
    my ($self) = @_;
    # Create a counter.
    my $inCount = 0;
    # Open the ID file.
    my $idFileName = $self->{idFileName};
    Open(\*IDFILE, "<$idFileName");
    # Loop through the records in the file.
    while (my $idRecord = <IDFILE>) {
        # Extract the three fields from the record.
        chomp $idRecord;
        my ($orgID, $ftype, $firstNumber) = split /\t/, $idRecord;
        # Add it to the ID hash.
        $self->{idHash}->{"$orgID.$ftype"} = $firstNumber;
        # Count the record.
        $inCount++;
    }
    Trace("$inCount ID ranges read in from $idFileName.") if T(2);
}

=head3 Directory

    my $dirName = $xprc->Directory;

Name of the directory containing the transaction files.

=cut
#: Return Type $;
sub Directory {
    # Get the parameters.
    my ($self) = @_;
    # Return the directory name.
    return $self->{directory};
}

=head3 IDHash

    my $idHash = $xprc->IDHash;

Return a reference to the ID hash. The ID hash is used to extract the base
value for new IDs when processing and to count the IDs needed when counting.

=cut
#: Return Type $%;
sub IDHash {
    # Get the parameters.
    my ($self) = @_;
    # Return the hash.
    return $self->{idHash};
}

=head3 IncrementID

    $xprc->IncrementID($ftype);

Increment the ID hash counter for the specified feature type and the current genome.

=over 4

=item ftype

Feature type whose ID counter is to be incremented.

=back

=cut
#: Return Type ;
sub IncrementID {
    # Get the parameters.
    my ($self, $ftype) = @_;
    # Create the key.
    my $key = $self->GenomeID . ".$ftype";
    # Increment the counter for the specified key.
    if (exists $self->{idHash}->{$key}) {
        $self->{idHash}->{$key}++;
    } else {
        $self->{idHash}->{$key} = 1;
    }
}

=head3 IDFileName

    my $idFileName = $xprc->IDFileName;

Return the name of the ID file.

=cut
#: Return Type $;
sub IDFileName {
    # Get the parameters.
    my ($self) = @_;
    # Return the ID file name.
    return $self->{idFileName};
}

=head3 Show

    my $printout = $xprc->Show();

Return a display of the global statistics object. The display will be in printable
form with embedded new-lines.

=cut
#: Return Type $;
sub Show {
    # Get the parameters.
    my ($self) = @_;
    # Return the statistical trace.
    return $self->{stats}->Show();
}

#### STUBS
#
# These essentially do nothing, and are only called if no override is present
# in the subclass.
#

sub Add {
    Trace("Add stub called.") if T(4);
}

sub Change {
    Trace("Change stub called.") if T(4);
}

sub Delete {
    Trace("Delete stub called.") if T(4);
}

sub Setup {
    Trace("Setup stub called.") if T(4);
}

sub Teardown {
    Trace("Teardown stub called.") if T(4);
}

sub SetupGenome {
    Trace("SetupGenome stub called.") if T(4);
}

sub TeardownGenome {
    Trace("TeardownGenome stub called.") if T(4);
}

1;

