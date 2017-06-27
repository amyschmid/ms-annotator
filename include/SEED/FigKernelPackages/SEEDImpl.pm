package SEEDImpl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

=head1 NAME

SEED

=head1 DESCRIPTION



=cut

#BEGIN_HEADER
use IPC::Run qw(run);
use PinnedRegions;
use FIG;
use Data::Dumper;
use WebColors;
use URI::Escape;
#END_HEADER

sub new
{
    my($class, @args) = @_;
    my $self = {
    };
    bless $self, $class;
    #BEGIN_CONSTRUCTOR

    $self->{fig} = FIG->new;

    #END_CONSTRUCTOR

    if ($self->can('_init_instance'))
    {
	$self->_init_instance();
    }
    return $self;
}

=head1 METHODS



=head2 compare_regions

  $return = $obj->compare_regions($opts)

=over 4

=item Parameter and return types

=begin html

<pre>
$opts is a compare_options
$return is a compared_regions
compare_options is a reference to a hash where the following keys are defined:
	pin has a value which is a reference to a list where each element is a string
	n_genomes has a value which is an int
	width has a value which is an int
	pin_alignment has a value which is a string
	pin_compute_method has a value which is a string
	sim_cutoff has a value which is a float
	limit_to_genomes has a value which is a reference to a list where each element is a string
	close_genome_collapse has a value which is a string
	coloring_method has a value which is a string
	color_sim_cutoff has a value which is a float
	genome_sort_method has a value which is a string
	features_for_cdd has a value which is a reference to a list where each element is a string
compared_regions is a reference to a list where each element is a genome_compare_info
genome_compare_info is a reference to a hash where the following keys are defined:
	beg has a value which is an int
	end has a value which is an int
	mid has a value which is an int
	org_name has a value which is a string
	pinned_peg_strand has a value which is a string
	genome_id has a value which is a string
	pinned_peg has a value which is a string
	features has a value which is a reference to a list where each element is a feature_compare_info
feature_compare_info is a reference to a hash where the following keys are defined:
	fid has a value which is a string
	beg has a value which is an int
	end has a value which is an int
	size has a value which is an int
	strand has a value which is a string
	contig has a value which is a string
	location has a value which is a string
	function has a value which is a string
	type has a value which is a string
	set_number has a value which is an int
	offset_beg has a value which is an int
	offset_end has a value which is an int
	offset has a value which is an int
	attributes has a value which is a reference to a list where each element is a reference to a list containing 2 items:
	0: (key) a string
	1: (value) a string


</pre>

=end html

=begin text

$opts is a compare_options
$return is a compared_regions
compare_options is a reference to a hash where the following keys are defined:
	pin has a value which is a reference to a list where each element is a string
	n_genomes has a value which is an int
	width has a value which is an int
	pin_alignment has a value which is a string
	pin_compute_method has a value which is a string
	sim_cutoff has a value which is a float
	limit_to_genomes has a value which is a reference to a list where each element is a string
	close_genome_collapse has a value which is a string
	coloring_method has a value which is a string
	color_sim_cutoff has a value which is a float
	genome_sort_method has a value which is a string
	features_for_cdd has a value which is a reference to a list where each element is a string
compared_regions is a reference to a list where each element is a genome_compare_info
genome_compare_info is a reference to a hash where the following keys are defined:
	beg has a value which is an int
	end has a value which is an int
	mid has a value which is an int
	org_name has a value which is a string
	pinned_peg_strand has a value which is a string
	genome_id has a value which is a string
	pinned_peg has a value which is a string
	features has a value which is a reference to a list where each element is a feature_compare_info
feature_compare_info is a reference to a hash where the following keys are defined:
	fid has a value which is a string
	beg has a value which is an int
	end has a value which is an int
	size has a value which is an int
	strand has a value which is a string
	contig has a value which is a string
	location has a value which is a string
	function has a value which is a string
	type has a value which is a string
	set_number has a value which is an int
	offset_beg has a value which is an int
	offset_end has a value which is an int
	offset has a value which is an int
	attributes has a value which is a reference to a list where each element is a reference to a list containing 2 items:
	0: (key) a string
	1: (value) a string



=end text



=item Description



=back

=cut

