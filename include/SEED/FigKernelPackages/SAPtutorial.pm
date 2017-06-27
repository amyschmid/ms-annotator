#!/usr/bin/perl -w
use strict;

=head1 Using the Sapling Server -- A Tutorial

=head2 What Is the Sapling Server?

The B<Sapling Server> is a web service that allows you to access data stored in
the Sapling database, a large-scale MySQL database of genetic data. The Sapling
database contains data on public genomes imported from I<RAST> (L<http://rast.nmpdr.org>)
and curated by the annotation team of the Fellowship for Interpretation of
Genomes.

The L<SAPserver> package wraps calls to the Sapling Server so that you can use
them in your PERL program.

All Sapling Server services are documented in the L<SAP> module. Each method has
a signature like

    my $document = $sapObject->taxonomy_of($args);

where C<$document> is usually a hash reference and C<$args> is B<always> a hash
reference. The method description includes a section called I<Parameter Hash
Fields> that describes the fields in C<$args>. For example, L<SAP/taxonomy_of>
has a field called C<-ids> that is to be a list of genome IDs and an optional
field called C<-format> that indicates whether you want taxonomy groups
represented by numbers, names, or both. To call the I<taxonomy_of> service,
you create a B<SAPserver> object and call a method with the same name as the
service.

    use strict;
    use SAPserver;

    my $sapServer = SAPserver->new();
    my $resultHash = $sapServer->taxonomy_of({ -ids => ['360108.3', '100226.1'],
                                               -format => 'names' });
    for my $id (keys %$resultHash) {
        my $taxonomy = $resultHash->{$id};
        print "$id: " . join(" ", @$taxonomy) . "\n";
    }

The output from this program (reformatted slightly for readability) is shown below.

    360108.3: Bacteria, Proteobacteria, delta/epsilon subdivisions, Epsilonproteobacteria,
              Campylobacterales, Campylobacteraceae, Campylobacter, Campylobacter jejuni,
              Campylobacter jejuni subsp. jejuni, Campylobacter jejuni subsp. jejuni 260.94
              
    100226.1: Bacteria, Actinobacteria, Actinobacteria (class), Actinobacteridae,
              Actinomycetales, Streptomycineae, Streptomycetaceae, Streptomyces,
              Streptomyces coelicolor, Streptomyces coelicolor A3(2)

For convenience, you can specify the parameters as a simple hash rather
than a hash reference. So, for example, the above I<taxonomy_of> call could
also be written like this.

    my $resultHash = $sapServer->taxonomy_of(-ids => ['360108.3', '100226.1'],
                                             -format => 'names');

=head2 A Simple Example: Genome Taxonomies

Let's look at a simple program that pulls all the complete genomes from the
database and displays their representative genomes plus their texonomies in name
format.

Three Sapling Server methods are needed to perform this function.

=over 4

=item *

L<SAP/all_genomes> to get the list of genome IDs.

=item *

L<SAP/taxonomy_of> to get the genome taxonomies.

=item *

L<SAP/representative> to get the representative genome IDs.

=back

The program starts by connecting to the Sapling Server itself.

    use strict;
    use SAPserver;
    
    my $sapServer = SAPserver->new();

Now we use I<all_genomes> to get a list of the complete genomes.
I<all_genomes> will normally return B<all> genomes, but we use the
C<-complete> option to restrict the output to those that are complete.

    my $genomeIDs = $sapServer->all_genomes(-complete => 1);

All we want are the genome IDs, so we use a PERL trick to convert the
hash reference in C<$genomeIDs> to a list reference.

    $genomeIDs = [ keys %$genomeIDs ];

Now we ask for the representatives and the taxonomies.

    my $representativeHash = $sapServer->representative(-ids => $genomeIDs);
    my $taxonomyHash = $sapServer->taxonomy_of(-ids => $genomeIDs,
                                               -format => 'names');

Our data is now contained in a pair of hash tables. The following loop
stiches them together to produce the output.

    for my $genomeID (@$genomeIDs) {
        my $repID = $representativeHash->{$genomeID};
        my $taxonomy = $taxonomyHash->{$genomeID};
        # Format the taxonomy string.
        my $taxonomyString = join(" ", @$taxonomy);
        # Print the result.
        print join("\t", $genomeID, $repID, $taxonomyString) . "\n";
    }

An excerpt from the output of this script is shown below. The first column contains
a genome ID, the second contains the representative genome's ID, and the third is
the full taxonomy. Note that the two genomes with very close taxonomies have the
same representative genome: this is the expected behavior.

    221109.1    221109.1    Bacteria Firmicutes Bacilli Bacillales Bacillaceae Oceanobacillus Oceanobacillus iheyensis Oceanobacillus iheyensis HTE831
    204722.1    204722.1    Bacteria Proteobacteria Alphaproteobacteria Rhizobiales Brucellaceae Brucella Brucella suis Brucella suis 1330
    391037.3    369723.3    Bacteria Actinobacteria Actinobacteria (class) Actinobacteridae Actinomycetales Micromonosporineae Micromonosporaceae Salinispora Salinispora arenicola Salinispora arenicola CNS205
    339670.3    216591.1    Bacteria Proteobacteria Betaproteobacteria Burkholderiales Burkholderiaceae Burkholderia Burkholderia cepacia complex Burkholderia cepacia Burkholderia cepacia AMMD
    272560.3    216591.1    Bacteria Proteobacteria Betaproteobacteria Burkholderiales Burkholderiaceae Burkholderia pseudomallei group Burkholderia pseudomallei Burkholderia pseudomallei K96243
    262768.1    262768.1    Bacteria Firmicutes Mollicutes Acholeplasmatales Acholeplasmataceae Candidatus Phytoplasma Candidatus Phytoplasma asteris Onion yellows phytoplasma Onion yellows phytoplasma OY-M
    272624.3    272624.3    Bacteria Proteobacteria Gammaproteobacteria Legionellales Legionellaceae Legionella Legionella pneumophila Legionella pneumophila subsp. pneumophila Legionella pneumophila subsp. pneumophila str. Philadelphia 1
    150340.3    150340.3    Bacteria Proteobacteria Gammaproteobacteria Vibrionales Vibrionaceae Vibrio Vibrio sp. Ex25
    205914.1    205914.1    Bacteria Proteobacteria Gammaproteobacteria Pasteurellales Pasteurellaceae Histophilus Histophilus somni Haemophilus somnus 129PT
    393117.3    169963.1    Bacteria Firmicutes Bacilli Bacillales Listeriaceae Listeria Listeria monocytogenes Listeria monocytogenes FSL J1-194
    203119.1    203119.1    Bacteria Firmicutes Clostridia Clostridiales Clostridiaceae Clostridium Clostridium thermocellum Clostridium thermocellum ATCC 27405
    380703.5    380703.5    Bacteria Proteobacteria Gammaproteobacteria Aeromonadales Aeromonadaceae Aeromonas Aeromonas hydrophila Aeromonas hydrophila subsp. hydrophila Aeromonas hydrophila subsp. hydrophila ATCC 7966
    259536.4    259536.4    Bacteria Proteobacteria Gammaproteobacteria Pseudomonadales Moraxellaceae Psychrobacter Psychrobacter arcticus Psychrobacter arcticus 273-4

The Sapling Server processes lists of data (in this case a list of genome IDs)
so that you can minimize the overhead of sending requests across the web. You
can, however, specify a single ID instead of a list to a method call, and
this would allow you to structure your program with a more traditional loop, as
follows. To make this process simpler, you construct the Sapling Server object
in I<singleton mode>. In singleton mode, when you pass in only a single ID,
you get back an actual result instead of a hash reference.

    use strict;
    use SAPserver;
    
    my $sapServer = SAPserver->new(singleton => 1);
    my $genomeIDs = $sapServer->all_genomes(-complete => 1);
    $genomeIDs = [ keys %$genomeIDs ];
    for my $genomeID (@$genomeIDs) {
        my $repID = $sapServer->representative(-ids => $genomeID);
        my $taxonomy = $sapServer->taxonomy_of(-ids => $genomeID,
                                               -format => 'names');
        # Format the taxonomy string.
        my $taxonomyString = join(" ", @$taxonomy);
        # Print the result.
        print join("\t", $genomeID, $repID, $taxonomyString) . "\n";
    }

At this point there is a risk that you are bewildered by all the options we've
presented-- hashes, hash references, singleton mode-- however, the goal here is
to provide a facility that will fit comfortably with different programming
styles. The server software tries to figure out how you want to use it and
adjusts accordingly.

=head2 Specifying Gene IDs

Many of the Sapling Server services return data on genes (a term we use rather
loosely to include any kind of genetic I<locus> or I<feature>). The standard
method for identifying a gene is the I<FIG ID>, an identifying string that
begins with the characters C<fig|> and includes the genome ID, the gene type,
and an additional number for uniqueness. For example, the FIG ID
C<fig|272558.1.peg.203> describes a protein encoding gene (I<peg>) in
Bacillus halodurans C-125 (I<272558.1>).

Frequently, however, you will have a list of gene IDs from some other
database (e.g. I<NCBI>, I<UniProt>) or in a community format such as Locus Tags
or gene names. Most services that take gene IDs as input allow you to specify a
C<-source> option that indicates the type of IDs being used. The acceptable
formats are as follows.

=over 4

=item CMR

I<Comprehensive Microbial Resource> (L<http://cmr.jcvi.org>) ID. The CMR IDs for
C<fig|272558.1.peg.203> are C<10172815> and C<NTL01BH0204>.

=item GENE

Common Gene name. Often, these correspond to a large number of specified genes.
For example, C<accD>, which identifies the Acetyl-coenzyme A carboxyl
transferase beta chain, corresponds to 58 specific genes in the database.

=item GeneID

Common gene number. The common gene number for C<fig|272558.1.peg.203> is
C<891745>.

=item KEGG

I<Kyoto Encyclopedia of Genes and Genomes> (L<http://www.genome.jp/kegg>) identifier.
For example, the KEGG identifier for C<fig|158878.1.peg.2821> is C<sav:SAV2628>.

=item LocusTag

Common locus tag. For example, the locus tag of C<fig|243160.4.peg.200> is
C<BMA0002>.

=item NCBI

I<NCBI> (L<http://www.ncbi.nlm.nih.gov>) number. The NCBI ID numbers for
C<fig|272558.1.peg.203> are C<10172815>, C<15612766>, and C<81788207>.

=item RefSeq

I<NCBI> (L<http://www.ncbi.nlm.nih.gov>) reference sequence identifier. The RefSeq
identifier for C<fig|272558.1.peg.203> is C<NP_241069.1>.

=item SEED

FIG identifier. This is the default option.

=item SwissProt

I<SwissProt> (L<http://www.expasy.ch/sprot>) identifier. For example, the SwissProt
identifier for C<fig|243277.1.peg.3952> is C<O31153>.

=item UniProt

I<UniProt> (L<http://www.uniprot.org>) identifier. The UniProt identifiers for
C<fig|272558.1.peg.203> are C<Q9KGA9> and C<Q9KGA9_BACHD>.

=back

You can also mix identifiers of different types by specifying C<mixed>
for the source type. In this case, however, care must be taken, because the same
identifier can have different meanings in different databases. You can also
specify C<prefixed> to use IDs with type prefixes. For RefSeq and SEED identifiers,
the prefixes are built-in; however, for other identifiers, the following
prefixes are used.

=over 4

=item CMR

C<cmr|> -- for example, C<cmr|10172815> and C<cmr|NTL01BH0204>.

=item GENE (Common gene name)

C<GENE:> -- for example, C<GENE:accD>

=item GeneID (Common gene number)

C<GeneID:> -- for example, C<GeneID:891745>

=item KEGG

C<kegg|> -- for example, C<kegg|sav:SAV2628>

=item LocusTag

C<LocusTag:> -- for example, C<LocusTag:ABK38410.1>

=item NBCI

C<gi|> -- for example, C<gi|10172815>, C<gi|15612766>, C<gi|81788207>.

=item UniProt

C<uni|> -- for example, C<uni|Q9KGA9>, C<uni|Q9KGA9_BACHD>

=back

=head2 Two Normal-Mode Examples

The following examples use the Sapling Server in normal mode: that is, data
is sent to the server in batches and the results are stitched together
afterward. In this mode there is significantly reduced overhead, but there is
also a risk that the server request might time out. If this happens, you may
want to consider breaking the input into smaller batches. At some point, the
server system will perform sophisticated flow control to reduce the risk of
timeout errors, but we are not yet there.

=head3 Retrieving Functional Roles

There are two primary methods for retrieving functional roles.

=over 4

=item *

L<SAP/ids_to_functions> returns the current functional assignment of a gene.

=item *

L<SAP/ids_to_subsystems> returns the subsystems and roles of a gene.

=back

In both cases, the list of incoming gene IDs is given as a list via the C<ids>
parameter. It is assumed the IDs are FIG identifiers, but the C<source> parameter
can be used to specify a different ID type (see L</Specifying Gene IDs>).

B<ids_to_functions> provides the basic functional role. Almost every gene in the
system will return a result with this method. The following example program
reads a file of UniProt IDs and produces their functional roles.  Note that
we're assuming the file is a manageable size: since we're submitting the entire
file at once, we risk a timeout error if it's too big.

    use strict;
    use SAPserver;
    
    my $sapServer = SAPserver->new();
    # Read all the gene IDs.
    my @genes = map { chomp; $_ } <STDIN>;
    # Compute the functional roles.
    my $results = $sapServer->ids_to_functions(-ids => \@genes, -source => 'UniProt');
    # Loop through the genes.
    for my $gene (@genes) {
        # Did we find a result?
        my $role = $results->{$gene};
        if (defined $role) {
            # Yes, print it.
            print "$gene\t$role\n";
        } else {
            # No, emit a warning.
            print STDERR "$gene was not found.\n";
        }
    }

Sample output from this script is shown below. Note that one of the input IDs
was not found.

    HYPA_ECO57      [NiFe] hydrogenase nickel incorporation protein HypA
    17KD_RICBR      rickettsial 17 kDa surface antigen precursor
    18KD_MYCLE      18 KDA antigen (HSP 16.7)
    P72620_SYNY3    [NiFe] hydrogenase metallocenter assembly protein HypD
    1A14_ARATH      1-aminocyclopropane-1-carboxylate synthase 4 / ACC synthase 4 (ACS4) / identical to gi:940370 [GB:U23481]; go_function: 1-aminocyclopropane-1-carboxylate synthase activity [goid 0016847]; go_process: ethylene biosynthesis [goid 0009693]; go_process: response to auxin stimulus [goid 0009733]
    Q2RXN5_RHORT    [NiFe] hydrogenase metallocenter assembly protein HypE
    O29118          Glutamate N-acetyltransferase (EC 2.3.1.35) / N-acetylglutamate synthase (EC 2.3.1.1)
    Q8PZM3          tRNA nucleotidyltransferase (EC 2.7.7.25)

    Q8YY27_ANASP was not found.

B<ids_to_subsystems> returns roles in subsystems. Roles in subsystems have
several differences from general functional roles. Only half of the genes in the
database are currently associated with subsystems.A single gene may be in In
addition, multiple subsystems and may have multiple roles in a subsystem.

As a result, instead of a single string per incoming gene, B<ids_to_subsystems>
returns a list. Each element of the list consists of the role name followed by
the subsystem name. This makes the processing of the results a little more
complex, because we have to iterate through the list. An empty list indicates
the gene is not in a subsystem (although it could also indicate the gene was
not found).

    use SAPserver;
    
    my $sapServer = SAPserver->new();
    # Read all the gene IDs.
    my @genes = map { chomp; $_ } <STDIN>;
    # Compute the functional roles.
    my $results = $sapServer->ids_to_subsystems(-ids => \@genes, -source => 'UniProt');
    # Loop through the genes.
    for my $gene (@genes) {
        # Did we find a result?
        my $roleData = $results->{$gene};
        if (! @$roleData) {
            # Not in a subsystem: emit a warning.
            print STDERR "$gene is not in a subsystem.\n";
        } else {
            # Yes, print the entries.
            for my $ssData (@$roleData) {
                print "$gene\t$ssData->[0]\t($ssData->[1])\n"
            }
        }
    }

Sample output from this script is shown below. In this case, four of the input IDs
failed to find a result; however, two of them (C<O29118> and C<Q8PZM3>) produced multiple
results. 

    HYPA_ECO57      [NiFe] hydrogenase nickel incorporation protein HypA    (NiFe hydrogenase maturation)
    P72620_SYNY3    [NiFe] hydrogenase metallocenter assembly protein HypD  (NiFe hydrogenase maturation)
    Q2RXN5_RHORT    [NiFe] hydrogenase metallocenter assembly protein HypE  (NiFe hydrogenase maturation)
    O29118  N-acetylglutamate synthase (EC 2.3.1.1) (Arginine Biosynthesis extended)
    O29118  Glutamate N-acetyltransferase (EC 2.3.1.35)     (Arginine Biosynthesis extended)
    O29118  N-acetylglutamate synthase (EC 2.3.1.1) (Arginine Biosynthesis)
    O29118  Glutamate N-acetyltransferase (EC 2.3.1.35)     (Arginine Biosynthesis)
    Q8PZM3  tRNA nucleotidyltransferase (EC 2.7.7.25)       (CBSS-316057.3.peg.1294)
    Q8PZM3  tRNA nucleotidyltransferase (EC 2.7.7.25)       (tRNA nucleotidyltransferase)

    17KD_RICBR is not in a subsystem.
    Q8YY27_ANASP is not in a subsystem.
    18KD_MYCLE is not in a subsystem.
    1A14_ARATH is not in a subsystem.

=head3 Genes in Subsystems for Genomes

This next example finds all genes in subsystems for a specific genome. We will
perform this operation in two phases. First, we will find the subsystems for
each genome, and then the genes for those subsystems. This requires two Sapling
Server functions.

=over 4

=item *

L<SAP/genomes_to_subsystems> returns a list of the subsystems for each
specified genome.

=item *

L<SAP/ids_in_subsystems> returns a list of the genes in each listed
subsystem for a specified genome.

=back

Our example program will loop through the genome IDs in an input file. For
each genome, it will call I<genomes_to_subsystems> to get the subsystem list,
and then feed the list to I<ids_in_subsystems> to get the result.

L<SAP/ids_in_subsystems> returns gene IDs rather than taking them as input.
Like L<SAP/ids_to_subsystems> and L<SAP/ids_to_functions>, it takes a C<source>
parameter that indicates the type of ID desired (e.g. C<NCBI>, C<CMR>, C<LocusTag>).
In this case, however, the type describes how the gene IDs will be formatted in
the output rather than the type expected upon input. If a gene does not have an
ID for a particular source type (e.g. C<fig|100226.1.peg.3361> does not have a
locus tag), then the FIG identifier is used. The default source type (C<SEED>)
means that FIG identifiers will be used for everything.

The program is given below.

    use strict;
    use SAPserver;
    
    my $sapServer = SAPserver->new();
    # Loop through the input file. Note that this loop will stop on the first
    # blank line.
    while (my $genomeID = <STDIN>) {
        chomp $genomeID;
        # Get the subsystems for this genome.
        my $subHash = $sapServer->genomes_to_subsystems(-ids => $genomeID);
        # The data returned for each genome (and in our case there's only one)
        # includes the subsystem name and the variant code. The following
        # statement strips away the variant codes, leaving only the subsystem
        # names.
        my $subList = [ map { $_->[0] } @{$subHash->{$genomeID}} ];
        # Ask for the genes in each subsystem, using NCBI identifiers.
        my $roleHashes = $sapServer->ids_in_subsystems(-subsystems => $subList,
                                                       -genome => $genomeID,
                                                       -source => 'NCBI',
                                                       -roleForm => 'full');
        # The hash maps each subsystem ID to a hash of roles to lists of feature
        # IDs. We therefore use three levels of nested loops to produce our
        # output lines. At the top level we have a hash mapping subsystem IDs
        # to role hashes.
        for my $subsystem (sort keys %$roleHashes) {
            my $geneHash = $roleHashes->{$subsystem};
            # The gene hash maps each role to a list of gene IDs.
            for my $role (sort keys %$geneHash) {
                my $geneList = $geneHash->{$role};
                # Finally, we loop through the gene IDs.
                for my $gene (@$geneList) {
                    print "$genomeID\t$gene\t$subsystem\t$role\n";
                }
            }
        }
    }

An excerpt of the output is shown here.

    360108.3    85840651    Queuosine-Archaeosine Biosynthesis          Queuosine Biosynthesis QueC ATPase
    360108.3    85841812    Queuosine-Archaeosine Biosynthesis          Queuosine Biosynthesis QueE Radical SAM
    360108.3    85841520    Queuosine-Archaeosine Biosynthesis          Queuosine biosynthesis QueD, PTPS-I
    360108.3    85841162    Queuosine-Archaeosine Biosynthesis          S-adenosylmethionine:tRNA ribosyltransferase-isomerase (EC 5.-.-.-)
    360108.3    85842244    Queuosine-Archaeosine Biosynthesis          tRNA-guanine transglycosylase (EC 2.4.2.29)
    360108.3    85841653    Quinate degradation                         3-dehydroquinate dehydratase II (EC 4.2.1.10)
    360108.3    85840760    RNA polymerase bacterial                    DNA-directed RNA polymerase alpha subunit (EC 2.7.7.6)
    360108.3    85841269    RNA polymerase bacterial                    DNA-directed RNA polymerase beta subunit (EC 2.7.7.6)
    360108.3    85841348    RNA polymerase bacterial                    DNA-directed RNA polymerase beta' subunit (EC 2.7.7.6)
    360108.3    85841887    RNA polymerase bacterial                    DNA-directed RNA polymerase omega subunit (EC 2.7.7.6)
    360108.3    85841283    RNA processing and degradation, bacterial   3'-to-5' exoribonuclease RNase R
    360108.3    85840820    RNA processing and degradation, bacterial   Ribonuclease III (EC 3.1.26.3)
    360108.3    85842272    Recycling of Peptidoglycan Amino Acids      Aminoacyl-histidine dipeptidase (Peptidase D) (EC 3.4.13.3)

The I<ids_in_subsystems> service has several useful options for changing the nature
of the output. For example, in the above program each role is represented by a
full description (C<roleForm> set to C<full>). If you don't need the roles, you
can specify C<none> for the role form. You can also request that the gene IDs
be returned in a comma-separated list instead of a list data structure. These
two changes can drastically simplify the above program.

    use strict;
    use SAPserver;
    
    my $sapServer = SAPserver->new();
    # Loop through the input file. Note that this loop will stop on the first
    # blank line.
    while (my $genomeID = <STDIN>) {
        chomp $genomeID;
        # Get the subsystems for this genome.
        my $subHash = $sapServer->genomes_to_subsystems(-ids => $genomeID);
        # The data returned for each genome (and in our case there's only one)
        # includes the subsystem name and the variant code. The following
        # statement strips away the variant codes, leaving only the subsystem
        # names.
        my $subList = [ map { $_->[0] } @{$subHash->{$genomeID}} ];
        # Ask for the genes in each subsystem, using NCBI identifiers.
        my $genesHash = $sapServer->ids_in_subsystems(-subsystems => $subList,
                                                      -genome => $genomeID,
                                                      -source => 'NCBI',
                                                      -roleForm => 'none',
                                                      -grouped => 1);
        # The hash maps each subsystem ID to a comma-delimited list of gene IDs.
        for my $subsystem (sort keys %$genesHash) {
            my $genes = $genesHash->{$subsystem};
            print "$genomeID\t$subsystem\t$genes\n";
        }
    }

The sample output in this case looks quite different. The role information is missing,
and all the data for a subsystem is in a single line.

    360108.3    Queuosine-Archaeosine Biosynthesis          85841622, 85841791, 85840661, 85841162, 85841520, 85842244, 85840651, 85841812
    360108.3    Quinate degradation                         85841653
    360108.3    RNA polymerase bacterial                    85840760, 85841269, 85841348, 85841887
    360108.3    RNA processing and degradation, bacterial   85840820, 85841283
    360108.3    Recycling of Peptidoglycan Amino Acids      85842019, 85842272

=head2 A More Complicated Example: Operon Upstream Regions

In this example we'll string several services together to perform a more
complex task: locating the upstream regions of operons involved in a particular
metabolic pathway. The theory is that we can look for a common pattern in
these regions.

A metabolic pathway is a subsystem, so we'll enter our database via the
subsystems. To keep the data manageable, we'll limit our results to
specific genomes. The program we write will take as input a subsystem name
and a file of genome IDs.

The worst part of the task is finding the operon for a gene. This involves
finding all the genes in a neighborhood and isolating the ones that point in
the correct direction. Fortunately, there is a Sapling Server function--
L<SAP/make_runs>-- that specifcally performs this task.

To start our program, we create a L<SAPserver> object and pull the subsystem
name from the command-line parameters. This program is going to be doing a
lot of complicated, long-running stuff, so we'll usually want to deal with one
result at a time. To facilitate that, we construct the server helper in
singleton mode.

    use strict;
    use SAPserver;
    
    my $sapServer = SAPserver->new(singleton => 1);
    # Get the subsystem name.
    my $ssName = $ARGV[0];

Our main loop will read through the list of genomes from the standard input
and call a method I<PrintUpstream> to process each one. We're going to be a bit
cheesy here and allow our genome loop to stop on the first blank line.

    while (my $genomeID = <STDIN>) {
        chomp $genomeID;
        PrintUpstream($sapServer, $ssName, $genomeID);
    }

Now we need to write I<PrintUpstream>. Its first task is to find all the
genes in the genome that belong to the subsystem. A single call to
L<SAP/ids_in_subsystems> will get this information. We then feed the
results into L<SAP/make_runs> to get operons and call L<SAP/upstream> for
each operon. The program is given below.

    sub PrintUpstream {
        my ($sapServer, $ssName, $genomeID) = @_;
        # Because we specify "roleForm => none", we get back one long
        # gene list.
        my $geneList = $sapServer->ids_in_subsystems(-subsystems => $ssName,
                                                     -genome => $genomeID,
                                                     -roleForm => 'none');
        # Convert the gene list to a comma-delimited string.
        my $geneString = join(", ", @$geneList);
        # Get a list of operons.
        my $opList = $sapServer->make_runs(-groups => $geneString);
        # Loop through the operons.
        for my $opString (@$opList) {
            # Get the first feature's ID.
            my ($front) = split /\s*,/, $opString, 2;
            # Grab its upstream region. We'll include the operon string as the
            # comment text.
            my $fasta = $sapServer->upstream(-ids => $front,
                                             -comments => { $front => $opString },
                                             -skipGene => 1);
            # Print the result.
            print "$fasta\n";
        }
    }


=cut

1;
