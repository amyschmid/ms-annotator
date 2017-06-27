package FFserver;

=head1 FIGfam Server Helper Object

This module is used to call the FIGfam server, which is a general-purpose
server for extracting data from the FIGfams database. Each FIGfam server
function correspond to a method of this object.

This package deliberately uses no internal SEED packages or scripts, only common
PERL modules.

=cut

use LWP::UserAgent;
use Data::Dumper;
use YAML;

use strict;

sub new
{
    my($class, $server_url) = @_;

    $server_url = "http://servers.nmpdr.org/figfam/server.cgi" unless $server_url;


    my $self = {
	server_url => $server_url,
	ua => LWP::UserAgent->new(),
    };
    $self->{ua}->timeout(20 * 60);

    return bless $self, $class;
}

=head2 Functions

=head3 members_of_families

    my $document = $ffObject->members_of_families(@ids);

Return the function and a list of the members for each specified family.

=over 4

=item ids

A list of FIGfam IDs.

=item RETURN

Returns a reference to a list of 3-tuples. Each 3-tuple will consist of a FIGfam
family ID followed by the family's function and a sub-list of all the FIG feature
IDs for the features in the family.

=back

=cut

sub members_of_families
{
    my($self, @ids) = @_;
    return $self->run_query('members_of_families', @ids);
}

=head3 families_containing_peg

    my $document = $ffObject->families_containing_peg(@ids);

Return the FIGfams containing the specified features.

=over 4

=item ids

A list of FIG feature IDs.

=item RETURN

Returns a list of 2-tuples, each consisting of an incoming feature ID
followed by a list of FIGfam IDs for the families containing the incoming
feature.

=back

=cut

sub families_containing_peg
{
    my($self, @ids) = @_;
    return $self->run_query('families_containing_peg', @ids);
}

=head3 families_implementing_role

    my $document = $ffObject->families_implementing_role(@roles);

Return the FIGfams that implement the specified roles. Each FIGfam has
a single function associated with it, but the function may involve
multiple roles, or may include comments. The role is therefore a more
compact string than the function.

=over 4

=item roles

A list of role names.

=item RETURN

Returns a list of 2-tuples, each consisting of an incoming role name
followed by a list of FIGfam IDs for the families that implement the
incoming role.

=back

=cut

sub families_implementing_role
{
    my($self,@roles) = @_;
    return $self->run_query('families_implementing_role', @roles);
}

=head3 families_with_function

    my $document = $ffObject->families_with_function(@functions);

Return the FIGfams that belong to the specified functions. Each FIGfam has
a single function associated with it, but the function may involve
multiple roles, or may include comments. The function is therefore a
more specific string than the role.

=over 4

=item functions

A list of functional roles.

=item RETURN

Returns a list of 2-tuples, each consisting of an incoming role name
followed by a list of FIGfam IDs for the families associated with the
incoming function.

=back

=cut

sub families_with_function 
{
    my($self,@functions) = @_;
    return $self->run_query('families_with_function', @functions);
}

=head3 families_in_genome

    my $document = $ffObject->families_in_genome(@genomes);

Return the FIGfams that have members in the specified genomes.

=over 4

=item genomes

A list of genome IDs.

=item RETURN

Returns a list of 2-tuples, each consisting of an incoming genome ID
followed by a list of FIGfam IDs for the families that have members in
that genome.

=back

=cut

sub families_in_genome
{
    my($self,@genomes) = @_;
    return $self->run_query('families_in_genome', @genomes);
}

=head3 get_subsystem_based_figfams

    my $document = $ffObject->get_subsystem_based_figfams();

Return a list of the FIGfams derived from subsystems.

=over 4

=item RETURN

Returns a reference to a list of the IDs for the FIGfams derived from subsystems.

=back

=cut

sub get_subsystem_based_figfams
{
    my ($self) = @_;
    return $self->run_query('get_subsystem_based_figfams');
}

##=head3 should_be_member
##
##    my $document = $ffObject->should_be_member(@id_seq_pairs);
##
##Determine whether a particular protein sequence belongs in a particular
##FIGfam. This method takes as input multiple FIGfam/sequence pairs and
##performs a determination for each.
##
##=over 4
##
##=item id_seq_pairs
##
##A list of 2-tuples, each consisting of a FIGfam ID followed
##by a protein sequence string.
##
##=item RETURN
##
##Returns a reference to a list of boolean flags, one per input pair. For each
##input pair, the flag will be C<1> if the sequence should be in the FIGfam and
##C<0> otherwise.
##
##=back
##
##=cut
##
##sub should_be_member
##{
##    my($self, @id_seq_pairs) = @_;
##    return $self->run_query('should_be_member', @id_seq_pairs);
##}

