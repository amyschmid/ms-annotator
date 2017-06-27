package PG;
use DBrtns;
use Data::Dumper;
use FIGM;
use SEEDClient;
use SeedUtils;
use Cache::Memcached::Fast;
use Carp 'cluck';

use strict;

my $dataset_file = "/vol/ross/PangeneraDatasets";
my $rast_jobdir = "/vol/rast-prod/jobs";
my $anno_orgdir = "/vol/mirror-seed/Data.mirror/Organisms";
my $pubseed_orgdir = "/vol/public-pseed/FIGdisk/FIG/Data/Organisms";

my $pubseed_client_url = "http://pubseed.theseed.org/FIG/seed_svc.cgi";
my $anno_client_url = "http://anno-3.nmpdr.org/anno/FIG/seed_svc.cgi";

my $anno_memcached_config = {
    servers => ["anno-3.nmpdr.org:11212",
		"bio-data-1.mcs.anl.gov:11212",
		"bio-data-2.mcs.anl.gov:11212",
		"oak.mcs.anl.gov:11212"],
    namespace => 'anno'
    };
my $pubseed_memcached_config = {
    servers => ["anno-3.nmpdr.org:11212",
                "bio-data-1.mcs.anl.gov:11212",
                "bio-data-2.mcs.anl.gov:11212",
                "oak.mcs.anl.gov:11212",
                "ash.mcs.anl.gov:11212"],
    namespace => 'pub',
};

my $anno_memcache = new Cache::Memcached::Fast($anno_memcached_config);
my $pubseed_memcache = new Cache::Memcached::Fast($pubseed_memcached_config);

sub rast_jobdir
{
    return $rast_jobdir;
}

sub anno_orgdir
{
    return $anno_orgdir;
}

sub get_available_datasets
{
    my $fh;
    my @list;
    if (open($fh, "<", $dataset_file))
    {
	while (<$fh>)
	{
	    chomp;
	    my($name, $path, $flag) = split(/\t/);
	    if (! -d $path)
	    {
		warn "Path $path not found\n";
	    }
	    else
	    {
		push(@list, [$name, $path, $flag]);
	    }
	}
    }
    else
    {
	warn "Cannot open dataset file $dataset_file: $!";
    }
    return @list;
}

sub new_from_name
{
    my($class, $name) = @_;

    my @list = get_available_datasets();
    my @ent = grep { $_->[0] eq $name } @list;
    if (@ent)
    {
	return $class->new($ent[0]->[1], $name);
    }
    else
    {
	return undef;
    }
}

sub new
{
    my($class, $dir, $name) = @_;

    if (! -d $dir)
    {
	die "PG::new: can't find $dir\n";
    }
    my $self = { dir => $dir };

    if ($name)
    {
	$self->{name} = $name;
    }
    else
    {
	my @list = get_available_datasets();
	my @ent = grep { $_->[1] eq $dir } @list;
	if (@ent)
	{
	    $self->{name} = $ent[0]->[0];
	}
    }

    bless $self, $class;
    my $fig = FIGM->new(undef, $self->rast_genome_dirs);
    $self->{fig} = $fig;

    my $annos = [$self->anno_genomes()];
    $self->{annos} = $annos;
    $self->{annosH} = { map { $_ => 1 } @$annos };

    my $pubs = [$self->pubseed_genomes()];
    $self->{pubs} = $annos;
    $self->{pubsH} = { map { $_ => 1 } @$pubs };

    my $anno_client = SEEDClient->new($anno_client_url);
    $anno_client->{client}->{ua}->credentials("anno-3.nmpdr.org:80", "SEED User",
					      $FIG_Config::api_username_anno3, $FIG_Config::api_key_anno3);
    $self->{anno_client} = $anno_client;

    my $pubseed_client = SEEDClient->new($pubseed_client_url);
    $self->{pubseed_client} = $pubseed_client;
    
    my $genome_client = {};
    $genome_client->{$_} = $anno_client foreach @$annos;
    $genome_client->{$_} = $pubseed_client foreach @$pubs;
    $self->{genome_client} = $genome_client;

    return $self;
}

sub client_for_peg
{
    my($self, $peg) = @_;
    my $c = $self->{genome_client}->{SeedUtils::genome_of($peg)};
    return $c;
}

sub client_for_genome
{
    my($self, $g) = @_;
    my $c = $self->{genome_client}->{$g};
    return $c;
}

sub fig
{
    my($self) = @_;
    return $self->{fig};
}

