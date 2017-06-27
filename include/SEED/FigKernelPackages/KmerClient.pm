#
# Client package for connecting to the kmer_guts server.
#

package KmerClient;

use Sim;
use strict;
use IO::Socket::INET;
use IO::Select;
use Cache::Memcached::Fast;
use Data::Dumper;

$SIG{PIPE} = 'IGNORE';

our $default_host = "elm.mcs.anl.gov";
our $default_port = 5100;

my $genome_map = "/scratch/olson/all.genomes";
my(%id_to_genome, %genome_to_id);

if (open(G, "<", $genome_map))
{

while (<G>)
{
    chomp;
    if (my($id, $genome) = /^\s*(\S+)\s+(\S+)/)
    {
	$id_to_genome{$id} = $genome;
    }
}
close(G);
}

sub new
{
    my($class, $fig, $host, $port) = @_;

    $host ||= $default_host;
    $port ||= $default_port;
    
    my $cache = new Cache::Memcached::Fast({
	servers => [ { address => 'elm.mcs.anl.gov:11211' } ],
	compress_threshold => 10_000,
	compress_ratio => 0.9,
	compress_methods => [ \&IO::Compress::Gzip::gzip,
			     \&IO::Uncompress::Gunzip::gunzip ],
	max_failures => 3,
	failure_timeout => 2,
    });
    
    my $self = {
	fig => $fig,
	host => $host,
	port => $port,
	cache => $cache,
    };
    return bless $self, $class;
}

sub connect
{
    my($self) = @_;
    my $sock = IO::Socket::INET->new(PeerAddr => $self->{host},
				     PeerPort => $self->{port},
				     Proto => 'tcp',
				     Blocking => 0);
    $sock or die "could not connect: $!";
    
    my $select = IO::Select->new();
    $select->add($sock);

    return($sock, $select);
}

sub get_close_pegs
{
    my($self, $fids, $maxN, $min_score) = @_;

    $maxN = 100 if !defined($maxN);

    if (!ref($fids))
    {
	$fids = [$fids];
    }

    my $kmers = $self->hits_for_pegs(@$fids);
    my $result = {};
    my @output;
    while (my($peg, $hits) = each %$kmers)
    {
	my @kmers = map { $_->[1] } @$hits;
	my $res = $self->{cache}->get_multi(@kmers);

	my %hits;
	while (my($kmer, $pegsN) = each(%$res))
	{
	    foreach my $pegN (unpack("I!*", $pegsN))
	    {
		$hits{$pegN}++;
	    }
	}
	my @sorted = map { [$_,$hits{$_}] } grep { $hits{$_} > $min_score } sort { $hits{$b} <=> $hits{$a} } keys(%hits);
	$#sorted = $maxN - 1 if @sorted > $maxN;
	
	@output = () unless wantarray;
	foreach my $tuple (@sorted)
	{
	    my($pegE,$n) = @$tuple;
	    
	    my $tpeg = "fig|" . $id_to_genome{($pegE >> 17)} . ".peg." . ($pegE & 0x7fff);
	    
	    my $sim = [$peg, $tpeg];
	    $sim->[11] = $n;
	    $sim->[14] = 'kmers';
	    bless $sim, 'Sim';
	    push(@output, $sim);
	}
	$result->{$peg} = [@output] unless wantarray;
    }
    return wantarray ? @output : $result;
}

sub hits_for_pegs
{
    my($self, @fids) = @_;

    my $fig = $self->{fig};

    my($sock, $select) = $self->connect();

    $select->can_write();

    print $sock "-d 1\n";
    my $x = <$sock>;

    my $results = {};
    my $done;
    my $data = '';

 OUTER:
    for my $fid (@fids)
    {
	my $written;
	my $seq = $fig->get_translation($fid);

	do {
	    if (my @write = $select->can_write(0))
	    {
		print $sock ">$fid\n$seq\n";
		$written = 1;
	    }
	    while (my @read = $select->can_read(0))
	    {
		my $buf;
		my $n = sysread($sock, $buf, 1000000);
		if (!defined($n))
		{
		    die "read error $!";
		}
		elsif ($n == 0)
		{
		    $done = 1;
		    last OUTER;
		}
		$data .= $buf;
		$self->process(\$data, $results);
	    }
	} until $written;
    }
    if (!$done)
    {
	shutdown($sock, 1);
	$sock->blocking(1);
	
	while (1)
	{
	    my $buf;
	    my $n = sysread($sock, $buf, 1000000);
	    if (!defined($n))
	    {
		die "read error $!";
	    }
	    elsif ($n == 0)
	    {
		last;
	    }
	    $data .= $buf;
	    $self->process(\$data, $results);
	}
    }
    if ($results->{cur_id})
    {
	$results->{all}->{$results->{cur_id}} = $results->{cur_hits};
    }
    close($sock);
    return $results->{all};
}

sub process
{
    my($self, $datap, $results) = @_;

    while ($$datap =~ s/^([^\n]*)\n//)
    {
	my $l = $1;
	if ($l =~ /^PROTEIN-ID\t(\S+)/)
	{
	    if ($results->{cur_id})
	    {
		$results->{all}->{$results->{cur_id}} = $results->{cur_hits};
	    }
	    $results->{cur_hits} = [];
	    $results->{cur_id} = $1;
	}
	elsif ($l =~ /^HIT\s+(.*)/)
	{
	    push(@{$results->{cur_hits}}, [split(/\t/, $1)]);
	}
    }
}

1;
