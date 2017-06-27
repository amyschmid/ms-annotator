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

package ProtFams;

use strict;
use DB_File;

use FIG;
use Data::Dumper;
use DBrtns;
use Carp;
use ProtFam;
use Cwd 'abs_path';
use Digest::MD5;
use ProtFamsLite;

# This is the constructor.  Presumably, $class is 'ProtFams'.  
#

sub new {
    my($class,$fig,$fam_data) = @_;
    my $protfams = {};
    
    $protfams->{fig} = defined($fig->{_fig}) ? $fig->{_fig} : $fig;

    $fam_data = $fig->get_figfams_data($fam_data);

    if ($ENV{REPORT_FIGFAM_DETAILS})
    {
	eval {
	    my $abs = abs_path($fam_data);
	    print STDERR "ProtFams.pm: $0 using data in $abs ($fam_data)\n";
	};
    }
    $protfams->{dir} = $fam_data;
    $protfams->{root} = $fam_data;
    $protfams->{ProtFamsLite} = new ProtFamsLite($fam_data);

#    &verify_dbs_made($fam_data,$protfams->{fig});
    bless $protfams,$class;
    $protfams->verify_dbs_made($fam_data,$protfams->{fig});

    return $protfams;
}

sub families_implementing_role {
    my($self,$role) = @_;

    return $self->{ProtFamsLite}->families_implementing_role($role);
}

sub rebuild_dbs {
    my($self) = @_;

    my $dir = $self->{dir};
    $self->rebuild_repdb;
    &FIG::run("formatdb -p T -i $dir/repdb");

    foreach my $db ("role","function","prot","genome","relevant.prot.data","PDB.connections","md5.protfams")
    {
	&remove_old($dir,$db);
    }

    $self->{fig} = new FIG if (!$self->{fig});
#    &verify_dbs_made($fam_data,$self->{fig});
    $self->verify_dbs_made($dir,$self->{fig});
}

sub remove_old {
    my($dir,$db) = @_;

    if ((-s "$dir/$db.db") && ((-M "$dir/$db.db") > (-M "$dir/$db")))
    {
	unlink("$dir/$db.db");
    }
}

sub path_to {
    my ($self,$family_name) = @_;

    return $self->{ProtFamsLite}->path_to($family_name);
}

sub families_with_function {
    my($self,$function) = @_;

    return $self->{ProtFamsLite}->families_with_function($function);
}

sub function_of_family {
    my($self,$fam) = @_;

    return $self->{ProtFamsLite}->function_of_family($fam);
}

sub get_translation {
    my ($self, $protein) = @_;

    return $self->{ProtFamsLite}->get_translation($protein);
}

sub get_translation_bulk {
    my ($self, $proteins) = @_;

    return $self->{ProtFamsLite}->get_translation_bulk($proteins);
}

sub PDB_connections {
    my($self,$fam,$raw) = @_;

    return $self->{ProtFamsLite}->PDB_connections($fam,$raw);
}

sub proteins_containing_md5 {
    my ($self,$md5) = @_;
    
    return $self->{ProtFamsLite}->proteins_containing_md5($md5);
}

sub families_containing_md5 {
    my ($self,$md5) = @_;
    
    return $self->{ProtFamsLite}->families_containing_md5($md5);
}

sub families_with_functional_role {
    my($self,$functional_role) = @_;

    return $self->families_implementing_role($functional_role);
}

sub families_containing_prot_bulk {
    my ($self, $prot_bulk) = @_;
    my $family_hash = {};

    foreach my $prot (@$prot_bulk) {
	my @fam = $self->{ProtFamsLite}->families_containing_peg($prot);
	if (@fam > 0){
	    $family_hash->{$prot} = $fam[0];
	}
    }
    return $family_hash;
}

sub families_containing_prot {
    my($self,$prot) = @_;

    return $self->{ProtFamsLite}->families_containing_peg($prot);
}

sub families_in_genome {
    my($self,$genome) = @_;

    return $self->{ProtFamsLite}->families_in_genome($genome);
}

sub all_families {
    my($self) = @_;

    return sort map { chomp; $_ } `cut -f1 $self->{dir}/family.functions`;
}

sub place_in_family {
    my($self,$seq,$debug,$loose,$debug_prot,$nuc,$md5_flag) = @_;

    return $self->{ProtFamsLite}->place_in_family($seq,$debug,$loose,$debug_prot,$nuc);
}

sub place_in_family_bulk {
    my($self,$seq,$debug,$loose,$debug_prot,$nuc) = @_;

    return $self->{ProtFamsLite}->place_in_family_bulk($seq,$debug,$loose,$debug_prot,$nuc);
}

