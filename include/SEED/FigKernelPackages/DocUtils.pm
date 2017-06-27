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

package DocUtils;

=head1 Sprout Documentation Utilities

=head2 Introduction

This module contains utilities for manipulating PERL source files.

=cut

use strict;
use Tracer;
use File::Basename;
use File::stat;
use Time::Local;
use CGI;
use Pod::Simple::HTML;

=head2 Public Methods

=head3 ModifyConfigFile

    DocUtils::ModifyConfigFile($targetFile, \%changes, \@inserts);

Modify the contents of a PERL configuration file. A PERL configuration file contains a
C<package> statement followed by a set of assignments having the form

    $var_name = "string";

with optional comments. The caller passes in a hash keyed by variable name, and the
configuration file will be updated to insure the variables mentioned in the hash have
the associated value in the specified configuration file. If the variables in the hash
already exist in the file, they will be replaced. If they do not exist they will be
added before the first line beginning with C<1;>.

=over 4

=item targetFile

Name of the configuration file to be changed.

=item changes

Reference to a hash mapping variable names to string values.

=item inserts

Reference to a list of lines to be inserted at the beginning.

=back

=cut
#: Return Type ;
sub ModifyConfigFile {
    # Get the parameters.
    my ($targetFile, $changes, $inserts) = @_;
    # Insure the target file exists.
    if (! -e $targetFile) {
        Confess("Configuration file $targetFile not found in ModifyConfigFile.");
    } else {
        Trace("Updating configuration file $targetFile.") if T(3);
        # Create a temporary file name from the target file name.
        my $tempFile = "$targetFile~";
        # Create a hash for tracking variable names used.
        my %varHash = ();
        # Open the target file for input and the temp file for output.
        Open(\*CONFIGIN, "<$targetFile");
        Open(\*CONFIGOUT, ">$tempFile");
        # Denote we haven't found a trailer line.
        my $oneFound = 0;
        # Count the lines skipped abd updated.
        my $skipLines = 0;
        my $updateLines = 0;
        my $insertLines = 0;
        # Read through the target file.
        while (my $line = <CONFIGIN>) {
            # Parse the input line. Note we look for the longest possible string value
            # that does not extend into the comment field.
            if ($line =~ /^\s*\$(\S+)\s*=\s*"([^#]*)";(.*)$/) {
                # Get the variable name and the value string.
                my ($varName, $value, $comment) = ($1, $2, $3);
                # See if this variable name has a new value.
                if (exists $changes->{$varName}) {
                    # Get the new value.
                    $value = $changes->{$varName};
                    # Denote it's been used.
                    $varHash{$varName} = 1;
                    Trace("New value for $varName is \"$value\".") if T(4);
                    $updateLines++;
                } else {
                    Trace("Variable $varName not modified.") if T(4);
                }
                # Write out the assignment statement.
                my $newLine = _BuildAssignment($varName, $value, $comment);
                print CONFIGOUT $newLine;
            } elsif ($line =~ /^1;/) {
                # This is the end line, so we write out the rest of the variables.
                for my $varName (keys %{$changes}) {
                    # Find out if this variable has already been seen.
                    if (! exists $varHash{$varName}) {
                        # It hasn't been seen, so we need to add it to the output.
                        my $value = $changes->{$varName};
                        my $newLine = _BuildAssignment($varName, $value, "");
                        Trace("Adding new value for $varName to config file.") if T(3);
                        print CONFIGOUT $newLine;
                        $insertLines++;
                    }
                }
                # Write out the end line.
                print CONFIGOUT "1;\n";
                # Denote we found it.
                $oneFound = 1;
            } elsif ($line =~ /package\s/i) {
                # Here we have a package statement. We write it out followed by the
                # insert lines.
                print CONFIGOUT $line;
                # Only proceed if insert lines were specified.
                if (defined $inserts) {
                    for my $insert (@{$inserts}) {
                        print CONFIGOUT "$insert\n";
                    }
                }
            } else {
                # Here the line doesn't parse, so we write it unmodified.
                print CONFIGOUT $line;
                $skipLines++;
            }
        }
        Trace("$skipLines lines skipped, $insertLines inserted, $updateLines updated.") if T(3);
        # Complain if we didn't find a trailer.
        if (! $oneFound) {
            Confess("No trailer (1;) found in FIG_Config.pm.");
        } else {
            # Close the files and rename the output file so it overwrites the input file.
            close CONFIGIN;
            close CONFIGOUT;
            rename $tempFile, $targetFile;
        }
    }
}

=head3 Augment

    DocUtils::Augment($inFile, $outDirectory, @statements);

