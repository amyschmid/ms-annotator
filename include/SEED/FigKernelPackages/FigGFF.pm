#
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
#

#
# FIG GFF utilities.
#

#
# A GFFWriter handles the generation of GFF files from SEED data structures.
#

package FigGFF;

use strict;

use base qw(Exporter);
use vars qw(@EXPORT);
@EXPORT = qw(map_seed_alias_to_dbxref map_dbxref_to_seed_alias);

#
# General GFF-related routines.
#


#
# Alias translation.
#
# These routines map between the SEED aliases and the standard
# dbxref names as defined here:
#
# ftp://ftp.geneontology.org/pub/go/doc/GO.xrf_abbs
#
# In particular:
#
# abbreviation: NCBI_gi
# database: NCBI databases.
# object: Identifier.
# example_id: NCBI_gi:10727410
# generic_url: http://www.ncbi.nlm.nih.gov/
# url_syntax:
# url_example: http://www.ncbi.nlm.nih.gov:80/entrez/query.fcgi?cmd=Retrieve&db=nucleotide&list_uids=10727410&dopt=GenBank
# 
# abbreviation: NCBI_NP
# database: NCBI RefSeq.
# object: Protein identifier.
# example_id: NCBI_NP:123456
# generic_url: http://www.ncbi.nlm.nih.gov/
# url_syntax:
# 
# abbreviation: KEGG
# database: Kyoto Encyclopedia of Genes and Genomes.
# generic_url: http://www.genome.ad.jp/kegg/

sub map_seed_alias_to_dbxref
{
    my($alias) = @_;

    $_ = $alias;
    if (/^NP_(\d+.*)/)
    {
        return "NCBI_NP:$1";
    }
    elsif (/^NM_(\d+.*)/)
    {
        return "NCBI_NM:$1";
    }
    elsif (/^gi\|(\d+)/)
    {
        return "NCBI_gi:$1";
    }
    elsif (/^kegg\|(\S+):(\S+)/)
    {
        return "KEGG:$1 $2";
    }
    elsif (/^uni\|(\S+)/)
    {
        return "UniProt:$1";
    }
    elsif (/^sp\|(\S+)/)
    {
        return "Swiss-Prot:$1";
    }

    return undef;
}

#
# And map back again.
#

sub map_dbxref_to_seed_alias
{
    my($dbxref) = @_;

    # if it is not a valid xref just return it
    return $dbxref unless $dbxref =~ m/:/;
    
    my($type, $ref) = split(/:/, $dbxref, 2);

    if (lc($type) eq "ncbi_np")
    {
        return "$ref";
    }
    elsif (lc($type) eq "ncbi_nm")
    {
        return "$ref";
    }
    elsif (lc($type) eq "ncbi_pid")
    {
        return "$ref";
    }
    elsif (lc($type) eq "ncbi_gi")
    {
        return "gi|$ref";
    }
    elsif (lc($type) eq "kegg")
    {
        $ref =~ s/ /:/;
        return "kegg|$ref";
    }
    elsif (lc($type) eq "uniprot")
    {
        return "uni|$ref";
    }
    elsif (lc($type) eq "swiss-prot")
    {
        return "sp|$ref";
    }

    return $dbxref; # just return itself if we don't know what it is.
}

package GFFWriter;

use strict;
use FIG;
use FigGFF;

use Carp;
use URI::Escape;
use Data::Dumper;

sub new
{
    my($class, $fig, %options) = @_;

    my $default_options = {
        escapespace => 0,
        outputfasta => 1,
        linelength => 60,
    };

    map { $default_options->{$_} = $options{$_} } keys(%options);

    # added contig_start_cache and contig_end_cache because we have something like
    # sequence-region   contigname      1       10000
    # in general we will set contig_start_cache == 1
    # and contig_end_cache == contig_length_cache
   
    my $self = {
        options => $default_options,
        contig_length_cache => {},
        contig_start_cache  => {},
        contig_end_cache    => {},
        fig => $fig,
    };

    return bless $self, $class;
}


