#!/usr/bin/perl -w
use strict;

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
package ANNO;

use Data::Dumper;
use FIG_Config;
use strict;
use ERDB;
use Tracer;
use SeedUtils;
use ServerThing;
use KmerMgr;

my $rna_tool = "/vol/search_for_rnas-2007-0625/search_for_rnas";

sub new {
    my ($class, $sapDB) = @_;
    # Create the sapling object.
    my $sap = $sapDB || ERDB::GetDatabase('Sapling');
    # Create the server object.
    my $retVal = { db => $sap };
    # Bless and return it.
    bless $retVal, $class;
    $retVal->init_kmers();
    return $retVal;
}


=head2 Primary Methods

=head3 methods

    my $methodList =        $ssObject->methods();

Return a list of the methods allowed on this object.

=cut

use constant METHODS => [qw(metabolic_reconstruction
			    assign_function_to_prot
			    call_genes
			    find_rnas
			    assign_functions_to_DNA
			    find_special_proteins
                            assign_functions_to_dna_small
			    get_dataset
			    get_vector_basis_sets
			    get_active_datasets
                        )];

use constant RAW_METHODS => [qw(assign_function_to_prot
				call_genes
				find_rnas
				assign_functions_to_DNA
                        )];

sub raw_methods
{
    my ($self) = @_;
    return RAW_METHODS;
}

sub methods {
    # Get the parameters.
    my ($self) = @_;
    # Return the result.
    return METHODS;
}

#
# Docs are in ANNOserver.pm.
#

sub find_special_proteins {
    # Get the parameters.
    my ($self, $args) = @_;
    # Pull in the special protein finder.
    require find_special_proteins;
    # Convert the hash to the form expected by find_special_proteins.
    my $params = {
        contigs => $args->{-contigs},
        is_init => $args->{-is_init},
        is_alt => $args->{-is_alt},
        is_term => $args->{-is_term},
        comment => $args->{-comment}
        };
    if (exists $args->{-templates}) {
        my $templates = $args->{-templates};
        if (ref $templates eq 'ARRAY') {
            $params->{references} = $templates;
        } elsif ($templates =~ /^pyr/) {
            $params->{pyrrolysine} = 1
        }
    }
    # Process the input.
    my @retVal = find_special_proteins::find_selenoproteins($params);
    # Return the result.
    return \@retVal;
}

sub metabolic_reconstruction {
    # Get the parameters.
    my ($self, $args) = @_;

    my $sapling = $self->{db};
    my $retVal = [];

    # This counter will be used to generate user IDs for roles without them.
    my $next = 1000;

    my $id_roles = $args->{-roles};
    my @id_roles1 = map { (ref $_ ? $_ : [$_, "FR" . ++$next]) } @$id_roles;

    my @id_roles = ();
    foreach my $tuple (@id_roles1)
    {
	my($function,$id) = @$tuple;
	foreach my $role (split(/(?:; )|(?: [\]\@] )/,$function))
	{
	    push(@id_roles,[$role,$id]);
	}
    }

    my %big;
    my $id_display = 1;
    map {push(@{$big{$_->[0]}}, $_->[1])} @id_roles;
    my @resultRows = $sapling->GetAll("Subsystem Includes Role", 
                            'Subsystem(usable) = ? ORDER BY Subsystem(id), Includes(sequence)',
			    [1], [qw(Subsystem(id) Role(id) Includes(abbreviation))]);
    my %ss_roles;
    foreach my $row (@resultRows) {
        my ($sub, $role, $abbr) = @$row;
        $ss_roles{$sub}->{$role} = $abbr;
    }
    foreach my $sub (keys %ss_roles) {
        my $roles = $ss_roles{$sub};
	my @rolesubset = grep { $big{$_} } keys %$roles;
        my @abbr = map{$roles->{$_}} @rolesubset;
        my $set =  join(" ",  @abbr);
        if (@abbr > 0) {
            my ($variant, $size) = $self->get_max_subset($sub, $set);
            if ($variant) {
                foreach my $role (keys %$roles) {
                    if ($id_display) {
			if (exists $big{$role}) {
			    foreach my $id (@{$big{$role}}) {
			        push (@$retVal, [$variant, $role, $id]);
			    }
			}
                    } else {
                        push (@$retVal, [$variant, $role]);
                    }
                }
            }
        }
    }
    # Return the result.
    return $retVal;
}

