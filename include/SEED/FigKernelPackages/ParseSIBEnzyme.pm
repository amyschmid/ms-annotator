=pod

=head1 ParseSIBEnzyme

Parse the SIB enzyme.dat file available from ftp://ftp.expasy.org/databases/enzyme/enzyme.dat and return an object with all the data

Written by Rob Edwards, 9/13/15 in Urbana

=cut

use strict;
use File::Fetch;
package ParseSIBEnzyme;



=head2 Methods

=head3 new

Just instantiate the object and return $self

You can start with an empty object:

$parse =  ParseSIBEnzyme->new()

or pass in the location of the file:

$parse = ParseSIBEnzyme->new(-file=>"filename");


=cut

sub new {
	my ($class, %args)=@_;
	my $self={};
	if ($args{'-file'}) {$self->{'file'}=$args{'-file'}}

	return bless $self, $class;
}


=head3 file

Get and set the file name that we parse

=cut

sub file {
	my ($self, $file) = @_;
	if (defined $file) {$self->{'file'} = $file}
	return $self->{'file'}
}


=head3 get_datafile

Get a new version of the data file and store it.

If you do not provide a directory to store it in, it will be put in FIG_Config::temp

eg.
	my $path = $parser->get_datafile('/homes/redwards');
pr
	my $path - $parser->get_datafile(); # ends up in FIG_Config::temp

Returns the full path to the file, and also sets the file name so that you 
can immediately call parse()

=cut

sub get_datafile {
	my ($self, $loc) = @_;
	if (!defined $loc) {$loc = $FIG_Config::temp}

	# where to get the ec file from:
	my $ecsource = "ftp://ftp.expasy.org/databases/enzyme/enzyme.dat";

	my $ff = File::Fetch->new(uri => $ecsource);
	my $ecfile = $ff->fetch( to => $loc );

	$self->{'file'}=$ecfile;
	return $ecfile;
}


=head3 parse

Parse the file that we have been given and return the data structure
with the parts of the data.

The current data structure has the following fields:
	header => the header information in the file (ie. the CC parts)
	release => the date of release of the file
	ids => a list of all EC ids that we encounter
	
	deleted => a list of all EC ids that have been deleted
	transferred => a list of all EC ids that have been transferred

	the rest of the data is hashed by EC number for fast lookup, and uses
	these fields from the enzyme.dat file:


	ID	ID number			A scalar
	DE	Accepted name			A scalar
	AN	Alternative names		An array
	CA	Catalyzed activity		An array
	CC	Comments			An array
	CF	Cofactors			An array
	DR	Other database references	An array
	PR	Prosite cross reference		An array

In other words, only ID and DE are unique per entry, the other fields
can occur multiple times and so we store them as arrays.

=cut


sub parse {
	my ($self) = @_;
	unless (-e $self->{'file'}) {die $self->{'file'} . " does not exist. Please provide a file (e.g. from ftp://ftp.expasy.org/databases/enzyme/enzyme.dat)"}
	open(IN, $self->{'file'}) || die "Can't open " . $self->{'file'};
	local $/ = "\n//\n";
	while (<IN>) {
		chomp;
		if (/^CC/) {
			$self->{'data'}->{'header'} .= $_;
			if (/Release of\s+(\S+)/) {$self->{'data'}->{'release'}=$1}
		}
		else {
			my @parts = split /\n/;
			my $entry;
			foreach my $p (@parts) {
				if ($p =~ s/^ID\s+//) {$entry->{'ID'}=$p}
				elsif ($p =~ s/^DE\s+//) {$entry->{'DE'}=$p}
				else {
					$p =~ s/^(..)\s+//;
					push @{$entry->{$1}}, $p;
				}
			}
			# sanity check:
			if (!defined $entry->{'ID'}) {
				print STDERR "We did not get an ID from $_\n";
			}
			if (!defined $entry->{'DE'}) {
				print STDERR "We did not get an DE from $_\n";
			}

			# now keep a list of deleted and transferred IDs:
			if ($entry->{'DE'} eq "Deleted entry.") {push @{$self->{'data'}->{'deleted'}}, $entry->{'ID'}}
			if ($entry->{'DE'} =~ /Transferred entry/) {push @{$self->{'data'}->{'transferred'}}, $entry->{'ID'}}

			$self->{'data'}->{$entry->{'ID'}} = $entry;
			push @{$self->{'data'}->{'ids'}}, $entry->{'ID'};
		}
				
	}
	return $self->{'data'};
}



1;
