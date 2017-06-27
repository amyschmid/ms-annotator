# -*- perl -*-
########################################################################
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
########################################################################

package ProtFamsLite;

use strict;
use DB_File;

#use ProtFamLite;
use Tracer;

use Data::Dumper;
use Carp;
use Digest::MD5;
use FIG;

# This is the constructor.  Presumably, $class is 'ProtFamsLite'.  
#

sub new {
    my($class,$fam_data) = @_;

    my $protfams = {};

    defined($fam_data) || return undef;
    $protfams->{dir} = $fam_data;
    $protfams->{root} = $fam_data;
    $protfams->{fig} = new FIG;

    bless $protfams,$class;
    return $protfams;
}

sub create_tie
{
    my($self, $hash, $file, $type) = @_;

    my $mode = -w $file ? O_RDWR : O_RDONLY;

    return tie %$hash, 'DB_File', $file, $mode, 0666, $type;	
}

sub check_db_role {
    my($self) = @_;
    my $fam_data = $self->{dir};

    my $db_role = "$fam_data/role.db";
    if (! -s $db_role) { return undef }

    my %role_hash;
    my $role_hash_tie = $self->create_tie(\%role_hash, $db_role, $DB_HASH);
    $role_hash_tie || die "tie $db_role failed: $!";
    $self->{role_db} = \%role_hash;
}

sub check_db_function {
    my($self) = @_;
    my $fam_data = $self->{dir};

    my $db_function = "$fam_data/function.db";
    if (! -s $db_function) { return undef }
    my %function_hash;
    my $function_hash_tie = $self->create_tie(\%function_hash, $db_function,  $DB_HASH);
    $function_hash_tie || die "tie $db_function failed: $!";
    $self->{function_db} = \%function_hash;
}

sub check_db_family_function {
    my($self) = @_;
    my $fam_data = $self->{dir};

    my $db_function = "$fam_data/fam_function.db";
    if (! -s $db_function) { return undef }
    my %function_hash;
    my $function_hash_tie = $self->create_tie(\%function_hash, $db_function,  $DB_HASH);
    $function_hash_tie || die "tie $db_function failed: $!";
    $self->{family_function_db} = \%function_hash;
}

sub check_db_prot_to_fams {
    my($self) = @_;
    my $fam_data = $self->{dir};

    my $db_prot_to_fams = "$fam_data/protein.db";
    if (! -s $db_prot_to_fams) { return undef }
    my %prot_to_fams_hash;
    my $prot_to_fams_hash_tie = $self->create_tie(\%prot_to_fams_hash, $db_prot_to_fams,  $DB_HASH);
    $prot_to_fams_hash_tie || die "tie $db_prot_to_fams failed: $!";
    $self->{prot_to_fams_db} = \%prot_to_fams_hash;
}

sub check_db_genome_to_fams {
    my($self) = @_;
    my $fam_data = $self->{dir};

    my $db_genome_to_fams = "$fam_data/genome.db";
    if (! -s $db_genome_to_fams) { return undef }
    my %genome_to_fams_hash;
    my $genome_to_fams_hash_tie = $self->create_tie(\%genome_to_fams_hash, $db_genome_to_fams, $DB_HASH);
    $genome_to_fams_hash_tie || die "tie $db_genome_to_fams failed: $!";
    $self->{genome_to_fams_db} = \%genome_to_fams_hash;
}

sub check_db_relevant_prot_data {
    my($self) = @_;
    my $fam_data = $self->{dir};

    my $db_relevant_prot_data = "$fam_data/relevant.prot.data.db";
    if (! -s $db_relevant_prot_data) { return undef }
    my %relevant_prot_data_hash;
    my $relevant_prot_data_hash_tie = $self->create_tie(\%relevant_prot_data_hash, $db_relevant_prot_data, $DB_HASH);
    $relevant_prot_data_hash_tie || die "tie $db_relevant_prot_data failed: $!";
    $self->{relevant_prot_data_db} = \%relevant_prot_data_hash;
}