sub compare_regions
{
    my $self = shift;
    my($opts) = @_;

    my @_bad_arguments;
    (ref($opts) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"opts\" (value was \"$opts\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to compare_regions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'compare_regions');
    }

    my $ctx = $SEEDServer::CallContext;
    my($return);
    #BEGIN compare_regions

    $opts->{limit_to_genomes} ||= [];

    my %collapse_map = (all => 0,
			close => 1,
			iden => 2);

    my $collapse = $collapse_map{$opts->{close_genome_collapse}};
    $collapse = 0 unless defined($collapse);

    my $width = $opts->{width} || 16000;
    my $n_genomes = $opts->{n_genomes} || 15;

    my $pin_desc = {
	pegs                   => $opts->{pin},
	collapse_close_genomes => $collapse,
	pin_alignment          => $opts->{pin_alignment} // 'stop',
	n_pch_pins             => 0,
	n_sims                 => 0,
	n_kmers 	       => 0,
	show_genomes           => $opts->{limit_to_genomes},
	sim_cutoff             => $opts->{sim_cutoff} // 1e-5,
	color_sim_cutoff       => $opts->{color_sim_cutoff} // 1e-5,
	sort_by                => 'similarity',
    };

    my $color_by_function = $opts->{coloring_method} eq 'function' ? 1 : 0;

    if ($opts->{pin_compute_method} eq 'sim')
    {
	$pin_desc->{n_sims} = $opts->{n_genomes};
    }
    elsif ($opts->{pin_compute_method} eq 'kmer')
    {
	$pin_desc->{n_kmers} = $opts->{n_genomes};
    }
    else
    {
	$pin_desc->{n_sims} = $opts->{n_genomes};
    }

    my $cdd_fids = ref($opts->{features_for_cdd}) eq 'ARRAY' ? $opts->{features_for_cdd} : [];

    print STDERR Dumper($pin_desc, $width, $cdd_fids);
    $return = PinnedRegions::pinned_regions($self->{fig}, $pin_desc, 1, 'blast', $width,
					    undef, 0, $color_by_function, undef, $cdd_fids);

    #END compare_regions
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to compare_regions:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'compare_regions');
    }
    return($return);
}




=head2 compare_regions_for_peg

  $return = $obj->compare_regions_for_peg($peg, $width, $n_genomes, $coloring_method)

=over 4

=item Parameter and return types

=begin html

<pre>
$peg is a string
$width is an int
$n_genomes is an int
$coloring_method is a string
$return is a compared_regions
compared_regions is a reference to a list where each element is a genome_compare_info
genome_compare_info is a reference to a hash where the following keys are defined:
	beg has a value which is an int
	end has a value which is an int
	mid has a value which is an int
	org_name has a value which is a string
	pinned_peg_strand has a value which is a string
	genome_id has a value which is a string
	pinned_peg has a value which is a string
	features has a value which is a reference to a list where each element is a feature_compare_info
feature_compare_info is a reference to a hash where the following keys are defined:
	fid has a value which is a string
	beg has a value which is an int
	end has a value which is an int
	size has a value which is an int
	strand has a value which is a string
	contig has a value which is a string
	location has a value which is a string
	function has a value which is a string
	type has a value which is a string
	set_number has a value which is an int
	offset_beg has a value which is an int
	offset_end has a value which is an int
	offset has a value which is an int
	attributes has a value which is a reference to a list where each element is a reference to a list containing 2 items:
	0: (key) a string
	1: (value) a string


</pre>

=end html

=begin text

$peg is a string
$width is an int
$n_genomes is an int
$coloring_method is a string
$return is a compared_regions
compared_regions is a reference to a list where each element is a genome_compare_info
genome_compare_info is a reference to a hash where the following keys are defined:
	beg has a value which is an int
	end has a value which is an int
	mid has a value which is an int
	org_name has a value which is a string
	pinned_peg_strand has a value which is a string
	genome_id has a value which is a string
	pinned_peg has a value which is a string
	features has a value which is a reference to a list where each element is a feature_compare_info
feature_compare_info is a reference to a hash where the following keys are defined:
	fid has a value which is a string
	beg has a value which is an int
	end has a value which is an int
	size has a value which is an int
	strand has a value which is a string
	contig has a value which is a string
	location has a value which is a string
	function has a value which is a string
	type has a value which is a string
	set_number has a value which is an int
	offset_beg has a value which is an int
	offset_end has a value which is an int
	offset has a value which is an int
	attributes has a value which is a reference to a list where each element is a reference to a list containing 2 items:
	0: (key) a string
	1: (value) a string



=end text



=item Description



=back

=cut

