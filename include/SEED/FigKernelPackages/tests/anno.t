use Test::More;
use Data::Dumper;
use strict;
use CGI;

BEGIN { use_ok('FIG_Config'); }
BEGIN { use_ok('ANNO'); }
BEGIN { use_ok('gjoseqlib'); }

my $anno = new_ok('ANNO');

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

my $ds = $anno->get_active_datasets();
isa_ok($ds, 'ARRAY');
my($default, $sets) = @$ds;
isa_ok($sets, 'HASH');

for my $rel (sort keys %$sets)
{
    for my $k (@{$sets->{$rel}})
    {
	print "$rel $k\n";
	my $cgi = CGI->new;
	$cgi->param(-name => '-kmer', -value => $k);
	$cgi->param(-name => '-kmerDataset', -value  => $rel);
	$cgi->param(-name => '-determineFamily', -value  => 1);
	$cgi->param(id_seq => join(",", "protein", $seq));
	my @res = $anno->assign_function_to_prot($cgi);
	is(@res, 1);
	is($res[0]->[1], $fn);
	last;
    }
}

{
    #
    # Test gene calling and kmer calls on the called genes.
    # Sequence is the first 1000 lines of the 83333.1 contigs.
    #
    my $cgi = CGI->new;
    $cgi->param(-name => '-minContigLen', -value => 1000);
    $cgi->param(id_seq => join(",", 'contig', get_contigs()));
    my $ret = $anno->call_genes($cgi);
    isa_ok($ret, 'ARRAY');
    is(@$ret, 2);
    my($fa, $tbl) = @$ret;
    isa_ok($tbl, 'ARRAY');
    is(@$tbl, 6);
    like($fa, qr/^>prot/);

    open(my $fh, "<", \$fa);
    my @ents = read_fasta($fh);
    close($fh);
    cmp_ok(scalar @ents, '==', 6);

    my $cgi2 = CGI->new;
    $cgi2->param(-name => '-kmer', -value => 8);
    $cgi2->param(-name => '-kmerDataset', -value => 'Release45');
    $cgi2->param(id_seq => map { join(",", $_->[0], $_->[2]) } @ents);
    my @res2 = $anno->assign_function_to_prot($cgi2);
    is($res2[1]->[1], 'Aspartokinase (EC 2.7.2.4) / Homoserine dehydrogenase (EC 1.1.1.3)');
    is($res2[2]->[1], 'Homoserine kinase (EC 2.7.1.39)');
    is($res2[3]->[1], 'Threonine synthase (EC 4.2.3.1)');
    is($res2[4]->[1], 'FIG00638853: hypothetical protein');
    is($res2[5]->[1], 'UPF0246 protein YaaA');
    
}

{
    #
    # Test DNA level kmer calling.
    # Sequence is the first 1000 lines of the 83333.1 contigs.
    #
    my $cgi = CGI->new;
    $cgi->param(-name => '-kmer', -value => 8);
    $cgi->param(-name => '-kmerDataset', -value => 'Release45');
    $cgi->param(id_seq => join(",", 'contig', get_contigs()));
    my @ret = $anno->assign_functions_to_DNA($cgi);
    cmp_ok(scalar @ret, '==', 14);
    is($ret[0]->[1]->[3], 'Aspartokinase (EC 2.7.2.4) / Homoserine dehydrogenase (EC 1.1.1.3)');
    
}

{
    # Test RNA calling.

    #
    # Sequence is locations 223000-226000 of 83333.1.
    #
    my $cgi = CGI->new;
    $cgi->param(-name => '-genus', -value => 'Escherichia');
    $cgi->param(-name => '-species', -value => 'coli');
    $cgi->param(-name => '-domain', -value => 'B');
    $cgi->param(id_seq => join(",", 'contig', get_rna_test_data()));
    my $ret = $anno->find_rnas($cgi);
    isa_ok($ret, 'ARRAY');
    cmp_ok(scalar @$ret, '==', 2);
    my($fa, $tbl) = @$ret;
    isa_ok($tbl, 'ARRAY');
    cmp_ok(scalar @$tbl, '==', 4);
    is($tbl->[0]->[4], 'tRNA-Ile-GAT');
    is($tbl->[1]->[4], 'tRNA-Ala-TGC');
    is($tbl->[2]->[4], 'Small Subunit Ribosomal RNA; ssuRNA; SSU rRNA');
    is($tbl->[3]->[4], 'Large Subunit Ribosomal RNA; lsuRNA; LSU rRNA');

}    