sub is_prots_in_family {
    my($self,$seqs) = @_;

    return $self->{ProtFamsLite}->is_prots_in_family($seqs);
}

sub rebuild_repdb {
    my($self) = @_;
    
    my $dir = $self->{dir};
    my($sub,$fam);
    if (-e "$dir/repdb") { system "rm $dir/repdb*" }
    open(REPDB,">$dir/repdb") || die "could not open $dir/repdb";

    opendir(D1,"$dir/FAMS") || die "could not open $dir/FAMS";
    
    foreach $sub (sort grep { $_ =~ /^(\d+)/ } readdir(D1))
    {
#	print STDERR "$sub\n";
	opendir(SUB,"$dir/FAMS/$sub") || die "could not open $dir/FAMS/$sub";
	my @protfam_dirs = sort grep { $_ !~ /^\./ } readdir(SUB);
	closedir(SUB);
	foreach my $pf (@protfam_dirs)
	{
	    my $final_dir = "$dir/FAMS/$sub/$pf";
	    my $rc = open(REPS,"<$final_dir/reps");
	    if (! $rc) 
	    {
		unlink("$final_dir/built");
		my $fig = $self->{fig};
		open (FAM_NAME, "<$final_dir/family_id");
		my $fam_name = <FAM_NAME>;
		chomp $fam_name;
		close FAM_NAME;
		my $protfam = new ProtFam($fig,$self,$fam_name);
		$rc = open(REPS,"<$final_dir/reps");
	    }
	    if ($rc)
	    {
		my $line;
		while (defined($line = <REPS>))
		{
		    print REPDB $line;
		}
		close(REPS);
	    }
	}
#	system "cat $dir/FIGFAMS/$sub/*/reps >> $dir/repdb";
    }
    closedir(D1);
    close(REPDB);
}

sub rebuild_md5_to_fams {
    my ($self) = @_;
    my $fig = $self->{fig};

    my $dir = $self->{dir};

    if (-e "$dir/md5.protfams") { system "rm $dir/md5.protfams*" }
    open(OUT,">$dir/md5.protfams") || die "could not open $dir/md5.protfams";
    
    my $md5Hash = {};
    open(TMP,"<$dir/families.3c")
	|| die "could not open $dir/families.2c";
    while (defined($_ = <TMP>))
    {
	if ($_ =~ /^(\S+)\t(\S+)\t(\S+)/)
	{
	    my $fam  = $1;
	    my $peg  = $2;
	    my $seq  = $3;

	    # get the MD5 for the sequence
	    my $md5 = Digest::MD5::md5_hex( uc $seq );
	    push (@{$md5Hash->{$md5}}, $fam);
	}
    }
    close(TMP);

    foreach my $md5 (sort keys %{$md5Hash}){
	my %saw;
	@saw{@{$md5Hash->{$md5}}} = ();
	my @array = sort keys %saw;  # remove sort if undesired

	print OUT join(",", @array) . "\t$md5\n";
    }
    close OUT;

}

sub verify_dbs_made {
    my($self,$fam_data,$fig) = @_;

    $self->verify_role_to_fams($fam_data);
    $self->verify_family_map($fam_data);
    $self->verify_function_to_fams($fam_data);
    $self->verify_fam_to_function($fam_data);
    $self->verify_prot_to_fams($fam_data);
    $self->verify_genome_to_fams($fam_data);
    $self->verify_relevant_prot_data($fam_data,$fig);
    $self->verify_PDB_connections($fam_data) if (-f "$fam_data/PDB.connections");
    $self->verify_md5_fams($fam_data);
    $self->verify_md5_prots($fam_data);
}

sub verify_md5_prots {
    my($self,$fam_data) = @_;

    my $db = "$fam_data/md5.prots.db";
    my %md5_hash;

    if (! -s $db)
    {
	my $md5_hash_tie = tie %md5_hash, 'DB_File', $db, O_RDWR | O_CREAT, 0666, $DB_HASH;
	$md5_hash_tie || die "tie failed";
	my %md5_to_prots;
	open(TMP,"<$fam_data/families.3c")
	    || die "could not open $fam_data/md5.protfams";
	while (defined($_ = <TMP>))
	{
	    if ($_ =~ /^(.*)\t(.*)\t(.*)/)
	    {
		my $fam      = $1;
		my $prot     = $2;
		my $seq      = $3;
		my $md5 = Digest::MD5::md5_hex( uc $seq );

		push(@{$md5_to_prots{$md5}},$prot);
	    }
	}
	close(TMP);
    
	foreach my $md5 (keys(%md5_to_prots))
	{
	    $md5_hash{$md5} = join("\n",@{$md5_to_prots{$md5}});
	}
	untie %md5_hash;
    }

}

