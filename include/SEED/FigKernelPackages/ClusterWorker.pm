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

package Cluster::Worker;

use strict;
use SOAP::Lite;
use Cluster;
use Data::Dumper;
use Time::HiRes 'time';

my $ns = $Cluster::Broker::ns;

=head1 Cluster::Worker

Worker-side interface to the cluster work broker.

=cut

BEGIN {
    #
    # Dynamically create the methods here.
    #

    my $start = time;
    my %methods = (register_worker => 6,
		   register_cluster => 2,
		   get_work => 1,
		   work_done => 4,
		   work_failed => 4,
		   get_upload_handles => 4,
		   worker_alive => 1,
		  );
    
    no strict 'refs';
    while (my($method_name, $arg_count) = each(%methods))
    {
	*$method_name = sub {
	    my($self, @args) = @_;
	    @args == $arg_count or die "Incorrect number of arguments to $method_name";

	    my $response = $self->{proxy}->call($method_name, @args);

	    if ($response->fault)
	    {
		die $response->faultstring;
	    }
	    else
	    {
		return $response->result;
	    }
	}
    }
    my $end = time;
    my $elap = ($end - $start) * 1000;
}


sub new
{
    my($class, $url) = @_;

    my $proxy = SOAP::Lite->uri($ns)->proxy($url, timeout => 3600);

    my $self = {
	proxy => $proxy,
    };
    return bless $self, $class;
}

1;
