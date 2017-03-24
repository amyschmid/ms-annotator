use strict;
use Data::Dumper;
use Carp;
use gjoseqlib;

#
# This is a SAS Component
#


=head1 svr_inherit_annotations

Cause a new genome to inherit annotations from an existing
genome for protein-encoding genes that are unique within each
genome and that have identical translations.

------

Example:

    svr_inherit_annotations OldSEEDdir NewSEEDdir User

would alter the contents of the NewSEEDdir.  Each directory may
contain a file called "rewrite.functions".  These are 2-column
tables [function,normalized.function].  We will speak of
"corresponding genes".  These are genes that can unambiguously be
identified in each genome, and they have identical translations.


    1. The assigned functions will be calculated as follows:

       Let Gn be a gene in the new genome.  The rewrite.functions in the
       new directory will be a superset of the rewrite.functions in the old directory.

       Let Fn be the initial function of Gn (the value in the
       assigned_functions file).  If the rewrite.functions specifies a
       rewrite to Fn' for Fn, then Fn' is the value placed into the
       assigned_functions file (and an annotation indicating the change
       is recorded).  If there is no rewrite rule in the old
       rewrite.functions, and there is a corresponding gene in the old
       directory with function Fo and Fo is not Fn, then Fo is the
       value placed in the new assigned_functions, and

           a. Fn -> Fo becomes a rewrite in the new rewrite.functions,

           b. an annotation is added designating the change (at the current time).

       Otherwise, Fn is retained.

    2. The annotations in the new directory become a merge of the annotations
       in the old and new directories.

------

=head2 Command-Line Options

=over 4

=item oldSEEDdir

This is a path to the old SEED directory from which assignments and annotations
are inherited

=item newSEEDdir

This is a path to the new SEED directory which inherits assignments and annotations.

-item User

This is the user credited with making the changes to the functions 

=back

=cut

my $usage = "usage: svr_inherit_annotations oldSEEDdir newSEEDdir User";

my($oldD,$newD,$user);

(($oldD = shift @ARGV) && (-d $oldD)) || die "$usage";
(($newD = shift @ARGV) && (-d $newD)) || die "$usage";
($user  = shift @ARGV) || die "you need to give a User: $usage";

if (-s "$newD/rewrite.functions")
{
    die "$newD/rewrite.functions already exists; delete it and rerun, if it is ok to do so";
}
if (-s "$oldD/rewrite.functions")
{
    &run("cp $oldD/rewrite.functions $newD/rewrite.functions");
}

my $rewrite = &load_rewrite("$newD/rewrite.rules");

&verify_exists("$oldD/Features/peg/fasta");
&verify_exists("$newD/Features/peg/fasta");
my $corrH = &get_correspondence("$oldD/Features/peg/fasta","$newD/Features/peg/fasta");
&update_functions($oldD,$newD,$corrH,$rewrite,$user);
&update_annotations($oldD,$newD);

sub update_functions {
    my($oldD,$newD,$corrH,$rewrite,$user) = @_;

    my $funcsN = &load_funcs("$newD/assigned_functions");
    my $funcsO = &load_funcs("$oldD/assigned_functions");
    foreach my $pegN (keys(%$funcsN))
    {
	my($pegO,$fO,$fn,$fn1);
	$fn = $funcsN->{$pegN};
	if ($fn1 = $rewrite->{$fn})
	{
	    $funcsN->{$pegN} = $fn1;
	    &assign_function($newD,$pegN,$fn1,$user);
	}
	elsif (($pegO = $corrH->{$pegN}) && ($fO = $funcsO->{$pegO}) && ($fO ne $fn))
	{
	    $rewrite->{$fn} = $fO;
	    &assign_function($newD,$pegN,$fO,$user);
	}
    }
}

sub load_funcs {
    my($assignF) = @_;

    my $assignments = {};

    if (open(ASSF,"<$assignF"))
    {
	while (defined($_ = <ASSF>))
	{
	    if ($_ =~ /^(\S+)\t(\S[^\t]+\S)/)
	    {
		$assignments->{$1} = $2;
	    }
	}
	close(ASSF);
    }
    else
    {
	print STDERR "No existing assigned_functions in $assignF\n";
    }
    return $assignments;
}

sub update_annotations {
    my($oldD,$newD) = @_;

    my $anno = {};
    &load_annotations($oldD,$anno);
    &load_annotations($newD,$anno);

    if (-s "$newD/annotations") { rename("$newD/annotations","$newD/annotations~") }
    open(ANNO,">$newD/annotations") || die "could not open $newD/annotations";
    foreach my $ts (sort { $b <=> $a } keys(%$anno))
    {
	my($peg,$user,$anno) = @{$anno->{$ts}};
	print ANNO join("\n",($peg,$ts,$user,$anno)),"\n//\n";
    }
    close(ANNO);
}

sub load_annotations {
    my($dir,$anno) = @_;

    if (open(ANNO,"<$dir/annotations"))
    {
	$/ = "\n//\n";
	while (defined(my $_ = <ANNO>))
	{
	    chomp;
	    my @lines = split(/\n/,$_);
	    my($peg,$ts,$user,@rest) = @lines;
	    $anno->{$ts} = [$peg,$user,join("\n",@rest)];
	}
	close(ANNO);
    }
}

sub load_rewrite {
    my($file) = @_;

    my $rewrite = {};
    if (open(REWRITES,"<$file"))
    {
	while (defined($_ = <REWRITES>))
	{
	    if ($_ =~ /^(\S[^\t]+\S)\t(\S[^\t+]\S)$/)
	    {
		$rewrite->{$1} = $2;
	    }
	}
	close(REWRITES);
    }
    return $rewrite;
}

sub get_correspondence {
    my($oldF,$newF) = @_;

    my %old;
    my @old = &gjoseqlib::read_fasta($oldF);
    foreach $_ (@old)
    {
	push @ { $old{$_->[2]} }, $_->[0];
    }
    
    my %new;
    my @new = &gjoseqlib::read_fasta($newF);
    foreach $_ (@new)
    {
	push @ { $new{$_->[2]} }, $_->[0];
    }
    
    my $corrH = {};
    foreach my $seqN (keys(%new))
    {
	if ((@ { $old{$seqN} } == 1) && (@ { $new{$seqN} } == 1))
	{
	    $corrH->{$new{$seqN}->[0]} = $old{$seqN}->[0];
	}
    }
    return $corrH;
}

sub verify_exists {
    my($file) = @_;

    if (! -s $file)
    {
	die "$file either does not exist or is empty";
    }
}

sub run {
    my($cmd) = @_;

    my $rc = system($cmd);
    if ($rc)
    {
	die "$rc: $cmd failed";
    }
}