=head3 all_families

    my $document = $ffObject->all_families();

Return a list of the IDs for all the FIGfams in the system.

=over 4

=item RETURN

Returns a reference to a list of the IDs for all the FIGfams in the system.

=back

=cut

sub all_families
{
    my($self) = @_;
    return $self->run_query('all_families');
}

=head3 assign_function_to_prot

    my $document = $ffObject->assign_function_to_prot($input, $blast, $min_hits, $assignToAll);

For each incoming protein sequence, attempt to place it in a FIGfam. If a
suitable FIGfam can be found for a particular sequence, the FIGfam ID and
its functional assignment will be returned.

=over 4

=item input

Either (1) an open input handle to a file containing the proteins in FASTA format,
or (2) a reference to a list of FASTA strings for the proteins.

=item blast

If nonzero, then when a protein is placed into a FIGfam, a BLAST will be performed
afterward, and the top I<N> hits (where I<N> is the value of this parameter)
will be returned as part of the protein's output tuple.

=item min_hits

A number from 1 to 10, indicating the minimum number of matches required to
consider a protein as a candidate for assignment to a FIGfam. A higher value
indicates a more reliable matching algorithm; the default is C<3>.

=item assign_to_all

If TRUE, then if the standard matching algorithm fails to assign a protein,
a BLAST will be used. The BLAST is slower, but is capable of placing more
proteins than the normal algorithm.

=item RETURN

Returns a Result Handler. Call C<get_next> on the result handler to get back a data
item. Each item sent back by the result handler is a 2-tuple containing the
incoming protein sequence and a reference to a list consisting of the proposed
functional assignment for the protein, the name of the Genome Set from which the
protein is likely to have originated (if known), a list of BLAST hits (if
requested), and the number of matches for the protein found in the FIGfam. If no
assignment could be made for a particular protein, it will not appear in the
output stream.

=back

=cut

sub assign_function_to_prot
{
    my($self, $input, $blast, $min_hits, $assignToAll) = @_;

    my $wq;

    my $params = [blast => $blast, min_hits => $min_hits, assign_to_all => ($assignToAll ? 1 : 0)];
    
    if (ref($input) eq 'ARRAY')
    {
	$wq = SequenceListWorkQueue->new($input);
    }
    else
    {
	$wq = FastaWorkQueue->new($input);
    }

    my $req_bytes = $blast ? 1000 : 1_000_000;

    return ResultHandler->new($wq, $self->{server_url}, 'assign_function_to_prot', \&id_seq_pair_bundler,
			      #\&tab_delimited_output_parser,
			      \&YAML::Load,
			      $params, $req_bytes);
}

=head3 call_genes

    my $document = $ffObject->call_genes($input, $genetic_code);

Call the protein-encoding genes for the specified DNA sequences. The result will
be a multi-sequence FASTA string listing all the proteins found and a hash mapping
each gene found to its location string.

=over 4

=item input

Open input handle to a file containing the DNA sequences in FASTA format.

=item genetic_code

The numeric code for the mapping from DNA to amino acids. The default is C<11>,
which is the standard mapping and should be used in almost all cases. A complete
list of mapping codes can be found at
L<http://www.ncbi.nlm.nih.gov/Taxonomy/Utils/wprintgc.cgi>.

=item RETURN

Returns a 2-tuple consisting of a FASTA string for all the proteins found
followed by a reference to a list of genes found. Each gene found will be
represented by a 4-tuple containing an ID for the gene, the ID of the contig
containing it, the starting offset, and the ending offset.

=back

=cut

sub call_genes
{
    my($self, $input, $genetic_code) = @_;

    if (ref($input) ne 'ARRAY')
    {
	my $fh;
	if (ref($input))
	{
	    $fh = $input;
	}
	else
	{
	    my $fasta_file = $input;
	    open($fh, "<", $fasta_file);
	}
	$input = [];
	while (my($id, $seqp, $com) = FastaWorkQueue::read_fasta_record($fh))
	{
	    push(@$input, "$id,$$seqp");
	}
	close($fh);
    }

    return $self->run_query_form([function => "call_genes",
				  genetic_code => $genetic_code,
				  id_seq => $input]);
}

=head3 find_rnas

    my $document = $ffObject->find_rnas($input, $genus, $species, $domain);

Call the RNAs for the specified DNA sequences. The result will be a
multi-sequence FASTA string listing all the RNAs found and a hash mapping
each RNA to its location string.

