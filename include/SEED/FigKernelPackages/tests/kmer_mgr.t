use Test::More;
use Data::Dumper;
use strict;
use CGI;

BEGIN { use_ok('FIG_Config'); }
BEGIN { use_ok('KmerMgr'); }

my $kmgr = new_ok('KmerMgr', [base_dir => '/vol/figfam-prod']);

my $seq = <<END;
MKLYNLKDHNEQVSFAQAVTQGLGKNQGLFFPHDLPEFSLTEIDEMLKLD
FVTRSAKILSAFIGDEIPQEILEERVRAAFAFPAPVANVESDVGCLELFH
GPTLAFKDFGGRFMAQMLTHIAGDKPVTILTATSGDTGAAVAHAFYGLPN
VKVVILYPRGKISPLQEKLFCTLGGNIETVAIDGDFDACQALVKQAFDDE
ELKVALGLNSANSINISRLLAQICYYFEAVAQLPQETRNQLVVSVPSGNF
GDLTAGLLAKSLGLPVKRFIAATNVNDTVPRFLHDGQWSPKATQATLSNA
MDVSQPNNWPRVEELFRRKIWQLKELGYAAVDDETTQQTMRELKELGYTS
EPHAAVAYRALRDQLNPGEYGLFLGTAHPAKFKESVEAILGETLDLPKEL
AERADLPLLSHNLPADFAALRKLMMNHQ
END
$seq =~ s/\s+//g;
my $fn = 'Threonine synthase (EC 4.2.3.1)';

my $ds = $kmgr->get_active_datasets();
isa_ok($ds, 'ARRAY');
my($default, $sets) = @$ds;
isa_ok($sets, 'HASH');

for my $rel (sort keys %$sets)
{
    my $kmers = $kmgr->get_kmer_object($rel);
    print "ffs: $kmers->{ffs}\n";
    for my $k (@{$sets->{$rel}})
    {
	my @res = $kmers->assign_functions_to_prot_set(-seqs => [['protein', undef, $seq]],
						       -kmer => $k,
						       -determineFamily => 1,
						      );
	cmp_ok(scalar @res, '==', 1);
	is($res[0]->[1], $fn);
	last;
    }
    last;
}


done_testing();