sub rast_genomes
{
    my($self) = @_;
    my $dataD = $self->{dir};

    my $f;
    my @genomes = ();
    if (open(my $f, "<", "$dataD/genomes.with.job"))
    {
	while (<$f>)
	{
	    chomp;
	    my($name, $orig_genome_id, $job) = split(/\t/);
	    my $genome_id = `cat $rast_jobdir/$job/GENOME_ID`;
	    chomp $genome_id;
	    push(@genomes, $genome_id);
	}
	close($f);
    }
    return @genomes;
}

sub rast_genome_data
{
    my($self) = @_;
    my $dataD = $self->{dir};

    my @out;
    my $fh;
    if (open(my $f, "<", "$dataD/genomes.with.job"))
    {
	while (<$f>)
	{
	    chomp;
	    my($name, $orig_genome_id, $job) = split(/\t/);
	    my $genome_id = `cat $rast_jobdir/$job/GENOME_ID`;
	    chomp $genome_id;
	    my $dir = "$rast_jobdir/$job/rp/$genome_id";
	    if (! -d $dir)
	    {
		die "Cannot find RAST genome dir $dir\n";
	    }
	    push(@out, [$name, $genome_id, $dir, $job]);
	}
	close($f);
    }
    return @out;
}

sub rast_genome_dirs
{
    my($self) = @_;
    my $dataD = $self->{dir};

    my $f;
    my @dirs = ();
    if (open($f, "<", "$dataD/genomes.with.job"))
    {
	while (<$f>)
	{
	    chomp;
	    my($name, $orig_genome_id, $job) = split(/\t/);
	    my $genome_id = `cat $rast_jobdir/$job/GENOME_ID`;
	    chomp $genome_id;
	    my $dir = "$rast_jobdir/$job/rp/$genome_id";
	    if (! -d $dir)
	    {
		die "Cannot find RAST genome dir $dir\n";
	    }
	    push(@dirs, $dir);
	}
	close($f);
    }
    return @dirs;
}

sub anno_genomes
{
    my($self) = @_;
    my $dataD = $self->{dir};

    my @list = ();
    my $f;
    if (open($f, "<", "$dataD/anno.seed"))
    {
	while (<$f>)
	{
	    if (/\b(\d+\.\d+)/)
	    {
		push(@list, $1);
	    }
	}
	close($f);
    }
    return @list;
}

sub anno_genome_dirs
{
    my($self) = @_;
    my $dataD = $self->{dir};

    my @dirs;
    foreach my $gid ($self->anno_genomes())
    {
	my $path = "$anno_orgdir/$gid";
	if (-d $path)
	{
	    push(@dirs, $path);
	}
	else
	{
	    die "Cannot find anno seed dir for $gid\n";
	}
    }

    return @dirs;
}

sub anno_genome_data
{
    my($self) = @_;
    my $dataD = $self->{dir};

    my @out;
    foreach my $gid ($self->anno_genomes())
    {
	my $path = "$anno_orgdir/$gid";
	if (-d $path)
	{
	    my $name = `cat $path/GENOME`;
	    chomp $name;
	    push(@out, [$name, $gid, $path]);
	}
	else
	{
	    die "Cannot find anno seed dir for $gid\n";
	}
    }

    return @out;
}

sub pubseed_genomes
{
    my($self) = @_;
    my $dataD = $self->{dir};

    my @list = ();
    my $f;
    if (open($f, "<", "$dataD/pubseed.seed"))
    {
	while (<$f>)
	{
	    if (/\b(\d+\.\d+)/)
	    {
		push(@list, $1);
	    }
	}
	close($f);
    }
    return @list;
}

sub pubseed_genome_dirs
{
    my($self) = @_;
    my $dataD = $self->{dir};

    my @dirs;
    foreach my $gid ($self->pubseed_genomes())
    {
	my $path = "$pubseed_orgdir/$gid";
	if (-d $path)
	{
	    push(@dirs, $path);
	}
	else
	{
	    die "Cannot find pubseed seed dir for $gid\n";
	}
    }

    return @dirs;
}

sub pubseed_genome_data
{
    my($self) = @_;
    my $dataD = $self->{dir};

    my @out;
    foreach my $gid ($self->pubseed_genomes())
    {
	my $path = "$pubseed_orgdir/$gid";
	if (-d $path)
	{
	    my $name = `cat $path/GENOME`;
	    chomp $name;
	    push(@out, [$name, $gid, $path]);
	}
	else
	{
	    die "Cannot find pubseed seed dir for $gid\n";
	}
    }

    return @out;
}

sub genomes
{
    my($self) = @_;
    return ($self->rast_genomes, $self->anno_genomes, $self->pubseed_genomes);
}

sub genome_data
{
    my($self) = @_;
    return ($self->rast_genome_data, $self->anno_genome_data, $self->pubseed_genome_data);
}