sub compare_regions_for_peg
{
    my $self = shift;
    my($peg, $width, $n_genomes, $coloring_method) = @_;

    my @_bad_arguments;
    (!ref($peg)) or push(@_bad_arguments, "Invalid type for argument \"peg\" (value was \"$peg\")");
    (!ref($width)) or push(@_bad_arguments, "Invalid type for argument \"width\" (value was \"$width\")");
    (!ref($n_genomes)) or push(@_bad_arguments, "Invalid type for argument \"n_genomes\" (value was \"$n_genomes\")");
    (!ref($coloring_method)) or push(@_bad_arguments, "Invalid type for argument \"coloring_method\" (value was \"$coloring_method\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to compare_regions_for_peg:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'compare_regions_for_peg');
    }

    my $ctx = $SEEDServer::CallContext;
    my($return);
    #BEGIN compare_regions_for_peg

    my $pin_desc = {
	             'pegs'                   => [$peg],
		     'collapse_close_genomes' => 0,
		     'n_pch_pins'             => 0,
		     'n_sims'                 => $n_genomes,
		     'show_genomes'           => [],
		     'sim_cutoff'             => 1e-5,
		     'color_sim_cutoff'       => 1e-5,
		     'sort_by'                => 'similarity',
		   };

    my $color_by_function = 0;
    if ($coloring_method eq 'function')
    {
	$color_by_function = 1;
    }
    print STDERR "Colorign method $coloring_method, by_fun=$color_by_function\n";
    $return = PinnedRegions::pinned_regions($self->{fig}, $pin_desc, 1, 'blast', $width,
					    undef, 0, $color_by_function);

    #END compare_regions_for_peg
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to compare_regions_for_peg:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'compare_regions_for_peg');
    }
    return($return);
}




=head2 get_ncbi_cdd_url

  $url = $obj->get_ncbi_cdd_url($feature)

=over 4

=item Parameter and return types

=begin html

<pre>
$feature is a string
$url is a string

</pre>

=end html

=begin text

$feature is a string
$url is a string


=end text



=item Description



=back

=cut

sub get_ncbi_cdd_url
{
    my $self = shift;
    my($feature) = @_;

    my @_bad_arguments;
    (!ref($feature)) or push(@_bad_arguments, "Invalid type for argument \"feature\" (value was \"$feature\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_ncbi_cdd_url:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_ncbi_cdd_url');
    }

    my $ctx = $SEEDServer::CallContext;
    my($url);
    #BEGIN get_ncbi_cdd_url
    my $protein = $self->{fig}->get_translation($feature);
    my $plink = uri_escape(">$feature\n$protein");
    $url = "http://www.ncbi.nlm.nih.gov/Structure/cdd/wrpsb.cgi?SEQUENCE=$plink&FULL";
    #END get_ncbi_cdd_url
    my @_bad_returns;
    (!ref($url)) or push(@_bad_returns, "Invalid type for return variable \"url\" (value was \"$url\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_ncbi_cdd_url:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_ncbi_cdd_url');
    }
    return($url);
}




=head2 compute_cdd_for_row

  $cdds = $obj->compute_cdd_for_row($pegs)

=over 4

=item Parameter and return types

=begin html

<pre>
$pegs is a genome_compare_info
$cdds is a reference to a list where each element is a feature_compare_info
genome_compare_info is a reference to a hash where the following keys are defined:
	beg has a value which is an int
	end has a value which is an int
	mid has a value which is an int
	org_name has a value which is a string
	pinned_peg_strand has a value which is a string
	genome_id has a value which is a string
	pinned_peg has a value which is a string
	features has a value which is a reference to a list where each element is a feature_compare_info
feature_compare_info is a reference to a hash where the following keys are defined:
	fid has a value which is a string
	beg has a value which is an int
	end has a value which is an int
	size has a value which is an int
	strand has a value which is a string
	contig has a value which is a string
	location has a value which is a string
	function has a value which is a string
	type has a value which is a string
	set_number has a value which is an int
	offset_beg has a value which is an int
	offset_end has a value which is an int
	offset has a value which is an int
	attributes has a value which is a reference to a list where each element is a reference to a list containing 2 items:
	0: (key) a string
	1: (value) a string


</pre>

=end html

=begin text

$pegs is a genome_compare_info
$cdds is a reference to a list where each element is a feature_compare_info
genome_compare_info is a reference to a hash where the following keys are defined:
	beg has a value which is an int
	end has a value which is an int
	mid has a value which is an int
	org_name has a value which is a string
	pinned_peg_strand has a value which is a string
	genome_id has a value which is a string
	pinned_peg has a value which is a string
	features has a value which is a reference to a list where each element is a feature_compare_info
feature_compare_info is a reference to a hash where the following keys are defined:
	fid has a value which is a string
	beg has a value which is an int
	end has a value which is an int
	size has a value which is an int
	strand has a value which is a string
	contig has a value which is a string
	location has a value which is a string
	function has a value which is a string
	type has a value which is a string
	set_number has a value which is an int
	offset_beg has a value which is an int
	offset_end has a value which is an int
	offset has a value which is an int
	attributes has a value which is a reference to a list where each element is a reference to a list containing 2 items:
	0: (key) a string
	1: (value) a string



