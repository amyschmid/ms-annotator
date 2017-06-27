#!/usr/bin/perl -w

package Markups;

    require Exporter;
    @ISA = ('Exporter');
    @EXPORT = qw();
    @EXPORT_OK = qw();

    use strict;
    use Tracer;
    use PageBuilder;

=head1 Markup Utilities

=head2 Introduction

The markup utilities provide a mechanism for managing markups to sections of a
FIG feature. The user specifies a region inside the feature's translation and
assigns it a label. The labels are used as styles when displaying the translation.

The styles for the labels will be taken from the file C<labels.css> in the
CSS directory. The full path to the file is

    $FIG_Config::fig/CGI/Html/css/labels.css

The styles should be expressed as classes. For example, in the following style file

    .lowerGamma { background-color: yellow }
    .upperGamma { background-color: turquoise }
    .supraCore { color: red }

there are three labels defined-- C<lowerGamma>, C<upperGamma>, and C<supraCore>. The
gamma type determines the background color of the region; a supra-core section changes
the font color to red. The Markup object must read the style file and determine from it
which labels are acceptable. Style changes should not alter the base font, only
decorations, color, style, and weight. The protein translation will be rendered using
the C<PRE> tag, and changes to the base font will throw off the character spacing.

The Markup object accepts as a parameter a fig-like object that enables it to access the
data store. This can be a real C<FIG> object or an object that mimics a FIG object but uses
a different method for accessing the data, such as an C<SFXlate> object.

Markups will be rendered using the HTML C<SPAN> tag. The rules of HTML are very strict, so a
markup can be wholly inside another markup, but it cannot overlap. So, for example, consider

          |--------|
    ABCDEFGHIJKLMNOPQRSTUVWXYZ
              |====|

Here we have G through P with one marking and K through P for another. This is legal because
the shorter marking is entirely inside the larger one. The following, however, is NOT legal.

          |--------|
    ABCDEFGHIJKLMNOPQRSTUVWXYZ
              |========|

Here the second marking extends past the end of the first. To be legal, this would have to
be reformatted as

          |--------|
    ABCDEFGHIJKLMNOPQRSTUVWXYZ
              |====||==|

The second marking is split in two so that it follows the rules.

If this proves to be an onerous restriction, the rendering engine can be made a little
smarter to account for the possibility of overlap.

=cut

#: Constructor Markups->new();

=head2 Public Methods

=head3 new

    my $$marks = Markups->new($fid, $fig);

Construct a new Markups object for a specified feature.

=over 4

=item fid

ID of the feature being marked up.

=item fig

FIG object used to access the data store.

=back

=cut

sub new {
    # Get the parameters.
    my ($class, $fid, $fig) = @_;
    # Read in the markup data.
    my $markList = $fig->ReadMarkups($fid);
    # Sort it for rendering purposes.
    my @sortedList = sort { Compare($a,$b) } @{$markList};
    # Create the $marks object.
    my $retVal = {
                  marks => \@sortedList,
                  fig => $fig,
                  fid => $fid
                 };
    # Bless and return it.
    bless $retVal;
    return $retVal;
}

=head3 Insert

    my $loc = $marks->Insert($start, $len, $label);

Insert a new entry into the markup list. If an identical entry already exists, this
method will have no effect.

=over 4

=item start

Offset (1-based) of the first letter in the protein translation to be marked.

=item len

Number of letters in the protein translation to be marked.

=item label

Label for this markup.

=item RETURN

Returns the location in the markup list where the new entry can be found.

=back

=cut
#: Return Type $;
sub Insert {
    # Get the parameters.
    my ($self, $start, $len, $label) = @_;
    # Create the new entry.
    my $entry = [$start, $len, $label];
    # Look for it in the markup list.
    my ($retVal, $flag) = _Find($self->{marks}, $entry);
    # If it wasn't found, we have to insert it.
    if (! $flag) {
        splice @{$self->{marks}}, $retVal, 0, $entry;
    }
    # Return the location of the new entry.
    return $retVal;
}

=head3 Delete

    $marks->Delete($start, $len, $label);

Delete an entry from the markup list. If the entry does not exist, this method will
have no effect.

=over 4

=item start

Offset (1-based) of the first letter in the protein translation of the markup.

=item len

Number of letters in the protein translation affected by the markup.

=item label

Label of the markup.

=back

=cut
#: Return Type ;
sub Delete {
    # Get the parameters.
    my ($self, $start, $len, $label) = @_;
    # Create the new entry.
    my $entry = [$start, $len, $label];
    # Look for it in the markup list.
    my ($loc, $flag) = _Find($self->{marks}, $entry);
    # If it was found, we have to delete it.
    if ($flag) {
        splice @{$self->{marks}}, $loc, 1;
    }
}

=head3 List

    my @marks = $marks->List();