=head3 assign_functions_to_dna_small

    my $idHash =            $annoObject->assign_functions_to_dna_small({
                                -seqs => [[$id1, $comment1, $seq1],
                                          [$id2, $comment2, $seq2],
                                          ... ],
                                -kmer => 10,
                                -minHits => 3,
                                -maxGap => 600,
                            });

This method uses FIGfams to assign functions to sequences. It is intended for smaller
sequence sets than the main method, because it eschews the normal flow control; however,
it is easier to use for things like the EXCEL interface.

The parameters are as follows.

=item parameter

The parameter should be a reference to a hash with the following keys.

=over 8

=item -seqs

Reference to a list of 3-tuples, each consisting of (0) an arbitrary unique ID and
(1) a comment, and (2) a sequence associated with the ID.

=item -kmer

KMER size (7 to 12) to use for the FIGfam analysis. Larger sizes are faster, smaller
sizes are more accurate.

=item -minHits (optional)

A number from 1 to 10, indicating the minimum number of matches required to
consider a protein as a candidate for assignment to a FIGfam. A higher value
indicates a more reliable matching algorithm; the default is C<3>.

=item -maxGap (optional)

When looking for a match, if two sequence elements match and are closer than
this distance, then they will be considered part of a single match. Otherwise,
the match will be split. The default is C<600>.

=back

=item RETURN

Returns a hash mapping each incoming ID to a list of hit regions. Each hit
region is a n-tuple consisting of (0) the number of matches to the function, (1) the
start location, (2) the stop location, (3) the proposed function, (4) the name
of the Genome Set from which the gene is likely to have originated, (5) the ID
number of the OTU (or C<undef> if the OTU was not found), and (6) the IDs of the
roles represented in the function, if any of them have IDs.


=back

=cut

sub assign_functions_to_dna_small {
    # Get the parameters.
    my ($self, $args) = @_;
    # Get the Kmers object.
    my $kmers = $self->{kmer_mgr}->get_default_kmer_object();
    
    # Analyze the options.
    my $maxGap = $args->{-maxGap} || 600;
    my $minHits = $args->{-minHits} || 3;
    # Get the KMER size.
    my $kmer = $args->{-kmer};
    # Declare the return variable.
    my $retVal = {};
    # Get the sapling database.
    my $sap = $self->{db};
    # Get the sequence tuples.
    my $seqs = ServerThing::GetIdList(-seqs => $args);
    # Loop through the sequences, finding assignments.
    for my $seqTuple (@$seqs) {
        # Extract the ID and sequence.
        my ($id, undef, $seq) = @$seqTuple;
        # Compute the assignment.
        my $assignment = $kmers->assign_functions_to_PEGs_in_DNA($kmer, $seq,
                                                                 $minHits, $maxGap);
        # Loop through the assignments, adding the function and OTU IDs.
        for my $tuple (@$assignment) {
            # Extract the function and OTU.
            my $function = $tuple->[3];
            my $otu = $tuple->[4];
            # Get the IDs for the roles (if any).
            my @roleIdx;
            if ($function) {
                # We have a function, so split it into roles.
                my @roles = roles_of_function($function);
                # Accumulate the IDs for the roles found.
                for my $role (@roles) {
                    push @roleIdx, $sap->GetEntityValues(Role => $role, ['role-index']);
                }
            }
            # Get the ID for the OTU (if any).
            my $otuIdx;
            if ($otu) {
                ($otuIdx) = $sap->GetFlat("Genome IsCollectedInto", 
                            'Genome(scientific-name) = ?', [$otu], 
                            'IsCollectedInto(to-link)');
            }
            # Update the tuple.
            splice @$tuple, 5, undef, $otuIdx, @roleIdx;
        }
        # Store the result.
        $retVal->{$id} = $assignment;
    }
    # Return the results.
    return $retVal;
}