Augment a PERL script file by adding a set of pre-defined statements. The statements
will be added immediately after the shebang line, if one is present. Otherwise they will
be added to the beginning of the file. The augmented file will have the same name
as the original file but will be placed in the specified output directory.

=over 4

=item inFile

Name of the input file.

=item outDirectory

Name of the directory to contain the output file.

=item libs

Statements to be added to the output file.

=back

=cut

sub Augment {
    # Get the parameters.
    my ($inFile, $outDirectory, @statements) = @_;
    # Get the input file name components.
    my ($fileName, $inDirectory) = fileparse($inFile);
    # Construct the output file name.
    my $outFile = "$outDirectory/$fileName";
    # Open the input and output files.
    (open INFILE, '<', $inFile) || Confess("Could not open input file $inFile.");
    (open OUTFILE, '>', $outFile) || Confess("Could not open output file $outFile.");
    # Get the first input line.
    my $line = <INFILE>;
    # If it's a shebang and we have statements to insert, echo
    # it out and save a blank line for later.
    if ($#statements >= 0 && $line =~ /#!/) {
        print OUTFILE $line;
        $line = "\n";
    }
    # Write out the augmenting statements.
    for my $statement (@statements) {
        print OUTFILE "$statement\n";
    }
    # Echo the saved line.
    print OUTFILE $line;
    # Spin out the rest of the file.
    while ($line = <INFILE>) {
        # If we're in PERL mode, we need to check for a duplicate line.
        print OUTFILE $line;
    }
    # Close both files.
    close INFILE;
    close OUTFILE;
}

=head3 GetDirectory

    my $fileHash = DocUtils::GetDirectory($directoryName);

Get a list of the files in the specified directory. The files will be returned as
a hash of lists. The hash will map the various file extensions to the corresponding
file titles. So, for example, if the directory contained C<Sprout.pm>, C<DocUtils.pl>,
C<Tracer.pm>, C<Genome.pm>, and C<Makefile>, the hash returned would be

    ( pm => ['Sprout', 'Tracer', 'Genome'], pl => ['DocUtils'], '' => ['Makefile'] )

=over 4

=item directoryName

Name of the directory whose files are desired.

=item RETURN

Returns a reference to a hash mapping each file extension to a list of the titles
of files having that extension.

=back

=cut

sub GetDirectory {
    # Get the parameter.
    my ($directoryName) = @_;
    # Create the return hash.
    my %retVal = ();
    # Open the directory and read in the file names.
    (opendir INDIR, $directoryName) || Confess("Could not open directory $directoryName.");
    my @fileNames = readdir INDIR;
    # Create the variables for holding the file titles and extensions.
    my ($ext, $title);
    # Loop through the files.
    for my $fileName (@fileNames) {
        # Separate the file name into a title and an extension.
        if ($fileName =~ /^\./) {
            # Ignore filenames that start with a period.
        } elsif ($fileName =~ /(.+)\.([^.]*)$/) {
            ($title, $ext) = ($1, $2);
            # Add the file's data into the hash.
            push @{$retVal{$ext}}, $title;
        } elsif ($fileName) {
            # Here the file name does not have an extension. Note that null filenames and
            # the various hidden files are skipped.
            ($title, $ext) = ($fileName, '');
            # Add the file's data into the hash.
            push @{$retVal{$ext}}, $title;
        }
    }
    # Return the result hash.
    return \%retVal;
}

=head3 GetPod

    my $podText = DocUtils::GetPod($parser, $fileName);

Get the POD text from the specified file using the specified parser. The
result will be a single text string with embedded new-lines. If there is
no POD text, this method will return an undefined value.

=over 4

=item parser

A subclass of B<Pod::Simple> that specifies the desired output format.

=item fileName

Name of the file to read.

=item RETURN

Returns the formatted Pod text if successful, or C<undef> if no Pod
documentation was found.

=back

=cut

sub GetPod {
    # Get the parameters.
    my ($parser, $fileName) = @_;
    # Declare the return variable.
    my $retVal;
    # Tell the parser to output to a string.
    $parser->output_string(\$retVal);
    # Parse the incoming file.
    $parser->parse_file($fileName);
    # Check for a meaningful result.
    if ($retVal !~ /\S/) {
        # No documentation was found, so we return an undefined value.
        undef $retVal;
    }
    # Return the result.
    return $retVal;
}

=head3 FindPod

    my $fileFound = DocUtils::FindPod($modName);

Attempt to find a POD document with the given name. If found, the file
name will be returned.

=over 4

=item modName

Name of the Pod module.

=item RETURN

Returns the name of the POD file found, or C<undef> if no such file was found.