sub check_db_PDB_connections {
    my($self) = @_;

    my $fam_data = $self->{dir};
    my $db_PDB_connections = "$fam_data/PDB.connections.db";
    if (! -s $db_PDB_connections) { return undef }
    my %PDB_hash;
    my $PDB_hash_tie = $self->create_tie(\%PDB_hash, $db_PDB_connections, $DB_HASH);
    $PDB_hash_tie || die "tie $db_PDB_connections failed: $!";
    $self->{PDB_connections_db} = \%PDB_hash;
}

sub check_db_md5_to_fams {
    my($self) = @_;

    my $fam_data = $self->{dir};
    my $db_md5_fams = "$fam_data/md5.protfams.db";
    if (! -s $db_md5_fams) { return undef }
    my %md5_hash;
    my $md5_hash_tie = $self->create_tie(\%md5_hash, $db_md5_fams, $DB_HASH);
    $md5_hash_tie || die "tie $db_md5_fams failed: $!";
    $self->{md5_fams_db} = \%md5_hash;
}

sub check_db_md5_to_prots {
    my($self) = @_;

    my $fam_data = $self->{dir};
    my $db_md5_fams = "$fam_data/md5.prots.db";
    if (! -s $db_md5_fams) { return undef }
    my %md5_hash;
    my $md5_hash_tie = $self->create_tie(\%md5_hash, $db_md5_fams, $DB_HASH);
    $md5_hash_tie || die "tie $db_md5_fams failed: $!";
    $self->{md5_prots_db} = \%md5_hash;
}

sub check_db_family_id_map {
    my($self) = @_;
    my $fam_data = $self->{dir};

    my $db_map = "$fam_data/family_id_map.db";
    if (! -s $db_map) { return undef }

    my %map_hash;
    my $map_hash_tie = $self->create_tie(\%map_hash, $db_map, $DB_HASH);
    $map_hash_tie || die "tie $db_map failed: $!";
    $self->{map_db} = \%map_hash;
}

sub PDB_connections {
    my($self,$fam,$raw) = @_;

    $self->check_db_PDB_connections;
    my $sims = $self->{PDB_connections_db}->{$fam};
    my @sims = map { $_ =~ /pdb\|([0-9a-zA-Z]+)/; [$1,[split(/\t/,$_)]] } split(/\n/,$sims);
    if (! $raw)  { @sims = map { $_->[0] } grep { ($_->[1]->[11] > 0.5) && ((($_->[1]->[4] - $_->[1]->[3]) / $_->[1]->[5]) > 0.8) } @sims}
    return \@sims;
}

sub function_of {
    my($self,$prot,$ignore_comments) = @_;

    $self->check_db_relevant_prot_data;  # lazily tie DB

    my $prot_data;
    if ($prot_data = $self->{relevant_prot_data_db}->{$prot})
    {
	my($org,$func,$seq,$aliases) = split(/\t/,$prot_data);
	if ($ignore_comments)
	{
	    $func =~ s/\s*\#.*$//;
	}
	return $func;
    }
    return "";
}

sub function_of_family {
    my($self,$fam,$ignore_comments) = @_;

    $self->check_db_family_function;  # lazily tie DB

    my $func;
    if ($func = $self->{family_function_db}->{$fam})
    {
	return $func;
    }
}

sub get_translation {
    my($self,$prot,$ignore_comments) = @_;
    
    $self->check_db_relevant_prot_data;  # lazily tie DB
    
    my $prot_data;
    if ($prot_data = $self->{relevant_prot_data_db}->{$prot})
    {
	my($org,$func,$seq,$aliases) = split(/\t/,$prot_data);
	return $seq;
    }
    return "";
}

sub get_translation_bulk {
    my($self,$prots,$ignore_comments) = @_;
    my $seqs = {};

    $self->check_db_relevant_prot_data;  # lazily tie DB
    
    my $prot_data;
    foreach my $prot (@$prots)
    {
	if ($prot_data = $self->{relevant_prot_data_db}->{$prot})
	{
	    my($org,$func,$seq,$aliases) = split(/\t/,$prot_data);
	    $seqs->{$prot} = $seq;
	}
    }
    
    return $seqs;
}