sub verify_md5_fams {
    my($self,$fam_data) = @_;

    my $db = "$fam_data/md5.protfams.db";
    my %md5_hash;

    if (! -s $db)
    {
	$self->rebuild_md5_to_fams() if (! -f "$fam_data/md5.protfams");

	my $md5_hash_tie = tie %md5_hash, 'DB_File', $db, O_RDWR | O_CREAT, 0666, $DB_HASH;
	$md5_hash_tie || die "tie failed";
	my %md5_to_fams;
	open(TMP,"<$fam_data/md5.protfams")
	    || die "could not open $fam_data/md5.protfams";
	while (defined($_ = <TMP>))
	{
	    if ($_ =~ /^(.*)\t(.*)/)
	    {
		my $fams      = $1;
		my $md5       = $2;
		push(@{$md5_to_fams{$md5}},$fams);
	    }
	}
	close(TMP);
    
	foreach my $md5 (keys(%md5_to_fams))
	{
	    $md5_hash{$md5} = join("\n",@{$md5_to_fams{$md5}});
	}
	untie %md5_hash;
    }
}

sub verify_PDB_connections {
    my($self,$fam_data) = @_;

    my $db = "$fam_data/PDB.connections.db";
    my %PDB_hash;

    if (! -s $db)
    {
	my $PDB_hash_tie = tie %PDB_hash, 'DB_File', $db, O_RDWR | O_CREAT, 0666, $DB_HASH;
	$PDB_hash_tie || die "tie failed";
	my %fam_to_PDB_sims;
	open(TMP,"<$fam_data/PDB.connections")
	|| die "could not open $fam_data/PDB.connections";
	while (defined($_ = <TMP>))
	{
	    if ($_ =~ /^(\S+)\t(\S.*\S)/)
	    {
		my $fam        = $1;
		my $pdb_data   = $2;
		push(@{$fam_to_PDB_sims{$fam}},$2);
	    }
	}
	close(TMP);
    
	foreach my $fam (keys(%fam_to_PDB_sims))
	{
	    $PDB_hash{$fam} = join("\n",@{$fam_to_PDB_sims{$fam}});
	}
	untie %PDB_hash;
    }
}


sub verify_role_to_fams {
    my($self,$fam_data) = @_;

    my $db = "$fam_data/role.db";
    my %role_hash;

    if (! -s $db)
    {
	my $role_hash_tie;
	($role_hash_tie = tie %role_hash, 'DB_File', $db, O_RDWR | O_CREAT, 0666, $DB_HASH)
	    || die qq(Attempt to tie \%role_hash to "$db" failed: \$\! = "$!");
	
	open(TMP,"<$fam_data/family.functions")
	|| die "could not open $fam_data/family.functions";
	my %role_to_fams;
	while (defined($_ = <TMP>))
	{
	    if ($_ =~ /^(\S+)\t(\S.*\S)/)
	    {
		my $fam  = $1;
		my $func = $2;

		# edit function only if FIG is present in function name
		$func =~ s/^FIG\d{6}[^:]+:\s*//;

		foreach my $role (&FIG::roles_of_function($func))
		{
		    push(@{$role_to_fams{$role}},$fam);
		}
	    }
	}
	close(TMP);
    
	foreach my $role (keys(%role_to_fams))
	{
	    my $fams = $role_to_fams{$role};
	    $role_hash{$role} = join("\t",@$fams);
	}
	untie %role_hash;
    }
}

sub verify_function_to_fams {
    my($self,$fam_data) = @_;

    my $db = "$fam_data/function.db";
    my %function_hash;

    if (! -s $db)
    {
	my $function_hash_tie = tie %function_hash, 'DB_File', $db, O_RDWR | O_CREAT, 0666, $DB_HASH;
	$function_hash_tie || die "tie failed";

	open(TMP,"<$fam_data/family.functions")
	|| die "could not open $fam_data/family.functions";
	my %function_to_fams;
	while (defined($_ = <TMP>))
	{
	    if ($_ =~ /^(\S+)\t(\S.*\S)/)
	    {
		my $fam  = $1;
		my $func = $2;

		# edit function only if FIG is present in function name
		$func =~ s/^\S+\d{6}[^:]+:\s*//;
		push(@{$function_to_fams{$func}},$fam);
	    }
	}
	close(TMP);
    
	foreach my $function (keys(%function_to_fams))
	{
	    my $fams = $function_to_fams{$function};
	    $function_hash{$function} = join("\t",@$fams);
	}
	untie %function_hash;
    }
}