=head1 gff3_for_feature

Returns the GFF3 information for a given feature.

The return is a pair ($contig_data, $fasta_sequences) that can be passed 
into write_gff3().

$contig_data is a hashref mapping a contig name to a list of GFF3 file lines
for the sequences in that contig.

=cut

sub gff3_for_feature
{
    my($self, $fid, $user, $user_note, $in_aliases, $in_loc) = @_;

    #
    # Options we need to figure out somehow.
    #
    my $options = $self->{options};
    
    my $escapespace = $options->{escapespace};
    my $outputfasta = $options->{outputfasta};

    my %outputtype;
    map { $outputtype{$_} = 1 } @{$options->{outputtype}};

    my $fastasequences = '';
    my $contig_data;
    my $linelength = $options->{linelength};

    my $beg = $self->{options}->{beg};
    my $end = $self->{options}->{end};

    my $fig = $self->{fig};

    #
    # Do this first to make sure that we really have a feature.
    #
    my @location = ref($in_loc) ? @$in_loc : $fig->feature_location($fid);
    if (@location == 0 or !defined($location[0]))
    {
        warn "No location found for feature $fid\n";
        return ({}, "");
    }
    
    ###########
    #
    # Begin figuring out the column 9 information about notes and aliases and GO terms
    # All the information is temporarily stored in @alias or @note, and at the end is joined
    # into $allnote
    #
    ###########

    #
    # the notes for the last column
    #
    my $note;
    #
    # all the aliases we are going to use
    #
    my @alias;
    my @xref;

    if ($options->{with_assignments})
    {
        my $func = $fig->function_of($fid, $user);
        if ($func) 
        {
            push @$note, ("Note=" . uri_escape($func));
        }
    }

    if ($options->{with_aliases})
    {
        # now find aliases
        my @feat_aliases = ref($in_aliases) ? @$in_aliases : $fig->feature_aliases($fid);
        foreach my $alias (@feat_aliases)
        {
            my $mapped = FigGFF::map_seed_alias_to_dbxref($alias);
            if ($mapped)
            {
                push(@xref, $mapped);
            }
            else
            {
                push(@alias, $alias);
            }
        }
    }
  
    # now just join all the aliases and put them into @$note so we can add it to the array
    if (@alias)
    {
        push @$note, "Alias=". join (",", map { uri_escape($_) } @alias);
    }

    #
    # If we have user note passed in, add it.
    #

    if ($user_note)
    {
        push @$note, $user_note;
    }
 
    # the LAST thing I am going to add as a note is the FIG id so that I can grep it out easily
    #
    # for now, make SEED xref the first in the list so we can search for DBxref=SEEd
    #

    unshift(@xref, "SEED:$fid");

    push(@$note, "Dbxref=" . join(",", map { uri_escape($_) } @xref));
  
    # finally join all the notes into a long string that can be added as column 9
    my $allnotes;
    $allnotes = join ";", @$note;
  
    # do we want to convert '%20' to  ' '
    unless ($escapespace)
    {
        $allnotes =~ s/\%20/ /g;
    }
  
    ###########
    #
    # End figuring out the column 9 information about notes and aliases and GO terms
    #
    ###########
 
    #
    # Cache contig  lengths.
    #
    my $len = $self->{contig_length_cache};

    my $genome = $fig->genome_of($fid);
    
    foreach my $loc (@location)
    {
        $loc =~ /^(.*)\_(\d+)\_(\d+)$/;
        my ($contig, $start, $stop) = ($1, $2, $3);
        my $original_contig=$contig;

        #
        # the contig name must be escaped
        #
        $contig = uri_escape($contig);

        #my $contig_key = "$genome:$contig";
        my $contig_key = $contig;

        unless (defined $len->{$contig})
        {
            $len->{$contig}=$fig->contig_ln($genome, $original_contig);
        }
        my $strand='+';

        #
        # These were bounds-checking for dumping all of a genome.
        #
        #next if (defined $beg && ($start < $beg || $stop < $beg));
        #next if (defined $end && ($start > $end || $stop > $end));
   
        if ($start > $stop)
        {
            ($start, $stop, $strand)=($stop, $start, '-');
        }
        elsif ($start == $stop)
        {
            $strand=".";
        }
   
        my $type=$fig->ftype($fid);
   
        if ($type eq "peg")
        {
            # it is a protein coding gene
            # create an artificial id that is just the fid.(\d+) information
            # we will use this to create ids in the form cds.xxx; trn.xxxx; pro.xxx; gen.xxx;
            $fid =~ /\.peg\.(\d+)/;
            my $geneid=$1;
    
            ############## KLUDGE
            #
            # At the moment the outputs for transcript, gene, CDS, and pro are all the same.
            # This is clearly a kludge and wrong, but it will work at the moment
            #
    
            # defined some truncations
            my %trunc=(
                       "transcript"  => "trn",
                       "gene"        => "gen",
                       "protein"     => "pro",
                       "cds"         => "cds",
                      );
            
            # SO terms:
            # transcript: SO:0000673
            # gene: SO:0000704
            # cds: SO:0000316
            # protein:  NOT VALID: should be protein_coding_primary_transcript SO:0000120

            #
            # For now, we will only output CDS features, and include
            # the translation as an attribute (attribuute name is
            # translation_id, value is a key that corresponds to a FASTA
            # section at the end of the file).
            #

            my $type = "cds";

            my $protein_id = "pro.$geneid";
            my $cds_id = "cds.$geneid";
            
            # we want to store some sequences to be output
            if ($outputfasta)
            {
                my $addseq = $fig->get_translation($fid);

                #
                # the chomp is so that we know for sure to add the line back
                #
                $addseq =~ s/(.{$linelength})/$1\n/g;
                chomp($addseq); 
                $fastasequences .= ">$protein_id\n$addseq\n";

                $addseq = uc($fig->dna_seq($genome, @location));
                $addseq =~ s/(.{$linelength})/$1\n/g; chomp($addseq);

                $fastasequences .= ">$cds_id\n$addseq\n";

                $allnotes .= ";translation_id=$protein_id";
            }

            push (@{$contig_data->{$contig_key}},
                  (join "\t",
                   ($contig, "The SEED", $type, $start, $stop, ".", $strand, ".", "ID=$cds_id;$allnotes")));
        }
        elsif ($type eq "rna")
        {
            $fid =~ /\.rna\.(\d+)/;
            my $geneid=$1;
            #
            # tRNA is a valid SOFA term == SO:0000253       
            #
            my ($id, $type)=("rna.$geneid", "tRNA"); 
            if ($outputfasta)
            {
                my $addseq = $fig->dna_seq($genome, @location);
                $addseq =~ s/(.{$linelength})/$1\n/g; chomp($addseq);
                $fastasequences .= ">$id\n$addseq\n";
            }
            push (@{$contig_data->{$contig_key}}, (join "\t", ($contig, "The SEED", $type, $start, $stop, ".", $strand, ".", "ID=$id;$allnotes")));
        } # end the if type == rna
        else
        {
            die "Don't know what type: |$type| is";
        }
    }
    return ($contig_data, $fastasequences);
}