=head3 assign_function_to_prot
    
Raw CGI handler for the Kmer protein assignment code.

=cut

sub assign_function_to_prot
{
    my($self, $cgi) = @_;

    my @id = $cgi->param('id_seq');

    my %params = map { my $v = $cgi->param($_); defined($v) ? ($_ => $cgi->param($_)) : () }
    qw(-kmer -scoreThreshold -hitThreshold -seqHitThreshold -normalizeScores -detailed 
       -assignToAll -kmerDataset -determineFamily -returnFamilySims);
    
    $params{-all} = 1;
    
    my $ds = $params{-kmerDataset} || $self->{kmer_mgr}->default_dataset;
    
    my $kmers = $self->{kmer_mgr}->get_kmer_object($ds);
    ref($kmers) or myerror($cgi, "500 invalid dataset name $ds");
    my $kmer_fasta = $self->{kmer_mgr}->get_extra_fasta_path($ds);
    
    @id or die "figfam server missing id_seq argument";

    my @output;
    my @missing;
    foreach my $parm (@id) {
	my ($id, $seq) = split /,/, $parm;
	my $triple = [$id, undef, $seq];
	my @res = $kmers->assign_functions_to_prot_set(-seqs => [$triple], %params);
	my $res = $res[0];
	if ($res->[1] || !$params{-assignToAll})
	{
	    push(@output, $res);
	}
	elsif ($params{-assignToAll})
	{
	    push(@missing, $triple);
	}
    }
    if ($params{-assignToAll} && @missing)
    {
	my @rest = $kmers->assign_functions_using_similarity(-seqs => \@missing,
							     -simDb => $kmer_fasta);
	
	push(@output, @rest);
    }

    return @output;
}

=head3 call_genes
    
Raw CGI handler for the gene caller.

=cut