sub verify_fam_to_function {
    my($self,$fam_data) = @_;

    my $db = "$fam_data/fam_function.db";
    my %function_hash;

    if (! -s $db)
    {
	my $function_hash_tie = tie %function_hash, 'DB_File', $db, O_RDWR | O_CREAT, 0666, $DB_HASH;
	$function_hash_tie || die "tie failed";

	open(TMP,"<$fam_data/family.functions")
	|| die "could not open $fam_data/family.functions";
	my %fam_to_function;
	while (defined($_ = <TMP>))
	{
	    if ($_ =~ /^(\S+)\t(\S.*\S)/)
	    {
		my $fam  = $1;
		my $func = $2;

		# edit function only if FIG is present in function name
		$func =~ s/^\S+\d{6}[^:]+:\s*//;
		push(@{$fam_to_function{$fam}},$func);
	    }
	}
	close(TMP);
    
	foreach my $family (keys(%fam_to_function))
	{
	    my $funcs = $fam_to_function{$family};
	    $function_hash{$family} = join("\t",@$funcs);
	}
	untie %function_hash;
    }
}

sub verify_prot_to_fams {
    my($self,$fam_data) = @_;

    my $db = "$fam_data/prot.db";
    my %prot_hash;

    if (! -s $db)
    {
	my $prot_hash_tie = tie %prot_hash, 'DB_File', $db, O_RDWR | O_CREAT, 0666, $DB_HASH;
	$prot_hash_tie || die "tie failed";

	open(TMP,"<$fam_data/families.3c")
	|| die "could not open $fam_data/families.2c";
	my %prot_to_fams;
	while (defined($_ = <TMP>))
	{
	    if ($_ =~ /^(\S+)\t(\S+)\t/)
	    {
		my $fam  = $1;
		my $prot  = $2;
		push(@{$prot_to_fams{$prot}},$fam);
	    }
	}
	close(TMP);
    
	foreach my $prot (keys(%prot_to_fams))
	{
	    my $fams = $prot_to_fams{$prot};
	    $prot_hash{$prot} = join("\t",@$fams);
	}
	untie %prot_hash;
    }
}

sub verify_genome_to_fams {
    my($self,$fam_data) = @_;

    my $db = "$fam_data/genome.db";
    my %genome_hash;

    if (! -s $db)
    {
	my $genome_hash_tie = tie %genome_hash, 'DB_File', $db, O_RDWR | O_CREAT, 0666, $DB_HASH;
	$genome_hash_tie || die "tie failed";

	open(TMP,"<$fam_data/families.3c")
	|| die "could not open $fam_data/families.2c";
	my %genome_to_fams;
	while (defined($_ = <TMP>))
	{
	    if ($_ =~ /^(.*)\t(.*)\t/)
	    {
		my $fam  = $1;
		my $prot  = $2;

		# need to get the genome from the protein id
		my ($genome);
		if (-f "$fam_data/FIG")
		{
		    ($genome) = $prot =~ /^fig\|(\d+\.\d+)\./;
		}
		else
		{
		    $genome = "Null";
		}

		$genome_to_fams{$genome}->{$fam} = 1;
	    }
	}
	close(TMP);
    
	foreach my $genome (keys(%genome_to_fams))
	{
	    my @fams = keys(%{$genome_to_fams{$genome}});
	    $genome_hash{$genome} = join("\t",@fams);
	}
	untie %genome_hash;
    }
}


sub verify_relevant_prot_data {
    my($self,$fam_data,$fig) = @_;

    my $db = "$fam_data/relevant.prot.data.db";
    my %relevant_prot_data_hash;
    if (! -s $db)
    {
	if (! -s "$fam_data/relevant.prot.data")
	{
	    if (-f "$fam_data/FIG")
	    {
		open(PROT,"(cut -f2 $fam_data/families.3c; grep \"^fig\" $fam_data/partitions.input) | sort -u | function_of |")
		    || die "could not make relevant.prot.data";
		open(OUT,">$fam_data/relevant.prot.data")
		    || die "could not open relevant.prot.data";

		my($line,$seq,$aliases,$prot);
		while (defined($line = <PROT>))
		{
		    chop $line;
		    if (($line =~ /^(\S+)/) && ($prot = $1) &&
			($seq = $fig->get_translation($prot)))
		    {
			$aliases = $fig->feature_aliases($prot);
			print OUT "$line\t$seq\t$aliases\n";
		    }
		}
		close(PROT);
		close(OUT);
	    }
	    else
	    {
		open(PROT, "<$fam_data/families.3c") 
		    || die "could not make relevant.prot.data";
		open(OUT,">$fam_data/relevant.prot.data")
                    || die "could not open relevant.prot.data";

		my $family_functions = $self->family_functions;
                while (defined(my $line = <PROT>))
                {
                    chop $line;
		    my ($fam,$prot,$seq) = split (/\t/, $line);
		    my $organism = "Null";
		    my $function = $family_functions->{$fam};
		    my $md5_id = "gnl|md5|". Digest::MD5::md5_hex( uc $seq );
		    my $aliases = $fig->feature_aliases($md5_id);
		    print OUT "$prot\t$organism\t$function\t$seq\t$aliases\n";
		}
		close (PROT);
		close (OUT);
	    }
	}
	my $relevant_prot_data_hash_tie = tie %relevant_prot_data_hash, 'DB_File', $db, O_RDWR | O_CREAT, 0666, $DB_HASH;
	$relevant_prot_data_hash_tie || die "tie failed";

	open(TMP,"<$fam_data/relevant.prot.data")
	    || die "could not open $fam_data/relevant.prot.data";
	while (defined($_ = <TMP>))
	{
	    if ($_ =~ /^(\S+)\t(\S.*\S)/)
	    {
		$relevant_prot_data_hash{$1} = $2;
	    }
	}
	close(TMP);
	untie %relevant_prot_data_hash;
    }
}