sub md5_function_of {
    my ($self, $md5, $preferred_db) = @_;

    # find if md5 is in a family

    # if in_family get the function

    # else go to seed to get function
    my (@tuples, $function);
    if (@tuples = $self->{fig}->mapped_prot_ids(qq(gnl|md5|$md5))) {
        my @tmp;
        if (@tmp = grep { $_->[0] =~ m/^fig\|\d+\.\d+\.peg\.\d+$/o } @tuples) {
            #...Pick the function of one of the FIDs
        }
        elsif (@tmp = grep { $_->[0] =~ m/^sp\|\S+$/o } @tuples) {
            #...Pick the function of one of the SP's
        }
        elsif (@tmp = grep { $_->[0] =~ m/^pir\|\S+$/o } @tuples) {
            #...DWIM
        }
        elsif (@tmp = grep { $_->[0] =~ m/^kegg\|\S+$/o } @tuples) {
        }
        elsif (@tmp = grep { $_->[0] =~ m/^gi\|\S+$/o } @tuples) {
        }
        else {
            $function = qq(Hypothetical protein);
        }
	return $function;
    }
}

sub org_of {
    my($self,$prot) = @_;

    $self->check_db_relevant_prot_data;  # lazily tie DB

    my $prot_data;
    if ($prot_data = $self->{relevant_prot_data_db}->{$prot})
    {
	my($org,$func,$seq,$aliases) = split(/\t/,$prot_data);
	return $org;
    }
    return "";
}

sub path_to {
    my ($self,$family_name) = @_;

    $self->check_db_family_id_map;   # lazily tie DB

    my $internal_id;
    if ($internal_id = $self->{map_db}->{$family_name})
    {
        #my($internal_id) = split(/\t/,$family_name);

        my $group = substr($internal_id, -3);
        $group = (qq(0) x (3-length($group))) . $group;

        my $path_to_family = qq($self->{dir}/FAMS/$group/$internal_id);

        return $path_to_family;
    }
    return "";
}

sub seq_of {
    my($self,$prot) = @_;

    $self->check_db_relevant_prot_data;  # lazily tie DB

    my $prot_data;
    if ($prot_data = $self->{relevant_prot_data_db}->{$prot})
    {
	my($org,$func,$seq,$aliases) = split(/\t/,$prot_data);
	return $seq;
    }
    return "";
}

sub aliases_of {
    my($self,$prot) = @_;

    $self->check_db_relevant_prot_data;  # lazily tie DB

    my $prot_data;
    if ($prot_data = $self->{relevant_prot_data_db}->{$prot})
    {
	my($org,$func,$seq,$aliases) = split(/\t/,$prot_data);
	return wantarray() ? split(/,/,$aliases) : $aliases;
    }
    return "";
}

sub families_implementing_role {
    my($self,$role) = @_;

    $self->check_db_role;  # lazily tie DB

    my $fams = $self->{role_db}->{$role};
    return $fams ? split("\t",$fams) : ();
}

sub families_with_function {
    my($self,$function) = @_;

    $self->check_db_function;  # lazily tie DB

    my $fams = $self->{function_db}->{$function};
    return $fams ? split("\t",$fams) : ();
}

sub family_containing_prot {
    my($self,$prot) = @_;
    my @fams = $self->families_containing_prot($prot);
    return (@fams > 0) ? $fams[0] : undef;
}

sub families_containing_prot {
    my($self,$prot) = @_;

    $self->check_db_prot_to_fams;  # lazily tie DB
    my $fams = $self->{prot_to_fams_db}->{$prot};
    return $fams ? split("\t",$fams) : ();
}

sub families_in_genome {
    my($self,$genome) = @_;

    $self->check_db_genome_to_fams;  # lazily tie DB

    my $fams = $self->{genome_to_fams_db}->{$genome};
    return $fams ? split("\t",$fams) : ();
}

