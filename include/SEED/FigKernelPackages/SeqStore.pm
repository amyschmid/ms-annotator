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

package SeqStore;

	use strict;
	use JSON;
	use Stats;
	use File::Copy;
	
=head1 SeqStore

This package manipulates a sequence store. A sequence store maintains a set of files containing sequence
data. Methods are provided to add a sequence, add a sequence file, and retrieve all or part of one or
more sequences.

The sequence store consists of a I<base directory> and a single table in a mysql database. The base directory
contains a control file with the tuning parameters in it (<Ccontrol.tbl>) and zero or more sub-directories
containing FASTA files. The mysql table associates each sequence ID with a file name, a seek address, and
a length.

The sequence store requires that sequence IDs be unique. So, for example, if DNA contigs are being represented,
and contig IDs are not unique within genome, then the contig ID must contain a genome prefix.

The fields of this object are as follows.

=over 4

=item _connect

Reference to a list containing the database connect string, the user name, and the password to be used to
connect to the database.

=item _tableName

The name of the database table containing the sequence index.

=item _db

The L<DBKernel> object used to connect to the database.

=item _directory

The name of the directory containing the sequence files.

=item -maxFiles

maximum number of files allowed per subdirectory

=item -maxSequences

maximum number of sequences expected

=back

=head2 Special Methods

=head3 create

	my $seqStore = SeqStore->create($db, $directoryName, $tableName, %parms);
	
Create a new, empty sequence store in an existing database and directory. The directory should be
empty.

=over 4

=item db

C<DBKernel> object for accessing the database.

=item directoryName

Name of the file directory to contain the FASTA files.

=item tableName

Name of the database table to use. The table will be created.

=item parms

Hash containing the tuning parameters for this instance. The current parameters are as follows.

=over 8

=item -maxFiles

maximum number of files allowed per subdirectory. The default is 1024.

=item -maxSequences

maximum number of sequences expected. The default is 100000000.

=back

=back

=cut

sub create {
	# Get the parameters.
	my ($class, $db, $directoryName, $tableName, %parms) = @_;
	# Compute the tuning parameters.
	my $maxSequences = $parms{-maxSequences} || 100000000;
	my $maxFiles = $parms{-maxFiles} || 1024;
	# Verify the directory.
	die "Directory $directoryName not found." if (! -d $directoryName);
	my $dh;
	opendir $dh, $directoryName;
	my @content = grep { $_ !~ /^\.\.?$/ } readdir($dh);
	closedir $dh;
	die "Directory $directoryName not empty." if (@content);
	# Get the database connection data.
	my $connect = $db->{_connect};
	# Form the SeqStore object.
	my $retVal = {
		_connect => $connect,
		_tableName => $tableName,
		_directory => $directoryName,
		-maxSequences => $maxSequences,
		-maxFiles => $maxFiles
	};
	# Save it in the control file.
	my $savedObject = encode_json($retVal);
	my $ih;
	open $ih, ">$directoryName/control.tbl" || die "Could not create control file in $directoryName: $!";
	print $ih $savedObject;
	close $ih;
	# Create the index table.
	$db->create_table(tbl => $tableName, estimates => [80, $maxSequences], 
					  flds => 'id VARCHAR(64) NOT NULL PRIMARY KEY, ' .
							  'dirNum INT NOT NULL, ' .
							  'fileNum INT NOT NULL, ' .
							  'seekIndex BIGINT, ' .
							  'len INT');
	# Create the file index record. This has a key of a single space and tells us the number of directories
	# in use and the number of files in that directory.
	$db->SQL("INSERT INTO $tableName (id, dirNum, fileNum, seekIndex, len) VALUES (' ', 0, 0, 0, 0)");
	# Attach the connected database.
	$retVal->{_db} = $db;
	# Bless and return the object.
	bless $retVal, $class;
	return $retVal;
}

=head3 new

	my $seqStore = SeqStore->new($directoryName, $db);

Create a sequence store object for an existing store.

=over 4

=item directoryName

Name of the directory containing the sequence store.

=item db (optional)

L<DBKernel> object for accessing the database. If none is provided, one will be created.

=back

=cut

sub new {
	# Get the parameters.
	my ($class, $directoryName, $db) = @_;
	# Read in and decode the SeqStore object.
	my $ih;
	open $ih, "<$directoryName/control.tbl" || die "Could not open control file in $directoryName: $!";
	my $savedObject = <$ih>;
	close $ih;
	die "Control file in $directoryName empty or not found." if (! $savedObject);
	my $retVal = decode_json($savedObject);
	# Connect to the database.
	if (! defined $db) {
		my ($source, $user, $pass) = @{$retVal->{_connect}};
		$db = DBKernel->new('mysql', $source, $user, $pass);
	}
	# Attach the connected database.
	$retVal->{_db} = $db;
	# Bless and return the object.
	bless $retVal, $class;
	return $retVal;
}