sub call_genes
{
    my($self, $cgi) = @_;

    my @id = $cgi->param('id_seq');
    @id or myerror($cgi, "500 missing id_seq", "figfam server missing id_seq argument");
    
    my %params = map { my $v = $cgi->param($_); defined($v) ? ($_ => $cgi->param($_)) : () }
	    qw(-geneticCode -minContigLen -verbose);
    
    my $genetic_code = ($params{-geneticCode} =~ /^(\d+)$/ ? $1 : 11);
    
    my $min_training_len = ($params{-minContigLen} =~ /^(\d+)$/ ? $1 : 2000);
    #
    # Create fasta of the contig data.
    #
    
    my $fh;
    my $tmp = "$FIG_Config::temp/contigs.$$";
    my $tmp2 = "$FIG_Config::temp/contigs.aa.$$";
    my $tbl = "$FIG_Config::temp/tbl.$$";
    my $tbl2 = "$FIG_Config::temp/tbl2.$$";
    open($fh, ">", $tmp) or die "Cannot write $tmp: $!";
    
    foreach my $parm (@id) {
	my ($id, $seq) = split /,/, $parm;
	&FIG::display_id_and_seq($id, \$seq, $fh);
    }
    close($fh);
    
    # Training stuff.
    my $trainingParms = "";
    my @trainSet = $cgi->param('training_set');
    if (@trainSet) {
	my $tmp3 = "$FIG_Config::temp/tbl3.$$";
	my $fh3;
	open($fh3, ">", $tmp3) or die "Cannot write $tmp3: $!";
	while (@trainSet) {
	    my $loc = pop @trainSet;
	    my $id = pop @trainSet;
	    print $fh3 "$id\t$loc\n";
	}
	$trainingParms = "-train=$tmp3";
	my @trainContigs = $cgi->param('train_seq');
	if (@trainContigs) {
	    undef $fh3;
	    my $tmp4 = "$FIG_Config::temp/fasta1.$$";
	    open($fh3, ">", $tmp4);
	    foreach my $parm (@trainContigs) {
		my ($id, $seq) = split /,/, $parm;
		&FIG::display_id_and_seq($id, \$seq, $fh3);
	    }
	    close($fh3);
	    $trainingParms .= ",$tmp4";
	}
    }
    # Verbose check
    my $verbose = ($params{-verbose} ? "-verbose" : "");
    if ($verbose) {
	warn "Input file: $tmp; training parameter=$trainingParms\n";
    }
    # Call glimmer
    my $res = system("$FIG_Config::bin/run_glimmer3 $verbose -minlen=$min_training_len $trainingParms -code=$genetic_code 1.1 $tmp > $tbl");
    if ($res != 0)
    {
	die "glimmer failed with rc=$res";
    }
    
    my $fh2;
    open($fh, "<", $tbl) or die "cannot read $tbl: $!";
    open($fh2, ">", $tbl2)or die "cannot write $tbl2: $!";
    my $ctr = 1;
    my $encoded_tbl = [];
    while (<$fh>)
    {
	chomp;
	my(@a)  = split(/\t/);
	$a[0] = sprintf("prot_%05d", $ctr++);
	push(@a, $a[1]);
	print $fh2 join("\t", @a), "\n";
	my ($contig, $beg, $end) = ($a[1] =~ /^(\S+)_(\d+)_(\d+)$/);
	push @$encoded_tbl, [$a[0], $contig, $beg, $end];
    }
    close($fh);
    close($fh2);
    
    $res = system("$FIG_Config::bin/get_fasta_for_tbl_entries -code=$genetic_code $tmp < $tbl2 > $tmp2");
    if ($res != 0)
    {
	die "error rc=$res running get_fasta_for_tbl_entries\n";
    }
    
    if (!open($fh,"<", $tmp2))
    {
	die "Cannot read $tmp2: $!";
    }

    my $out;
    my $buf;
    while (read($fh, $buf, 4096))
    {
	$out .= $buf;
    }
    
    close($fh);
    return [$out, $encoded_tbl];
}

=head3 find_rnas
    
Raw CGI handler for the rna finder

=cut

