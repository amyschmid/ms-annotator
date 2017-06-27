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

package LogReader;

    use strict;
    use Tracer;

=head1 Log File Reader

=head2 Introduction

The log reader contains information about a log file currently being read. A log file
contains two types of data lines.

=over 4

=item Formatted Lines

I<Formatted lines> consist of one or more columns of data followed by a free-form string,
which is treated the last column. Each data column is enclosed in square brackets and
separated from neighboring columns by zero or more spaces.

=item Free-Form Lines

I<Free-form lines> consist of a single string.

=back

A I<record> is defined as a formatted line followed by zero or more free-form lines.
The log file is processed one record at a time.

In most formatted records, the first column is a time stamp. When trying to decipher
a log, the time stamps are critical. Unfortunately, in the case of the
error log, not all of the software components that write to it put in a time stamp.
When this happens, we put in an undefined value for the time stamp. Note also
that internally, a time stamp is stored as a number of seconds since the epoch.

Reading a record from a log file involves pulling in multiple lines of text, so
we don't know whether or not we have the last line of text in a record until we've
read the first line of the next record. For this reason, the log file reader
keeps the next line in an internal buffer. If a record has no time stamp, we will read
ahead so we can interpolate a time. As a result, there may be an extensive list of
full records buffered in this object as well.

The fields in this object are as follows.

=over 4

=item fh

Input file handle.

=item columnCount

Number of columns in each record. The first column is always a time stamp and the
last is always a free-form string. The useful information here is how many middle
columns we expect.

=item buffer

A line of data from the file.

=item tell

The seek location of the line of data in the buffer.

=item fileSize

File size in bytes at the time of the open.

=item stop

Position in the file at which the reader should stop when reading ahead.

=back

=head2 Constants and Globals

=over 4

=item SEEK_SET

Constant value used to tell C<seek> to position from the start of the file.

=cut

use constant SEEK_SET => 0;

=item FRAGMENT

Time string to use for a record fragment.

=cut

use constant FRAGMENT => 'Fragment';

=item NO_TIME

Time string to use for an unknown time.

=cut

use constant NO_TIME => '(none)';

=back

=head2 Public Methods

=head3 new

C<< my $logrdr = LogReader->new($fileName, %options); >>

Construct a new LogReader object.

=over 4

=item fileName

Name of the log file to open.

=item options

Hash containing options.

=back

The permissible options are as follows.

=over 4

=item columnCount

Number of columns expected in each record, including the last column that contains a free-form string.
The default is C<5>.

=back

=cut

sub new {
    # Get the parameters.
    my ($class, $fileName, %options) = @_;
    # Create the Log File Reader object.
    my $retVal = {};
    # Extract the number of columns from the options.
    $retVal->{columnCount} = $options{columnCount} || 5;
    # Open the file for input and save the handle.
    my $fh = Open(undef, "<$fileName");
    $retVal->{fh} = $fh;
    # Get the file size.
    $retVal->{fileSize} = -s $fh;
    # The file size is the default stop point.
    $retVal->{stop} = $retVal->{fileSize};
    # Position at the start of the file.
    $retVal->{buffer} = '';
    $retVal->{tell} = 0;
    # Denote we have no record in memory.
    $retVal->{record} = undef;
    # Bless and return the object.
    bless $retVal, $class;
    return $retVal;
}

=head3 GetRecord

    my $record = $logrdr->GetRecord();

Return the record at the current position and advance the file position
past it. The record will be a reference to a list of columns. The first
column will be the display-formatted time stamp. The last column will be
free-form text. The intervening columns will contain full strings if they
were present in the record, and empty strings if they were not. If we've
reached the end of the file, an undefined value will be returned.

=cut