=end text



=item Description



=back

=cut

sub compute_cdd_for_row
{
    my $self = shift;
    my($pegs) = @_;

    my @_bad_arguments;
    (ref($pegs) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"pegs\" (value was \"$pegs\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to compute_cdd_for_row:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'compute_cdd_for_row');
    }

    my $ctx = $SEEDServer::CallContext;
    my($cdds);
    #BEGIN compute_cdd_for_row

    #
    # For each peg in the row, compute CDD hits and create new features to return as a new row.
    # We translate the protein positions from the hits back into contig coordinates.
    #
    
    my $prots = "";
    my %fmap;

    for my $feature (@{$pegs->{features}})
    {
	my $trans = $self->{fig}->get_translation($feature->{fid});
	next unless $trans;
	$prots .= ">$feature->{fid}\n$trans\n";
	$fmap{$feature->{fid}} = $feature;
    }
    my $res;
    my $ok = run ["svr_cdd_scan"], '<', \$prots, '>', \$res;

    my $new_feats = [];
    my $pinned_cdd;
    my $pinned_cdd_strand;
    #
    # Do a first pass to coalesce on start/stop.
    #
    my %hits;
    for my $row (split(/\n/, $res))
    {
	my($fid, undef, undef, $type, $pssm, $from, $to, $evalue, $bitscore, $acc, $domain, $shortname, $incomplete, $superfam) = split(/\t/, $row);

	push(@{$hits{$fid}->{$from, $to}}, $row);
    }

    # print Dumper(\%hits);
    for my $feature (@{$pegs->{features}})
    {
	my $fid = $feature->{fid};

	for my $set (values %{$hits{$fid}})
	{
	    my @hits = @$set;
	    next unless @hits;
	    
	    my($fid, undef, undef, $type, $pssm, $from, $to, $evalue, $bitscore, $acc, $domain, $shortname, $incomplete, $superfam) = split(/\t/, $hits[0]);

	    print Dumper(SET => $fid, \@hits);

	    my $dbeg = ($from - 1) * 3;
	    my $dend = ($to - 1) * 3;
	    
	    if ($feature->{strand} eq '-')
	    {
		$dbeg = $feature->{beg} - $dbeg;
		$dend = $feature->{beg} - $dend;
	    }
	    else
	    {
		$dbeg += $feature->{beg};
		$dend += $feature->{beg};
	    }
	    
	    my $loc = join("_", $feature->{contig}, $dbeg, $dend);
	    
	    my $ident;
	    my @acc;
	    for my $hit (@hits)
	    {
		my($fid, undef, undef, $type, $pssm, $from, $to, $evalue, $bitscore, $acc, $domain, $shortname, $incomplete, $superfam) = split(/\t/, $hit);
		push(@acc, $acc);
	    }
	    print Dumper(\@hits, \@acc);
	    $ident = join(",", @acc);
	    
	    if (!defined($pinned_cdd) && $fid eq $pegs->{pinned_peg})
	    {
		$pinned_cdd = $ident;
		$pinned_cdd_strand = $feature->{strand};
	    }
	    
	    my $cdd = {
		fid => $ident,
		beg => $dbeg,
		end => $dend,
		size => (3 * ($to - $from + 1)),
		strand => $feature->{strand},
		contig => $feature->{contig},
		location => $loc,
		type => 'domain',
		set_number => 1,
	    };
	    
	    push(@$new_feats, $cdd);
	}
    }
    # %$cdds = %$pegs;
    # $cdds->{features} = $new_feats;
    # $cdds->{pinned_peg} = $pinned_cdd;
    # $cdds->{pinned_peg_strand} = $pinned_cdd_strand;
    $cdds = $new_feats;
    print Dumper($cdds);
    #END compute_cdd_for_row
    my @_bad_returns;
    (ref($cdds) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"cdds\" (value was \"$cdds\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to compute_cdd_for_row:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'compute_cdd_for_row');
    }
    return($cdds);
}




=head2 compute_cdd_for_feature

  $cdds = $obj->compute_cdd_for_feature($feature)

=over 4

=item Parameter and return types

=begin html

