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

package ProtFamLite;

use strict;
use Carp;
use Data::Dumper;

=head1 Module to access a Protein Family

=head3 new

usage:
    my $ProtFam_Obj = ProtFamLite->new($ProtFams_Obj, $fam_id);

C<$fam_id> is the ID of the family, of the form C<n+> where C<n+> is one or more digits;
it is required.

C<$ProtFams_Obj> is required, since it is the Families-Object
that provides access to the desired collection of protein-family data.

=cut

sub new {
    my ($class, $ProtFams_Obj, $fam_id) = @_;
    
    defined($ProtFams_Obj) || confess "ProtFams_Obj is undefined";
    
    my $fig = $ProtFams_Obj->{fig} ||
	confess "ProtFams_Obj does not contain a FIG object";
    
#    ($fam_id =~ /\d+$/) || confess "invalid family id: $fam_id";
    
    my $fam = {};
    $fam->{id}   = $fam_id;
    $fam->{root} = $ProtFams_Obj->{root};
    $fam->{fig} = $fig;
    
    my $fams_dir = qq($fam->{root}/FAMS);
#    my $dir = &fam_dir($ProtFams_Obj, $fam_id);
    my $dir = $ProtFams_Obj->path_to($fam_id);
    $fam->{dir} = $dir;
    (-d $dir) || return undef;
    
    $fam->{function} = $fig->file_read( qq($dir/function), 1) || qq();
    chomp $fam->{function};
    $fam->{protfams_obj} = $ProtFams_Obj;
    
    my ($prot, $prots);
    my $protsL = [ map { $_ =~ /^(\S+)/ ? ($1) : () } 
		  $fig->file_read( qq($dir/PROTS), qq(*))
		  ];
    
    if (@$protsL < 2) {
	return undef;
    }
    
    $fam->{protsL} = $protsL;
    my $protsH = {};
    foreach $prot (@$protsL) {
	$protsH->{$prot} = 1;
    }
    $fam->{protsH} = $protsH;
    
    if (-s "$dir/PROTS.fasta") {
	open(FASTA,"<$dir/PROTS.fasta") || die "could not read-open $dir/PROTS.fasta";
	while (my ($prot, $seqP) = &read_fasta_record(\*FASTA)) {
	    $fam->{prot_lengths}->{$prot} = length($$seqP);
	}
	close(FASTA);
    }
    else {
	confess "$fam_id is missing PROTS.fasta";
    }
    
    if ((-f $fam->{root}."/FIG") && (&use_ross_bounds($class,$dir)) && (-s "$dir/bounds")) {
	$fam->{bounds} = &load_bounds("$dir/bounds");
    }
    
    bless $fam,$class;
    return $fam;
}

sub use_blast {
    my($dir) = @_;

    return ((-s "$dir/decision.procedure") && &which_dec("$dir/dec",'blast'));
}

sub use_ross_bounds {
    my ($self, $dir) = @_;

    return ( (! (-s "$dir/decision.procedure"))
	   ||
	      &which_dec("$dir/dec",'ross')
	   );
}

sub which_dec {
    my($dir,$pat) = @_;

    if (open(DEC,"<$dir/decision.procedure"))
    {
	my $x = <DEC>;
	close(DEC);
	if ($x)
	{
	    
	    return ($x =~ /^$pat/);
	}
    }
    return 0;
}
	
sub load_bounds {
    my($file) = @_;

    my $bounds;
    if (open(BOUNDS,"<$file"))
    {
	$bounds = {};
	my $x;
	while (defined($x = <BOUNDS>))
	{
	    chomp $x;
	    my @flds = split(/\t/,$x);
	    my $prot  = shift @flds;
	    $bounds->{$prot} = [@flds];
	}
	close(BOUNDS);
    }
    return $bounds;
}

=head3 prots_of

usage:
    print $protfam_obj->prots_of();

Returns a list of just prots.

=cut

