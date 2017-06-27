# -*- perl -*-
########################################################################
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
########################################################################

=head1 TODO

=over 4

=item Null arg to ContigO::dna_seq() should return entire contig seq.

=item Add method to access "FIG::crude_estimate_of_distance()"

=back

=cut

=head1 Overview

This module is a set of packages encapsulating the SEED's core methods
using an "OOP-like" style.

There are several modules clearly related to "individual genomes:"
GenomeO, ContigO, FeatureO (and I<maybe> AnnotationO).

There are also modules that deal with complex relationships between
pairs or sets of features in one, two, or more genomes,
rather than any particular single genome:
BBHO, CouplingO, SubsystemO, FunctionalRoleO, FigFamO.

Finally, the methods in "Attribute" might in principle attach
"atributes" to any type of object.
(Likewise, in principle one might also want to attach an "annotation"
to any type of object,
although currently we only support annotations of "features.")

The three modules that act on "individual genomes" have a reasonable clear
"implied heirarchy" relative to FIGO:

=over 4

    FIGO > GenomeO > ContigO > FeatureO

=back

However, inheritance is B<NOT> implemented using the C<@ISA> mechanism,
because some methods deal with "pairwise" or "setwise" relations between objects
or other more complex relationships that do not naturally fit into any heirarchy ---
which would get us into the whole quagmire of "multiple inheritance."

We have chosen to in many cases sidestep the entire issue of inheritance
via an I<ad hoc> mechanism:
If a "child" object needs access to its "ancestors'" methods,
we will explicitly pass it references to its "ancestors,"
as subroutine arguments.
This is admittedly ugly, clumsy, and potentially error-prone ---
but it has the advantage that, unlike multiple inheritance,
we understand how to do it...

MODULE DEPENDENCIES: FIG, FIG_Config, FigFams, SFXlate, SproutFIG, Tracer,
    gjoparseblast, Data::Dumper.

=cut

########################################################################
package FIGO;
########################################################################
use strict;
use FIG;
use FIGV;
use FIG_Config;
use SFXlate;
use SproutFIG;
use Tracer;
use Data::Dumper;
use Carp;
use FigFams;
use gjoparseblast;

=head1 FIGO

The effective "base class" containing a few "top-level" methods.

=cut


=head3 new

Constructs a new FIGO object.

=over 4

=item USAGE:

    my $figO = FIGO->new();                    #...Subclass defaults to FIG

    my $figO = FIGO->new('SPROUT');            #...Subclass is a SPROUT object

    my $figO = FIGO->new($orgdir);             #...Subclass includes $orgdir as a "Virtual" SEED genome

    my $figO = FIGO->new($orgdir, 'SPROUT');   #...Subclass includes $orgdir as a "Virtual" SPROUT genome

=back

=cut

sub new {
    my ($class, @argv) = @_;
    
    my $fig;
    if (@argv) {
	print STDERR ("New FIGO using FIGV( ",
		      join(qq(, ), @argv),
		      " )\n",
		      ) if $ENV{FIG_DEBUG};
	
	$fig = FIGV->new(@argv);
    }
    else {
	print STDERR "FIGO using FIG with installed SEED orgs\n" if $ENV{FIG_DEBUG};
	$fig = FIG->new();
    }
    
    my $self = {};
    $self->{_fig} = $fig;
    $self->{_tmp_dir} = $FIG_Config::temp;
    return bless $self, $class;
}

sub function_of {
    my($self,$id) = @_;

    my $fig  = $self->{_fig};
    my $func = $fig->function_of($id);

    return ($func ? $func : "");
}

=head3 genomes

Returns a list of Taxonomy-IDs, possibly constrained by selection criteria.
(Default: Empty constraint returns all Tax-IDs in the SEED or SPROUT.)

=over 4

=item USAGE:

    my @tax_ids = $figo->genomes();

    my @tax_ids = $figo->genomes( @constraints );

=item @constraints

One or more element of: complete, prokaryotic, eukaryotic, bacterial, archaeal, nmpdr.

=item RETURNS: List of Tax-IDs.

=item EXAMPLE:

L<Display all complete, prokaryotic genomes>

=back

=cut

sub genomes {
    my($self,@constraints) = @_;
    my $fig = $self->{_fig};

    my %constraints = map { $_ => 1 } @constraints;
    my @genomes = ();

    if ($constraints{complete})
    {
	@genomes = $fig->genomes('complete');
    }
    else
    {
	@genomes = $fig->genomes;
    }

    if ($constraints{prokaryotic})
    {
	@genomes = grep { $fig->is_prokaryotic($_) } @genomes;
    }

    if ($constraints{eukaryotic})
    {
	@genomes = grep { $fig->is_eukaryotic($_) } @genomes;
    }

    if ($constraints{bacterial})
    {
	@genomes = grep { $fig->is_bacterial($_) } @genomes;
    }

    if ($constraints{archaeal})
    {
	@genomes = grep { $fig->is_archaeal($_) } @genomes;
    }

    if ($constraints{nmpdr})
    {
	@genomes = grep { $fig->is_NMPDR_genome($_) } @genomes;
    }

    return map { &GenomeO::new('GenomeO',$self,$_) } @genomes;
}



=head3 subsystems

=over 4

=item RETURNS:

List of all subsystems.

=item EXAMPLE:

L<Accessing Subsystem data>

=back

=cut

sub subsystems {
    my($self) = @_;
    my $fig = $self->{_fig};

    return map { &SubsystemO::new('SubsystemO',$self,$_) } $fig->all_subsystems;
}


=head3 functional_roles

(Not yet implemented)

=over

=item RETURNS:

=item EXAMPLE:

=back

=cut

sub functional_roles {
    my($self) = @_;
    my $fig = $self->{_fig};

    my @functional_roles = ();

    return @functional_roles;
}



=head3 all_figfams

Returns a list of all FIGfam objects.

=over 4