Return a list of this feature's markups. The value returned is a sorted list
of 3-tuples. Each 3-tuple consists of the offset to the start of the markup,
the length of the markup, and the label of the markup. The offset is 1-based
and the offset and length are both in terms of position in the feature's
protein translation.

=cut
#: Return Type @;
sub List {
    # Get the parameters.
    my ($self) = @_;
    # Return the result.
    return @{$self->{marks}};
}

=head3 Save

    $marks->Save();

Save this markup list. The markups will be written back to disk or to a database,
depending on the nature of the incoming access object.

=cut
#: Return Type ;
sub Save {
    # Get the parameters.
    my ($self) = @_;
    # Get the FIG-like object.
    my $fig = $self->{fig};
    # Write the markups.
    $fig->WriteMarkups($self->{fid}, $self->{marks});
}

=head3 Render

    my $proteinHtml = $marks->Render($id, $lineWidth);

Render the feature's protein translation using the specified markups. The translation will
be converted to HTML, with C<SPAN> tags used to alter the display of the marked-up areas. If
a line width is specified, then the translation will be broken into fixed-length chunks on
separate lines. (Some browsers have trouble with long unbroken character strings.)

The basic rendering algorithm works by copying sections of the translation string to the
return string interrupted by certain events. There are three types of events (1) start of
a markup, (2) end of a markup, and (3) end of a line. Three separate data structures will
be used to track the three events. Because we require all markups to be wholly contained
in other markups, the end-of-markup data structure can be handled using a simple stack. The
end-of-line structure is simply a number that tells us how much space remains on the current
line. The start-of-markup structure is the markup list itself, which has been carefully
maintained in such a way that we can run through it linearly to find the start locations in
the correct order.

=over 4

=item id (optional)

ID to be assigned to the translation. If this value is specified, the entire translation will
be wrapped in a C<PRE> element with the specified ID. The ID can be used to find the translation
in JavaScript code.

=item lineWidth (optional)

Number of characters per line. If this value is specified, the translation will be broken into
fixed-length chunks.

=item RETURN

Returns an HTML string rendering the marked-up protein translation.

=back