sub genome_dirs
{
    my($self) = @_;
    return ($self->rast_genome_dirs, $self->anno_genome_dirs, $self->pubseed_genome_dirs);
}

sub load_funcs
{
    my($self) = @_;

    my $to_func = {};
    for my $dir ($self->rast_genome_dirs)
    {
	foreach $_ (`cat $dir/proposed*functions`)
	{
	    chomp;
	    my($id, $func) = split(/\t/);
	    if ($id && $func)
	    {
		$to_func->{$id} = $func;
	    }
	}
    }

    for my $gid ($self->anno_genomes)
    {
	my $funcs = $self->anno_functions_from_genomes([$gid]);
	$to_func->{$_->[0]} = $_->[1] foreach @$funcs;
    }
    for my $gid ($self->pubseed_genomes)
    {
	my $fids = $self->{pubseed_client}->get_genome_features([$gid], 'peg');
	$fids = $fids->{$gid};
	my $funcs = $self->{pubseed_client}->get_function($fids);
	$to_func->{$_} = $funcs->{$_} foreach keys %$funcs;
    }
    return $to_func;
}

sub connect_to_anno_db
{
    my($self) = @_;
    my $anno_db = DBrtns->new("mysql", "fig_anno_v5", "seed", undef, undef, "seed-db-read.mcs.anl.gov");
    return $anno_db;
}

sub anno_functions_from_genomes
{
    my($self, $genomes) = @_;

    my $anno_db = $self->connect_to_anno_db;

    my $qs = join(", ", map { "?" } @$genomes);

    my $res = $anno_db->SQL("select prot, assigned_function FROM assigned_functions WHERE org IN ($qs)", undef,
			    @$genomes);

    return $res;
}

sub load_seqs {
    my($self) = @_;
    my $dataD = $self->{dir};

    my $peg_to_seq = {};
    my $seq_to_pegs = {};

    foreach my $dir ($self->genome_dirs())
    {
	$/ = "\n>";
	foreach $_ (`cat $dir/Features/peg/fasta`)
	{
	    chomp;
	    if ($_ =~ /^>?(\S+)[^\n]*\n(.*)/s)
	    {
		my $peg = $1;
		my $seq = $2;
		$seq =~ s/\s//gs;
		$peg_to_seq->{$peg} = $seq;
		push(@{$seq_to_pegs->{$seq}},$peg);
	    }
	}
	$/ = "\n";
    }

    return ($peg_to_seq,$seq_to_pegs);
}

sub subsystem_bindings_for_genome
{
    my($self, $genome) = @_;

    if (grep { $_ eq $genome } $self->anno_genomes)
    {
	my $anno_db = $self->connect_to_anno_db();
	my $cond = "fig|$genome.peg.%";
	my $res = $anno_db->SQL(qq(SELECT subsystem, role, protein from subsystem_index
				   WHERE protein LIKE ? and variant not in ('0', '-1', '*0', '*-1')), undef,
				$cond);
	return $res;
    }
    else
    {
	my @data = $self->genome_data;
	my($ent) = grep { $_->[1] eq $genome } @data;
	my $dir = $ent->[2];
	my $b;
	if (!open($b, "<", "$dir/Subsystems/bindings"))
	{
	    warn "Cannot open bindings $dir/Subsystems/bindings: $!";
	    return [];
	}
	my $out;
	while (<$b>)
	{
	    chomp;
	    my($ss, $role, $fid) = split(/\t/);
	    push(@$out, [$ss, $role, $fid]);
	}
	return $out;
    }
}

sub mk_link
{
    my($self, $app, $fid) = @_;

    my $g = SeedUtils::genome_of($fid);
    if ($self->{annosH}->{$g})
    {
	my $l = "http://anno-3.nmpdr.org/anno/FIG/seedviewer.cgi?page=Annotation&feature=$fid";
	return $l;
    }
    elsif ($self->{pubsH}->{$g})
    {
	my $l = "http://pubseed.theseed.org/seedviewer.cgi?page=Annotation&feature=$fid";
	return $l;
    }
    else
    {
	return $app->url . "?page=Annotation&feature=$fid";
    }
}