sub families_containing_md5 {
    my ($self,$md5) = @_;

    $self->check_db_md5_to_fams; # lazily tie DB
    
    my $fams = $self->{md5_fams_db}->{$md5};
    if ($fams){
	return $fams;
    }
    else{
	return undef;
    }
}

sub proteins_containing_md5 {
    my ($self,$md5) = @_;

    $self->check_db_md5_to_prots; # lazily tie DB
    
    my $prots = $self->{md5_prots_db}->{$md5};
    if ($prots){
	return $prots;
    }
    else{
	return undef;
    }
}

sub all_families {
    my($self) = @_;

    return sort map { chomp; $_ } `cut -f1 $self->{dir}/family.functions`;
}

sub is_prots_in_family {
    my($self,$seqs) = @_;
    my $id_2_protfam = {};

    my $protD   = $self->{dir};
    my $protfam_file     = "$protD/families.3c";

    my $contents;
    sysopen(FAM_PROTS, $protfam_file, 0) or die "could not open file '$protfam_file': $!";
    sysread(FAM_PROTS, $contents, 1000000000);
    close(FAM_PROTS) or die "could not close file '$protfam_file': $!";
    my %protfam_prots = map { $_ =~ /^(\S+)\t(\S+)\t/; $2 => $1 } split("\n", $contents);

    foreach (@$seqs){
	if ($protfam_prots{$_}){
	    $id_2_protfam->{$_} = $protfam_prots{$_};
	}
    }
    return $id_2_protfam;
}

sub place_in_family {
    my($self,$seq,$debug,$loose,$debug_prot,$nuc,$md5_flag) = @_;
    my($protfam,$should_be,$sims);

    my $old_sep = $/;
    $/ = "\n";

    my $dir = $self->{dir};
    my $tmpF = "$FIG_Config::temp/tmp$$.fasta";
    open(TMP,">$tmpF") 
	|| die "could not open $tmpF";
    print TMP ">query\n$seq\n";
    close(TMP);

    # check if sequence is in any protfam by md5 checksum
    my $md5 = Digest::MD5::md5_hex( uc $seq );
    my $fams = $self->families_containing_md5($md5);
    if ((!$md5_flag) && ($fams) && ($fams !~ /\,/)){     # do regular check if the checksum returns more than one protfam
        my $got = new ProtFamLite($self,$fams);
        ($should_be, $sims) = $got->should_be_member($seq,$debug,$loose,$debug_prot,$nuc);
	return ($got,$sims);
    }
    
    if ($nuc){
#	open(BLAST,"blastall -i $tmpF -d $dir/repdb -m 8 -FF -p blastx -g F | head -n 20 |")
	Open(\*BLAST,"$FIG_Config::ext_bin/blastall -i $tmpF -d $dir/repdb -m 8 -FF -p blastx -g T |");
	print STDERR "blastall -i $tmpF -d $dir/repdb -m 8 -FF -p blastx -g T\n" if ($debug);
    }
    else{
#	open(BLAST,"blastall -i $tmpF -d $dir/repdb -m 8 -FF -p blastp | head -n 20 |")
	Open(\*BLAST, "$FIG_Config::ext_bin/blastall -i $tmpF -d $dir/repdb -m 8 -FF -p blastp |");

    }

    my(%seen);
    my $got = undef;
    my $min_sc = 1;
    my $checked = 0;
    while ((! $got) && ($checked < 30) && (defined($_ = <BLAST>)))
    {
	if ($debug) { print STDERR $_ }
	chop;
	my $sim = [split(/\t/,$_)];
	if ($min_sc > $sim->[10]) { $min_sc = $sim->[10] }
	my $fam_id = ($sim->[1] =~ /(.*)-/) ? $1 : "";
	if (! $seen{$fam_id})
	{
	    $seen{$fam_id} = 1;
	    
	    # skip if the e-value is 1 or higher
	    if ($sim->[10] >= 1){
		print STDERR "SIM evalue: " . $sim->[10] . "\n" if ($debug);
		$checked++;
		next;
	    }

	    $protfam = new ProtFamLite($self,$fam_id);

	    if (not defined($protfam))
	    {
		next;
	    }
	    else
	    {
		$checked++;
		if ($debug) { print STDERR "checking family $fam_id ",$protfam->family_function,"\n" }
		($should_be, $sims) = $protfam->should_be_member($seq,$debug,$loose,$debug_prot,$nuc);
		if ($debug) { print STDERR "    should_be=$should_be\n" }
		my $psc;
		if ($should_be && defined($psc = &psc($sims->[0])) && ($psc <= $min_sc))
		{
		    if ($debug) { print STDERR "min_sc=$min_sc best=$psc\n" }
		    $got = $protfam;
		}
	    }
	}
    }

    if ($debug)
    {
	while ($_ && (defined($_ = <BLAST>)))  ### JUST PRINT OUT REMAINING BLASTS AGAINST REPDB
	{
	    print STDERR $_;
	}
    }
    $/ = $old_sep;
    close(BLAST);

    unlink($tmpF);
    return $got ? ($got,$sims) : (undef,undef);
}