sub prots_of {
    my($self) = @_;
    return [$self->list_members];
}

=head3 list_members

usage:
    @ids = $protfam_obj->list_members();

Returns a list of the PROT FIDs in a family.

=cut

sub list_members {
    my ($self)  = @_;

    my $fam_dir = $self->{dir};
    my @prots   = map { ($_ =~ /^(\S+)/) ? ($1) : ()
			} $self->{fig}->file_read(qq($fam_dir/PROTS), qq(*));

    return @prots;
}

=head3 representatives

usage:
    C<< @rep_seqs = $protfam_obj->representatives(); >>

Returns a list of the "representative sequences" characterizing a FIGfam.

=cut

sub representatives {
    my($self) = @_;

    my $reps = $self->{reps};
    if (! $reps)
    {
	my $rep_file = "$self->{dir}/reps";
	$reps = $self->{reps} = (-s $rep_file) ? [map { $_ =~ /(\S+)/; $1 } `fgrep  -v ">" $rep_file`] : [];
    }
    return @$reps;
}


=head3 should_be_member

usage:
    if ( $protfam_obj->should_be_member( $seq ) ) { #...do something... }

Returns ($placed,$sims).  $placed will be
C<TRUE> if the protein sequence in C<$seq> is judged to be
"similar enough" to the members of a family to potentially be included.

I have added the "loose" argument as an optional last argument.  This means that

    if ( $protfam_obj->should_be_member( $seq,0,1 ) ) { #...do something... }

will return true, even if the input sequence is truncated (i.e., we do not force the
similarity to go across 80% of matched sequences in the family).

=cut

sub should_be_member {
    my($self,$seq,$debug,$loose,$debug_prot,$nuc) = @_;

    my $old_eol = $/;
    $/ = "\n";

    my $dir = $self->{dir};
    my($in,@rc);
    if ( ((open(DEC,"<$dir/decision.procedure") && ($in = <DEC>) && ($in =~ /^(\S+)(\s+(\S.*\S))?/) )) ||
	 (($nuc) && open(DEC,"<$dir/decision.procedure.blast") && ($in = <DEC>) && ($in =~ /^(\S+)(\s+(\S.*\S))?/) ) )
#    if ( ((open(DEC,"<$dir/decision.procedure") && ($in = <DEC>) && ($in =~ /^(\S+)(\s+(\S.*\S))?/) )))
    {
	no strict 'refs';

	my $procedure = $1;
	my @args      = $3 ? split(/\s+/,$3) : ();
	close(DEC);
	@rc =  &{$procedure}($self,$debug,$loose,$seq,$dir,$debug_prot,$nuc,@args);
    }
    else
    {
#	@rc = &ross_hack($self,$debug,$loose,$seq,$dir,$debug_prot,$nuc);

	open(DEC,"<$dir/decision.procedure.blast");
	$in = <DEC>;
	$in =~ /^(\S+)(\s+(\S.*\S))?/;
	my $procedure = $1;
        my @args      = $3 ? split(/\s+/,$3) : ();
        close(DEC);

	@rc = &blast_vote($self,$debug,$loose,$seq,$dir,$debug_prot,$nuc,@args);
    }
    $/ = $old_eol;
    return @rc;
}

sub min {
    my($x,$y) = @_;

    return ($x <= $y) ? $x : $y;
}

use ProtFamsLite;
sub blast_vote {
    my($self,$debug, $loose, $seq,$dir,$debug_prot,$nuc,$partition,$min_bsc) = @_;
    
    if ($ENV{DEBUG}) { $debug = 1 }
    (-s "$dir/PROTS") || return undef;
    
    my $PFsO = ProtFamsLite->new($self->{root});
    my $fig = $self->{fig};

    if ($debug) { print STDERR "checking: ",$self->family_id," min_bsc=$min_bsc\n" }
    my %prots_in = map { $_ =~ /(\S+)/; $1 => 1 } $self->{fig}->file_read( qq($dir/PROTS), qq(*) );
    
    my $N = &min(10,scalar keys(%prots_in) - ($debug_prot ? 1 : 0));
    my $tmpF = "$FIG_Config::temp/tmp$$.fasta";
    open(TMP,">$tmpF")
	|| die "could not open tmp$$.fasta";
    print TMP ">query\n$seq\n";
    close(TMP);

    my $query_ln = length($seq);
    my $partitionF = "$self->{root}/Partitions/" . ($partition % 1000) . "/$partition/fasta";
    my @tmp;
    if ($nuc){
	#@tmp = `$FIG_Config::ext_bin/blastall -i $tmpF -d $partitionF -m 8 -FF -p blastx -g F`;
	@tmp = `$FIG_Config::ext_bin/blastall -i $tmpF -d $partitionF -m 8 -FF -p blastx -g T`;
	print STDERR "blastall -i $tmpF -d $partitionF -m 8 -FF -p blastx -g T\n" if ($debug);
    }
    else{
	@tmp = `$FIG_Config::ext_bin/blastall -i $tmpF -d $partitionF -m 8 -FF -p blastp`;
    }
    unlink($tmpF);

    my $sims = [];
    my $in = 0;
    my $out = 0;
    my(%seen);
    for (my $simI=0; ($simI < @tmp); $simI++)
    {
	$_ = $tmp[$simI];
	if ($debug) { print STDERR $_ }
	chop;

	my $sim = [split(/\t/,$_)];
	my $prot = $sim->[1];
	#next if ((! -f "$self->{root}/FIG") && ($prot =~ /fig\|/));
	next if ($debug_prot && ($debug_prot eq $prot));
	my $bit_score = $sim->[11];
	my $matched1 = abs($sim->[7] - $sim->[6]) + 1;
	my $matched2 = abs($sim->[9] - $sim->[8]) + 1;
	if ($debug) { print STDERR "normalized bit-score=",sprintf("%3.2f",$bit_score / $matched2),"\n" }
	if (! $seen{$prot})
	{
	    $seen{$prot} = 1;
	    my $count_in = &count_in($self,$PFsO,$fig,\%prots_in,$loose,$prot);
	    my $ln2 = &get_len2($self,$PFsO,$fig,$prot,\%prots_in);

	    if (sprintf("%3.2f",($bit_score / $matched2)) >= $min_bsc)
	    {
		if ($nuc){
		    if ($count_in                             &&                 # (print "in-ok\n") &&
			$ln2                                  &&
			($matched1 >= (0.7 * $query_ln))                         # (print "mat1-ok\n") &&
			)
		    {
			push @$sim, $query_ln, $self->{prot_lengths}->{$prot};
			bless $sim, 'Sim';
			push @$sims, $sim;
			if ($N > 0)
			{
			    $in++;
			}
		    }
		    else
		    {
			if ($N > 0)
			{
			    $out++;
			}
		    }
		    if ($debug) {print STDERR      &Dumper(["in=$in",
							    "out=$out",
							    $count_in,
							    "ln1=$query_ln",
							    "ln2=$ln2",
							    "matched1=$matched1",
							    "matched2=$matched2",
							    "bsc=$bit_score",
							    $ln2 ? sprintf("%3.2f",$bit_score/$matched2) : ""]); }
		    if ($N > 0)
		    {
			$N--;
			last if ($N <= 0);
		    }
		    else
		    {
			last;
		    }
		}
		else{
		    if ($count_in                             &&                 # (print "in-ok\n") &&
			$ln2                                  &&
			($matched1 >= (0.7 * $query_ln))      &&                 # (print "mat1-ok\n") &&
			($matched2 >= (0.7 * $ln2))                              # (print "mat2-ok\n") &&
			)
		    {
			push @$sim, $query_ln, $self->{prot_lengths}->{$prot};
			bless $sim, 'Sim';
			push @$sims, $sim;
			if ($N > 0)
			{
			    $in++;
			}
		    }
		    else
		    {
			if ($N > 0)
			{
			    $out++;
			}
		    }
		    if ($debug) {print STDERR      &Dumper(["in=$in",
							    "out=$out",
							    $count_in,
							    "ln1=$query_ln",
							    "ln2=$ln2",
							    "matched1=$matched1",
							    "matched2=$matched2",
							    "bsc=$bit_score",
							    $ln2 ? sprintf("%3.2f",$bit_score/$matched2) : ""]); }
		    if ($N > 0)
		    {
			$N--;
			last if ($N <= 0);
		    }
		    else
		    {
			last;
		    }
		}
	    }
	    else{
		$out++;
		$N--;
		last if ($N <= 0);
	    }
	}
    }
    if ($debug) { print STDERR "in=$in out=$out, FINAL VOTE\n" }
    return (($in > $out),$sims);
}

sub get_len2 {
    my($self,$PFsO,$fig,$prot,$prots_in) = @_;

    if ($prots_in->{$prot})
    {
	return $self->{prot_lengths}->{$prot};
    }
    elsif ($prot =~ /fig\|\d+/)
    {
	return $fig->translation_length($prot);
    }
    else
    {
	return length($PFsO->seq_of($prot));
    }
}

use Digest::MD5;
sub count_in {
    my($self,$PFsO,$fig,$prots_in,$loose,$prot) = @_;

    if ($prots_in->{$prot}) { return 1 }

    # figure out if it should be count_in by md5 sequence
    my $seq;
    if ($prot =~ /^fig\|/)
    {
	$seq = $fig->get_translation($prot);
    }
    else
    {
	$seq = $PFsO->get_translation($prot);
    }

    my $md5 = Digest::MD5::md5_hex( uc $seq );
    my @proteins_with_md5;
    push (@proteins_with_md5, split (/\n/, $PFsO->proteins_containing_md5($md5)));

    foreach my $md5_prot (@proteins_with_md5)
    {
	if ($prots_in->{$md5_prot}) { return 1 }
    }

    if (! $loose)         { return 0 }
    my $fam_func = $self->family_function;
    $fam_func =~ s/.*: //;
    chomp $fam_func;
    my $prot_func;
    #my $fig = $self->{fig};

    if ($prot =~ /^fig\|/)
    {
	$prot_func = $fig->function_of($prot);
    }
    else
    {
	$prot_func = $PFsO->function_of($prot);
    }

    if ($prot_func)
    {
	$prot_func =~ s/\s*\#.*$//;
	return ($prot_func eq $fam_func);
    }
    return 0;
}

sub ross_hack {
    my($self,$debug,$loose,$seq,$dir,$debug_prot,$nuc,$boundsFile) = @_;

    my $all_bounds;
    if ($boundsFile)
    {
	if    ($boundsFile eq "bounds")     { $all_bounds = $self->{bounds} }
	elsif (-s "$boundsFile")            { $all_bounds = &load_bounds($boundsFile) }
	elsif (-s "$dir/$boundsFile")       { $all_bounds = &load_bounds("$dir/$boundsFile") }
	else                                { $all_bounds = $self->{bounds} }
    }
    else
    {
	$all_bounds = $self->{bounds};
    }

    my $tmpF = "$FIG_Config::temp/tmp$$.fasta";
    open(TMP,">$tmpF")
	|| die "could not open tmp$$.fasta";
    print TMP ">query\n$seq\n";
    close(TMP);

    my $query_ln = length($seq);
    my @tmp;
    if ($nuc){
	@tmp = `blastall -i $tmpF -d $dir/PROTS.fasta -m 8 -FF -p blastx -g T`;
    }
    else{
	@tmp = `blastall -i $tmpF -d $dir/PROTS.fasta -m 8 -FF -p blastp`;
    }

    unlink($tmpF);

    my %seen;
    my $should_be = 0;
    my $yes = 0;
    my $no  = 0;

    my $ln1 = length($seq);
    my $good = 0;
    my $bad = 0;

    my $sims = [];
    my $required_better = ((@{$self->{protsL}} - ($debug_prot ? 1 : 0)) > 1) ? 1 : 0;
#   print STDERR "required_better=$required_better\n";

    for (my $simI=0; ($simI < @tmp) && (! $good) && (! $bad); $simI++)
    {
	$_ = $tmp[$simI];
	if ($debug) { print STDERR $_ }
	chop;

	my $sim = [split(/\t/,$_)];
	my $prot = $sim->[1];
	next if ($debug_prot && ($debug_prot eq $prot));

	my $sc = $sim->[10];
	my $bit_score = $sim->[11];

	my $matched1 = abs($sim->[7] - $sim->[6]) + 1;
	my $matched2 = abs($sim->[9] - $sim->[8]) + 1;
	my $ln2 = $self->{prot_lengths}->{$prot};

	my $bounds;
	if ($nuc) {
	    if ((! $seen{$prot}) &&
		($loose ||
		 (
		  ($matched1 >= (0.7 * $ln1)) )
		 )
		)
	    {
		$seen{$prot} = 1;
		push @$sim, $query_ln, $self->{prot_lengths}->{$prot};
		bless $sim, 'Sim';
		push @$sims, $sim;
		
		$bounds = $all_bounds->{$prot};
		if ($bounds && (@$sims <= 10))
		{
		    if ((($bit_score >= $bounds->[1]) && ((! $bounds->[2]) || $bounds->[3] < $bit_score)) ||
			($loose &&
			 ((($bit_score/$ln1) >= ($bounds->[1] / $ln2)) &&
			  ((! $bounds->[2]) || (($bounds->[3]/$ln2) < ($bit_score/$ln1))))))
		    {
			if ($debug) { print STDERR "    yes - $prot matched1=$matched1 ln1=$ln1 matched2=$matched2 ln2=$ln2\n" }
			++$yes;
			if ($yes > ($no+$required_better)) { $good = 1 }
		    }
		    else
		    {
			if ($debug) { print STDERR "    no - $prot ", join(",",@$bounds),"\n" }
			++$no;
			if ($no > ($yes+$required_better)) { $bad = 1 }
		    }
		}
		else {
		    if ($debug) {
			print STDERR "    bounds=", ($bounds ? qq(non-nil) : qq(nil))
			    , ", num_sims=", (scalar @$sims), "\n";
		    }
		}
	    }
	    else {
		if ($debug) {
		    print STDERR
			"    seen=", ($seen{$prot} ? $seen{$prot} : 0), " score=$sc,"
			, " matched1=$matched1, ln1=$ln1,"
			, " matched2=$matched2, ln2=$ln2,"
			, "\n";
		}
	    }
	}
	else{
	    if ((! $seen{$prot}) &&
		($loose ||
		 (($sc <= 1.0e-10) &&
		  ($matched1 >= (0.7 * $ln1)) &&
		  ($matched2 >= (0.7 * $ln2)))
		 )
		)
	    {
		$seen{$prot} = 1;
		push @$sim, $query_ln, $self->{prot_lengths}->{$prot};
		bless $sim, 'Sim';
		push @$sims, $sim;
		
		$bounds = $all_bounds->{$prot};
		if ($bounds && (@$sims <= 10))
		{
		    if ((($bit_score >= $bounds->[1]) && ((! $bounds->[2]) || $bounds->[3] < $bit_score)) ||
			($loose &&
			 ((($bit_score/$ln1) >= ($bounds->[1] / $ln2)) &&
			  ((! $bounds->[2]) || (($bounds->[3]/$ln2) < ($bit_score/$ln1))))))
		    {
			if ($debug) { print STDERR "    yes - $prot matched1=$matched1 ln1=$ln1 matched2=$matched2 ln2=$ln2\n" }
			++$yes;
			if ($yes > ($no+$required_better)) { $good = 1 }
		    }
		    else
		    {
			if ($debug) { print STDERR "    no - $prot ", join(",",@$bounds),"\n" }
			++$no;
			if ($no > ($yes+$required_better)) { $bad = 1 }
		    }
		}
		else {
		    if ($debug) {
			print STDERR "    bounds=", ($bounds ? qq(non-nil) : qq(nil))
			    , ", num_sims=", (scalar @$sims), "\n";
		    }
		}
	    }
	    else {
		if ($debug) {
		    print STDERR
			"    seen=", ($seen{$prot} ? $seen{$prot} : 0), " score=$sc,"
			, " matched1=$matched1, ln1=$ln1,"
			, " matched2=$matched2, ln2=$ln2,"
			, "\n";
		}
	    }
	}
    }
    if ($yes > $no) { $good = 1 }
    if ($debug) { print STDERR "        yes=$yes no=$no good=$good\n"; }
    return ($good,$sims);
}

=head3 family_function

usage:
    $func = $protfam_obj->family_function();

Returns the "consensus function" assigned to a FIGfam object.

=cut

sub family_function {
    my($self,$full) = @_;
    
    my $fam_id = $self->{id};
    my $func   = $self->{function};
    if (! $full) { $func =~ s/^$fam_id \(not subsystem-based\): // }
    return $func;
}



=head3 family_id

usage:
    $fam_id = $figfam_obj->family_id();

Returns the FIGfam ID of a FIGfam object.

=cut

sub family_id {
    my($self) = @_;

    return $self->{id};
}



=head3 family_dir

usage:

    $dir = &ProtFamLite::family_dir( $ProtFams_Obj, $fam_id );

Returns the path to the subdirectory of C<$ProtFams_Obj>
that the protein Family data for a Family with ID C<$fam_id>
would be stored in.

=cut

sub fam_dir {
    my ($ProtFams_Obj, $fam_id) = @_;
    my $protfam_root = $ProtFams_Obj->{root};
    
    my $group = substr($fam_id, -3) ||
	confess "Could not extract group-number from Family-ID $fam_id";
    $group = (qq(0) x (3-length($group))) . $group;
    
    return qq($protfam_root/FAMS/$group/$fam_id);
}

sub by_fig_id {
    my($a,$b) = @_;
    my($g1,$g2,$t1,$t2,$n1,$n2);
    if (($a =~ /^fig\|(\d+\.\d+).([^\.]+)\.(\d+)$/) && (($g1,$t1,$n1) = ($1,$2,$3)) &&
	($b =~ /^fig\|(\d+\.\d+).([^\.]+)\.(\d+)$/) && (($g2,$t2,$n2) = ($1,$2,$3))) {
        ($g1 <=> $g2) or ($t1 cmp $t2) or ($n1 <=> $n2);
    } else {
        $a cmp $b;
    }
}

sub read_fasta_record {

    shift if UNIVERSAL::isa($_[0],__PACKAGE__);
    my ($file_handle) = @_;
    my ($old_end_of_record, $fasta_record, @lines, $head, $sequence, $seq_id, $comment, @parsed_fasta_record);

    if (not defined($file_handle))  { $file_handle = \*STDIN; }

    $old_end_of_record = $/;
    $/ = "\n>";

    if (defined($fasta_record = <$file_handle>)) {
        chomp $fasta_record;
        @lines  =  split( /\n/, $fasta_record );
        $head   =  shift @lines;
        $head   =~ s/^>?//;
        $head   =~ m/^(\S+)/;
        $seq_id = $1;
        if ($head  =~ m/^\S+\s+(.*)$/)  { $comment = $1; } else { $comment = ""; }
        $sequence  =  join( "", @lines );
        @parsed_fasta_record = ( $seq_id, \$sequence, $comment );
    } else {
        @parsed_fasta_record = ();
    }

    $/ = $old_end_of_record;

    return @parsed_fasta_record;
}

1;