done_testing();

sub get_contigs
{
    my $str = <<END;
agcttttcattctgactgcaacgggcaatatgtctctgtgtggattaaaaaaagagtgtc
tgatagcagcttctgaactggttacctgccgtgagtaaattaaaattttattgacttagg
tcactaaatactttaaccaatataggcatagcgcacagacagataaaaattacagagtac
acaacatccatgaaacgcattagcaccaccattaccaccaccatcaccattaccacaggt
aacggtgcgggctgacgcgtacaggaaacacagaaaaaagcccgcacctgacagtgcggg
ctttttttttcgaccaaaggtaacgaggtaacaaccatgcgagtgttgaagttcggcggt
acatcagtggcaaatgcagaacgttttctgcgtgttgccgatattctggaaagcaatgcc
aggcaggggcaggtggccaccgtcctctctgcccccgccaaaatcaccaaccacctggtg
gcgatgattgaaaaaaccattagcggccaggatgctttacccaatatcagcgatgccgaa
cgtatttttgccgaacttttgacgggactcgccgccgcccagccggggttcccgctggcg
caattgaaaactttcgtcgatcaggaatttgcccaaataaaacatgtcctgcatggcatt
agtttgttggggcagtgcccggatagcatcaacgctgcgctgatttgccgtggcgagaaa
atgtcgatcgccattatggccggcgtattagaagcgcgcggtcacaacgttactgttatc
gatccggtcgaaaaactgctggcagtggggcattacctcgaatctaccgtcgatattgct
gagtccacccgccgtattgcggcaagccgcattccggctgatcacatggtgctgatggca
ggtttcaccgccggtaatgaaaaaggcgaactggtggtgcttggacgcaacggttccgac
tactctgctgcggtgctggctgcctgtttacgcgccgattgttgcgagatttggacggac
gttgacggggtctatacctgcgacccgcgtcaggtgcccgatgcgaggttgttgaagtcg
atgtcctaccaggaagcgatggagctttcctacttcggcgctaaagttcttcacccccgc
accattacccccatcgcccagttccagatcccttgcctgattaaaaataccggaaatcct
caagcaccaggtacgctcattggtgccagccgtgatgaagacgaattaccggtcaagggc
atttccaatctgaataacatggcaatgttcagcgtttctggtccggggatgaaagggatg
gtcggcatggcggcgcgcgtctttgcagcgatgtcacgcgcccgtatttccgtggtgctg
attacgcaatcatcttccgaatacagcatcagtttctgcgttccacaaagcgactgtgtg
cgagctgaacgggcaatgcaggaagagttctacctggaactgaaagaaggcttactggag
ccgctggcagtgacggaacggctggccattatctcggtggtaggtgatggtatgcgcacc
ttgcgtgggatctcggcgaaattctttgccgcactggcccgcgccaatatcaacattgtc
gccattgctcagggatcttctgaacgctcaatctctgtcgtggtaaataacgatgatgcg
accactggcgtgcgcgttactcatcagatgctgttcaataccgatcaggttatcgaagtg
tttgtgattggcgtcggtggcgttggcggtgcgctgctggagcaactgaagcgtcagcaa
agctggctgaagaataaacatatcgacttacgtgtctgcggtgttgccaactcgaaggct
ctgctcaccaatgtacatggccttaatctggaaaactggcaggaagaactggcgcaagcc
aaagagccgtttaatctcgggcgcttaattcgcctcgtgaaagaatatcatctgctgaac
ccggtcattgttgactgcacttccagccaggcagtggcggatcaatatgccgacttcctg
cgcgaaggtttccacgttgtcacgccgaacaaaaaggccaacacctcgtcgatggattac
taccatcagttgcgttatgcggcggaaaaatcgcggcgtaaattcctctatgacaccaac
gttggggctggattaccggttattgagaacctgcaaaatctgctcaatgcaggtgatgaa
ttgatgaagttctccggcattctttctggttcgctttcttatatcttcggcaagttagac
gaaggcatgagtttctccgaggcgaccacgctggcgcgggaaatgggttataccgaaccg
gacccgcgagatgatctttctggtatggatgtggcgcgtaaactattgattctcgctcgt
gaaacgggacgtgaactggagctggcggatattgaaattgaacctgtgctgcccgcagag
tttaacgccgagggtgatgttgccgcttttatggcgaatctgtcacaactcgacgatctc
tttgccgcgcgcgtggcgaaggcccgtgatgaaggaaaagttttgcgctatgttggcaat
attgatgaagatggcgtctgccgcgtgaagattgccgaagtggatggtaatgatccgctg
ttcaaagtgaaaaatggcgaaaacgccctggccttctatagccactattatcagccgctg
ccgttggtactgcgcggatatggtgcgggcaatgacgttacagctgccggtgtctttgct
gatctgctacgtaccctctcatggaagttaggagtctgacatggttaaagtttatgcccc
ggcttccagtgccaatatgagcgtcgggtttgatgtgctcggggcggcggtgacacctgt
tgatggtgcattgctcggagatgtagtcacggttgaggcggcagagacattcagtctcaa
caacctcggacgctttgccgataagctgccgtcagaaccacgggaaaatatcgtttatca
gtgctgggagcgtttttgccaggaactgggtaagcaaattccagtggcgatgaccctgga
aaagaatatgccgatcggttcgggcttaggctccagtgcctgttcggtggtcgcggcgct
gatggcgatgaatgaacactgcggcaagccgcttaatgacactcgtttgctggctttgat
gggcgagctggaaggccgtatctccggcagcattcattacgacaacgtggcaccgtgttt
tctcggtggtatgcagttgatgatcgaagaaaacgacatcatcagccagcaagtgccagg
gtttgatgagtggctgtgggtgctggcgtatccggggattaaagtctcgacggcagaagc
cagggctattttaccggcgcagtatcgccgccaggattgcattgcgcacgggcgacatct
ggcaggcttcattcacgcctgctattcccgtcagcctgagcttgccgcgaagctgatgaa
agatgttatcgctgaaccctaccgtgaacggttactgccaggcttccggcaggcgcggca
ggcggtcgcggaaatcggcgcggtagcgagcggtatctccggctccggcccgaccttgtt
cgctctgtgtgacaagccggaaaccgcccagcgcgttgccgactggttgggtaagaacta
cctgcaaaatcaggaaggttttgttcatatttgccggctggatacggcgggcgcacgagt
actggaaaactaaatgaaactctacaatctgaaagatcacaacgagcaggtcagctttgc
gcaagccgtaacccaggggttgggcaaaaatcaggggctgttttttccgcacgacctgcc
ggaattcagcctgactgaaattgatgagatgctgaagctggattttgtcacccgcagtgc
gaagatcctctcggcgtttattggtgatgaaatcccacaggaaatcctggaagagcgcgt
gcgcgcggcgtttgccttcccggctccggtcgccaatgttgaaagcgatgtcggttgtct
ggaattgttccacgggccaacgctggcatttaaagatttcggcggtcgctttatggcaca
aatgctgacccatattgcgggtgataagccagtgaccattctgaccgcgacctccggtga
taccggagcggcagtggctcatgctttctacggtttaccgaatgtgaaagtggttatcct
ctatccacgaggcaaaatcagtccactgcaagaaaaactgttctgtacattgggcggcaa
tatcgaaactgttgccatcgacggcgatttcgatgcctgtcaggcgctggtgaagcaggc
gtttgatgatgaagaactgaaagtggcgctagggttaaactcggctaactcgattaacat
cagccgtttgctggcgcagatttgctactactttgaagctgttgcgcagctgccgcagga
gacgcgcaaccagctggttgtctcggtgccaagcggaaacttcggcgatttgacggcggg
tctgctggcgaagtcactcggtctgccggtgaaacgttttattgctgcgaccaacgtgaa
cgataccgtgccacgtttcctgcacgacggtcagtggtcacccaaagcgactcaggcgac
gttatccaacgcgatggacgtgagtcagccgaacaactggccgcgtgtggaagagttgtt
ccgccgcaaaatctggcaactgaaagagctgggttatgcagccgtggatgatgaaaccac
gcaacagacaatgcgtgagttaaaagaactgggctacacttcggagccgcacgctgccgt
agcttatcgtgcgctgcgtgatcagttgaatccaggcgaatatggcttgttcctcggcac
cgcgcatccggcgaaatttaaagagagcgtggaagcgattctcggtgaaacgttggatct
gccaaaagagctggcagaacgtgctgatttacccttgctttcacataatctgcccgccga
ttttgctgcgttgcgtaaattgatgatgaatcatcagtaaaatctattcattatctcaat
caggccgggtttgcttttatgcagcccggcttttttatgaagaaattatggagaaaaatg
acagggaaaaaggagaaattctcaataaatgcggtaacttagagattaggattgcggaga
ataacaaccgccgttctcatcgagtaatctccggatatcgacccataacgggcaatgata
aaaggagtaacctgtgaaaaagatgcaatctatcgtactcgcactttccctggttctggt
cgctcccatggcagcacaggctgcggaaattacgttagtcccgtcagtaaaattacagat
aggcgatcgtgataatcgtggctattactgggatggaggtcactggcgcgaccacggctg
gtggaaacaacattatgaatggcgaggcaatcgctggcacctacacggaccgccgccacc
gccgcgccaccataagaaagctcctcatgatcatcacggcggtcatggtccaggcaaaca
tcaccgctaaatgacaaatgccgggtaacaatccggcattcagcgcctgatgcgacgctg
gcgcgtcttatcaggcctacgttaattctgcaatatattgaatctgcatgcttttgtagg
caggataaggcgttcacgccgcatccggcattgactgcaaacttaacgctgctcgtagcg
tttaaacaccagttcgccattgctggaggaatcttcatcaaagaagtaaccttcgctatt
aaaaccagtcagttgctctggtttggtcagccgattttcaataatgaaacgactcatcag
accgcgtgctttcttagcgtagaagctgatgatcttaaatttgccgttcttctcatcgag
gaacaccggcttgataatctcggcattcaatttcttcggcttcaccgatttaaaatactc
END
    $str =~ s/\s+//g;
    return $str;
}