=cut
#: Return Type $;
sub Render {
    # Get the parameters.
    my ($self, $id, $lineWidth) = @_;
    my $fig = $self->{fig};
    # Check for an ID. Note that we use a leading space if an ID is present to separate the
    # ID attribute from the PRE tag.
    my $idAttribute = ($id ? " id=\"$id\"" : "");
    # Begin building the string by putting in the PRE tag.
    my $retVal = "<pre$idAttribute>";
    # Get our feature's protein translation.
    my $proteins = $fig->get_translation($self->{fid});
    # Get the translation length. This is used as a sort of plus-infinity in the various
    # loops.
    my $translationLength = length $proteins;
    my $infinity = $translationLength + 1;
    # Determine the chunk size. A new-line will be inserted after every chunk to make the
    # display more manageable.
    my $chunkSize = ($lineWidth ? $lineWidth : $infinity);
    # This next list is the end-of-markup stack. We prime it with a value past the
    # end of the translation string. The first element of a stack entry is the location
    # at which to put the tag. The second element is the tag itself. Most entries will
    # specify a "</span>" tag, but we want "</pre>" for the very last one.
    my @endMarks = ([$infinity, "</pre>"]);
    # Get the markup list and the number of markups.
    my $markList = $self->{marks};
    my $markCount = @{$markList};
    # Get the location of the next chunk break.
    my $chunkBreak = $chunkSize;
    # Now position on the first markup and the first protein.
    my $loc = 0;
    my $markIndex = 0;
    # Loop until we've copied everything, which means loop until we empty the end-mark
    # stack.
    while (@endMarks) {
        # Now we must find the next point where we need to do something. We'll stash the
        # location of the next point and the action we're to take. First, we look
        # for end-of-markup, which is the highest-priority event.
        my ($nextMark, $type) = ($endMarks[$#endMarks]->[0], 'endOfMarkup');
        # Next, look for the end of a chunk. This is lower priority than end-of-markup,
        # but higher priority than start-of-markup.
        if ($chunkBreak < $nextMark) {
            ($nextMark, $type) = ($chunkBreak, 'endOfChunk');
        }
        # Finally, look for the start of a new markup. This is the lowest-priority break.
        # Note we pretend there's an extra mark past the end of the list. This prevents
        # an infinite loop.
        my $nextStartMark = ($markIndex < $markCount ? $markList->[$markIndex]->[0] : $infinity);
        if ($nextStartMark < $nextMark) {
            ($nextMark, $type) = ($nextStartMark, 'startOfMarkup');
        }
        # Insure we don't go past the end of the translation string.
        if ($nextMark > $translationLength) {
            $nextMark = $translationLength;
        }
        # Now grab the string between here and the next mark and put it onto the return
        # string.
        $retVal .= substr $proteins, $loc, $nextMark - $loc;
        # Update our location in the protein translation string.
        $loc = $nextMark;
        # Now we can put in the appropriate character or tag.
        if ($type eq 'endOfMarkup') {
            # Close the SPAN tag to end the markup style.
            $retVal .= $endMarks[$#endMarks]->[1];
            # Pop the mark off the end-of-markup stack.
            pop @endMarks;
        } elsif ($type eq 'endOfChunk') {
            # Put in a new-line.
            $retVal .= "\n";
            # Update the pointer to the start of the next chunk.
            $chunkBreak += $chunkSize;
        } elsif ($type eq 'startOfMarkup') {
            # Put in a SPAN tag activating the markup label.
            my $tag = "<span class=\"$markList->[$markIndex]->[2]\">";
            $retVal .= $tag;
            # Now compute the location at which this markup will end.
            my $endPoint = $loc + $markList->[$markIndex]->[1];
            # Insure it's not past the end of the translation.
            if ($endPoint > $translationLength) {
                $endPoint = $translationLength;
            }
            # Push it onto the end-mark stack.
            push @endMarks, [$endPoint, "</span>"];
            # Move to the next markup in the markup list.
            $markIndex++;
        } else {
            # Here we have an error. The next markup point is not anything we recognize.
            Confess("Unknown marking directive $type when at location $loc in translation for $self->{fid}.");
        }
    }
    # Return the result.
    return $retVal;
}

=head3 GetLabels

    my @labels = Markups::GetLabels();

Return a list of the valid markup labels. These are computed from reading the appropriate style file.

A markup label is a style class found in the file C<$FIG_Config::fig/CGI/Html/css/labels.css>. This is
a very dumb parser, and looks for the style by processing lines where the first non-white character is
a period. Most programs for editting style files enforce that kind of structural restriction, so it is
not expected to be a problem.

=cut
#: Return Type @;
sub GetLabels {
    # Declare the return variable.
    my @retVal = ();
    # Open the style file.
    Open (\*STYLEIN, "<$FIG_Config::fig/CGI/Html/css/labels.css");
    # Loop until we run out of file, saving any labels we find.
    while (my $line = <STYLEIN>) {
        if ($line =~ /^\s*\.(\S+)\s/) {
            push @retVal, $1;
        }
    }
    # Close the style file.
    close STYLEIN;
    # Return the result.
    return @retVal;
}

=head3 Compare

    my $cmp = Markups::Compare($a, $b);

Compare two markup entries for sorting. Markup entries are sorted by ascending start location
followed by descending length. This is exactly the ideal order for rendering the markups.

A markup entry is always a reference to a 3-tuple, consisting of the 1-based starting offset,
the length, and then the label. The starting offset and length are relative to the protein
translation of the feature.

=over 4

=item a

First markup entry.

=item b

Second markup entry.

=item RETURN

Returns 0 if the markups are identical, a negative number if the first markup entry
should precede the second, and a positive number if the first markup entry should follow
the second.

=back

=cut
#: Return Type $;
sub Compare {
    # Get the parameters.
    my ($a, $b) = @_;
    # Compare the start positions.
    my $retVal = ($a->[0] <=> $b->[0]);
    # If necessary, compare the lengths. Note the comparison result is inverted because
    # we want longer lengths in front of shorter ones.
    if (! $retVal) {
        $retVal = -($a->[1] <=> $b->[1]);
    }
    # Finally, compare the labels. This is a string comparison.
    if (! $retVal) {
        $retVal = ($a->[2] cmp $b->[2]);
    }
    # Return the result.
    return $retVal;
}

=head3 Clear

    my  = $marks->Clear();

Delete all the markups.

=cut
#: Return Type ;
sub Clear {
    # Get the parameters.
    my ($self) = @_;
    # Erase the markup list.
    $self->{marks} = [];
}

=head2 Internal Utilities

=head3 Find

    my ($loc, $flag) = Markups::_Find($list, $entry);

Find the proper location for a markup entry in a markup list.

=over 4

=item list

Markup list to search. It must be sorted using the L</Compare> function.

=item entry

Reference to a 3-tuple representing the desired markup entry. The first element is the
offset to the start of the markup, the second is the length, and the third is the
label.

=item RETURN

Returns a 2-element list. The first element is the location in the markup list at
which the entry should be placed. The second element is TRUE if the entry was
found in the markup list and FALSE otherwise.

=back

=cut
#: Return Type @;
sub _Find {
    # Get the parameters.
    my ($list, $entry) = @_;
    # Get the length of the markup list.
    my $len = @{$list};
    # Declare the key loop variables.
    my $loc = 0;
    my $cmp = 1;
    # Loop through the list.
    while ($loc < $len && ($cmp = Compare($entry, $list->[$loc])) > 0) { $loc++; }
    # At this point, either $loc is the location where the new entry should be
    # inserted, or the location of an identical entry. The value of $cmp is 0 if
    # an identical entry was found.
    return ($loc, ($cmp == 0));
}

1;

