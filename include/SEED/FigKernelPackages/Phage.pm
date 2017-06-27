#_perl_

=pod

=head1 

Methods used by Rob and others to access the phage genomes.

=cut

package Phage;
use strict;
use Data::Dumper;
use FIG;

=head2 Methods

=head3 new

Just instantiate the object and return $self
Can also provide a fig object to the class.

=cut

sub new {
	my ($class, $fig)=@_;
	my $self={};
	if (defined $fig) {
		$self->{'fig'}=$fig;
	}
	else {
		$self->{'fig'}=new FIG;
	}
	return bless $self, $class;
}


=head3 phages

Get a list of all the phage genome IDs.

   my @phages = Phage->phages();

=cut

sub phages {
	my $self=shift;
	my %seen;
	return grep {!$seen{$_}++} grep { $self->{'fig'}->is_genome($_) } map {$_->[0]} $self->{'fig'}->get_attributes(undef, 'virus_type', 'Phage');
}


=head3 is_phage_function

Is the function a phage function.
	my $bool = $phage->is_phage_function($fn);

=cut

sub is_phage_function {
	my ($self, $fn)=@_;
	
	# false positives
	return 0 if ($fn =~ /phage shock protein/i);

	# positives
	if (
		$fn =~ /\bphage\b/i       || 
		$fn =~ /integrase/i       ||
		$fn =~ /tail protein/i    ||
		$fn =~ /minor structural protein/i ||
		$fn =~ /major structural protein/i ||
		$fn =~ /tail fiber/i ||
		$fn =~ /baseplate/i ||
		$fn =~ /tape measure/i
	) {
		return 1;
	}
	return 0;
}

=head3 prophages_in_genome

Get the ids of all the known prophages in the genome

	my @prophage_ids = $phage->prophages_in_genome($genome);

=cut

sub prophages_in_genome {
	my ($self, $genome) = @_;
	return $self->{'fig'}->all_features($genome, "pp");
}


=head3 prophage_pegs

Get all the pegs in the prophages in a genome

	my @pegs = $phage->prophage_pegs($genome);

=cut

sub prophage_pegs {
	my ($self, $genome) = @_;
	my @pegs = ();
	foreach my $pp ($self->prophages_in_genome($genome)) {
		my ($contig, $beg, $end)=$self->{'fig'}->boundaries_of($self->{'fig'}->feature_location($pp));
		my ($temp, $rstart, $rend) = $self->{'fig'}->genes_in_region($genome, $contig, $beg, $end);
		push @pegs, grep {m/\.peg\./} @$temp;
	}
	return @pegs;
}



1;