=item USAGE:

    foreach $fam ($figO->all_figfams) { #...Do something }

=item RETURNS:

List of FIGfam Objects

=item EXAMPLE:

L<Accessing FIGfams>

=back

=cut

sub all_figfams {
    my($self) = @_;
    my $fig = $self->{_fig};
    my $fams = FigFams->new($fig);
    return map { &FigFamO::new('FigFamO',$self,$_) } $fams->all_families;
}



=head3 family_containing

=over 4

=item USAGE:

    my ($fam, $sims) = $figO->family_containing($seq);

=item $seq:

A protein translation string.

=item RETURNS:
 
$fam:  A FIGfam Object.

$sims: A set of similarity objects.

=item EXAMPLE: L<Placing a sequence into a FIGfam>

=back

=cut

sub family_containing {
    my($self,$seq) = @_;

    my $fig = $self->{_fig};
    my $fams = FigFams->new($fig);
    my($fam,$sims) = $fams->place_in_family($seq);
    if ($fam)
    {
	return (&FigFamO::new('FigFamO',$self,$fam->family_id),$sims);
    }
    else
    {
	return undef;
    }
}

=head3 figfam

=over 4

=item USAGE:

    my $fam = $figO->figfam($family_id);

=item $family_id;

A FigFam ID

=item RETURNS:
 
$fam:  A FIGfam Object.

=back

=cut

sub figfam {
    my($self,$fam_id) = @_;

    return &FigFamO::new('FigFamO',$self,$fam_id);
}


########################################################################
package GenomeO;
########################################################################
use Carp;
use Data::Dumper;

=head1 GenomeO

=cut


=head3 new

Constructor of GenomeO objects.

=over 4

=item USAGE:

    my $orgO = GenomeO->new($figO, $tax_id);

=item RETURNS:

A new "GenomeO" object.

=back

=cut

sub new {
    my($class,$figO,$genomeId) = @_;

    my $self = {};
    $self->{_figO} = $figO;
    $self->{_id} = $genomeId;
    return bless $self, $class;
}



=head3 id

=over 4

=item USAGE:

    my $tax_id = $orgO->id();

=item RETURNS:

Taxonomy-ID of "GenomeO" object.

=back

=cut

sub id {
    my($self) = @_;

    return $self->{_id};
}



=head3 genus_species

=over 4

=item USAGE:

    $gs = $orgO->genus_species();

=item RETURNS:

Genus-species-strain string

=back

=cut

sub genus_species {
    my($self) = @_;
    
    my $fig = $self->{_figO}->{_fig};
    if (defined($fig)) {
	return $fig->genus_species($self->{_id});
    }
    else {
	confess "Undefined FIG or FIGV\n", Dumper($self);
    }
}



=head3 taxonomy_of

=over 4

=item FUNCTION:

Return the TAXONOMY string of a "GenomeO" object.

=item USAGE:

    my $taxonomy = $orgO->taxonomy_of();

=item RETURNS:

TAXONOMY string.

=back

=cut

sub taxonomy_of {
    my ($self) = @_;

    my $figO = $self->{_figO};
    my $fig  = $figO->{_fig};

    return $fig->taxonomy_of($self->{_id});
}


=head3 contigs_of

=over 4

=item RETURNS:

List of C<contig> objects contained in a C<GenomeO> object.

=item EXAMPLE:

L<Show how to access contigs and extract sequence>

=back

=cut

sub contigs_of {
    my($self) = @_;

    my $figO = $self->{_figO};
    my $fig  = $figO->{_fig};
    return map { &ContigO::new('ContigO',$figO,$self->id,$_) } $fig->contigs_of($self->id);
}



=head3 features_of

=over 4

=item FUNCTION:

Returns a list of "FeatureO" objects contained in a "GenomeO" object.

=item USAGE:

    my @featureOs = $orgO->features_of();        #...Fetch all features

or

    my @featureOs = $orgO->features_of('peg');   #...Fetch only PEGs

=item RETURNS:

List of "FeatureO" objects.

=back

=cut

sub features_of {
    my($self,$type) = @_;

    my $figO = $self->{_figO};
    my $fig  = $figO->{_fig};

    return map { &FeatureO::new('FeatureO',$figO,$_) } $fig->all_features($self->id,$type);
}


=head3 display

Prints the genus, species, and strain information about a genome to STDOUT.

=over 4

=item USAGE:

    $genome->display();

=item RETURNS:

(Void)

=back

=cut

sub display {
    my($self) = @_;

    print join("\t",("Genome",$self->id,$self->genus_species)),"\n";
}



########################################################################
package ContigO;
########################################################################
use Data::Dumper;

=head1 ContigO

Methods for working with DNA sequence objects.

=cut

=head3 new

Contig constructor.

=over 4

=item USAGE:

    $contig = ContigO->new( $figO, $genomeId, $contigId);

=item $figO:

Parent FIGO object.

=item $genomeId:

Taxon-ID for the genome the contig is from.

=item $contigId:

Identifier for the contig

=item RETURNS:

A "ContigO" object.

=back

=cut

sub new {
    my($class,$figO,$genomeId,$contigId) = @_;

    my $self = {};
    $self->{_figO} = $figO;
    $self->{_id} = $contigId;
    $self->{_genome} = $genomeId;
    return bless $self, $class;
}



=head3 id

=over 4

=item RETURNS:

Sequence ID string of "ContigO" object

=back

=cut

sub id {
    my($self) = @_;

    return $self->{_id};
}


=head3 genome

=over 4

=item USAGE:

    my $tax_id = $contig->genome->id();

=item RETURNS:

Tax-ID of the GenomeO object containing the contig object.

=back

=cut

sub genome {
    my($self) = @_;

    my $figO = $self->{_figO};
    return GenomeO->new($figO,$self->{_genome});
}



=head3 contig_length

=over 4

=item USAGE:

    my $len = $contig->contig_length();

=item RETURNS:

Length of contig's DNA sequence.

=back

=cut

sub contig_length {
    my($self) = @_;

    my $fig = $self->{_figO}->{_fig};
    my $contig_lengths = $fig->contig_lengths($self->genome->id);
    return $contig_lengths->{$self->id};
}


=head3 dna_seq

=over 4

=item USAGE:

    my $seq = $contig->dna_seq(beg, $end);

=item $beg:

Begining point of DNA subsequence

=item $end:

End point of DNA subsequence

=item RETURNS:

String containing DNA subsequence running from $beg to $end
(NOTE: if $beg > $end, returns reverse complement of DNA subsequence.)

=back

=cut

sub dna_seq {
    my($self,$beg,$end) = @_;

    my $fig = $self->{_figO}->{_fig};
    my $max = $self->contig_length;
    if (($beg && (&FIG::between(1,$beg,$max))) &&
	($end && (&FIG::between(1,$end,$max))))
    {
	return $fig->dna_seq($self->genome->id,join("_",($self->id,$beg,$end)));
    }
    else
    {
	return undef;
    }
}


=head3 display

Prints summary information about a "ContigO" object to STDOUT:

Genus, species, strain

Contig ID

Contig length

=over 4

=item RETURNS:

(Void)

=back

=cut

sub display {
    my($self) = @_;

    print join("ContigO",$self->genome->id,$self->id,$self->contig_length),"\n";
}

sub features_in_region {
    my($self,$beg,$end) = @_;
    my $figO = $self->{_figO};
    my $fig = $figO->{_fig};

    my($features) = $fig->genes_in_region($self->genome->id,$self->id,$beg,$end);
    return map { FeatureO->new($figO,$_) } @$features;
}



########################################################################
package FeatureO;
########################################################################
use Data::Dumper;
use Carp;

=head1 FeatureO

Methods for working with features on "ContigO" objects.

=cut


=head3 new

Constructor of new "FeatureO" objects

=over 4

=item USAGE:

    my $feature = FeatureO->new( $figO, $fid );

=item C<$figO>:

"Base" FIGO object.

=item C<$fid>:

Feature-ID for new feature

=item RETURNS:

A newly created "FeatureO" object.

=back

=cut

sub new {
    my($class,$figO,$fid) = @_;

    ($fid =~ /^fig\|\d+\.\d+\.[^\.]+\.\d+$/) || return undef;
    my $self = {};
    $self->{_figO} = $figO;
    $self->{_id} = $fid;
    return bless $self, $class;
}



=head3 id

=over 4

=item USAGE:

    my $fid = $feature->id();

=item RETURNS:

The FID (Feature ID) of a "FeatureO" object.

=back

=cut

sub id {
    my($self) = @_;

    return $self->{_id};
}



=head3 genome

=over 4

=item USAGE:

    my $taxid = $feature->genome();

=item RETURNS:

The Taxon-ID for the "GenomeO" object containing the feature.

=back

=cut

sub genome {
    my($self) = @_;
    my $figO = $self->{_figO};
    $self->id =~ /^fig\|(\d+\.\d+)/;
    return GenomeO->new($figO,$1);
}



=head3 type

=over 4

=item USAGE:

    my $feature_type = $feature->type();

=item RETURNS:

The feature object's "type" (e.g., "peg," "rna," etc.)

=back

=cut

sub type {
    my($self) = @_;

    $self->id =~ /^fig\|\d+\.\d+\.([^\.]+)/;
    return $1;
}



=head3 location

=over 4

=item USAGE:

    my $loc = $feature->location();

=item RETURNS:

A string representing the feature object's location on the genome's DNA,
in SEED "tbl format" (i.e., "contig_beging_end").

=back

=cut

sub location {
    my($self) = @_;

    my $fig = $self->{_figO}->{_fig};
    return scalar $fig->feature_location($self->id);
}


=head3 contig

=over 4

=item USAGE:

    my $contig = $feature->contig();

=item RETURNS:

A "ContigO" object to access the contig data
for the contig the feature is on.

=back

=cut

sub contig {
    my($self) = @_;

    my $figO = $self->{_figO};
    my $loc      = $self->location;
    my $genomeID = $self->genome->id;
    return (($loc =~ /^(\S+)_\d+_\d+$/) ? ContigO->new($figO,$genomeID,$1) : undef);
}



=head3 begin

=over 4

=item USAGE:

    my $beg = $feature->begin();

=item RETURNS:

The numerical coordinate of the first base of the feature.

=back

=cut

sub begin {
    my($self) = @_;

    my $loc = $self->location;
    return ($loc =~ /^\S+_(\d+)_\d+$/) ? $1 : undef;
}



=head3 end

=over 4

=item USAGE:

    my $end = $feature->end();

=item RETURNS:

The numerical coordinate of the last base of the feature.

=back

=cut

sub end {
    my($self) = @_;

    my $loc = $self->location;
    return ($loc =~ /^\S+_\d+_(\d+)$/) ? $1 : undef;
}



=head3 dna_seq

=over 4

=item USAGE:

    my $dna_seq = $feature->dna_seq();

=item RETURNS:

A string contining the DNA subsequence of the contig
running from the first to the last base of the feature.

If ($beg > $end), the reverse complement subsequence is returned.

=back

=cut

sub dna_seq {
    my($self) = @_;

    my $fig = $self->{_figO}->{_fig};
    my $fid = $self->id;
    my @loc = $fig->feature_location($fid);
    return $fig->dna_seq(&FIG::genome_of($fid),@loc);
}



=head3 prot_seq

=over 4

=item USAGE:

    my $dna_seq = $feature->prot_seq();

=item RETURNS:

A string contining the protein translation of the feature (if it exists),
or the "undef" value if the feature does not exist or is not a PEG.

=back

=cut

sub prot_seq {
    my($self) = @_;

    ($self->type eq "peg") || return undef;
    my $fig = $self->{_figO}->{_fig};
    my $fid = $self->id;
    return $fig->get_translation($fid);
}



=head3 function_of

=over 4

=item USAGE:

    my $func = $feature->function_of();

=item RETURNS:

A string containing the function assigned to the feature,
or the "undef" value if no function has been assigned.

=back

=cut

sub function_of {
    my($self) = @_;

    my $fig = $self->{_figO}->{_fig};
    my $fid = $self->id;
    return scalar $fig->function_of($fid);
}



=head3 coupled_to

=over 4

=item USAGE:

    my @coupled_features = $feature->coupled_to();

=item RETURNS:

A list of "CouplingO" objects describing the evidence for functional coupling
between this feature and other nearby features.

=back

=cut

sub coupled_to {
    my($self) = @_;

    ($self->type eq "peg") || return ();
    my $figO = $self->{_figO};
    my $fig  = $figO->{_fig};
    my $peg1 = $self->id;
    my @coupled = ();
    foreach my $tuple ($fig->coupled_to($peg1))
    {
	my($peg2,$sc) = @$tuple;
	push(@coupled, &CouplingO::new('CouplingO',$figO,$peg1,$peg2,$sc));
    }
    return @coupled;
}



=head3 annotations

=over 4

=item USAGE:

    my @annot_list = $feature->annotations();

=item RETURNS:

A list of "AnnotationO" objects allowing access to the annotations for this feature.

=back

=cut

sub annotations {
    my($self) = @_;

    my $figO = $self->{_figO};
    my $fig  = $figO->{_fig};

    return map { &AnnotationO::new('AnnotationO',@$_) } $fig->feature_annotations($self->id,1);
}


=head3 in_subsystems

=over 4

=item USAGE:

    my @subsys_list = $feature->in_subsystems();

=item RETURNS:

A list of "SubsystemO" objects allowing access to the subsystems
that this feature particupates in.

=back

=cut

sub in_subsystems {
    my($self) = @_;
    my $figO = $self->{_figO};
    my $fig  = $figO->{_fig};

    return map { SubsystemO->new($figO,$_) } $fig->peg_to_subsystems($self->id);
}


=head3 possibly_truncated

=over 4

=item USAGE:

    my $trunc = $feature->possibly_truncated();

=item RETURNS:

Boolean C<TRUE> if the feature may be truncated;
boolean C<FALSE> otherwise.

=back

=cut

sub possibly_truncated {
    my($self) = @_;
    my $figO = $self->{_figO};
    my $fig  = $figO->{_fig};

    return $fig->possibly_truncated($self->id);
}



=head3 possible_frameshift

=over 4

=item USAGE:

    my $fs = $feature->possible_frameshift();

=item RETURNS:

Boolean C<TRUE> if the feature may be a frameshifted fragment;
boolean C<FALSE> otherwise.

(NOTE: This is a crude prototype implementation,
and is mostly as an example of how to code using FIGO.)

=back

=cut

sub possible_frameshift {
    my($self) = @_;
    my $figO = $self->{_figO};
    my $fig = $figO->{_fig};
    
    return $fig->possible_frameshift($self->id);
}



=head3 run

(Note: This function should be considered "PRIVATE")

=over 4

=item FUNCTION:

Passes a string containing a command to be execture by the "system" shell command.

=item USAGE:

    $feature->run($cmd);

=item RETURNS:

Nil if the execution of C<$cmd> was successful;
aborts with traceback if C<$cmd> fails.

=back

=cut

sub run {
    my($cmd) = @_;
    (system($cmd) == 0) || confess("FAILED: $cmd");
}



=head3 max

(Note: This function should be considered "PRIVATE")

=over 4

=item USAGE:

    my $max = $feature->max($x, $y);

=item C<$x> and  C<$y>

Numerical values.

=item RETURNS:

The larger of the two numerical values C<$x> and C<$y>.

=back

=cut

sub max {
    my($x,$y) = @_;
    return ($x < $y) ? $y : $x;
}



=head3 min

(Note: This function should be considered "PRIVATE")

=over 4

=item USAGE:

    my $min = $feature->min($x, $y);

=item C<$x> and C<$y>

Numerical values.

=item RETURNS:

The smaller of the two numerical values C<$x> and C<$y>.

=back

=cut

sub min {
    my($x,$y) = @_;
    return ($x < $y) ? $x : $y;
}

=head3 sims

=over 4

=item FUNCTION:

Returns precomputed "Sim.pm" objects from the SEED.

=item USAGE:

    my @sims = $pegO->sims( -all, -cutoff => 1.0e-10);

    my @sims = $pegO->sims( -max => 50, -cutoff => 1.0e-10);

=item RETURNS: List of sim objects.

=back

=cut

use Sim;
sub sims {
    my($self,%args) = @_;

    my $figO = $self->{_figO};
    my $fig  = $figO->{_fig};

    my $cutoff = $args{-cutoff} ? $args{-cutoff} : 1.0e-5;
    my $all    = $args{-all}    ? 'all'          : "fig";
    my $max    = $args{-max}    ? $args{-max}    : 10000;

    my @sims = $fig->sims($self->id,$max,$cutoff,$all);

    if (@sims) {
	my $peg1 = FeatureO->new($figO, $sims[0]->[0]);

	foreach my $sim (@sims) {
#	    $sim->[0] = $peg1;
#	    $sim->[1] = FeatureO->new($figO, $sim->[1]);
	}
    }

    return @sims;
}



=head3 bbhs

=over 4

=item FUNCTION:

Given a PEG-type "FeatureO" object, returns the list of BBHO objects
corresponding to the pre-computed BBHs for that PEG.

=item USAGE:

    my @bbhs = $pegO->bbhs();

=item RETURNS:

List of BBHO objects.

=back

=cut

sub bbhs {
    my($self) = @_;

    my $figO = $self->{_figO};
    my $fig  = $figO->{_fig};

    my @bbhs  = $fig->bbhs($self->id);
    return map { my($peg2,$sc,$bs) = @$_; bless({ _figO => $figO,
	                                          _peg1 => $self->id,
						  _peg2 => $peg2,
						  _psc => $sc,
						  _bit_score => $bs
						},'BBHO') } @bbhs;
}


=head3 display

=over 4

=item FUNCTION:

Prints info about a "FeatureO" object to STDOUT.

=item USAGE:

    $pegO->display();

=item RETURNS;

(void)

=back

=cut

sub display {
    my($self) = @_;

    print join("\t",$self->id,$self->location,$self->function_of),"\n",
          $self->dna_seq,"\n",
          $self->prot_seq,"\n";
}



########################################################################
package BBHO;
########################################################################

=head1 BBHO

Methods for accessing "Bidirectiona Best Hits" (BBHs).

=cut


=head3 new

Constructor of BBHO objects.

(NOTE: The "average user" should never need to invoke this method.)

=cut

sub new {
    my($class,$figO,$peg1,$peg2,$sc,$normalized_bitscore) = @_;

    my $self = {};
    $self->{_figO}      = $figO;
    $self->{_peg1}      = $peg1;
    $self->{_peg2}      = $peg2;
    $self->{_psc}       = $sc;
    $self->{_bit_score} = $normalized_bitscore

}



=head3 peg1

=over 4

=item USAGE:

    my $peg1 = $bbh->peg1();

=item RETURNS:

A "FeatureO" object corresponding to the "query" sequence
in a BBH pair.

=back

=cut

sub peg1 {
    my($self) = @_;

    my $figO = $self->{_figO};
    return FeatureO->new($figO, $self->{_peg1});
}

=head3 peg2

=over 4

=item USAGE:

    my $peg2 = $bbh->peg2();

=item RETURNS:

A "FeatureO" object corresponding to the "database" sequence
in a BBH pair.

=back

=cut

sub peg2 {
    my($self) = @_;

    my $figO = $self->{_figO};
    return FeatureO->new($figO,$self->{_peg2});
}



=head3 psc

=over 4

=item USAGE:

    my $psc = $bbh->psc();

=item RETURNS:

The numerical value of the BLAST E-value for the pair.

=back

=cut

sub psc {
    my($self) = @_;

    return $self->{_psc};
}



=head3 norm_bitscore


=over 4

=item USAGE:

    my $bsc = $bbh->norm_bitscore();

=item RETURNS:

The "BLAST bit-score per aligned character" for the pair.

=back

=cut

sub norm_bitscore {
    my($self) = @_;

    return $self->{_bit_score};
}



########################################################################
package AnnotationO;
########################################################################

=head1 AnnotationO

Methods for accessing SEED annotations.

=cut



=head3 new

=over 4

=item FUNCTION:

Cronstruct a new "AnnotationO" object

=item USAGE:

    my $annotO = AnnotationO->new( $fid, $timestamp, $who, $text);

=item C<$fid>

A feature identifier.

=item C<$timestamp>

The C<UN*X> timestamp one wishes to associate with the annotation.

=item C<$who>

The annotator's user-name.

=item C<$text>

The textual content of the annotation.

=item RETURNS:

An "AnnotationO" object.

=back

=cut

sub new {
    my($class,$fid,$timestamp,$who,$text) = @_;

    my $self = {};
    $self->{_fid} = $fid;
    $self->{_timestamp} = $timestamp;
    $self->{_who} = $who;
    $self->{_text} = $text;
    return bless $self, $class;
}



=head3 fid

=over 4

=item FUNCTION:

Extract the feature-ID that was annotated.

=item USAGE:

    my $fid = $annotO->fid();

=item RETURNS;

The feature-ID as a string.

=back

=cut

sub fid {
    my($self) = @_;

    return $self->{_fid};
}



=head3 timestamp

=over 4

=item FUNCTION:

Extract the C<UN*X> timestamp of the annotation.

=item USAGE:

    my $fid = $annotO->timestamp();

=item RETURNS;

The timestamp as a string.

=back

=cut

sub timestamp {
    my($self,$convert) = @_;

    if ($convert)
    {
	return scalar localtime($self->{_timestamp});
    }
    else
    {
	return $self->{_timestamp};
    }
}



=head3 made_by

=over 4

=item FUNCTION:

Extract the annotator's user-name.

=item USAGE:

    my $fid = $annotO->made_by();

=item RETURNS;

The username of the annotator, as a string.

=back

=cut

sub made_by {
    my($self) = @_;

    my $who = $self->{_who};
    $who =~ s/^master://i;
    return $who;
}



=head3 text

=over 4

=item FUNCTION:

Extract the text of the annotation.

=item USGAE:

    my $text = $annotO->text();

=item RETURNS:

The text of the annotation, as a string.

=back

=cut

sub text {
    my($self) = @_;

    my $text = $self->{_text};
    return $text;
}


=head3 display

=over 4

=item FUNCTION:

Print the contents of an "AnnotationO" object to B<STDOUT>
in human-readable form.

=item USAGE:

    my $annotO->display();

=item RETURNS:

(void)

=back

=cut

sub display {
    my($self) = @_;

    print join("\t",($self->fid,$self->timestamp(1),$self->made_by)),"\n",$self->text,"\n";
}



########################################################################
package CouplingO;
########################################################################
use Data::Dumper;

=head1 CouplingO

Methods for accessing the "Functional coupling scores"
of PEGs in close physical proximity to each other.

=cut



=head3 new

=over 4

=item FUNCTION:

Construct a new "CouplingO" object
encapsulating the "functional coupling" score
between a pair of features in some genome.

=item USAGE:

    $couplingO = CouplingO->new($figO, $fid1, $fid2, $sc);

=item C<$figO>

Parent "FIGO" object.

=item C<$fid1> and C<$fid2>

A pair of feature-IDs.

=item C<$sc>

A functional-coupling score

=item RETURNS:

A "CouplingO" object.

=back

=cut

sub new {
    my($class,$figO,$peg1,$peg2,$sc) = @_;

    ($peg1 =~ /^fig\|\d+\.\d+\.peg\.\d+$/) || return undef;
    ($peg2 =~ /^fig\|\d+\.\d+\.peg\.\d+$/) || return undef;
    my $self = {};
    $self->{_figO} = $figO;
    $self->{_peg1} = $peg1;
    $self->{_peg2} = $peg2;
    $self->{_sc}   = $sc;
    return bless $self, $class;
}



=head3 peg1

=over 4

=item FUNCTION:

Returns a "FeatureO" object corresponding to the first FID in a coupled pair.

=item USAGE:

    my $peg1 = $couplingO->peg1();

=item RETURNS:

A "FeatureO" object.

=back

=cut

sub peg1 {
    my($self) = @_;

    my $figO = $self->{_figO};
    return FeatureO->new($figO,$self->{_peg1});
}



=head3 peg2

=over 4

=item FUNCTION:

Returns a "FeatureO" object corresponding to the second FID in a coupled pair.

=item USAGE:

    my $peg2 = $couplingO->peg2();

=item RETURNS:

A "FeatureO" object.

=back

=cut

sub peg2 {
    my($self) = @_;

    my $figO = $self->{_figO};
    return FeatureO->new($figO,$self->{_peg2});
}



=head3 sc

=over 4

=item FUNCTION:

Extracts the "functional coupling" score from a "CouplingO" object.

=item USAGE:

    my $sc = $couplingO->sc();

=item RETURNS:

A scalar score.

=back

=cut

sub sc {
    my($self) = @_;

    return $self->{_sc};
}



=head3 evidence

=over 4

=item FUNCTION:

Fetch the evidence for a "functional coupling" between two close PEGs,
in the form of a list of objects describing the "Pairs of Close Homologs" (PCHs)
supporting the existence of a functional coupling between the two close PEGs.

=item USAGE:

    my $evidence = $couplingO->evidence();

=item RETURNS

List of pairs of "FeatureO" objects.

=back

=cut

sub evidence {
    my($self) = @_;

    my $figO = $self->{_figO};
    my $fig  = $figO->{_fig};
    my @ev = ();
    foreach my $tuple ($fig->coupling_evidence($self->peg1->id,$self->peg2->id))
    {
	my($peg3,$peg4,$rep) = @$tuple;
	push(@ev,[&FeatureO::new('FeatureO',$figO,$peg3),
		  &FeatureO::new('FeatureO',$figO,$peg4),
		  $rep]);
    }
    return @ev;
}



=head3 display

=over 4

=item FUNCTION:

Print the contents of a "CouplingO" object to B<STDOUT> in human-readable form.

=item USAGE:

    $couplingO->display();

=item RETURNS:

(Void)

=back

=cut

sub display {
    my($self) = @_;

    print join("\t",($self->peg1,$self->peg2,$self->sc)),"\n";
}



########################################################################
package SubsystemO;
########################################################################
use Data::Dumper;
use Subsystem;

=head1 SubsystemO

=cut



=head3 new

=cut

sub new {
    my($class,$figO,$name) = @_;

    my $self = {};
    $self->{_figO} = $figO;
    $self->{_id} = $name;

    return bless $self, $class;
}



=head3 id

=cut

sub id {
    my($self) = @_;

    return $self->{_id};
}



=head3 usable


=cut

sub usable {
    my($self) = @_;

    my $figO = $self->{_figO};
    my $fig  = $figO->{_fig};
    return $fig->usable_subsystem($self->id);
}



=head3 genomes

=cut

sub genomes {
    my($self) = @_;

    my $figO = $self->{_figO};
    my $subO = $self->{_subO};
    if (! $subO) {
	$subO = $self->{_subO} = Subsystem->new($self->{_id}, $figO->{_fig});
    }
    
    return map { &GenomeO::new('GenomeO',$figO,$_) } $subO->get_genomes;
}



=head3 roles

=cut

sub roles {
    my($self) = @_;

    my $figO = $self->{_figO};
    my $subO = $self->{_subO};
    if (! $subO) {
	$subO = $self->{_subO} = Subsystem->new($self->{_id}, $figO->{_fig});
    }
    
    return map { &FunctionalRoleO::new('FunctionalRoleO',$figO,$_) }  $subO->get_roles($self->id);
}



=head3 curator

=cut

sub curator {
    my($self) = @_;

    my $figO = $self->{_figO};
    my $subO = $self->{_subO};
    if (! $subO) {
	$subO = $self->{_subO} = Subsystem->new($self->{_id}, $figO->{_fig});
    }
    
    return $subO->get_curator;
}




=head3 variant

=cut

sub variant {
    my($self,$genome) = @_;

    my $figO = $self->{_figO};
    my $subO = $self->{_subO};
    if (! $subO) {
	$subO = $self->{_subO} = Subsystem->new($self->{_id},$figO->{_fig});
    }
    
    return $subO->get_variant_code_for_genome($genome->id);
}



=head3 pegs_in_cell

=cut

sub pegs_in_cell {
    my($self,$genome,$role) = @_;

    my $figO = $self->{_figO};
    my $subO = $self->{_subO};
    if (! $subO) {
	$subO = $self->{_subO} = Subsystem->new($self->{_id},$figO->{_fig});
    }
    
    return $subO->get_pegs_from_cell($genome->id,$role->id);
}



########################################################################
package FunctionalRoleO;
########################################################################
use Data::Dumper;

=head1 FunctionalRoleO

Methods for accessing the functional roles of features.

=cut


=head3 new

=cut

sub new {
    my($class,$figO,$fr) = @_;

    my $self = {};
    $self->{_figO} = $figO;
    $self->{_id} = $fr;
    return bless $self, $class;
}



=head3 id

=cut

sub id {
    my($self) = @_;

    return $self->{_id};
}



########################################################################
package FigFamO;
########################################################################
use FigFams;
use FigFam;


=head1 FigFamO

=cut


=head3 new

=cut

sub new {
    my($class,$figO,$id) = @_;

    my $self = {};
    $self->{_figO} = $figO;
    $self->{_id} = $id;
    return bless $self, $class;
}



=head3 id

=cut

sub id {
    my($self) = @_;

    return $self->{_id};
}


=head3 function

=cut

sub function {
    my($self) = @_;

    my $fig  = $self->{_figO}->{_fig};
    my $famO = $self->{_famO};
    if (! $famO) { $famO = $self->{_famO} = &FigFam::new('FigFam',$fig,$self->id) }

    return $famO->family_function;
}



=head3 members

=cut

sub members {
    my($self) = @_;

    my $figO = $self->{_figO};
    my $fig  = $figO->{_fig};
    my $famO = $self->{_famO};
    if (! $famO) { $famO = $self->{_famO} = &FigFam::new('FigFam',$fig,$self->id) }

    return map { &FeatureO::new('FeatureO',$figO,$_) } $famO->list_members;
}

=head3 rep_seqs

=cut

sub rep_seqs {
    my($self) = @_;

    my $figO = $self->{_figO};
    my $fig  = $figO->{_fig};
    my $famO = $self->{_famO};
    if (! $famO) { $famO = $self->{_famO} = &FigFam::new('FigFam',$fig,$self->id) }

    return $famO->representatives;
}



=head3 should_be_member

=cut

sub should_be_member {
    my($self,$seq) = @_;

    my $figO = $self->{_figO};
    my $fig  = $figO->{_fig};
    my $famO = $self->{_famO};
    if (! $famO) { $famO = $self->{_famO} = &FigFam::new('FigFam',$fig,$self->id) }

    return $famO->should_be_member($seq);
}



=head3 display

=cut

sub display {
    my($self) = @_;

    print join("\t",($self->id,$self->function)),"\n";
}



########################################################################
package Attribute;
########################################################################
=head1 Attribute

(Note yet implemented.)

=cut

1;
__END__

=head1 Examples

=head3 Display all complete, prokaryotic genomes

use FIGO;
my $figO = FIGO->new();

foreach $genome ($figO->genomes('complete','prokaryotic'))
{
    $genome->display;
}

#---------------------------------------------

use FIG;
my $fig = FIG->new();

foreach $genome (grep { $fig->is_prokaryotic($_) } $fig->genomes('complete'))
{
    print join("\t",("Genome",$genome,$fig->genus_species($genome))),"\n";
}

###############################################

=head3 Show how to access contigs and extract sequence

use FIGO;
my $figO = FIGO->new();

$genomeId = '83333.1';
my $genome = GenomeO->new($figO, $genomeId);

foreach $contig ($genome->contigs_of)
{
    $tag1 = $contig->dna_seq(1,10);
    $tag2 = $contig->dna_seq(10,1);
    print join("\t",($tag1,$tag2,$contig->id,$contig->contig_length)),"\n";
}

#---------------------------------------------

use FIG;
my $fig = FIG->new();

$genomeId = '83333.1';

$contig_lengths = $fig->contig_lengths($genomeId);

foreach $contig ($fig->contigs_of($genomeId))
{
    $tag1 = $fig->dna_seq($genomeId,join("_",($contig,1,10)));
    $tag2 = $fig->dna_seq($genomeId,join("_",($contig,10,1)));
    print join("\t",($tag1,$tag2,$contig,$contig_lengths->{$contig})),"\n";
}

###############################################

### accessing data related to features

use FIGO;
my $figO = FIGO->new();

my $genome = GenomeO->new($figO, "83333.1");
my $peg  = "fig|83333.1.peg.4";
my $pegO = FeatureO->new($figO, $peg);

print join("\t",$pegO->id,$pegO->location,$pegO->function_of),"\n",
      $pegO->dna_seq,"\n",
      $pegO->prot_seq,"\n";

foreach $fidO ($genome->features_of('rna'))
{
    print join("\t",$fidO->id,$fidO->location,$fidO->function_of),"\n";
}

#---------------------------------------------


use FIG;
my $fig = FIG->new();

my $genome = "83333.1";
my $peg  = "fig|83333.1.peg.4";

print join("\t",$peg,scalar $fig->feature_location($peg),scalar $fig->function_of($peg)),"\n",
      $fig->dna_seq($genome,$fig->feature_location($peg)),"\n",
      $fig->get_translation($peg),"\n";

foreach $fid ($fig->all_features($genome,'rna'))
{
    print join("\t",$fid,scalar $fig->feature_location($fid),scalar $fig->function_of($fid)),"\n";
}

###############################################

### accessing similarities

use FIGO;
my $figO = FIGO->new();

$peg  = "fig|83333.1.peg.4";
$pegO = FeatureO->new($figO, $peg);

@sims = $pegO->sims;  # use sims( -all => 1, -max => 10000, -cutoff => 1.0e-20) to all
                      # sims (including non-FIG sequences
foreach $sim (@sims)
{
    $peg2  = $sim->id2;
    $pegO2 = FeatureO->new($figO, $peg2);
    $func  = $pegO2->function_of;
    $sc    = $sim->psc;
    print join("\t",($peg2,$sc,$func)),"\n";
}

#---------------------------------------------


use FIG;
my $fig = FIG new;

$peg  = "fig|83333.1.peg.4";

@sims = $fig->sims($peg,1000,1.0e-5,"fig");
foreach $sim (@sims)
{
    $peg2  = $sim->id2;
    $func  = $fig->function_of($peg2);
    $sc    = $sim->psc;
    print join("\t",($peg2,$sc,$func)),"\n";
}

###############################################

### accessing BBHs

use FIGO;
my $figO = FIGO new;

$peg  = "fig|83333.1.peg.4";
$pegO = FeatureO->new($figO, $peg);

@bbhs = $pegO->bbhs;
foreach $bbh (@bbhs)
{
    $peg2  = $bbh->peg2;
    $pegO2 = FeatureO->new($figO, $peg2);
    $func  = $pegO2->function_of;
    $sc    = $bbh->psc;
    print join("\t",($peg2,$sc,$func)),"\n";
}

#---------------------------------------------

use FIG;
my $fig = FIG->new();

$peg  = "fig|83333.1.peg.4";

@bbhs = $fig->bbhs($peg);
foreach $bbh (@bbhs)
{
    ($peg2,$sc,$bit_score) = @$bbh;
    $func  = $fig->function_of($peg2);
    print join("\t",($peg2,$sc,$func)),"\n";
}

###############################################

### accessing annotations

use FIGO;
my $figO = FIGO->new();

$peg  = "fig|83333.1.peg.4";
$pegO = FeatureO->new($figO, $peg);

@annotations = $pegO->annotations;

foreach $ann (@annotations)
{
    print join("\n",$ann->fid,$ann->timestamp(1),$ann->made_by,$ann->text),"\n\n";
}

#---------------------------------------------

use FIG;
my $fig = FIG->new();

$peg = "fig|83333.1.peg.4";
@annotations = $fig->feature_annotations($peg);
foreach $_ (@annotations)
{
    (undef,$ts,$who,$text) = @$_;
    $who =~ s/master://i;
    print "$ts\n$who\n$text\n\n";
}

###############################################

### accessing coupling data


use FIGO;
my $figO = FIGO->new();

my $peg  = "fig|83333.1.peg.4";
my $pegO = FeatureO->new($figO, $peg);
foreach $coupled ($pegO->coupled_to)
{
    print join("\t",($coupled->peg1,$coupled->peg2,$coupled->sc)),"\n";
    foreach $tuple ($coupled->evidence)
    {
	my($peg3O,$peg4O,$rep) = @$tuple;
	print "\t",join("\t",($peg3O->id,$peg4O->id,$rep)),"\n";
    }
    print "\n";
}

#---------------------------------------------


use FIG;
my $fig = FIG->new();

my $peg1  = "fig|83333.1.peg.4";
foreach $coupled ($fig->coupled_to($peg1))
{
    ($peg2,$sc) = @$coupled;
    print join("\t",($peg1,$peg2,$sc)),"\n";
    foreach $tuple ($fig->coupling_evidence($peg1,$peg2))
    {
	my($peg3,$peg4,$rep) = @$tuple;
	print "\t",join("\t",($peg3,$peg4,$rep)),"\n";
    }
    print "\n";
}

###############################################

=head3 Accessing Subsystem data

use FIGO;
my $figO = FIGO->new();

foreach $sub ($figO->subsystems)
{
    if ($sub->usable)
    {
	print join("\t",($sub->id,$sub->curator)),"\n";

	print "\tRoles\n";
	@roles = $sub->roles;
	foreach $role (@roles)
	{
	    print "\t\t",join("\t",($role->id)),"\n";
	}

	print "\tGenomes\n";
	foreach $genome ($sub->genomes)
	{
	    print "\t\t",join("\t",($sub->variant($genome),
				    $genome->id,
				    $genome->genus_species)),"\n";
	    @pegs = ();
	    foreach $role (@roles)
	    {
		push(@pegs,$sub->pegs_in_cell($genome,$role));
	    }
	    print "\t\t\t",join(",",@pegs),"\n";
	}
    }
}

#---------------------------------------------

use FIG;
my $fig = FIG->new();

foreach $sub (grep { $fig->usable_subsystem($_) } $fig->all_subsystems)
{
    $subO = Subsystem->new($sub, $fig);
    $curator = $subO->get_curator;
    print join("\t",($sub,$curator)),"\n";

    print "\tRoles\n";
    @roles = $subO->get_roles;
    foreach $role (@roles)
    {
	print "\t\t",join("\t",($role)),"\n";
    }

    print "\tGenomes\n";
    foreach $genome ($subO->get_genomes)
    {
	print "\t\t",join("\t",($subO->get_variant_code_for_genome($genome),
	                        $genome,
	                        $fig->genus_species($genome))),"\n";
	foreach $role (@roles)
	{
	    push(@pegs,$subO->get_pegs_from_cell($genome,$role));
	}
	print "\t\t\t",join(",",@pegs),"\n";
    }
    print "\n";
}

###############################################

=head3 Accessing FIGfams

use FIGO;
my $figO = FIGO->new();

foreach $fam ($figO->all_figfams)
{
    print join("\t",($fam->id,$fam->function)),"\n";
    foreach $pegO ($fam->members)
    {
	$peg = $pegO->id;
	print "\t$peg\n";
    }
}

#---------------------------------------------

use FIG;
use FigFam;
use FigFams;

my $fig = FIG->new();
my $figfams = FigFams->new($fig);

foreach $fam ($figfams->all_families)
{
    my $figfam = FigFam->new($fig, $fam);
    print join("\t",($fam,$figfam->family_function)),"\n";
    foreach $peg ($figfam->list_members)
    {
	print "\t$peg\n";
    }
}

###############################################

=head3 Placing a sequence into a FIGfam

use FIGO;
my $figO = FIGO->new();

$seq = "MKLYNLKDHNEQVSFAQAVTQGLGKNQGLFFPHDLPEFSLTEIDEMLKLDFVTRSAKILS
AFIGDEIPQEILEERVRAAFAFPAPVANVESDVGCLELFHGPTLAFKDFGGRFMAQMLTH
IAGDKPVTILTATSGDTGAAVAHAFYGLPNVKVVILYPRGKISPLQEKLFCTLGGNIETV
AIDGDFDACQALVKQAFDDEELKVALGLNSANSINISRLLAQICYYFEAVAQLPQETRNQ
LVVSVPSGNFGDLTAGLLAKSLGLPVKRFIAATNVNDTVPRFLHDGQWSPKATQATLSNA
MDVSQPNNWPRVEELFRRKIWQLKELGYAAVDDETTQQTMRELKELGYTSEPHAAVAYRA
LRDQLNPGEYGLFLGTAHPAKFKESVEAILGETLDLPKELAERADLPLLSHNLPADFAAL
RKLMMNHQ";
$seq =~ s/\n//gs;

my($fam,$sims) = $figO->family_containing($seq);

if ($fam)
{
    print join("\t",($fam->id,$fam->function)),"\n";
    print &Dumper($sims);
}
else
{
    print "Could not place it in a family\n";
}

#---------------------------------------------

use FIG;
use FigFam;
use FigFams;

my $fig = FIG->new();
my $figfams = FigFams->new($fig);

$seq = "MKLYNLKDHNEQVSFAQAVTQGLGKNQGLFFPHDLPEFSLTEIDEMLKLDFVTRSAKILS
AFIGDEIPQEILEERVRAAFAFPAPVANVESDVGCLELFHGPTLAFKDFGGRFMAQMLTH
IAGDKPVTILTATSGDTGAAVAHAFYGLPNVKVVILYPRGKISPLQEKLFCTLGGNIETV
AIDGDFDACQALVKQAFDDEELKVALGLNSANSINISRLLAQICYYFEAVAQLPQETRNQ
LVVSVPSGNFGDLTAGLLAKSLGLPVKRFIAATNVNDTVPRFLHDGQWSPKATQATLSNA
MDVSQPNNWPRVEELFRRKIWQLKELGYAAVDDETTQQTMRELKELGYTSEPHAAVAYRA
LRDQLNPGEYGLFLGTAHPAKFKESVEAILGETLDLPKELAERADLPLLSHNLPADFAAL
RKLMMNHQ";
$seq =~ s/\n//gs;

my($fam,$sims) = $figfams->place_in_family($seq);

if ($fam)
{
    print join("\t",($fam->family_id,$fam->family_function)),"\n";
    print &Dumper($sims);
}
else
{
    print "Could not place it in a family\n";
}

###############################################

=head3 Getting representative sequences for a FIGfam

use FIGO;
my $figO = FIGO->new();

$fam         = "FIG102446";
my $famO     = &FigFamO::new('FigFamO',$figO,$fam);
my @rep_seqs = $famO->rep_seqs;

foreach $seq (@rep_seqs)
{
    print ">query\n$seq\n";
}

#---------------------------------------------

use FIG;
use FigFam;
use FigFams;

my $fig = FIG->new();

$fam         = "FIG102446";
my $famO     = FigFam->new($fig, $fam);
my @rep_seqs = $famO->representatives;

foreach $seq (@rep_seqs)
{
    print ">query\n$seq\n";
}


###############################################


=head3 Testing for membership in FIGfam

use FIGO;
my $figO = FIGO->new();

$seq = "MKLYNLKDHNEQVSFAQAVTQGLGKNQGLFFPHDLPEFSLTEIDEMLKLDFVTRSAKILS
AFIGDEIPQEILEERVRAAFAFPAPVANVESDVGCLELFHGPTLAFKDFGGRFMAQMLTH
IAGDKPVTILTATSGDTGAAVAHAFYGLPNVKVVILYPRGKISPLQEKLFCTLGGNIETV
AIDGDFDACQALVKQAFDDEELKVALGLNSANSINISRLLAQICYYFEAVAQLPQETRNQ
LVVSVPSGNFGDLTAGLLAKSLGLPVKRFIAATNVNDTVPRFLHDGQWSPKATQATLSNA
MDVSQPNNWPRVEELFRRKIWQLKELGYAAVDDETTQQTMRELKELGYTSEPHAAVAYRA
LRDQLNPGEYGLFLGTAHPAKFKESVEAILGETLDLPKELAERADLPLLSHNLPADFAAL
RKLMMNHQ";
$seq =~ s/\n//gs;

$fam                  = "FIG102446";
my $famO              = &FigFamO::new('FigFamO',$figO,$fam);
my($should_be, $sims) = $famO->should_be_member($seq);

if ($should_be)
{
    print join("\t",($famO->id,$famO->function)),"\n";
    print &Dumper($sims);
}
else
{
    print "Sequence should not be added to family\n";
}

#---------------------------------------------

use FIG;
use FigFam;
use FigFams;

my $fig = FIG->new();

$seq = "MKLYNLKDHNEQVSFAQAVTQGLGKNQGLFFPHDLPEFSLTEIDEMLKLDFVTRSAKILS
AFIGDEIPQEILEERVRAAFAFPAPVANVESDVGCLELFHGPTLAFKDFGGRFMAQMLTH
IAGDKPVTILTATSGDTGAAVAHAFYGLPNVKVVILYPRGKISPLQEKLFCTLGGNIETV
AIDGDFDACQALVKQAFDDEELKVALGLNSANSINISRLLAQICYYFEAVAQLPQETRNQ
LVVSVPSGNFGDLTAGLLAKSLGLPVKRFIAATNVNDTVPRFLHDGQWSPKATQATLSNA
MDVSQPNNWPRVEELFRRKIWQLKELGYAAVDDETTQQTMRELKELGYTSEPHAAVAYRA
LRDQLNPGEYGLFLGTAHPAKFKESVEAILGETLDLPKELAERADLPLLSHNLPADFAAL
RKLMMNHQ";
$seq =~ s/\n//gs;

$fam                  = "FIG102446";
my $famO              = FigFam->new($fig, $fam);
my($should_be, $sims) = $famO->should_be_member($seq);

if ($should_be)
{
    print join("\t",($famO->family_id,$famO->family_function)),"\n";
    print &Dumper($sims);
}
else
{
    print "Sequence should not be added to family\n";
}

=cut

