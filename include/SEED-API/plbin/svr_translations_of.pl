#!/usr/bin/env perl -w

use strict;
use Data::Dumper;
use Carp;

use SeedUtils;
use SAPserver;
my $sapObject = SAPserver->new();

#
# This is a SAS Component
#

my $usage = <<End_of_Usage;

Get translations from ids:

usage: svr_translations_of [-c column] [-fasta] [-function] < ids

Options:

   -a           #  Same as -function
   -c  column   #  Take ids from specified column of tab delimited input
   -f           #  Same as -fasta
   -fasta       #  Output is fasta format, not tab delimited columns
   -function    #  Include assigned functions in fasta header, or as
                #      penultimate column of tab delimited output.

Examples:

    svr_all_features 83333.1 peg | svr_translations_of > id_tab_seq

    svr_all_features 83333.1 peg | svr_translations_of -a -f > annotated_fasta

End_of_Usage

my $column;
my $fasta = 0;
my $funcs = 0;

while ( $ARGV[0] && ($ARGV[0] =~ s/^-//))
{
    $_ = shift @ARGV;
    if    ($_ =~ s/^c//)       { $column = /./ ? $_ : shift @ARGV; next }
    elsif ($_ =~ /^fasta/)     { $fasta  = 1; next }
    elsif ($_ =~ /^function/)  { $funcs  = 1; next }

    if ($_ =~ s/a//g) { $funcs  = 1 }
    if ($_ =~ s/f//g) { $fasta  = 1 }
    if ($_ =~ /./ )   { print STDERR "Bad Flag: -$_\n", $usage; die }
}

my @lines = map { chomp; [split(/\t/,$_)] } <STDIN>;
if (@lines) {
    if (! $column)  { $column = @{$lines[0]} }
    my @fids = map { $_->[$column-1] } @lines;
    
    if (! $fasta) {
	my $seqsH = $sapObject->ids_to_sequences(-ids     => \@fids,
						 -protein => 1);
        my $funcH;
        $funcH = $sapObject->ids_to_functions( -ids => \@fids ) if $funcs;

	foreach $_ ( @lines )
	{
	    my $id = $_->[$column-1];
	    print join( "\t",  @$_,
	                       ( $funcs ? $funcH->{$id} || '' : () ),
	                       $seqsH->{$id} || ''
	              ),
	          "\n";
	}
    } else {
        my @funcs = $funcs ? ( -comments => $sapObject->ids_to_functions( -ids => \@fids ) )
                           : ();
        
	my $seqsH = $sapObject->ids_to_sequences(-ids     => \@fids,
						 -fasta   => 1,
						 -protein => 1,
						 @funcs
						);
	foreach $_ ( @fids )
	{
	    print $seqsH->{ $_ };
	}
    }
}