sub get_rna_test_data
{
    return 'tggcattgctcgcggtaaatttaccgaagcacagtttgaaacgctgaccgagtggatggactggtcgctggcggaccgagatgtcgatctggatggtatctattattgcccgcatcatccgcagggtagtgttgaagagtttcgccaggtctgcgattgccgcaaaccacatccggggatgcttttgtcagcacgcgattatttgcatattgatatggccgcttcttatatggtgggcgataaattagaagatatgcaggcagcggttgcggcgaacgtgggaacaaaagtgctggtgcgtacgggtaaacctattacgcctgaagcagaaaacgcggcggattgggtgttaaatagcctggcagacctgccgcaagcgataaaaaagcagcaaaaaccggcacaatgattaaaagatgagcggttgaaataaaaatgcatttttccgcttgtcttcctgagccgactccctataatgcgcctccatcgacacggcggatgtgaatcacttcacacaaacagccggttcggttgaagagaaaaatcctgaaattcagggttgactctgaaagaggaaagcgtaatatacgccacctcgcgacagtgagctgaaagccgcgtcgcaactgctctttaacaatttatcagacaatctgtgtgggcactcgaagatacggattcttaacgtcgcaagacgaaaaatgaataccaagtctcaagagtgaacacgtaattcattacaaagtttaattctttgagcatcaaacttttaaattgaagagtttgatcatggctcagattgaacgctggcggcaggcctaacacatgcaagtcgaacggtaacaggaagaagcttgcttctttgctgacgagtggcggacgggtgagtaatgtctgggaaactgcctgatggagggggataactactggaaacggtagctaataccgcataacgtcgcaagaccaaagagggggaccttcgggcctcttgccatcggatgtgcccagatgggattagctagtaggtggggtaacggctcacctaggcgacgatccctagctggtctgagaggatgaccagccacactggaactgagacacggtccagactcctacgggaggcagcagtggggaatattgcacaatgggcgcaagcctgatgcagccatgccgcgtgtatgaagaaggccttcgggttgtaaagtactttcagcggggaggaagggagtaaagttaatacctttgctcattgacgttacccgcagaagaagcaccggctaactccgtgccagcagccgcggtaatacggagggtgcaagcgttaatcggaattactgggcgtaaagcgcacgcaggcggtttgttaagtcagatgtgaaatccccgggctcaacctgggaactgcatctgatactggcaagcttgagtctcgtagaggggggtagaattccaggtgtagcggtgaaatgcgtagagatctggaggaataccggtggcgaaggcggccccctggacgaagactgacgctcaggtgcgaaagcgtggggagcaaacaggattagataccctggtagtccacgccgtaaacgatgtcgacttggaggttgtgcccttgaggcgtggcttccggagctaacgcgttaagtcgaccgcctggggagtacggccgcaaggttaaaactcaaatgaattgacgggggcccgcacaagcggtggagcatgtggtttaattcgatgcaacgcgaagaaccttacctggtcttgacatccacagaactttccagagatggattggtgccttcgggaactgtgagacaggtgctgcatggctgtcgtcagctcgtgttgtgaaatgttgggttaagtcccgcaacgagcgcaacccttatcttttgttgccagcggtccggccgggaactcaaaggagactgccagtgataaactggaggaaggtggggatgacgtcaagtcatcatggcccttacgaccagggctacacacgtgctacaatggcgcatacaaagagaagcgacctcgcgagagcaagcggacctcataaagtgcgtcgtagtccggattggagtctgcaactcgactccatgaagtcggaatcgctagtaatcgtggatcagaatgccacggtgaatacgttcccgggccttgtacacaccgcccgtcacaccatgggagtgggttgcaaaagaagtaggtagcttaaccttcgggagggcgcttaccactttgtgattcatgactggggtgaagtcgtaacaaggtaaccgtaggggaacctgcggttggatcacctccttaccttaaagaagcgtactttgcagtgctcacacagattgtctgatgaaaatgagcagtaaaacctctacaggcttgtagctcaggtggttagagcgcacccctgataagggtgaggtcggtggttcaagtccactcaggcctaccaaatttgcacggcaaatttgaagaggttttaactacatgttatggggctatagctcagctgggagagcgcctgctttgcacgcaggaggtctgcggttcgatcccgcatagctccaccatctctgtagtggttaaataaaaaatacttcagagtgtacctgcaaaggttcactgcgaagttttgctctttaaaaatctggatcaagctgaaaattgaaacactgaacaatgaaagttgttcgtgagtctctcaaattttcgcaacacgatgatggatcgcaagaaacatcttcgggttgtgaggttaagcgactaagcgtacacggtggatgccctggcagtcagaggcgatgaaggacgtgctaatctgcgataagcgtcggtaaggtgatatgaaccgttataaccggcgatttccgaatggggaaacccagtgtgtttcgacacactatcattaactgaatccataggttaatgaggcgaaccgggggaactgaaacatctaagtaccccgaggaaaagaaatcaaccgagattcccccag';
}