sub assign_functions
{
    my($self, $assigns, $user_obj, $seed_user) = @_;

    my $is_annotator = $user_obj->has_right(undef, 'annotate', 'genome', '*');

    my @out = ();
    
    my(%anno_assigns, %other_assigns, %pubseed_assigns );
    
    for my $ent (@$assigns)
    {
	my($peg, $func) = @$ent;
	my $g = SeedUtils::genome_of($peg);
	my $cli = $self->client_for_genome($g);
	#
	# anno seed annotations require privilege
	#
	if ($self->{annosH}->{$g})
	{
	    $anno_assigns{$peg} = $func;
	}
	elsif ($self->{pubsH}->{$g})
	{
	    $pubseed_assigns{$peg} = $func;
	}
	else
	{
	    $other_assigns{$peg} = $func;
	}
    }

    if (%anno_assigns)
    {
	if ($is_annotator)
	{
	    my $res;
	    eval
	    {
		$res = $self->{anno_client}->assign_function(\%anno_assigns, $seed_user, $FIG_Config::api_key_anno3);
	    };
	    if ($@)
	    {
		push(@out, "Failure to assign to annotator seed: $@");
	    }
	    else
	    {
		for my $ent (@$assigns)
		{
		    my($peg, $func) = @$ent;
		    if ($self->{annosH}->{SeedUtils::genome_of($peg)})
		    {
			push(@out, "$peg (annoseed): success=$res->{$peg}->{success}", split(/\n/, $res->{$peg}->{text}), '');
		    }
		}
	    }
	}
	else
	{
	    push(@out, "User cannot change anno pegs: not an annotator");
	}
    }
    if (%pubseed_assigns)
    {
	my $res;
	eval
	{
	    $res = $self->{pubseed_client}->assign_function(\%pubseed_assigns, $seed_user, $FIG_Config::api_key_pubseed);
	};
	if ($@)
	{
	    push(@out, "Failure to assign to pubseed: $@");
	}
	else
	{
	    for my $ent (@$assigns)
	    {
		my($peg, $func) = @$ent;
		if ($self->{pubsH}->{SeedUtils::genome_of($peg)})
		{
		    push(@out, "$peg (pubseed): success=$res->{$peg}->{success}", split(/\n/, $res->{$peg}->{text}), '');
		}
	    }
	}
    }
    else
    {
	push(@out, "Unknown pegs " . join(" ", keys %other_assigns));
    }
    return join("\n", "<pre>", @out,"</pre>", '');
}

sub is_real_feature
{
    my($self, $fid) = @_;

    my $g = SeedUtils::genome_of($fid);

    my $cl = $self->client_for_genome($g);
    my $x = $cl->is_real_feature([$fid]);
    return $x->{$fid} ? 1 : 0;
}

sub filter_real_features
{
    my($self, $fids) = @_;

    my %h;

    for my $fid (@$fids)
    {
	my $g = SeedUtils::genome_of($fid);
	push(@{$h{$g}}, $fid);
    }

    my %map;
    for my $g (keys %h)
    {
	my $cl = $self->client_for_genome($g);
	my $x = $cl->is_real_feature($h{$g});
	$map{$_} = $x->{$_} foreach keys %$x;
    }
    return grep { $map{$_} } @$fids;
}

sub function_of_bulk
{
    my($self, $fids) = @_;

    my(@pubseed, @anno);
    for my $fid (@$fids)
    {
	my $g = SeedUtils::genome_of($fid);
	if ($self->{annosH}->{$g})
	{
	    push(@anno, $fid);
	}
	elsif ($self->{pubsH}->{$g})
	{
	    push(@pubseed, $fid);
	}
	else
	{
	    cluck "fid '$fid' (genome '$g') not found in either list\n";
	}
    }
    #
    # Try the memcached first.
    #

    my $out = {};
    
    my $mcout  = $anno_memcache->get_multi(map { "f:$_" } @anno);
#    print STDERR Dumper('anno memcache hits' => $mcout);
    map { my $k = $_; s/^f://;  $out->{$_} = $mcout->{$k} } keys %$mcout;
    @anno = grep { !$mcout->{"f:$_"} } @anno;
    
    $mcout  = $pubseed_memcache->get_multi(map { "f:$_" } @pubseed);
#    print STDERR Dumper('pubseed memcache hits' => $mcout);
    map { my $k = $_; s/^f://;  $out->{$_} = $mcout->{$k} } keys %$mcout;
    @pubseed = grep { !$mcout->{"f:$_"} } @pubseed;

#    print STDERR Dumper(lookup=> \@anno, \@pubseed);

    my $anno_ret = $self->{anno_client}->get_function(\@anno);
    my $pub_ret = $self->{pubseed_client}->get_function(\@pubseed);

    $out->{$_} = $anno_ret->{$_} foreach keys %$anno_ret;
    $out->{$_} = $pub_ret->{$_} foreach keys %$pub_ret;
    # return { %$anno_ret, %$pub_ret };
    return $out;
}

sub genus_species
{
    my($self, $g) = @_;


    return $self->{fig}->genus_species($g);
}