sub verify_family_map {
    my($self,$fam_data) = @_;

    my $db = "$fam_data/family_id_map.db";
    my %map_hash;

    if (! -s $db)
    {
	# create family.map file
	$self->make_internal_family_id_file();

        my $map_hash_tie = tie %map_hash, 'DB_File', $db, O_RDWR | O_CREAT, 0666, $DB_HASH;
        $map_hash_tie || die "tie failed";
        my %mappings;
        open(TMP,"<$fam_data/family.map")
            || die "could not open $fam_data/family.map";
        while (defined($_ = <TMP>))
        {
            if ($_ =~ /^(.*)\t(.*)/)
            {
                my $internal_id      = $1;
                my $user_fam_name    = $2;
                push(@{$mappings{$user_fam_name}},$internal_id);
            }
        }
        close(TMP);

        foreach my $map (keys(%mappings))
        {
            $map_hash{$map} = join("\n",@{$mappings{$map}});
        }
        untie %map_hash;
    }
}


sub make_internal_family_id_file {
    my ($self) = @_;

    my $file = $self->{dir} ."/family.functions";
    my $internal_fam_id_file = $self->{dir} . "/family.map";
    open (FH, "<$file") || die " could not open file $file\n";
    open (FW, ">$internal_fam_id_file") || die "could not open file $internal_fam_id_file\n";
    my $internal_id = 1;

    while (my $line = <FH>){
        chomp $line;
        my ($user_fam_name, $user_fam_func) = split (/\t/, $line);

        print FW join ("\t", $internal_id, $user_fam_name) . "\n";
        $internal_id++;
    }
    close FH;
    close FW;

}


=head3
usage: $protfams->family_functions();

returns a hash of all the functions for all figfams from the family.functions file

=cut

sub family_functions {
    my($self) = @_;

    return $self->{ProtFamsLite}->family_functions();
}

sub all_prots_in_protfams{
    my ($self) = @_;

    my $ff_data = $self->{dir};
    my $ff_file     = "$ff_data/families.3c";

    my $contents;
    my $len = -s $ff_file;
    sysopen(FF, $ff_file, 0) or die "could not open file '$ff_file': $!";
    sysread(FF, $contents, $len);
    close(FF) or die "could not close file '$ff_file': $!";
    my %ff_name;
    foreach my $line (split("\n", $contents)){
	my ($fam, $prot, $seq) = split (/\t/, $line);
	push (@{$ff_name{$fam}}, $prot);
    }

    return \%ff_name;

}

#############################################################
#############################################################
#
#    The following functions are specific to FIGfams


########################################
#
# reset_functions is specific to FIGfams.
# Functions for external families do not get reset
#

sub reset_functions {
    my($self,$fams, $parallel) = @_;

#    my $fig = $self->{fig};    
    my $fig = new FIG;  # this needs to be like this in case the reset_functions_parallel_procs is called
    my $dir = $self->{dir};

    if (!$fams){
	$fams = [];
	push (@$fams, $self->all_families);
    }

    foreach my $fam_id (@$fams)
    {
	print STDERR "...resetting function for $fam_id\n";
	if (!$fig){
	    $fig = new FIG;
	}
	my $figfam = new ProtFam($fig,$self,$fam_id);
	if ($figfam)
	{
	    $figfam->reset_function;
	}
    }
    if (!$parallel){
	$self->rebuild_family_funcs;
    }
}