=over 4

=item input

Open input handle to a file containing the DNA sequences in FASTA format.

=item genus

Common name of the genus for this DNA.

=item species

Common name of the species for this DNA.

=item domain

Domain of this DNA. The default is C<Bacteria>.

=item RETURN

Returns a 2-tuple consisting of a FASTA string for all the RNAs found
followed by reference to a list of RNAs found. Each RNA will be represented by
a 4-tuple consisting of an ID for the RNA, the ID of the contig containing it, its
starting offset, and its ending offset.

=back

=cut

sub find_rnas
{
    my($self, $input, $genus, $species, $domain) = @_;

    if (ref($input) ne 'ARRAY')
    {
	my $fh;
	if (ref($input))
	{
	    $fh = $input;
	}
	else
	{
	    my $fasta_file = $input;
	    open($fh, "<", $fasta_file);
	}
	$input = [];
	while (my($id, $seqp, $com) = FastaWorkQueue::read_fasta_record($fh))
	{
	    push(@$input, "$id,$$seqp");
	}
	close($fh);
    }

    return $self->run_query_form([function => "find_rnas",
				  genus => $genus,
				  species => $species,
				  domain => $domain,
				  id_seq => $input]);
}

=head3 assign_functions_to_DNA

    my $document = $ffObject->assign_functions_to_DNA($input, $blast, $min_hits, $max_gap);

Analyze DNA sequences and output regions that probably belong to FIGfams.
The selected regions will be high-probability candidates for protein
production.

=over 4

=item input

Either (1) an open input handle to a file containing the DNA sequences in FASTA format,
or (2) a reference to a list of FASTA strings for the DNA sequences.

=item blast

If nonzero, then when a protein is placed into a FIGfam, a BLAST will be performed
afterward, and the top I<N> hits (where I<N> is the value of this parameter)
will be returned as part of each protein's output tuple.

=item min_hits

A number from 1 to 10, indicating the minimum number of matches required to
consider a protein as a candidate for assignment to a FIGfam. A higher value
indicates a more reliable matching algorithm; the default is C<3>.

=item max_gap

When looking for a match, if two sequence elements match and are closer than
this distance, then they will be considered part of a single match. Otherwise,
the match will be split. The default is C<600>.

=item RETURN

Returns a Result Handler. Call C<get_next> on the result handler to get back a data
item. Each item sent back by the result handler is a 2-tuple containing the
incoming protein sequence and a reference to a list of hit regions. Each hit
region is a 6-tuple consisting of the number of matches to the FIGfam, the start
location, the stop location, the proposed functional assignment, the name of the
Genome Set from which the gene is likely to have originated, and a list of BLAST
hits. If the I<blast> option is not specified, the list of BLAST hits will be
empty.

=back

=cut

sub assign_functions_to_dna
{
    my($self, $input, $min_hits, $max_gap, $blast) = @_;

    $min_hits = 3 unless defined($min_hits);
    $max_gap = 600 unless defined($max_gap);
    $blast = 0 unless defined($blast);

    my $wq;
    
    if (ref($input) eq 'ARRAY')
    {
	$wq = SequenceListWorkQueue->new($input);
    }
    else
    {
	$wq = FastaWorkQueue->new($input);
    }

    my $req_bytes = $blast ? 1000 : 500000;
    my $params = [min_hits => $min_hits, max_gap => $max_gap, blast => $blast];
    return ResultHandler->new($wq, $self->{server_url}, 'assign_functions_to_DNA',
			      \&id_seq_pair_bundler,
			      \&tab_delimited_output_parser, $params, $req_bytes);
}

###### Utility Methods ######

sub run_query
{
    my($self, $function, @args ) = @_;
    my $form = [function  => $function,
		args => YAML::Dump(\@args),
		];
    return $self->run_query_form($form);
}

sub run_query_form
{
    my($self, $form, $raw) = @_;

    my $res = $self->{ua}->post($self->{server_url}, $form);
    
    if ($res->is_success)
    {
	my $content = $res->content;
	if ($raw)
	{
	    return $content;
	}
	     
#	print "Got $content\n";
	my $ret;
	eval { 
	    $ret = Load($content);
	};
	if ($@)
	{
	    die "Query returned unparsable content ($@): " . $content;
	}
	return $ret;
    }
    else
    {
	die "error on post " . $res->status_line . " " . $res->content;
    }
}

sub id_seq_pair_bundler
{
    my($item) = @_;
    my($id, $seq) = @$item[0,2];
    return "id_seq", join(",", $id, (ref($seq) eq 'SCALAR' ? $$seq : $seq));
}

