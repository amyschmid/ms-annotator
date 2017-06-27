
package SapCompareRegions;

use strict;
use SeedUtils;
use ServerThing;
use Tracer;
use Data::Dumper;

our $fig;
eval {
    require FIG;
    $fig = FIG->new();
};

sub get_pin
{
    my($self, $args) = @_;

    my $sap = $self->{db};

    my $peg = $args->{-focus};
    my $cutoff = $args->{-cutoff};
    my $count = $args->{-count};

    $cutoff = 1e-5 unless defined($cutoff);

    my $pegged_genomes = ServerThing::GetIdList(-genomes => $args, 1);
    my %pegged_genomes;
    $pegged_genomes{$_}++ for @$pegged_genomes;

    my @sims;
    if ($fig)
    {
	@sims = $fig->sims($peg,
			   $count * 10,
			   $cutoff,
			   'fig');
    }
    else
    {
	@sims = SeedUtils::sims($peg,
				$count * 10,
				$cutoff,
				'fig');
    }
    
    @sims = map { [$_, SeedUtils::genome_of($_->id2)] } @sims;
    my $ex = $self->exists({ -ids => [map { $_->[1] } @sims], -type => 'Genome'});
    @sims = grep { $ex->{$_->[1]} } @sims;

    if (%pegged_genomes)
    {
	@sims = grep { $pegged_genomes{$_->[1]} } @sims;
    }

    if (@sims > $count)
    {
	$#sims = $count-1;
    }

    return [map { $_->[0]->id2 } @sims];
}

sub get_context
{
    my($self, $args) = @_;

    my $focus = $args->{-focus};
    my $pin = $args->{-pin};
    my $extent = $args->{-extent};

    my @pegs = ($focus, @$pin);

    my $locs = $self->fid_locations({ -ids => [@pegs], -boundaries => 1 });
    # print Dumper($locs);

    my %peg_to_reg;
    my %peg_to_ctg;
    for my $peg (@pegs)
    {
	my($ctg, $beg, $end, $dir) = SeedUtils::parse_location($locs->{$peg});

	$beg -= $extent;
	$beg = 1 if $beg < 1;

	$end += $extent;
	
	my $rloc = SeedUtils::location_string($ctg, $beg, $end);

	$peg_to_ctg{$peg} = $ctg;
	$peg_to_reg{$peg} = $rloc;
    }

    my $regions = $self->genes_in_region({ -locations => [ values %peg_to_reg ]});

    my @all_pegs = map { @$_ } values %$regions;
    my $all_locs = $self->fid_locations({-ids => \@all_pegs, -boundaries => 1});

    my $all_fams = $self->ids_to_figfams({-ids => \@all_pegs});
    my $all_funcs = $self->ids_to_functions({-ids => \@all_pegs});
    

    # print Dumper($all_locs, $all_fams, $all_funcs);

    my @result;
    my $row = 0;

    my $names = $self->genome_names({-ids => [ map { SeedUtils::genome_of($_) } @pegs ]});
    
    for my $peg (@pegs)
    {
	my $genome = SeedUtils::genome_of($peg);
	
	my $reg = $regions->{$peg_to_reg{$peg}};

	my @row_data = map { my($ctg, $beg, $end, $dir) = SeedUtils::parse_location($all_locs->{$_});
			     my $fams = $all_fams->{$_};
			     [$_,
			      ($all_funcs->{$_} ? $all_funcs->{$_} : "hypothetical protein"),
			      (ref($fams) ? join(",", @$fams) : ""),
			      $ctg, $beg, $end, $dir, $row]; } @$reg;

	@row_data = sort { $a->[5] <=> $b->[5] } @row_data;
	push(@result, {
	    pin => $peg,
	    genome_id => $genome,
	    genome_name => $names->{$genome},
	    row_id => $row,
	    features => \@row_data,
	});
	$row++;
    }
    return \@result;
}

sub cluster_by_function
{
    my($self, $args) = @_;

    my $context = $args->{-context};

    #
    # Now cluster by function.
    #
    
    my $next = 1;
    my %group;
    my %group_count;
    for my $row (@$context)
    {
	for my $ent (@{$row->{features}})
	{
	    my($peg, $func, $fam, $ctg, $beg, $end, $dir, $rownum) = @$ent;
	    next unless defined($func);
	    $func =~ s/\s+#.*$//;
		my $group = $group{$func};
	    if (!defined($group))
	    {
		$group = $next++;
		$group{$func} = $group;
	    }
	    
	    $group_count{$group}++;
	    $ent->[8] = $group;
	}
    }

    return $context;
}

1;