sub reset_functions_parallel_procs {
    my($self,$fams) = @_;

    my $fig = $self->{fig};    
    my $dir = $self->{dir};

    if (!$fams){
	$fams = [];
	push (@$fams, $self->all_families);
    }

    my $sets = {};
    my $procs = 12;
    my $procNum = 0;

    foreach my $fam_id (@$fams){
	$procNum = 0 if ($procNum == $procs);
	push (@{$sets->{$procNum}}, $fam_id);
	$procNum++;
    }


    my (@children);
    for (my $i=0; ($i < $procs); $i++){
	my $pid = fork();
	if ($pid) { # parent
	    push @children, $pid;
	}
	elsif ($pid == 0) { # child
	    &reset_functions($self, $sets->{$i},'1');
	    exit;
	}
	else{
	    print STDERR "couldn't fork\n";
	}
    }

    foreach my $child (@children){
	waitpid($child, 0);
    }

    $self->rebuild_family_funcs;
}

sub rebuild_family_funcs {
    my($self) = @_;
    
    my $dir = $self->{dir};
    my($sub,$fam);
    if (-e "$dir/family.functions") { system "rm $dir/family.functions*" }

    open(OUT,">$dir/family.functions") || die "could not open $dir/family.functions";

    opendir(D1,"$dir/FAMS") || die "could not open $dir/FAMS";
    
    foreach $sub (grep { $_ =~ /^(\d+)/ } readdir(D1))
    {
	opendir(D2,"$dir/FAMS/$sub") || die "could not open $dir/FAMS/$sub";
	foreach $fam (grep { $_ !~ /^\./ } readdir(D2))
	{
	    if (open(IN,"<$dir/FAMS/$sub/$fam/function") && ($_ = <IN>))
	    {
		print OUT "$fam\t$_";
		close(IN);
	    }
	}
	closedir(D2);
    }
    closedir(D1);
    close(OUT);
    &verify_function_to_fams($dir);

}

sub is_paralog_figfams{
    my ($self, $fig, $figfamObject1, $figfamObject2) = @_;

    # get the sequences for figfamObject1 and figfamObject2
    my @ff1_ids = $figfamObject1->list_members();
    my @ff2_ids = $figfamObject2->list_members();
    
    foreach my $ff1_id (@ff1_ids){
	foreach my $ff2_id (@ff2_ids){
	    if ($fig->genome_of($ff1_id) eq $fig->genome_of($ff2_id)){
		return 1; # if there are paralogs of each other in the two figfams
	    }
	}
    }
}

sub are_figfams_same_gene_context{
    my ($self, $fig, $figfamObject1, $figfamObject2, $threshold) = @_;

    # get the sequences for figfamObject1 and figfamObject2
    my @ff1_ids = $figfamObject1->list_members();
    my @ff2_ids = $figfamObject2->list_members();
    
    foreach my $ff1_id (@ff1_ids){
	# get the gene context of the $ff1_id
	my $genome = $fig->genome_of($ff1_id);
	
	# get the contig informmation
	my $data = $fig->feature_location($ff1_id);
	my ($contig, $beg, $end);
	if ($data =~ /(.*)_(\d+)_(\d+)$/){
	    $contig = $1;
	    if ($2 < $3)
	    {
		$beg = $2-4000;
		$end = $3+4000;
	    }
	    else
	    {
		$beg = $2+4000;
		$end = $3-4000;
	    }
	}
	
	my ($gene_features, $reg_beg, $reg_end) = $fig->genes_in_region($genome, $contig, $beg, $end);
	my %bbh_feature_hash = ();
	foreach my $fid1 (@$gene_features){
	    my @bbhs  = $fig->bbhs($fid1);
	    my @featureList = map { $_->[0] } @bbhs;
	    foreach my $feature (@featureList){	
		$bbh_feature_hash{$feature} = $fid1;
	    }
	}
	my $gene_context_count = scalar(@$gene_features);
	next if ($gene_context_count < 1);

	foreach my $ff2_id (@ff2_ids){
	    # check if the majority (>.80) of the genes are in the second id
	    # get the gene context of the $ff2_id
	    my $genome2 = $fig->genome_of($ff2_id);
	
	    # get the contig informmation
	    my $data2 = $fig->feature_location($ff2_id);
	    my ($contig2, $beg2, $end2);
	    if ($data2 =~ /(.*)_(\d+)_(\d+)$/){
		$contig2 = $1;
		if ($2 < $3)
		{
		    $beg2 = $2-4000;
		    $end2 = $3+4000;
		}
		else
		{
		    $beg2 = $2+4000;
		    $end2 = $3-4000;
		}
	    }
	
	    my ($gene_features2, $reg_beg2, $reg_end2) = $fig->genes_in_region($genome2, $contig2, $beg2, $end2);
	    my $agree = 0;
	    foreach my $fid2 (@$gene_features2){
		if ($bbh_feature_hash{$fid2}){
		    $agree++;
		}
	    }
	    if ($agree/$gene_context_count >= $threshold){
		return (1,$ff1_id, $ff2_id);  # if they have same gene context.
	    }
	}
    }
    return (0, "empty", "empty");
}

