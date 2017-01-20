use strict;
use Data::Dumper;
use Carp;

#
# This is a SAS Component
#


use SeedEnv;
my $sapObject = SAPserver->new();

=head1 svr_aliases_of

Return all identifiers for genes in the database that are protein-sequence-equivalent to the specified identifiers. In this case, the identifiers are assumed to be in their natural form (without prefixes). For each identifier, the identified protein sequences will be found and then for each protein sequence, all identifiers for that protein sequence or for genes that produce that protein sequence will be returned.

Alternatively, you can ask for identifiers that are precisely equivalent, that is, that identify the same location on the same genome.

------
Example: svr_all_features 3702.1 peg | svr_aliases_of

would produce a 2-column table.  The first column would contain
PEG IDs for genes occurring in genome 3702.1, and the second
would contain the aliases (comma-seprated) of those genes.

The aliases are IDs of genes that have precisely the same
protein sequence, but may or may not be from the same genome.
------

The standard input should be a tab-separated table (i.e., each line 
is a tab-separated set of fields).  Normally, the last field in each
line would contain the PEG for which aliases are being requested.
If some other column contains the PEGs, use

    -c N

where N is the column (from 1) that contains the PEG in each case.

This is a pipe command. The input is taken from the standard input, and the
output is to the standard output.

=head2 Command-Line Options

=over 4

=item -c Column

This is used only if the column containing PEGs is not the last.

=item -r regexp

This is used to restrict the aliases being returned. Only aliases matching the regexp are returned.

=item -precise

Only identifiers that refer to the same location on the same genome will be returned. If this option is specified, identifiers that refer to proteins rather than features will return no result.

=back

=head2 Output Format

The standard output is a tab-delimited file. It consists of the input
file with an extra column added (a comma-separated list of aliases).

=cut


my $usage = "usage: svr_aliases_of [-c column -r regexp -precise]";

my $column;
my $regexp;
my $precise = 0;
while ($ARGV[0] && ($ARGV[0] =~ /^-/))
{
    $_ = shift @ARGV;
    if    ($_ =~ s/^-c//) { $column       = ($_ || shift @ARGV) }
    elsif ($_ =~ s/^-r//) { $regexp	  = ($_ || shift @ARGV) }
    elsif ($_ =~ s/^-precise//) { $precise 	  = 1; next} 
    else                  { die "Bad Flag: $_" }
}


ScriptThing::AdjustStdin();
my @lines = map { chomp; [split(/\t/,$_)] } <STDIN>;
if (! $column)  { $column = @{$lines[0]} }
my @fids = map { $_->[$column-1] } @lines;

my $aliases = &get_aliases($sapObject,\@fids, $regexp);

foreach $_ (@lines)
{
    print join("\t",@$_,$aliases->{$_->[$column-1]}),"\n";
}

sub get_aliases {
    my($sapObject,$pegs, $regexp) = @_;
    
    my $aliases = {};
    my $aliasHash;
    $aliasHash = $sapObject->equiv_sequence_ids(-ids => $pegs,  -precise => $precise);
    foreach my $peg (@$pegs)
    {
	my $aliasList = $aliasHash->{$peg} || [];
	my @all_aliases = grep { $_ ne $peg } @$aliasList;
	if ($regexp) {
		@all_aliases = grep {/$regexp/} @all_aliases;
	}
	my $aliasStr = (@all_aliases > 0) ? join(",",@all_aliases) : "";
	$aliases->{$peg} = $aliasStr;
    }
    return $aliases;
}