<pre>
$feature is a feature_compare_info
$cdds is a reference to a list where each element is a feature_compare_info
feature_compare_info is a reference to a hash where the following keys are defined:
	fid has a value which is a string
	beg has a value which is an int
	end has a value which is an int
	size has a value which is an int
	strand has a value which is a string
	contig has a value which is a string
	location has a value which is a string
	function has a value which is a string
	type has a value which is a string
	set_number has a value which is an int
	offset_beg has a value which is an int
	offset_end has a value which is an int
	offset has a value which is an int
	attributes has a value which is a reference to a list where each element is a reference to a list containing 2 items:
	0: (key) a string
	1: (value) a string


</pre>

=end html

=begin text

$feature is a feature_compare_info
$cdds is a reference to a list where each element is a feature_compare_info
feature_compare_info is a reference to a hash where the following keys are defined:
	fid has a value which is a string
	beg has a value which is an int
	end has a value which is an int
	size has a value which is an int
	strand has a value which is a string
	contig has a value which is a string
	location has a value which is a string
	function has a value which is a string
	type has a value which is a string
	set_number has a value which is an int
	offset_beg has a value which is an int
	offset_end has a value which is an int
	offset has a value which is an int
	attributes has a value which is a reference to a list where each element is a reference to a list containing 2 items:
	0: (key) a string
	1: (value) a string



=end text



=item Description



=back

=cut

sub compute_cdd_for_feature
{
    my $self = shift;
    my($feature) = @_;

    my @_bad_arguments;
    (ref($feature) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"feature\" (value was \"$feature\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to compute_cdd_for_feature:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'compute_cdd_for_feature');
    }

    my $ctx = $SEEDServer::CallContext;
    my($cdds);
    #BEGIN compute_cdd_for_feature

    #
    # For each peg in the row, compute CDD hits and create new features to return as a new row.
    # We translate the protein positions from the hits back into contig coordinates.
    #
    
    my $trans = $self->{fig}->get_translation($feature->{fid});

    $cdds = [];

    if ($trans)
    {
	my $prots = ">$feature->{fid}\n$trans\n";
	
	my $res;
	my $ok = run ["svr_cdd_scan"], '<', \$prots, '>', \$res;

	print STDERR $res;

	my %hits;

	my @hits = map { chomp; [split(/\t/)] } split(/\n/, $res);
	my %hits_by_type;

	push(@{$hits_by_type{$_->[3]}}, $_) foreach @hits;
	print Dumper(\%hits_by_type);

	for my $type (keys %hits_by_type)
	{
	    my @hits = sort { $a->[7] <=> $b->[7] } @{$hits_by_type{$type}};
	    
	    next unless @hits;

	    my($fid, undef, undef, $type, $pssm, $from, $to, $evalue, $bitscore, $acc, $domain, $incomplete, $superfam) = @{$hits[0]};

	    my $dbeg = ($from - 1) * 3;
	    my $dend = ($to - 1) * 3;
#	    my $dbeg = $from;
#	    my $dend = $to;
	    
	    if ($feature->{strand} eq '-')
	    {
		$dbeg = $feature->{beg} - $dbeg;
		$dend = $feature->{beg} - $dend;
	    }
	    else
	    {
		$dbeg += $feature->{beg};
		$dend += $feature->{beg};
	    }
	    
	    my $loc = join("_", $feature->{contig}, $dbeg, $dend);

	    my $attrs = [[evalue => $evalue],
			 [bitscore => $bitscore],
			 [type => $type]];
	    push(@$attrs, [incomplete_start => 1]) if ($incomplete =~ /N/);
	    push(@$attrs, [incomplete_stop => 1]) if ($incomplete =~ /C/);

	    my $cdd = {
		fid => $acc,
		beg => $dbeg,
		end => $dend,
		size => (3 * ($to - $from + 1)),
		strand => $feature->{strand},
		contig => $feature->{contig},
		location => $loc,
		type => 'domain',
		set_number => 1,
		attributes => $attrs,
	    };
	    
	    push(@$cdds, $cdd);
	}
    }
    print Dumper($cdds);

    #END compute_cdd_for_feature
    my @_bad_returns;
    (ref($cdds) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"cdds\" (value was \"$cdds\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to compute_cdd_for_feature:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'compute_cdd_for_feature');
    }
    return($cdds);
}




=head2 get_palette

  $colors = $obj->get_palette($palette_name)

=over 4

=item Parameter and return types

=begin html

<pre>
$palette_name is a string
$colors is a reference to a list where each element is a reference to a list containing 3 items:
	0: (r) an int
	1: (g) an int
	2: (b) an int

</pre>

=end html

=begin text

$palette_name is a string
$colors is a reference to a list where each element is a reference to a list containing 3 items:
	0: (r) an int
	1: (g) an int
	2: (b) an int


=end text



=item Description



=back

=cut