=head1 write_gff3

Write a set of gff3 per-contig data and fasta sequence data to a file or filehandle.

$genome is the genome these contigs are a part of.
$contig_list is a list of contig-data hashes as returned by gff_for_feature.
$fast_list is a list of fasta data strings.

=cut    

sub write_gff3
{
    my($self, $output, $genome, $contig_list, $fasta_list) = @_;

    my $fig = $self->{fig};

    my $len = $self->{contig_length_cache};
    my $fh;

    my $beg = $self->{options}->{beg};
    my $end = $self->{options}->{end};

    my $close_output;

    if (ref($output))
    {
        $fh = $output;
    }
    else
    {
        open($fh, ">$output") or confess "Cannot open output '$output': $!";
        $close_output = 1;
    }

    #
    # Build a data structure from the list of contigs
    # that has a list of lists of data per contig name.
    # (Do this so we don't copy all of the contig data itself, as it
    # could be quite large).
    #
    my %contigs;

    #
    # iterate over the given list of contig hashes.
    #
    for my $chash (@$contig_list)
    {
        #
        # Then for each contig in the individual contig hashes,
        # add the data list to %contigs.
        #
        for my $contig (keys %$chash)
        {
            push(@{$contigs{$contig}}, $chash->{$contig});
        }
    }

    foreach my $contig (sort keys %contigs)
    {
        print $fh "##sequence-region\t$contig\t";
        if (defined $beg) {
            print $fh "$beg\t";
        } else {
            print $fh "1\t";
        }
        if (defined $end) {
            print $fh "$end\n";
        } else {
            print $fh "$len->{$contig}\n";
        }
        for my $list (@{$contigs{$contig}})
        {
            print $fh join("\n", @$list), "\n";
        }
    }
    
    print $fh "##FASTA\n";
    # print out the cds and pro if we need them

    if ($self->{options}->{outputfasta})
    {
        for my $fastasequences (@$fasta_list)
        {
            print $fh $fastasequences;
        }
    }
 
    my $ll = $self->{options}->{linelength};
    foreach my $contig (sort keys %contigs)
    {
        my $len=$fig->contig_ln($genome, $contig);
        my $dna_seq=$fig->dna_seq($genome, $contig . "_1_". $len);
        if (defined $beg) 
        {
            unless (defined $end) {
                $end=$len;
            }
            $dna_seq = substr($dna_seq, $beg, $end);
        } 
        elsif (defined $end)
        {
            $beg=1;
            $dna_seq = substr($dna_seq, $beg, $end);
        }
  
        my $contig=uri_escape($contig);

        $dna_seq =~ s/(.{$ll})/$1\n/g;
        chomp($dna_seq); # just remove the last \n if there is one
        print $fh ">$contig\n$dna_seq\n";
    }

    close($fh) if $close_output;
}

