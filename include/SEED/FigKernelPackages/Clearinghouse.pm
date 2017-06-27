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
# The clearinghouse is the centralized location where information
# about live SEED instances is collected.
#
# This module defines interface mechanisms for accessing the clearinghouse. The
# clearinghouse exports its functionality via an XMLRPC interface.
#
#

use Frontier::Client;

use LWP::UserAgent;

package Clearinghouse;

use FIGAttributes;
use base 'FIGAttributes';

sub new
{
    my($class, $url) = @_;

    if (!$url)
    {
	#
	# Default clearinghouse.
	#

	# $url = "http://www.mcs.anl.gov/~olson/SEED/api.cgi";
	$url = "http://pubseed.theseed.org/legacy_clearinghouse/api.cgi";
    }

    $self = {};

    $self->{url} = $url;
    $self->{proxy} = Frontier::Client->new('url' => $url);

    return bless $self, $class;
}

sub publish_subsystem
{
    my($self, $name, $version, $date, $curator, $pedigree, $seed_id, $roles, $genomes) = @_;

    return $self->{proxy}->call("publish_subsystem",
				$name, $version, $date, $curator, $pedigree, $seed_id, $roles, $genomes);
}

sub upload_subsystem_package
{
    my($self, $url, $package) = @_;

    my $ua = LWP::UserAgent->new;

    my $req = HTTP::Request->new(POST => $url);
    $req->content_type("application/octet-stream");
    $req->content($package);

    my $res = $ua->request($req);
    return $res->as_string;
}

sub get_subsystems :Scalar
{
    my($self) = @_;

    return $self->{proxy}->call("get_subsystems");

}

sub get_full_subsystems :Scalar
{
    my($self, $roles, $genomes, $pedigree) = @_;

    return $self->{proxy}->call("get_full_subsystems",
				($roles ? 1 : 0),
				($genomes ? 1 : 0),
				($pedigree ? 1 : 0));
}

sub get_subsystem_details :Scalar
{
    my($self, $ss, $roles, $genomes, $pedigree) = @_;

    return $self->{proxy}->call("get_subsystem_details",
				$ss,
				($roles ? 1 : 0),
				($genomes ? 1 : 0),
				($pedigree ? 1 : 0));
}

1;