=head3
usage: my $out = $protfams->place_in_family_bulk($seqs);

The genereal overview of this function is that it does an initial blast of all
input sequences against the repdb with one call, and then does individual blast
calls for each input sequence to determine to which family it should be placed.

input
    the only difference to place_in_family is that the $seqs parameter is a
    list of sequences to be placed in a family.
    The list can be either a number of sequences in fasta format or an array
    of just the sequences to be placed in a family
    
    i.e. ->>>>   [">seq1\nADTGGHHH\n", ">seq2\nRARGHTGK\n", ....]
                        or
                 ["ADTGGHHH", "RARGHTGK", ....]

output
    return reference to a hash where the keys are the input sequence 
    and the values are tuples same as what place in family returns:  [$family, $sims]
    
    $family is a hash reference to the Protfam it was placed in. If the sequence
            was not placed in a family, then it will be an empty tuple.

    $sims is a reference to the similarities of the Protfam selected


=cut

sub place_in_family_bulk {
    my($self,$seqs,$debug,$loose,$debug_prot,$nuc) = @_;
    my($protfam,$should_be,$sims);
    my $out = {};
    my @run_blast = ();

    my $dir = $self->{dir};
    my $old_sep = $/;
    $/ = "\n";
    my $seq_list = {};
    my $count = 0;

    foreach my $fasta (@$seqs){
	my ($id, $header, $seq);
	if ($fasta =~ m/^>(.*?)\n(.*?)\n/){
	    #($header,$seq) = $fasta =~ m/^>(.*?)\n(.*?)\n/;
	    $header = $1;
	    $seq = $2;
	    ($id) = split (/\s+/, $header);
	}
	else{
	    $id = "fasta".$count;
	    $seq = $fasta;
	    $count++;
	    $fasta = ">$id\n$seq\n";
	}


	# check if sequence is in any protein fam by md5 checksum
	my $fams;
	if (!$nuc){
	    my $md5 = Digest::MD5::md5_hex( uc $seq );
	    $fams = $self->families_containing_md5($md5);
	}
	if (($fams) && ($fams !~ /\,/)){     # do regular check if the checksum returns more than one prtofam
	    my $got = new ProtFamLite($self, $fams);
	    ($should_be, $sims) = $got->should_be_member($seq,$debug,$loose,$debug_prot,$nuc);
	    $out->{$seq} = [$got, $sims];
	    #push (@$out, [$seq, $got, $sims]);
	}
	else{
	    $seq_list->{$id} = $seq;
	    push (@run_blast, $fasta);
	}
    }    

    my $tmpF = "$FIG_Config::temp/tmp$$.fasta";
    open(TMP,">$tmpF") 
	|| die "could not open $tmpF";
    print TMP @run_blast;
    close(TMP);
    my @tmp;

    if ($nuc){
	@tmp = `$FIG_Config::ext_bin/blastall -i $tmpF -d $dir/repdb -m 8 -FF -p blastx -g T` || die "could not open blast";
	print STDERR "$FIG_Config::ext_bin/blastall -i $tmpF -d $dir/repdb -m 8 -FF -p blastx -g T\n" if ($debug);
    }
    else{
	@tmp = `$FIG_Config::ext_bin/blastall -i $tmpF -d $dir/repdb -m 8 -FF -p blastp` || die "could not open blast";
	print STDERR "$FIG_Config::ext_bin/blastall -i $tmpF -d $dir/repdb -m 8 -FF -p blastx -g T\n" if ($debug);
    }

    my $prev_id;
    my $seen = {};
    my $got = {};
    my $min_sc = {};
    my $checked = {};

    while ( (defined( $_ = shift @tmp)) )
    {
	my $sim = [split(/\t/,$_)];

	next if ($got->{$sim->[0]});
	next if ($checked->{$sim->[0]} > 30);
	if (!$min_sc->{$sim->[0]}){
	    $min_sc->{$sim->[0]} = 1;
	}

	if ($debug) { print STDERR $_ }
	chop;
	if ($min_sc->{$sim->[0]} > $sim->[10]) { $min_sc->{$sim->[0]} = $sim->[10] }
	my $fam_id = ($sim->[1] =~ /(.*)-/) ? $1 : "";
	if (! $seen->{$sim->[0]}->{$fam_id})
	{
	    $seen->{$sim->[0]}->{$fam_id} = 1;
	    
	    # skip if the e-value is 1 or higher
	    if ($sim->[10] >= 1){
		#print STDERR "SIM evalue: " . $sim->[10] . "\n" if ($debug);
		$checked->{$sim->[0]}++;
		next;
	    }
	    
	    $protfam = new ProtFamLite($self, $fam_id);
	    
	    if (not defined($protfam))
	    {
		next;
	    }
	    else
	    {
		$checked->{$sim->[0]}++;
		if ($debug) { print STDERR "checking family $fam_id ",$protfam->family_function,"\n" }
		my ($should_be, $sims) = $protfam->should_be_member($seq_list->{$sim->[0]},$debug,$loose,$debug_prot,$nuc);
		if ($debug) { print STDERR "    should_be=$should_be\n" }
		my $psc;
		if ($should_be && defined($psc = &psc($sims->[0])) && ($psc <= $min_sc->{$sim->[0]}))
		{
		    if ($debug) { print STDERR "min_sc=$min_sc best=$psc\n" }
		    $got->{$sim->[0]} = $protfam;
		    #push (@$out, [$seq_list->{$sim->[0]}, $got->{$sim->[0]}, $sims]);
		    $out->{$seq_list->{$sim->[0]}} = [$got->{$sim->[0]}, $sims];
		}
	    }
	}

#	if ($debug)
#	{
#	    my $blast_line;
#	    while ($blast_line && (defined($blast_line = shift @blast_tmp)))  ### JUST PRINT OUT REMAINING BLASTS AGAINST REPDB
#	    {
#		print STDERR $blast_line;
#	    }
#	}
#
#	if (!$got){
#	    push (@$out, [$prev_id, undef, undef]);
#	}

    }

    $/ = $old_sep;
#    close(BLAST);

    foreach my $id (keys %$seq_list)
    {
	if (!$got->{$id})
	{
	    #push (@$out, [$seq_list->{$id}, undef, undef]);
	    $out->{$seq_list->{$id}} = [undef, undef];
	}
    }

    unlink($tmpF);
    return $out;
}

sub psc {
    my ($sim) = @_;
    return ($sim->[10] =~ /^e-/) ? "1.0" . $sim->[10] : $sim->[10];
}


=head3
usage: $protfams->family_functions();

returns a hash of all the functions for all protein fams from the family.functions file

=cut

sub family_functions {
    my($self) = @_;
    my $ffD   = $self->{dir};
    my $ff_file     = "$ffD/family.functions";

    my $contents;
    sysopen(FAM_FUNC, $ff_file, 0) or die "could not open file '$ff_file': $!";
    sysread(FAM_FUNC, $contents, 1000000000);
    close(FAM_FUNC) or die "could not close file '$ff_file': $!";
    my %ff_name = map {split(/\t/)} split("\n", $contents);

    return \%ff_name;
}



1;