package GFFParser;

use strict;
use URI::Escape;
use Carp;
use Data::Dumper;

use base qw(Class::Accessor);

__PACKAGE__->mk_accessors(qw(fig current_file features_by_genome feature_index features filename fasta_data contig_checksum genome_checksum contigs));
								       
my $count;

=pod

=head1 GFFParser

A parser for GFF3 files.

=head2 new()

Instantiate
my $fgff = GFFParser->new($fig);

=cut


#
# GFF file parser. Creates GFFFiles.
#

sub new
{
    my($class, $fig) = @_;

    my $self = {
        fig => $fig,
    };

    return bless($self, $class);
}

=head2 parse()

Takes a filename as an argument, and returns a file object.

The file object is a reference to a hash with the following keys:
	features_by_genome
		An array of all the features in this genome
	feature_index
		A hash with a key of the features by ID and the value being the GFFFeature
	features
		All the features in the genome, as an array with each element being a GFFFeature element
	filename
		The filename of the file that was parsed
	fasta_data
		A hash with the key being the ID and the value being the sequence
	
Not sure about:
	contig_checksum
	genome_checksum
	contigs
	fig

This is method now stores the data internally, so you can then access the data as:
	$fgff->features_by_genome->{}
	$fgff->feature_index->{}
	$fgff->features->{}
	$fgff->filename->{}
	$fgff->fasta_data->{}
	$fgff->contig_checksum->{}
	$fgff->genome_checksum->{}
	$fgff->contigs->{}
	$fgff->fig->{}
=cut