=head2 Update Methods

=head3 Import

	my $stats = $seqStore->Import($fileName, $prefix);

Import a FASTA file into the sequence store. The sequences in the file will replace any existing sequences
with the same names, but the space used by the old sequences will not be reclaimed.

=over 4

=item fileName

Name of the FASTA file containing the sequences to import.

=item prefix (optional)

If specified, a prefix to be put in front of each ID as it is stored, to insure uniqueness.

=item RETURN

Returns a L<Stats> object describing what happened during the load.

=back

=cut

sub Import {
	# Get the parameters.
	my ($self, $fileName, $prefix) = @_;
	# Create the statistics object for the return variable.
	my $stats = Stats->new();
	# Normalize the prefix. If none is specified, a null string will work.
	if (! defined $prefix) {
		$prefix = '';
	}
	# Insure the input file exists.
	die "Input file $fileName not found." if ! -f $fileName;
	# Get a file name into which this FASTA file can be stored.
	my ($newFileName, $dirNum, $fileNum) = $self->_AllocateFile();
	# Open the copied FASTA file for input.
	my $ih;
	open $ih, "<$fileName" || die "Could not open FASTA file $fileName: $!";
	# Open the new file for output. We want to treat it as a binary file to
	# avoid seek problems.
	my $oh;
	open $oh, ">$newFileName" || die "Could not open store file $fileName: $!";
	binmode($oh);
	# Remember our current location in the output file.
	my $oLoc = 0;
	# Loop through the FASTA file, posting the sequences. At any give time, we
	# will have the current sequence ID and the current sequence in the following
	# variables.
	my ($id, $seq);
	while (! eof $ih) {
		my $line = <$ih>;
		$stats->Add(linesIn => 1);
		if ($line =~ /^>(\S+)/) {
			# Here we have a header record. Extract the ID.
			my $newID = $1;
			# If a current sequence exists, add it to the database.
			if ($id) {
				my $writeLen = $self->_StoreSequence($stats, $dirNum, $fileNum, $oLoc, "$prefix$id", $seq, $oh);
				# Update the position indicator for the output file.
				$oLoc += $writeLen;
			}
			# Set up for the next sequence.
			$id = $newID;
			$seq = "";
		} else {
			# Here we have a data record. Add its letters to the current sequence.
			chomp $line;
			$seq .= $line;
		}
	}
	# If there is a residual sequence, add it to the database.
	if ($id) {
		$self->_StoreSequence($stats, $dirNum, $fileNum, $oLoc, "$prefix$id", $seq, $oh);
	}
	# Close both files.
	close $ih;
	close $oh;
	# Return the statistics.
	return $stats;
}

=head3 seq

	my $letters = $seqStore->seq($id, $start, $len);

Return a portion of a sequence in the sequence store.

=over 4

=item id

ID of the desired sequence.

=item start (optional)

Offset (1-based) of the first letter to return. If omitted, C<1> is assumed.

=item len (optional)

Number of letters to return. If omitted, the entire remainder of the sequence is assumed.

=item RETURN

Returns the specified subsequence, or C<undef> if the sequence does not exist.

=back

=cut

sub seq {
	# Get the parameters.
	my ($self, $id, $start, $len) = @_;
	# This will contain the return value.
	my $retVal;
	# Get the database object and the table name.
	my $db = $self->{_db};
	my $tableName = $self->{_tableName};
	# Get the sequence for the specified ID.
	my $rv = $db->SQL("SELECT dirNum, fileNum, seekIndex, len FROM $tableName WHERE id = ?", 0, $id);
	# Only proceed if we found something.
	if (@$rv) {
		my ($dirNum, $fileNum, $seekIndex, $seqLen) = @{$rv->[0]};
		# Compute the name of the file containing the sequence.
		my $fileName = "$self->{_directory}/$dirNum/$fileNum.fa";
		# Compute the location and length to read.
		my ($realStart, $realLen);
		$realStart = 0;
		if ($start) {
			$realStart = $start - 1;
		}
		$realLen = $len;
		if (! $len || $realStart + $len > $seqLen) {
			$realLen = $seqLen - $realStart;
		}
		$realStart = $realStart + $seekIndex;
		# If the sequence length is nonzero, we need to read it.
		if ($realLen == 0) {
			$retVal = '';
		} else {
			# Open the file containing the sequence.
			my $ih;
			open $ih, "<$fileName" || die "Could not open sequence file $fileName: $!";
			# Read from the specified position for the specified length, directly into $retVal;
			sysseek $ih, $realStart, 0;
			sysread($ih, $retVal, $realLen);
		}
	}
	# Return the result.
	return $retVal;
}