sub get_palette
{
    my $self = shift;
    my($palette_name) = @_;

    my @_bad_arguments;
    (!ref($palette_name)) or push(@_bad_arguments, "Invalid type for argument \"palette_name\" (value was \"$palette_name\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_palette:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_palette');
    }

    my $ctx = $SEEDServer::CallContext;
    my($colors);
    #BEGIN get_palette

    if ($palette_name eq 'compare_region')
    {
	$colors = [@{WebColors::get_palette('special')}, @{WebColors::get_palette('many')}];
	splice(@$colors, 0, 3);
    }
    else
    {
	$colors = WebColors::get_palette($palette_name);
	$colors = [] unless $colors;
    }

    #END get_palette
    my @_bad_returns;
    (ref($colors) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"colors\" (value was \"$colors\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_palette:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_palette');
    }
    return($colors);
}




=head2 get_function

  $functions = $obj->get_function($fids)

=over 4

=item Parameter and return types

=begin html

<pre>
$fids is a reference to a list where each element is a feature_id
$functions is a reference to a hash where the key is a feature_id and the value is a string
feature_id is a string

</pre>

=end html

=begin text

$fids is a reference to a list where each element is a feature_id
$functions is a reference to a hash where the key is a feature_id and the value is a string
feature_id is a string


=end text



=item Description



=back

=cut