sub tab_delimited_output_parser
{
    my($line) = @_;
    chomp $line;
    my @cols = split(/\t/, $line);
    return \@cols;
}


sub tab_delimited_dna_data_output_parser
{
    my($line) = @_;
    chomp $line;
    my ($id, $idbe, $fam) = split(/\t/, $line);
    my ($beg, $end) = $idbe =~ /_(\d+)_(\d+)$/;
    return [$id, $beg, $end, $fam];
}

package ResultHandler;
use strict;
use Data::Dumper;

sub new
{
    my($class, $work_queue, $server_url, $function, $input_bundler, $output_parser, $form_vars, $req_bytes) = @_;

    my $self = {
	work_queue => $work_queue,
	server_url => $server_url,
	function => $function,
	input_bundler => $input_bundler,
	output_parser => $output_parser,
	ua => LWP::UserAgent->new(),
	cur_result => undef,
	form_vars => $form_vars ? $form_vars : [],
	req_bytes => ($req_bytes ? $req_bytes : 16000),
    };
    $self->{ua}->timeout(20 * 60);
    return bless $self, $class;
}

sub get_next
{
    my($self) = @_;

    my $res =  $self->get_next_from_result();
    # print "gnfr returns: " , Dumper($res);

    if ($res)
    {
	return $res;
    }
    else
    {
	
	while (my @inp = $self->{work_queue}->get_next_n_bytes($self->{req_bytes}))
	{
	    my $form = [@{$self->{form_vars}}];
	    push(@$form, function => $self->{function},
			 map { &{$self->{input_bundler}}($_) } @inp);
	    # print "Invoke " .Dumper($form);

	    my $res = $self->{ua}->post($self->{server_url}, $form);
	    if ($res->is_success)
	    {
		eval { 
		    $self->{cur_result} = [YAML::Load($res->content)];
		};
		if ($@)
		{
		    die "Query returned unparsable content ($@): " . $res->content;
		}
		# print "res: " . Dumper($self->{cur_result});
		my $oneres =  $self->get_next_from_result();
		if ($oneres)
		{
		    return $oneres;
		}
	    }
	    else
	    {
		die "error " . $res->status_line . " on post " . $res->content;
	    }
	}
	return;
    }
}

sub get_next_from_result
{
    my($self) = @_;
    my $l = $self->{cur_result};
    if ($l and @$l)
    {
	return shift(@$l);
    }
    else
    {
	delete $self->{cur_result};
	return undef;
    }
}

package SequenceWorkQueue;
use strict;

sub new
{
    my($class) = @_;

    my $self = {};
    
    return bless $self, $class;
}

sub get_next_n
{
    my($self, $n) = @_;
    my @out;
    
    for (my $i = 0;$i < $n; $i++)
    {
	my($id, $com, $seqp) = $self->get_next();
	if (defined($id))
	{
	    push(@out, [$id, $com, $seqp]);
	}
	else
	{
	    last;
	}
    }
    return @out;
}

sub get_next_n_bytes
{
    my($self, $n) = @_;
    my @out;

    my $size = 0;
    while ($size < $n)
    {
	my($id, $com, $seqp) = $self->get_next();
	if (defined($id))
	{
	    push(@out, [$id, $com, $seqp]);
	    $size += (ref($seqp) eq 'SCALAR') ? length($$seqp) : length($seqp);
	}
	else
	{
	    last;
	}
    }
    return @out;
}

package FastaWorkQueue;
use strict;
use base 'SequenceWorkQueue';
use FileHandle;

sub new
{
    my($class, $input) = @_;

    my $fh;
    if (ref($input))
    {
	$fh = $input;
    }
    else
    {
	$fh = new FileHandle("<$input");
    }

    my $self = $class->SUPER::new();

    $self->{fh} = $fh;

    return bless $self, $class;
}

sub get_next
{
    my($self) = @_;

    my($id, $seqp, $com) = read_fasta_record($self->{fh});
    return defined($id) ? ($id, $com, $seqp) : ();
}

sub read_fasta_record {
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

package SequenceListWorkQueue;
use strict;
use base 'SequenceWorkQueue';

sub new
{
    my($class, $input) = @_;

    my $fh;
    if (ref($input) ne 'ARRAY')
    {
	die "SequenceWorkQueue requires a list as input";
    }

    my $self = $class->SUPER::new();

    $self->{list} = $input;

    return bless $self, $class;
}

sub get_next
{
    my($self) = @_;

    my $top = shift @{$self->{list}};

    return defined($top) ? @$top : ();
}


1;