sub find_rnas
{
    my($self, $cgi) = @_;
    my @id = $cgi->param('id_seq');
    
    my %params = map { my $v = $cgi->param($_); defined($v) ? ($_ => $cgi->param($_)) : () }
	    qw(-genus -species -domain -rnas);
    
    @id or die "missing id_seq parameter";
    
    $params{-genus} or die "missing genus parameter";
    $params{-species} or die "missing species parameter"; 
    $params{-domain} or die "missing domain parameter";
    
    #
    # Create fasta of the contig data.
    #
    
    my $fh;
    my $tmp_dir = "$FIG_Config::temp/find_rnas.$$";
    my $log = "$tmp_dir/log";
    &FIG::verify_dir($tmp_dir);
    my $tmp = "$tmp_dir/contigs";
    my $tmp2 = "$tmp_dir/contigs2";
    my $tbl = "$tmp_dir/tbl";
    my $tbl2 = "$tmp_dir/tbl2";
    
    open($fh, ">", $tmp) or die "cannot write $tmp: $!";
    
    foreach my $parm (@id) {
	my ($id, $seq) = split /,/, $parm;
	&FIG::display_id_and_seq($id, \$seq, $fh);
    }
    close($fh);
    
    my $opt_rna_types = $params{-rnas} ? "-rnas=$params{-rnas}" : "";
    my $cmd = "$rna_tool $opt_rna_types --tmpdir=$tmp_dir --contigs=$tmp --orgid=1 --domain=$params{-domain} --genus=$params{-genus} --species=$params{-species}";
    warn "Run: $cmd\n";
    #
    # Need to clear the PERL5LIB from the environment since tool is configured to use its own.
    #
    my $res = system("cd $tmp_dir; env PERL5LIB= $cmd > $tbl 2> $log");
    if ($res != 0)
    {
	die "cmd failed with rc=$res: $cmd";
    }
    
    my $fh2;
    open($fh, "<", $tbl) or die "cannot read $tbl: $!";
    open($fh2, ">", $tbl2) or die "cannot write $tbl2: $!";
    my $ctr = 1;
    my $encoded_tbl = [];
    while (<$fh>)
    {
	chomp;
	my(@a)  = split(/\t/);
	
	my $new = sprintf("rna_%05d", $ctr++);
	
	print $fh2 join("\t", $new, $a[1]), "\n";
	my ($contig, $beg, $end) = ($a[1] =~ /^(\S+)_(\d+)_(\d+)$/);
	push @$encoded_tbl, [$new, $contig, $beg, $end, $a[2]];
    }
    close($fh);
    close($fh2);
    
    $res = system("$FIG_Config::bin/get_dna $tmp < $tbl2 > $tmp2");
    if ($res != 0)
    {
	die "get_dna $tmp failed with rc=$res";
    }
    
    open($fh,"<", $tmp2) or die "Cannot read $tmp2: $!";

    my $out;
    my $buf;
    while (read($fh, $buf, 4096))
    {
	$out .= $buf;
    }
    close($fh);
    return [$out, $encoded_tbl];
    #unlink($tmp);
    #unlink($tmp2);
    #unlink($tbl);
    #unlink($tbl2);
}


=head3 assign_functions_to_DNA
    
Raw CGI handler for the DNA kmer code

=cut

sub assign_functions_to_DNA
{
    my($self, $cgi) = @_;

    my @id = $cgi->param('id_seq');
    my %params = map { my $v = $cgi->param($_); defined($v) ? ($_ => $cgi->param($_)) : () }
    	qw(-kmer -minHits -maxGap -kmerDataset -detailed);

    my $min_hits = $params{-minHits};
    my $max_gap = $params{-maxGap};

    my $details = $params{-detailed} ? 1 : 0;
    
    my $kmer = $params{-kmer};
    
    my $ds = $params{-kmerDataset} || $self->{kmer_mgr}->default_dataset;
    
    my $kmers = $self->{kmer_mgr}->get_kmer_object($ds);
    ref($kmers) or myerror($cgi, "500 invalid dataset name $ds");
    
    @id or die "missing id_seq argument";

    my @out;
    foreach my $parm (@id) {
	my ($id, $seq) = split /,/, $parm;
	# print L "try $id\n$seq\n";
	my $res;
	eval {
	    $res = $kmers->assign_functions_to_PEGs_in_DNA($kmer, $seq, $min_hits, $max_gap, 0, $details);

	};
	if ($@)
	{
	    die "failure on assign_functions_to_PEGs_in_DNA: $@";
	}
	push(@out, map { [$id, $_ ] } @$res);
    }	    
    return @out;
}

=head3 get_dataset

Return the default dataset; if -kmerDataset is passed, verify that it is
a valid dataset.

=cut

sub get_dataset
{
    my($self, $args) = @_;
    my $ds;
    if (defined($ds = $args->{'-kmerDataset'}))
    {
	my $kmers = $self->{kmer_mgr}->get_kmer_object($ds);
	ref($kmers) or return undef;
    }
    else
    {
	$ds = $self->{kmer_mgr}->default_dataset;
    }
    return $ds;
}

=head3 get_vector_basis_sets

Return the vector basis sets for the given dataset name.

=cut