sub GetRecord {
    # Get the parameters.
    my ($self) = @_;
    # Declare the return variable.
    my $retVal;
    # Only proceed if the file is still operating; that is, we have not yet reached the
    # end of the section.
    if (defined $self->{fh}) {
        # Get the current buffer content. It should contain the first line of
        # the record, which would be a formatted line. If it is not a formatted
        # line, it will be treated as a fragment.
        my $buffer = $self->{buffer};
        # We'll put the output columns in here.
        my @cols;
        # Check for a fragment.
        if (substr($buffer, 0, 1) ne '[') {
            # A fragment has a special timestamp value.
            @cols = (FRAGMENT, $buffer);
        } else {
            # Here we have a real formatted line. We need to split it
            # into columns. The following SPLIT will do the job, but
            # we'll end up with extra columns containing nothing but a
            # single space. We fix that using a GREP filter.
            @cols = grep { $_ =~ /\S/ } split /\[(.+?)\]/, $buffer;
            # Check for a time stamp.
            my $time = Tracer::ParseDate($cols[0]);
            # If the first column is not a time stamp, jam one in. Otherwise, replace it
            # with a re-formatted time value.
            if (! defined $time) {
                unshift @cols, NO_TIME;
            } else {
                $cols[0] = Tracer::DisplayTime($time);
            }
        }
        # Now we need to normalize the number of columns.
        my $columnCount = $self->{columnCount};
        while (scalar(@cols) > $columnCount) {
            # Too many columns, so merge the last column with its predecessor.
            my $lastCol = pop @cols;
            $cols[$#cols] .= " " . $lastCol;
        }
        while (scalar(@cols) < $columnCount) {
            # Too few columns, so add an empty one before the last one.
            my $lastCol = pop @cols;
            push @cols, '', $lastCol;
        }
        # We have our record. All that remains is to slurp in subsequent free-form lines.
        # Set up to do some reading.
        my $done = 0;
        # Loop until we hit end-of-file or find the next formatted line.
        while (! $done) {
            # Pull the next line into the buffer.
            my $found = $self->_ReadLine();
            if (! $found) {
                # We've hit end-of-file, so stop the record.
                $done = 1;
            } elsif (_Formatted($self->{buffer})) {
                # This is the first line of the next record. Stop the loop.
                $done = 1;
            } else {
                # This is a free-form line. Add it to the last column.
                $cols[$#cols] .= $self->{buffer};
            }
        }
        # Store the record found as the result.
        $retVal = \@cols;
    }
    # Return the result.
    return $retVal;
}

=head3 FragmentString

    my $marker = LogReader::FragmentString();

Return the string used to mark a record as a fragment.

=cut

sub FragmentString {
    return FRAGMENT;
}

=head3 AtEnd

    my $flag = $logrdr->AtEnd();

Return TRUE if we're at the end of the section to be displayed, else FALSE.
The section is set by L</SetRegion>. If no section has been specified,
then the default extends from the beginning of the file to the end of the
file at the time it was opened.

=cut

sub AtEnd {
    # Get the parameters.
    my ($self) = @_;
    # Compute the result.
    my $retVal = ($self->{tell} >= $self->{stop});
    # If we're at the end, close the handle. This is a precaution to prevent
    # the file from being locked accidentally for an extended period.
    if ($retVal && defined $self->{fh}) {
        close $self->{fh};
        $self->{fh} = undef;
        # Clear the buffer. This insures that "ReadLine" doesn't update the tell
        # value.
        $self->{buffer} = '';
    }
    # Return the flag.
    return $retVal;
}

=head3 FileSize

    my $bytes = $logrdr->FileSize();

Return the total number of bytes in the log file.

=cut

sub FileSize {
    # Get the parameters.
    my ($self) = @_;
    # Return the result.
    return $self->{fileSize};
}

=head3 SetRegion

    $logrdr->SetRegion($start, $end);

Set up to read the specified section of the log file.

=over 4

=item start

Offset to the place where the reading should start.

=item end

Offset to the place where the reading should stop. Note that the
read operations may extend past this point if it is in the middle
of a line of text.

=back

=cut

sub SetRegion {
    # Get the parameters.
    my ($self, $start, $end) = @_;
    # Get the file handle.
    my $fh = $self->{fh};
    # Position the file at the specified start point.
    $self->{tell} = $start;
    seek $fh, $start, SEEK_SET;
    Trace("SetRegion from $start to $end. Tell is " . tell($fh) . ".") if T(3);
    # Read the first line into the buffer.
    $self->{buffer} = <$fh>;
    Trace(length($self->{buffer}) . " bytes in first buffer.") if T(3);
    # Save the end point.
    $self->{stop} = $end;
}


=head2 Private Methods

=head3 _Formatted

    my $flag = _Formatted($line);

Returns TRUE if the specified line is formatted, FALSE if it is
free-form. A formatted line contains one or more columns of data at the
beginning that are enclosed in square brackets and separated by spaces.

=over 4

=item line

Line of input to examine.

=item RETURN

Returns TRUE if the line is formatted, else FALSE.

=back

=cut

sub _Formatted {
    # Get the parameters.
    my ($line) = @_;
    # Declare the return variable. We'll set this to TRUE if the line is formatted.
    my $retVal = 0;
    # Examine the line.
    if ($line =~ /^\[.+?\]\s/) {
        # We have a column, so we're formatted.
        $retVal = 1;
    }
    # Return the result.
    return $retVal;
}

=head3 _ReadLine

    my $flag = $logrdr->_ReadLine();

Read the next line of data into the buffer. Return TRUE if successful,
FALSE if we are at the end of the currently-selected region. If we are
at the end of the region, the file will be closed automatically.

=cut

sub _ReadLine {
    # Get the parameters.
    my ($self) = @_;
    # Update the location.
    $self->{tell} += length $self->{buffer};
    # Check for end-of-section.
    my $retVal = ! $self->AtEnd();
    # If we're not at end-of-section, read the next line.
    if ($retVal) {
        Trace("Reading line at $self->{tell}.") if T(3);
        my $fh = $self->{fh};
        $self->{buffer} = <$fh>;
        Trace(length($self->{buffer}) . " bytes read at $self->{tell}.") if T(3);
    }
    # Return the result.
    return $retVal;
}

1;