=back

=cut

sub FindPod {
    # Get the parameters.
    my ($modName) = @_;
    # Declare the return variable.
    my $retVal;
    # Only proceed if this is a reasonable Pod name.
    if ($modName =~ /^(?:\w|::)+$/) {
        # Here we have a module. Convert the module name to a path.
        $modName =~ s/::/\//g;
        # Get a list of the possible file names for our desired file.
        my @files = map { ("$_/$modName.pod", "$_/$modName.pm", "$_/pod/$modName.pod") } @INC;
        # Find the first file that exists.
        for (my $i = 0; $i <= $#files && ! defined $retVal; $i++) {
            # Get the file name.
            my $fileName = $files[$i];
            # Fix windows/Unix file name confusion.
            $fileName =~ s#\\#/#g;
            if (-f $fileName) {
                $retVal = $fileName;
            }
        }
    } elsif ($modName =~ /^(\w+)\.pl$/) {
        # Here we have a command-line script. We strip off the .pl and
        # look for it in the binary directory.
        my $file = "$FIG_Config::bin/$1";
        $retVal = $file if -f $file;
    } elsif ($modName =~ /^\w+\.cgi$/) {
        # Here we have a web service.
        my $file = "$FIG_Config::fig/CGI/$modName";
        $retVal = $file if -f $file;
    }
    # Return the result.
    return $retVal;
}

=head3 ShowPod

    my $html = DocUtils::ShowPod($module, $url);

Return the HTML pod documentation for the specified module. The incoming
URL will be used to relocate links.

=over 4

=item module

Name of the module whose POD documentation is to be converted to HTML.

=item url

URL prefix to be used for documentation of other modules. It should be possible
to concatenate a module name directly to this string and produce a valid URL.

=item RETURN

Returns HTML text for displaying the POD documentation. The HTML will not include
page or body tags, and will be enclosed in a DIV block named C<pod>. Errors will
be displayed as block quotes of class C<error>.

=back

=cut

sub ShowPod {
    # Get the parameters.
    my ($module, $url) = @_;
    # We'll build the HTML in here.
    my @lines;
    # Try to find the module.
    my $fileFound = FindPod($module);
    if (! $fileFound) {
        push @lines, CGI::blockquote({ class => 'error' }, "Module $module not found.");
    } else {
        # We have a file containing our module documentation. Display its name
        # and date. This helps us to insure we have the correct file.
        my $fileData = stat($fileFound);
        my $fileDate = Tracer::DisplayTime($fileData->mtime);
        push @lines, CGI::p("Documentation read from $fileDate version of  $fileFound.");
        # Now the real meaty part. We must convert the file's POD to hTML.
        # To do that, we need a parser.
        my $parser = Pod::Simple::HTML->new();
        # Denote we want an index.
        $parser->index(1);
        # Set up L-links to use this script.
        $parser->perldoc_url_prefix($url);
        # Denote that we want to format the Pod into a string.
        my $pod;
        $parser->output_string(\$pod);
        # Parse the file.
        $parser->parse_file($fileFound);
        # Check for a meaningful result.
        if ($pod !~ /\S/) {
            # No luck. Output an error message.
            push @lines, CGI::blockquote({ class => 'error' }, "No POD documentation found in <u>$module</u>.");
        } else {
            # Put the result in the output area. We use a DIV to give ourselves
            # greater control in the CSS file.
            push @lines, CGI::start_div({ id => "pod" }), $pod, CGI::end_div();
            # Put a horizontal line at the bottom to make it pretty.
            push @lines, CGI::hr({ style => 'clear: all'});
        }
    }
    # Return the result.
    return join("\n", @lines);
}


=head2 Private Methods

=head3 _BuildAssignment

    my $statement = _BuildAssignment($varName, $value, $comment);

Create an assignment statement out of the specified components.

=over 4

=item varName

Variable name.

=item value

Value to be assigned to the variable (will be quoted).

=item comment

Comments or trailing characters.

=back

=cut

sub _BuildAssignment {
    # Get the parameters.
    my ($varName, $value, $comment) = @_;
    # Pad the variable name.
    my $varPad = Tracer::Pad($varName, 30);
    # Check the value. It could be a string, a hash reference literal, or
    # a list reference literal.
    my $literal;
    if ($value =~ /^{.+}$|^\[.+\]$/) {
        # Here we have a reference.
        $literal = $value;
    } else {
        # Here we have a string.
        $literal = "\"$value\"";
    }
    # Return the assignment statement.
    my $retVal = '$' . "$varPad = $literal; $comment\n";
    return $retVal;
}


1;