sub get_vector_basis_sets
{
    my($self, $args) = @_;

    my $ds = $args->{'-kmerDataset'} || $self->{kmer_mgr}->default_dataset;
    my $kmers = $self->{kmer_mgr}->get_kmer_object($ds);
    ref($kmers) or return undef;

    my $dir = $kmers->dir();
    
    my $res = {};
    my @todo = ([function => "$dir/family.vector.def"], [otu => "$dir/setI"]);
    for my $ent (@todo)
    {
	my($what, $file) = @$ent;
	if (open(my $fh, "<", $file))
	{
	    local $/ = undef;
	    $res->{$what} = <$fh>;
	    close($fh);
	}
	else
	{
	    push(@{$res->{errors}}, "Cannot open $file: $!");
	}
    }
    return $res;
}

=head3 get_active_datasets

Return a list of the currently active Kmer datasets.

=cut

sub get_active_datasets
{
    my($self) = @_;

    return $self->{kmer_mgr}->get_active_datasets;
}

=head2 Internal Utility Methods

=head3 init_kmers

    $annoObject->init_kmers()

Initialize the kmer data set information from the FIG environment. Used
on the annotation servers.

=cut

sub init_kmers
{
    my($self) = @_;

    my $kmer_dir = $FIG_Config::KmerBase || "/vol/figfam-prod";
    -d $kmer_dir or die "Cannot find kmer base directory $kmer_dir";

    my $kmgr = KmerMgr->new(base_dir => $kmer_dir);

    $self->{kmer_mgr} = $kmgr;
}

=head3 get_max_subset

    my ($max_variant, $max_size) = $ssObject->get_max_subset($sub, $setA);

Given a subsystem ID and a role rule, return the ID of the variant for
the subsystem that matches the most roles in the rule and the number of
roles matched.

=over 4

=item sub

Name (ID) of the subsystem whose variants are to be examined.

=item setA

A space-delimited list of role abbreviations, lexically ordered. This provides
a unique specification of the roles in the set.

=item RETURN

Returns a 2-element list consisting of name variant found (subsystem name, colon,
and variant code) and the number of roles matched.

=back

=cut

sub get_max_subset {
    my ($self, $sub, $setA) = @_;
    my $sapling = $self->{db};
    my $max_size = 0;
    my $max_set;
    my $max_variant;
    my %set_hash;
    my $qh = $sapling->Get("Subsystem Describes Variant", 'Subsystem(id) = ? AND Variant(type) = ?', [$sub, 'normal']);
    while (my $resultRow = $qh->Fetch()) {
        my @variantRoleRule = $resultRow->Value('Variant(role-rule)');
        my ($variantCode) = $resultRow->Value('Variant(code)');
        my $variantId = $sub.":".$variantCode;
        foreach my $setB (@variantRoleRule) {
                    my $size = is_A_a_superset_of_B($setA, $setB);
                    if ($size  && $size > $max_size) {
                            $max_size = $size;
                            $max_set = $setB;
                            $max_variant = $variantId;
                    }
        }
    }
    #if ($max_size) {
            #print STDERR "Success $max_variant, $max_set\n";
    #}
    return($max_variant, $max_size);
}


=head3 is_A_a_superset_of_B

    my $size = SS::is_A_a_superset_of_B($a, $b);

This method takes as input two role rules, and returns 0 if the first
role rule is NOT a superset of the second; otherwise, it returns the size
of the second rule. A role rule is a space-delimited list of role
abbreviations in lexical order. This provides a unique identifier for a
set of roles in a subsystem.

=over 4

=item a

First role rule.

=item b

Second role rule.

=item RETURN

Returns 0 if the first rule is NOT a superset of the second and the size of the
second rule if it is. As a result, if the first rule IS a superset, this method
will evaluate to TRUE, and to FALSE otherwise.

=back

=cut

sub is_A_a_superset_of_B {
    my ($a, $b) = @_;
    my @a = split(" ", $a);
    my @b = split(" ", $b);
    if (@b > @a) {
            return(0);
    }
    my %given;
    map { $given{$_} = 1} @a;
    map { if (! $given{$_}) {return 0}} split(" ", $b);
    my $l = scalar(@b);
    return scalar(@b);
}


1;