=head3
usage: $figfams->pegs_of_family_in_genomes(["fig|83333.1.peg.3", "fig|83333.1.peg.4"],["83334.1", "831.1"]);

for each input peg(s) and genome(s) wanted, a hash is returned with the list of pegs from the query genome(s) in the same
figfam as the query peg(s).

=cut


sub pegs_of_family_in_genomes {
    my ($self, $query, $genomes) = @_;

    return if (scalar @$genomes < 1);
    my $search_genomes = "(\\\|".join( ".)|(\\\|", @$genomes).".)";
    $search_genomes =~ s/\./\\./ig;

    my $fig = $self->{fig};
    my $peg_data = &all_pegs_in_figfams();
    my $results = {};
    
    my @all_pegs;
    my ($query_org, $pegs) = @$query;
    if ($pegs && scalar @$pegs > 0){
	push (@all_pegs, @$pegs);
    }
    else{
	@all_pegs = $fig->pegs_of($query_org);
    }

    foreach my $peg (@all_pegs){
	my @families = $self->families_containing_peg($peg);
	my $family = $families[0] if (scalar @families >0);

	# get the genome pegs for the family
	foreach my $member (@{$peg_data->{$family}}){
	    next if ($member !~ /$search_genomes/);
	    push (@{$results->{$peg}}, $member);
	}
    }

    return $results;
}

sub figfam_active_subsystems {
    my ($self, $fig, $tmp) = @_;

    my $dir = $self->{dir};
    my ($ff_ss, $ff_func);
    if ($tmp){
	open (FH, "$tmp/figfam_subsystem.dat");
    }
    else{
        open (FH, "$dir/release_history/figfam_subsystem.dat");
    }
    while (my $line = <FH>)
    {
        chomp $line;
	my ($fam, $function, @subsystems) = split (/\t/, $line);
        foreach my $ss (@subsystems){
            push (@{$ff_ss->{$ss}}, $fam);
        }
        $ff_func->{$fam} = $function;
    }
    return ($ff_ss, $ff_func);
}

sub get_quality_control_data{
    my ($self, $fig, $tmp) = @_;
    my $data;
    my $dir = $self->{dir};

    if ($tmp){
        open (FH, "$tmp/QC.dat");
    }
    else{
        open (FH, "$dir/release_history/QC.dat");
    }

    $/ = "//\n";
    while (my $line = <FH>){
        chomp ($line);
        $line =~ s/\n//ig;
        my ($name, $org, $total, $annotated, $misannotated) = ($line) =~ /NAME\tRelease (.*)ORGANISM\t(.*)TOTAL\t(.*)ANNOTATED\t(.*)MISANNOTATED\t(.*)/;

        if (! defined $data->{$org}->{annotations}){
            my $genus = $fig->genus_species($org);
            push (@{$data->{$org}->{annotations}}, ['name', $genus]);
            push (@{$data->{$org}->{correct}}, ['name', $genus]);
        }

        push (@{$data->{$org}->{annotations}}, [$name, $annotated/$total]);
        if ($annotated > 0){
            push (@{$data->{$org}->{correct}}, [$name, ($annotated-$misannotated)/$annotated]);
	}
        else{
            push (@{$data->{$org}->{correct}}, [$name, 0]);
        }

    }
    close FH;
    $/ = "\n";

    return $data;
}

sub get_current_figfam_size_data {
    my ($self, $fig, $tmp) = @_;

    my $dir = $self->{dir};
    my ($ff_size);

    if ($tmp){
        open (FH, "$tmp/size_distribution.dat");
        open (VERSION, "$tmp/VERSION");
    }
    else{
        open (FH, "$dir/release_history/size_distribution.dat");
        open (VERSION, "$dir/release_history/VERSION");
    }

    my ($total_pegs,$total_ff);
    my $distribution = [];
    while (my $line = <FH>){
        chomp($line);
        my ($ff_size, $ff_qty) = split(/\t/, $line);
        $total_pegs += $ff_size*$ff_qty;
        $total_ff += $ff_qty;
        my $array = [$ff_size, $ff_qty];
	push(@$distribution, $array);
    }
    close FH;

    my $rel_name;
    while (my $line =<VERSION>){
        chomp $line;
        if ($line =~ m/^(version)\t(.*)/){
            $ff_size->{release} = $2;
            push(@$distribution, ['name',$2]);
            $ff_size->{name}=$2;
            #last;
	}
        else{
            my ($key, $value) = split(/\t/, $line);
            $ff_size->{$key}=$value;
	}
    }
    close VERSION;

    $ff_size->{distribution} = $distribution;
    $ff_size->{ff_peg_qty} = $total_pegs;
    $ff_size->{ff_qty} =  $total_ff;

    return $ff_size;
}

