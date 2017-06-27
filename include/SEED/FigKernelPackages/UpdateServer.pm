package UpdateServer;

use strict;
use Data::Dumper;

#### Delete a Feature
sub delete_feature {
    my($cgi,$user,$sap,$fig,$fid) = @_;
    $fig->delete_feature($fid, $user);
}

#### Make an annotation
sub make_annotation {
    my($cgi,$user,$sapdb,$fig,$fid,$anno) = @_;
    $fig->add_annotation($fid, $user, $anno);
}

#### Assign Function 
sub assign_function {
    my($cgi,$user,$sapdb,$fig,$new_func,@pegs) = @_;

    my %newFunctions;
    foreach my $peg (@pegs) {
	$newFunctions{$peg} = [$new_func, $user];
	$fig->assign_function($peg, $user, $new_func);
    }
}

#### Save a Dlit
sub record_pmid {
    my($cgi,$user,$sapdb,$fig,$fid,$pmid) = @_;

    my @html;
    if ($sapdb) {
	    my @ids = split(/[\s,]+/,$pmid);
	    foreach my $id (@ids)
	    {   
		push(@html,$cgi->h3("Added PubMed ID $id to $fid"));
		my $rc = $fig->add_dlit(-status => 'D',
				-peg => $fid,
				-pubmed => $pmid,
				-curator => $user);
		if (!$rc) {
			print STDERR "$pmid for $fid not inserted";
		}
	    }
     }
    return @html;
}

1;