sub get_function
{
    my $self = shift;
    my($fids) = @_;

    my @_bad_arguments;
    (ref($fids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"fids\" (value was \"$fids\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_function:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_function');
    }

    my $ctx = $SEEDServer::CallContext;
    my($functions);
    #BEGIN get_function

    $functions = $self->{fig}->function_of_bulk($fids);

    #END get_function
    my @_bad_returns;
    (ref($functions) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"functions\" (value was \"$functions\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_function:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_function');
    }
    return($functions);
}




=head2 assign_function

  $result = $obj->assign_function($functions, $user, $token)

=over 4

=item Parameter and return types

=begin html

<pre>
$functions is a reference to a hash where the key is a feature_id and the value is a string
$user is a string
$token is a string
$result is a reference to a hash where the key is a feature_id and the value is an assignment_result
feature_id is a string
assignment_result is a reference to a hash where the following keys are defined:
	success has a value which is an int
	text has a value which is a string

</pre>

=end html

=begin text

$functions is a reference to a hash where the key is a feature_id and the value is a string
$user is a string
$token is a string
$result is a reference to a hash where the key is a feature_id and the value is an assignment_result
feature_id is a string
assignment_result is a reference to a hash where the following keys are defined:
	success has a value which is an int
	text has a value which is a string


=end text



=item Description



=back

=cut

sub assign_function
{
    my $self = shift;
    my($functions, $user, $token) = @_;

    my @_bad_arguments;
    (ref($functions) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"functions\" (value was \"$functions\")");
    (!ref($user)) or push(@_bad_arguments, "Invalid type for argument \"user\" (value was \"$user\")");
    (!ref($token)) or push(@_bad_arguments, "Invalid type for argument \"token\" (value was \"$token\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to assign_function:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'assign_function');
    }

    my $ctx = $SEEDServer::CallContext;
    my($result);
    #BEGIN assign_function

    #
    # Validate token. It must be configured in $FIG_Config::allowed_api_users.
    # If it's there, we assuming the caller has vetted the appropriate permissions
    # for the given user and the given seed.
    #

    if (!$FIG_Config::allowed_api_users{$token})
    {
	die "Invalid user token provided";
    }

    $result = {};
    for my $fid (sort { &FIG::by_fig_id($a, $b) } keys %$functions)
    {
	my $func = $functions->{$fid};
	my @res = $self->{fig}->assign_function($fid, $user, $func,
						{ annotation => "Via remote api from " . $ctx->client_ip,
						  return_value => 'all_lists' });
	my($changed, $failed, $moot) = @res;
	my $str = join("\n",
		       "Changed fids: " . join(" ", ref($changed) ? @$changed : ''),
		       "Failed fids: " . join(" ", ref($failed) ? @$failed : ''),
		       "Moot fids: " . join(" ", ref($moot) ? @$moot : ''));

	$result->{$fid} = { success => (ref($changed) ? scalar(@$changed) : 0),
				text => $str };
    }

    
    #END assign_function
    my @_bad_returns;
    (ref($result) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"result\" (value was \"$result\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to assign_function:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'assign_function');
    }
    return($result);
}




=head2 get_location

  $locations = $obj->get_location($fids)

=over 4

=item Parameter and return types

=begin html

<pre>
$fids is a reference to a list where each element is a feature_id
$locations is a reference to a hash where the key is a feature_id and the value is a location
feature_id is a string
location is a string

</pre>

=end html

=begin text

$fids is a reference to a list where each element is a feature_id
$locations is a reference to a hash where the key is a feature_id and the value is a location
feature_id is a string
location is a string


=end text



=item Description



=back

=cut

sub get_location
{
    my $self = shift;
    my($fids) = @_;

    my @_bad_arguments;
    (ref($fids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"fids\" (value was \"$fids\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_location:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_location');
    }

    my $ctx = $SEEDServer::CallContext;
    my($locations);
    #BEGIN get_location

    my @list = $self->{fig}->feature_location_bulk($fids);
    $locations->{$_->[0]} = $_->[1] foreach @list;

    #END get_location
    my @_bad_returns;
    (ref($locations) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"locations\" (value was \"$locations\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_location:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_location');
    }
    return($locations);
}




=head2 get_translation

  $translations = $obj->get_translation($fids)

=over 4

=item Parameter and return types

=begin html

<pre>
$fids is a reference to a list where each element is a feature_id
$translations is a reference to a hash where the key is a feature_id and the value is a translation
feature_id is a string
translation is a string

</pre>

=end html

=begin text

$fids is a reference to a list where each element is a feature_id
$translations is a reference to a hash where the key is a feature_id and the value is a translation
feature_id is a string
translation is a string


=end text



=item Description



=back

=cut

sub get_translation
{
    my $self = shift;
    my($fids) = @_;

    my @_bad_arguments;
    (ref($fids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"fids\" (value was \"$fids\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_translation:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_translation');
    }

    my $ctx = $SEEDServer::CallContext;
    my($translations);
    #BEGIN get_translation

    for my $fid (@$fids)
    {
	$translations->{$fid} = $self->{fig}->get_translation($fid);
    }

    #END get_translation
    my @_bad_returns;
    (ref($translations) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"translations\" (value was \"$translations\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_translation:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_translation');
    }
    return($translations);
}




=head2 is_real_feature

  $results = $obj->is_real_feature($fids)

=over 4

=item Parameter and return types

=begin html

<pre>
$fids is a reference to a list where each element is a feature_id
$results is a reference to a hash where the key is a feature_id and the value is an int
feature_id is a string

</pre>

=end html

=begin text

$fids is a reference to a list where each element is a feature_id
$results is a reference to a hash where the key is a feature_id and the value is an int
feature_id is a string


=end text



=item Description



=back

=cut

sub is_real_feature
{
    my $self = shift;
    my($fids) = @_;

    my @_bad_arguments;
    (ref($fids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"fids\" (value was \"$fids\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to is_real_feature:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'is_real_feature');
    }

    my $ctx = $SEEDServer::CallContext;
    my($results);
    #BEGIN is_real_feature

    for my $fid (@$fids)
    {
	$results->{$fid} = $self->{fig}->is_real_feature($fid);
    }

    #END is_real_feature
    my @_bad_returns;
    (ref($results) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"results\" (value was \"$results\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to is_real_feature:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'is_real_feature');
    }
    return($results);
}




=head2 get_genome_features

  $features = $obj->get_genome_features($genomes, $type)

=over 4

=item Parameter and return types

=begin html

<pre>
$genomes is a reference to a list where each element is a genome_id
$type is a string
$features is a reference to a hash where the key is a genome_id and the value is a reference to a list where each element is a feature_id
genome_id is a string
feature_id is a string

</pre>

=end html

=begin text

$genomes is a reference to a list where each element is a genome_id
$type is a string
$features is a reference to a hash where the key is a genome_id and the value is a reference to a list where each element is a feature_id
genome_id is a string
feature_id is a string


=end text



=item Description



=back

=cut

sub get_genome_features
{
    my $self = shift;
    my($genomes, $type) = @_;

    my @_bad_arguments;
    (ref($genomes) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"genomes\" (value was \"$genomes\")");
    (!ref($type)) or push(@_bad_arguments, "Invalid type for argument \"type\" (value was \"$type\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_genome_features:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_genome_features');
    }

    my $ctx = $SEEDServer::CallContext;
    my($features);
    #BEGIN get_genome_features

    undef $type if $type eq '';
    for my $g (@$genomes)
    {
	my @list = $self->{fig}->all_features($g, $type);
	$features->{$g} = \@list;
    }

    #END get_genome_features
    my @_bad_returns;
    (ref($features) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"features\" (value was \"$features\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_genome_features:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_genome_features');
    }
    return($features);
}




=head2 get_genomes

  $genomes = $obj->get_genomes()

=over 4

=item Parameter and return types

=begin html

<pre>
$genomes is a reference to a list where each element is a reference to a list containing 3 items:
	0: (genome_id) a genome_id
	1: (genome_name) a string
	2: (domain) a string
genome_id is a string

</pre>

=end html

=begin text

$genomes is a reference to a list where each element is a reference to a list containing 3 items:
	0: (genome_id) a genome_id
	1: (genome_name) a string
	2: (domain) a string
genome_id is a string


=end text



=item Description



=back

=cut

sub get_genomes
{
    my $self = shift;

    my $ctx = $SEEDServer::CallContext;
    my($genomes);
    #BEGIN get_genomes

    my $fig = $self->{fig};

    $genomes = [];
    for my $g ($fig->genomes())
    {
	my $gs = $fig->genus_species($g);
	my $domain = $fig->genome_domain($g);
	push(@$genomes, [$g, $gs, $domain]);
    }
    
    #END get_genomes
    my @_bad_returns;
    (ref($genomes) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"genomes\" (value was \"$genomes\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_genomes:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_genomes');
    }
    return($genomes);
}




=head2 version 

  $return = $obj->version()

=over 4

=item Parameter and return types

=begin html

<pre>
$return is a string
</pre>

=end html

=begin text

$return is a string

=end text

=item Description

Return the module version. This is a Semantic Versioning number.

=back

=cut

sub version {
    return $VERSION;
}

=head1 TYPES



=head2 feature_compare_info

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
fid has a value which is a string
beg has a value which is an int
end has a value which is an int
size has a value which is an int
strand has a value which is a string
contig has a value which is a string
location has a value which is a string
function has a value which is a string
type has a value which is a string
set_number has a value which is an int
offset_beg has a value which is an int
offset_end has a value which is an int
offset has a value which is an int
attributes has a value which is a reference to a list where each element is a reference to a list containing 2 items:
0: (key) a string
1: (value) a string


</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
fid has a value which is a string
beg has a value which is an int
end has a value which is an int
size has a value which is an int
strand has a value which is a string
contig has a value which is a string
location has a value which is a string
function has a value which is a string
type has a value which is a string
set_number has a value which is an int
offset_beg has a value which is an int
offset_end has a value which is an int
offset has a value which is an int
attributes has a value which is a reference to a list where each element is a reference to a list containing 2 items:
0: (key) a string
1: (value) a string



=end text

=back



=head2 genome_compare_info

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
beg has a value which is an int
end has a value which is an int
mid has a value which is an int
org_name has a value which is a string
pinned_peg_strand has a value which is a string
genome_id has a value which is a string
pinned_peg has a value which is a string
features has a value which is a reference to a list where each element is a feature_compare_info

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
beg has a value which is an int
end has a value which is an int
mid has a value which is an int
org_name has a value which is a string
pinned_peg_strand has a value which is a string
genome_id has a value which is a string
pinned_peg has a value which is a string
features has a value which is a reference to a list where each element is a feature_compare_info


=end text

=back



=head2 compared_regions

=over 4



=item Definition

=begin html

<pre>
a reference to a list where each element is a genome_compare_info
</pre>

=end html

=begin text

a reference to a list where each element is a genome_compare_info

=end text

=back



=head2 compare_options

=over 4



=item Description

* How to sort the genomes.
* similarity - by similarity
* phylogenetic_distance - by phylogenetic distance to focus peg
* phylogeny - by phylogeny


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
pin has a value which is a reference to a list where each element is a string
n_genomes has a value which is an int
width has a value which is an int
pin_alignment has a value which is a string
pin_compute_method has a value which is a string
sim_cutoff has a value which is a float
limit_to_genomes has a value which is a reference to a list where each element is a string
close_genome_collapse has a value which is a string
coloring_method has a value which is a string
color_sim_cutoff has a value which is a float
genome_sort_method has a value which is a string
features_for_cdd has a value which is a reference to a list where each element is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
pin has a value which is a reference to a list where each element is a string
n_genomes has a value which is an int
width has a value which is an int
pin_alignment has a value which is a string
pin_compute_method has a value which is a string
sim_cutoff has a value which is a float
limit_to_genomes has a value which is a reference to a list where each element is a string
close_genome_collapse has a value which is a string
coloring_method has a value which is a string
color_sim_cutoff has a value which is a float
genome_sort_method has a value which is a string
features_for_cdd has a value which is a reference to a list where each element is a string


=end text

=back



=head2 genome_id

=over 4



=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 feature_id

=over 4



=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 assignment_result

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
success has a value which is an int
text has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
success has a value which is an int
text has a value which is a string


=end text

=back



=head2 location

=over 4



=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 translation

=over 4



=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=cut

1;