sub get_previous_figfam_size_data {
    my ($self, $fig, $tmp) = @_;

    my $dir = $self->{dir};
    my ($ff_size);
    my $prev_dir;
    my $prev_releases ={};

    if ($tmp){
        $prev_dir = "$tmp/old_releases";
    }
    else{
        $prev_dir = "$dir/release_history/old_releases";
    }

    my @releases = glob("$prev_dir/*");
    foreach my $release (@releases){
        open (FH, "$release/size_distribution.dat");
        open (VERSION, "$release/VERSION");

        my ($total_pegs,$total_ff);
        my $distribution = [];
        while (my $line = <FH>){
            chomp($line);
            my ($ff_size, $ff_qty) = split(/\t/, $line);
            $total_pegs += $ff_size*$ff_qty;
            $total_ff += $ff_qty;
            my $array = [$ff_size, $ff_qty];
            push(@$distribution, $array);
        }
        close FH;

        my $release_name;
        while (my $line =<VERSION>){
            chomp $line;
            if ($line =~ m/^(version)\t(.*)/){
                $ff_size->{release} = $2;
                push(@$distribution, ['name',$2]);
                $release_name = $2;
                $ff_size->{name} = $2;
                last;
            }
        }
        close VERSION;

        $ff_size->{distribution} = $distribution;
        $ff_size->{ff_peg_qty} = $total_pegs;
        $ff_size->{ff_qty} =  $total_ff;
        $prev_releases->{$release_name} = $ff_size;
    }

    return $prev_releases;
}


sub merge_figfams{
    my ($self, $ff_list, $user) = @_;

    my @list = sort @$ff_list;
    my $main_ff = shift @list;

#    print STDERR "$main_ff and merged are" . join(",",@list) . "\n";
    if ($self->add_to_merge_file($main_ff, \@list)){
        $self->update_peg_to_ff_db($main_ff, \@list);
        return 1;
    }
#    return 1;
}

sub update_peg_to_ff_db{
    my ($self, $main_ff, $ff_list) = @_;

    my $db = "$FIG_Config::FigfamsData/prot.db";
#    my $db = "$FIG_Config::temp/prot.db";
    my %peg_hash;
    my $peg_hash_tie = tie %peg_hash, 'DB_File', $db, O_RDWR, 0666, $DB_HASH;
    ($peg_hash_tie) || die "failed the tie";

    foreach my $fam_id (@$ff_list){
        my $figfam = new FF($fam_id,"$FIG_Config::FigfamsData");
        #print STDERR "STEP1\n";
	foreach my $peg (@{$figfam->pegs_of}){
            #print STDERR "STEP2\n";
            #print join("\t",($peg,$peg_hash{$peg})),"\n";
	    $peg_hash{$peg} = $main_ff;
            #print STDERR join("\t",($peg,$peg_hash{$peg})),"\n";
	}
    }
    untie %peg_hash;
    return 1;
}

sub add_to_merge_file{
    my ($self, $main_ff, $mergers) = @_;
    my $merge_file = "$FIG_Config::global/figfams.merge";
#    print STDERR "MERGE FILE: $merge_file";

    open (FH, ">>$merge_file") || die "could not open $merge_file";
    foreach my $to_merge (@$mergers){
	print FH "$main_ff\t$to_merge\n";
    }
    close FH;
    return 1;
}

sub should_be_merged_to{
    my ($self, $ff) = @_;

    my $ffD = $self->{dir};
    my $merge_file = "$ffD/figfams.merge";

    open (FH, ">>$merge_file") || die "could not open $merge_file";
    while (my $line = <FH>){
        chomp ($line);
	my ($mainFF, $mergeFF, $user) = split (/\t/, $line);
        return $mainFF if ($ff eq $mergeFF);
    }

    return;
}

sub get_merged_children{
    my ($self, $ff) = @_;

    my $ffD = $self->{dir};
    my $merge_file = "$ffD/figfams.merge";
    my $merged_associations = [];

    open (FH, ">>$merge_file") || die "could not open $merge_file";
    while (my $line = <FH>){
	chomp ($line);
	my ($mainFF, $mergerFF, $user) = split (/\t/, $line);

	push @$merged_associations, $mergerFF if ($mainFF eq $ff);
    }
    return $merged_associations if (scalar @$merged_associations > 0);
}

1;