=head2 Internal Methods

	my $writeLen = $seqStore->_StoreSequence($stats, $dirNum, $fileNum, $oLoc, $id, $seq, $oh);

Store a sequence in the database.

=over 4

=item stats

L<Stats> object to contain the statistics about the current import.

=item dirNum

Directory number of the output file to contain the sequence letters.

=item fileNum

File number within the directory of the output file to contain the sequence letters.

=item oLoc

Location in the output file where the sequence is being stored.

=item id

ID to be given to the sequence. If a sequence with this ID already exists, it will be replaced.

=item seq

Sequence letters to store in the database.

=item oh

File handle for the output file. This should be open in binary mode.

=item RETURN

Returns the length of the data written to the output file.

=back

=cut

sub _StoreSequence {
	# Get the parameters.
	my ($self, $stats, $dirNum, $fileNum, $oLoc, $id, $seq, $oh) = @_;
	# This will be the return value. It counts the number of characters written.
	my $retVal = 0;
	# Determine the size of the input sequence.
	my $seqLen = length($seq);
	# Output the sequence ID. This is done so that the output file looks FASTA-like, even though it is technically
	# something else.
	print $oh ">$id\n";
	$retVal += length($id) + 2;
	# The sequence goes next. Compute its seek location.
	my $seekLoc = $oLoc + $retVal;
	# Write the sequence.
	print $oh "$seq\n";
	$retVal += $seqLen + 1;
	# Update the statistics.
	$stats->Add(seqsOut => 1);
	$stats->Add(lettersOut => $seqLen);
	$stats->Add(bytesOut => $retVal);
	# Now update the database.
	my $db = $self->{_db};
	my $tableName = $self->{_tableName};
	$db->SQL("REPLACE $tableName (id, fileNum, dirNum, seekIndex, len) VALUES (?,?,?,?,?)", 0,
		$id, $fileNum, $dirNum, $seekLoc, $seqLen);
	# Return the number of bytes written.
	return $retVal;
}

=head3 _AllocateFile

	my ($fileName, $dirNum, $fileNum) = $seqStore->_AllocateFile();
	
Allocate a new file for use in storing sequences. The file name is computed from the base directory name,
the directory number, and the file number. These in turn are allocated using the database.

The return is a list consisting of the full file name, the directory number, and the file number in that
directory.

=cut

sub _AllocateFile {
	# Get the parameters.
	my ($self) = @_;
	# Get the database object and the name of our table.
	my $db = $self->{_db};
	my $tableName = $self->{_tableName};
	# We'll put the file and directory numbers for the new file in here.
	my ($fileNum, $dirNum);
	# Loop until successful.
	my $done = 0;
	while (! $done) {
		# Read the control record.
		my $rv = $db->SQL("SELECT id, fileNum, dirNum FROM $tableName WHERE id = ' '");
		die "Control record from $tableName missing or invalid." if ! @$rv;
		my ($id, $oldFileNum, $oldDirNum) = @{$rv->[0]};
		# Compute the new file's numbers, insuring we don't exceed the files per directory limit.
		if ($oldFileNum < $self->{-maxFiles}) {
			$fileNum = $oldFileNum + 1;
			$dirNum = $oldDirNum;
		} else {
			$fileNum = 1;
			$dirNum = $oldDirNum + 1;
		}
		# Try to claim these numbers.
		$rv = $db->SQL("UPDATE $tableName SET fileNum = ?, dirNum = ? WHERE id = ' ' AND fileNum = ? AND dirNum = ?",
						 0, $fileNum, $dirNum, $oldFileNum, $oldDirNum);
		# If we succeeded, denote we're done.
		if ($rv > 0) {
			$done = 1;
		}
	}
	# Insure we have the directory.
	my $fileName = "$self->{_directory}/$dirNum";
	if (! -d $dirNum) {
		mkdir $fileName;
	}
	# Build the full file name.
	$fileName .= "/$fileNum.fa";	
	# Return the file specifications.
	return ($fileName, $dirNum, $fileNum);
}

1;