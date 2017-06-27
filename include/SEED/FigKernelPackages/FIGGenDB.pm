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

package FIGGenDB;

use FIG;
use strict;

use Fcntl qw/:flock/;  # import LOCK_* constants
use CGI;
use POSIX;
use IPC::Open2;

use DBrtns;
use FIG_Config;


use constant GENDB_CGI => "/GENDB/cgi-bin/";


sub linkPEGGenDB {
    my ($peg) = @_;
    $peg =~ /fig\|(.+)\.peg/;
    my $taxon = $1;

    my $cgi = &FIG::plug_url(GENDB_CGI);
    
    return q(<a target="_blank" href=") . $cgi .
	"seed_interface.cgi?action=view".
	"&region=$peg&taxon_id=$taxon\">To View in GenDB</a>\n";
}

sub importOrganismGenDB {
    my ($peg) = @_;
    $peg =~ /fig\|(.+)\.peg/;
    my $taxon = $1;

    my $cgi = &FIG::plug_url(GENDB_CGI);

    return q(<a target="_blank" href=") . $cgi .
        "seed_interface.cgi?action=import".
        "&taxon_id=$taxon\">Import Organism into GenDB</a>\n";

}

sub linkClusterGenDB {
    my ($peg, $taxon) = @_;
    # RAE: just return undef here so that we don't display the form for the Bounds as people think that this is working
    return undef;

    my $cgi = &FIG::plug_url(GENDB_CGI);
    my $html = "<form target=\"_blank\" action=\"${cgi}seed_interface.cgi\">\n
                Bound1<input type=\"text\" id=\"bound1\" name=\"bound1\"/>\n
                Bound2<input type=\"text\" id=\"bound2\" name=\"bound2\"/>\n
                Candidate(s):<input type=\"text\" id=\"candidates\" name=\"candidates\"/>\n
		Threshold<input type=\"text\" name=\"fmgth\" value=\"1e-20\"/>\n
                <input type=\"hidden\" name=\"action\" value=\"predict\"/>\n
		<input type=\"hidden\" name=\"peg_id\" value=\"$peg\"/>\n
		<input type=\"submit\" name=\"GenDB\" value=\"Find uncalled Gene\"/>\n 
                </form>";
    return $html;
}



1;