sub parse
{
    my($self, $file) = @_;

    my($fh, $close_handle);

    my $fobj = GFFFile->new($self->fig);
    $self->current_file($fobj);

    if (ref($file) ? (ref($file) eq 'GLOB'
                       || UNIVERSAL::isa($file, 'GLOB')
                       || UNIVERSAL::isa($file, 'IO::Handle'))
        : (ref(\$file) eq 'GLOB'))
    {
        $fh = $file;
    }
    else
    {
	if ($file =~ /\.gz$/) {open($fh, "gunzip -c $file |") or confess "can't open a pipe to gunzip $file"}
	else {open($fh, "<$file") or confess "Cannot open $file: $!";}
        $fobj->filename($file);
        $close_handle = 1;
    }

    #
    # Start parsing by verifying this is a gff3 file.
    #

    $_ = <$fh>;

    if (m,^\#gff-version\t(\S+),)
    {
        if ($1 != 3)
        {
            confess "Invalid GFF File: version is not 3";
        }
    }

    #
    # Now parse.
    #

    while (<$fh>)
    {
        chomp;
        next unless ($_); # ignore empty lines
        #
        # Check first for the fasta directive so we can run off and parse that
        # separately.
        #
        

        if (/^>/)
        {
            $self->parse_fasta($fh, $_);
            last;
        }
        elsif (/^\#\#FASTA/)
        {
            # print "Got fasta directive\n";
            $_ = <$fh>;
            chomp;
            $self->parse_fasta($fh, $_);
            last;
        }
        elsif (/^\#\s/)
        {
            #
            # comment.
            #
            next;
        }
        elsif (/^\#$/)
        {
            #
            # blank line starting with #
            #
            next;
        }
        elsif (/^\#\#(\S+)(?:\t(.*))?/)
        {
            #
            # GFF3 directive.
            #

            $self->parse_gff3_directive($1, $2);
            
        }
        elsif (/^\#(\S+)(?:\t(.*))?/)
        {
            #
            # Directive.
            #

            if (lc($1) eq "seed")
            {
                $self->parse_seed_directive($2);
            }
            else
            {
                $self->parse_local_directive($1, $2);
            }
            
        }
        elsif (/^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$/)
        {
            $self->parse_feature($1, $2, $3, $4, $5, $6, $7, $8, $9);
        }
        else
        {
            die "bad line: '$_'\n";
        }
    }
    
    foreach my $k (qw[features_by_genome feature_index features filename fasta_data contig_checksum genome_checksum contigs])
    {
	    $self->{$k}=$fobj->{$k};
    }

    return $fobj;
}

=head2 feature_tree

Generate and return a feature tree for the features in the GFF3 file. Most features have Parent/Child relationships, eg. an exon is a child of a gene, and a CDS is a child of an mRNA. This method will return the tree so that you can recurse up and down it.

=cut

sub feature_tree {
	my $self=shift;
	return $self->{'tree'} if (defined $self->{'tree'});
	my $tree;
	my $fc;
	foreach my $k (keys %{$self->features_by_genome})
	{
# first create a hash with only parents, and an array that houses thei children
		my $children;
		foreach my $feat (@{$self->features_by_genome->{$k}})
		{
			my $parent;
			if (defined $feat->{'Parent'}) {$parent=$feat->{'Parent'}}
			elsif (defined $feat->{'attributes'}->{'Parent'}) {$parent=$feat->{'attributes'}->{'Parent'}}

			if (defined $parent) {push @{$children->{$parent}}, $feat->{'ID'}}
			else {$tree->{$feat->{'ID'}}=undef}
		}

# now add them to a tree
		$self->_add2tree($tree, [keys %$tree], $children);
	}	
	$self->{'tree'}=$tree;
	return $tree;
}

sub _add2tree {
	my ($self, $tree, $parents, $children)=@_;
        foreach my $parent (@$parents)
        {
                if ($children->{$parent})
                {
                        map {$tree->{$parent}->{$_}=undef} @{$children->{$parent}};
                        $self->_add2tree($tree->{$parent}, $children->{$parent}, $children);
                }
        }
}





=head2 parse_gff3_directive()

Pases the directives within the files (e.g. headers, flags for FASTA, and so on).

=cut



sub parse_gff3_directive
{
    my($self, $directive, $rest) = @_;

    $directive = lc($directive);
    # this should catch both #seed and ##seed :-)
    if ($directive eq "seed")
    {
      return $self->parse_seed_directive($rest);
    }
    
    my @rest=split /\t/, $rest;
   
    # removed genome, genome_md5, origin, taxnomy as they are not real gff directives. These are in seed_directives below
    if ($directive eq "project") 
    {
        # I am not sure if PROJECT is a seed directive or a GFF directive
        $self->current_file->project($rest[0]);
    }
    elsif ($directive eq "sequence-region")
    {
        $self->current_file->contigs($rest[0]);
        $self->{contig_length_cache}->{$rest[0]}=$rest[2]-$rest[1];
        $self->{contig_start_cache}->{$rest[0]}=$rest[1];
        $self->{contig_end_cache}->{$rest[0]}=$rest[2];
    }
    else 
    {
        print STDERR "Have gff3 directive '$directive' rest='$rest'\n";
    }
    
}

=head2 parse_seed_directive()

Parse out seed information that we hide in the headers, eg, project, name, taxid, and so on. These are our internal representations, but are generally treated as comments by other gff3 parsers

=cut

sub parse_seed_directive
{
    my($self, $rest) = @_;

    my($verb, @rest) = split(/\t/, $rest);

    # are we case sensitive? I don't think so
    $verb=lc($verb);
    
    if ($verb eq "genome_id")
    {
        $self->current_file->genome_id($rest[0]);
    }
    elsif ($verb eq "name")
    {
        $self->current_file->genome_name($rest[0]);
    }
    elsif ($verb eq "genome_md5")
    {
        $self->current_file->set_genome_checksum($rest[0]);
    }
    elsif ($verb eq "project") 
    {
        # I am not sure if PROJECT is a seed directive or a GFF directive
        $self->current_file->project($rest[0]);
    }
    elsif ($verb eq "taxonomy")
    {
        $self->current_file->taxonomy($rest[0]);
    }
    elsif ($verb eq "taxon_id")
    {
        $self->current_file->taxon_id($rest[0]);
    }
    elsif ($verb eq "anno_start")
    {
        $self->current_file->anno_start($rest[0]);
    }
    elsif ($verb eq "anno_end")
    {
        $self->current_file->anno_start($rest[0]);
    }
    elsif ($verb eq "contig_md5")
    {
        $self->current_file->set_contig_checksum(@rest[0,1,2]);
    }
}

=head2 parse_local_directive()

I haven't seen one of these :)

=cut

sub parse_local_directive
{
    my($self, $directive, $rest) = @_;

    print STDERR "Have local directive '$directive' rest='$rest'\n";
}

=head2 parse_feature

Reads a feature line and stuffs it into the right places, as appropriate.

=cut

sub parse_feature
{
    my($self, $seqid, $source, $type, $start, $end, $score, $strand, $phase, $attributes) = @_;

    #print "data: seqid=$seqid source=$source type=$type start=$start end=$end\n";
    #print "      score=$score strand=$strand phase=$phase\n";
    #print "      $attributes\n";

    #
    # Parse this feature, creating a GFFFeature object for it.
    #

    my $feature = GFFFeature->new($self->fig);

    $feature->seqid($seqid);
    $feature->source($source);
    $feature->type($type);
    $feature->start($start);
    $feature->end($end);
    $feature->score($score);
    $feature->strand($strand);
    $feature->phase($phase);

    my $athash = {};

    for my $attr (split(/;/, $attributes))
    {
        my($name, $value) = split(/=/, $attr);

        my @values = map { uri_unescape($_) } split(/,/, $value);

        # handle the aliases
        if ($name eq "Alias") { 
         foreach my $val (@values) 
         {
           $val = FigGFF::map_dbxref_to_seed_alias($val);
         }
        }

        #
        # This might be a little goofy for the users, but we will use it
        # for now:
        #
        # if there is more than one value, the value is a ref to a list
        # of the values.
        #
        # Otherwise, the value is a scalar.
        #

        if (@values > 1)
        {
            #
            # Yes, you can do this ... I had to look it up :-).
            #
            # It's in 'man perlfaq3'.
            #
            
            $value = \@values;
        }
        else
        {
            $value = $values[0];
        }
           

        $athash->{$name} = $value;

        #
        # Handle the GFF3-defined attributes.
        #
        # These show up as Class::Accessor's on the feature object.
        #

        if ($GFFFeature::GFF_Tags{$name})
        {
            $feature->set($name, $value);

            if ($name eq "Dbxref")
            {
                #
                # If we have a SEED:figid DBxref, set the genome and fig_id attributes.
                #

                my @seed_xref = grep /^"?SEED:/, @values;
                if (@seed_xref and $seed_xref[0] =~ /^"?SEED:(fig\|(\d+\.\d+)\..*)/)
                {
                    $feature->genome($2);
                    $feature->fig_id($1);
                }
                
            }
        }
    }
    $feature->attributes($athash);

        
    $self->current_file->add_feature($feature);
}

#
# We come in here with the first line of the fasta already read
# in order to support the backward-compatiblity syntax that
# lets a file skip the ##FASTA directive if it wishes.
#

=head2 parse_fasta()

Read the fasta sequence into memory

=cut

sub parse_fasta
{
    my($self, $fh, $first_line) = @_;
    my($cur, $cur_id);

    for ($_ = $first_line; defined($_);  $_ = <$fh>, chomp)
    {
        if (/^>\s*(\S+)/)
        {
            if ($cur)
            {
                $self->handle_fasta_block($cur_id, $cur);
            }

            $cur = '';
            $cur_id = $1;
        }
        else
        {
            s/^\s*$//;
            s/\s*$//;
            if (/\s/)
            {
                die "FASTA data had embedded space: $_\n";
            }
            $cur .= $_;
        }           
    }
    if ($cur)
    {
        $self->handle_fasta_block($cur_id, $cur);
    }
}

sub handle_fasta_block
{
    my($self, $id, $data) = @_;

    my $len = length($data);
    $self->current_file->fasta_data($id, $data);
}

=pod

=head1 GFFFeature

A GFFFeature that acceesses the data

=head2 methods

fig seqid source type start end score strand phase attributes genome fig_id

=cut

package GFFFeature;

use strict;
use base qw(Class::Accessor);

our @GFF_Tags = qw(ID Name  Alias Parent Target Gap Note Dbxref Ontology_term);
our %GFF_Tags;

map { $GFF_Tags{$_} = 1 } @GFF_Tags;

__PACKAGE__->mk_accessors(qw(fig seqid source type start end score strand phase attributes
                             genome fig_id),
                          @GFF_Tags);


sub new
{
    my($class, $fig) = @_;

    my $self = {
        fig => $fig,
    };

    return bless($self, $class);
}

sub find_local_feature
{
    my($self, $local_genome) = @_;
    my $db = $self->fig->db_handle;

    # For debugging.
    undef $local_genome;
    if ($local_genome)
    {
        #
        # It's a precise match. We need to determine if we have this 
        # particular feature in this SEED (it is possible for one to
        # have exported an annotation for a feature that was added
        # to a genome after its initial release).
        #
        # We do this by searching for a local feature with the same contig,
        # start, and stop as this feature.
        #
        
        my $qry = qq(SELECT id
                     FROM features
                     WHERE (genome = ? AND
                            contig = ? AND
                            minloc = ? AND
                            maxloc = ?));
        my $res = $db->SQL($qry, undef, $local_genome, $self->seqid,
                           $self->start, $self->end);

        return map { $_->[0] } @$res;
    }

    #
    # Otherwise, we need to try a set of heuristics to match
    # this id.
    #

    #
    # Try matching aliases first.
    #

    my @aliases = grep { !/^\"?SEED/ } ref($self->Dbxref) ? @{$self->Dbxref} : ($self->Dbxref);

    my @maliases = map { FigGFF::map_dbxref_to_seed_alias($_) } @aliases;

    print "Found aliases @aliases\n";
    print "Found mapped aliases @maliases\n";

    for my $malias (@maliases)
    {
        my $fid = $self->fig->by_alias($malias);
        if ($fid)
        {
            print "Mapped $malias to $fid\n";
        }
    }
    
}


package GFFFile;

use strict;
use base qw(Class::Accessor);

__PACKAGE__->mk_accessors(qw(fig filename features feature_index anno_start anno_end taxon_id genome_id));

#
# Package to hold the contents of a GFF file, and to hold the code
# for mapping its contents to the local SEED.
#
# Created by GFFParser->parse.
#

sub new
{
    my($class, $fig) = @_;

    my $self = {
        fig => $fig,
        features => [],
        contigs  => [],
        feature_index => {},
        genome_checksum => '',
        contig_checksum => {},
        features_by_genome => {},
    };
    return bless($self, $class);
}

sub add_feature
{
    my($self, $feature) = @_;

    push(@{$self->features}, $feature);
    $self->feature_index->{$feature->ID} = $feature;
    push(@{$self->{features_by_genome}->{$feature->genome}}, $feature);
}

sub features_for_genome
{
    my($self, $genome) = @_;

    return $self->{features_by_genome}->{$genome};
}

sub genome_checksum
{
    my($self) = @_;

    return $self->{genome_checksum};
}

sub set_genome_checksum
{
    my($self, $md5sum) = @_;
    $self->{genome_checksum} = $md5sum;
}

sub set_contig_checksum
{
    my($self, $genome, $contig, $md5sum) = @_;
    $self->{contig_checksum}->{$genome}->{$contig} = $md5sum;
}

=head2 fasta_data()

Get or set the fasta data. Given an id and some data will set the data for that id. Given an id will return the data for that id. Called without arguments will return a reference to a hash of sequences.

This means that if you give it an id and sequence it will return that sequence. Hmmm.

=cut

sub fasta_data 
{
    my($self, $id, $data) = @_;
    $id && $data && ($self->{fasta_data}->{$id} = $data);
    $id && return $self->{fasta_data}->{$id};
    return $self->{fasta_data};
}


=head2 contigs()

Add a contig to the list, or return a reference to an array of contigs

=cut

sub contigs
{
    my($self, $contig) = @_;
    if ($contig && $contig =~ /\w\w\_\d+\.\d+/) {
      print STDERR "WARNING: $contig appears to have a version number. We should standardize on timming that somewhere\n";
    }
    $contig && (push @{$self->{contigs}}, $contig);
    return $self->{contigs};
}

=head2 contig_length()

Get or set the length of a specfic contig. 
  my $length=$fob->contig_length($contig, $length);
  my $length=$fob->contig_length($contig);

=cut

sub contig_length
{
   my($self, $contig, $length) = @_;
   $length && ($self->{contig_length_cache}->{$contig}=$length);
   return $self->{contig_length_cache}->{$contig};
}

=head1 Information about the source of the sequence.

These are things that we have parsed out the GFF3 file, or want to add into the GFF3 file. We can use these methods to get or set them as required. In general, if a value is supplied that will be used as the new value.

=cut

=head2 genome_id()

Get or set a genome id for this file. 

=cut

sub genome_id
{
    my($self, $genomeid) = @_;
    $genomeid && ($self->{genome_id}=$genomeid);
    return $self->{genome_id};
}

=head2 genome_name()

Get or set a genome id for this file.

=cut

sub genome_name
{
    my($self, $genomename) = @_;
    $genomename && ($self->{genome_name}=$genomename);
    return $self->{genome_name};
}

=head2 project()

Get or set the project.

=cut

sub project
{
     my ($self, $pro) = @_;
     $pro && ($self->{project}=$pro);
     return $self->{project};
}

=head2 taxonomy()

Get or set the taxonomy

=cut

sub taxonomy
{
    my($self, $tax) = @_;
    $tax && ($self->{taxonomy}=$tax);
    return $self->{taxonomy};
}





1;
