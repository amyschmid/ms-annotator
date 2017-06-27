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
# Basic user management tools for a SEED.
#
# The user database explicitly isn't kept in the SEED database instance because
# it is intended to be persistent across database loads and the installation of
# new Data directories.
#
# If we had the freedom to require a new compiled environment, we might use
# DBD::SQLite to hold it. But that's not straightforward at this point, so
# we will hold the user data in a simple flat file, reading it into memory
# as needed and rewriting to disk when changes need to be made. At this point
# there will be fairly few accesses to it anyway.
#
# We define the following operations on a user database.
#
# get_users(): returns the list of usernames that we know about on this system.
#
# ensure_user($user): Ensure that a database entry for $user exists.
#
# get_user($user): Returns the user parameters as a hash ref.
#
# set_user_param($user, $param, $value): Set a user parameter $param to $value.
#
# get_user_param($user, $param): Retrieve the user paramter $param.
#
# write(): Writes the modified user database to disk.
#
# The file format for the user database is intended to be exceedingly simple to generate and
# parse.
#
# It consists of blocks separated by // lines. The first line in the block is the
# user name, and the remaining lines are tab-delimited pairs 'param-name'\t'param-value'
#
# Parameter values are not allowed to contain newlines.
#

package UserDB;
use FIG_Config;

use Data::Dumper;

use strict;

sub new
{
    #
    # We require a $fig reference so we can poke at the database.
    #
    
    my($class, $fig) = @_;

    my $file = "$FIG_Config::fig_disk/config/user.db";

    my $fh;
    if (!open($fh, "<$file"))
    {
	#
	# DB file doesn't exist yet. Create a new database initialized
	# from the users that show up in the annotations and  assignments
	# in the database.
	#

	ref($fig) or die "UserDB::new requires a valid FIG object\n";

	open(my $wfh, ">$file") or die "Cannot write new user database $file: $!\n";

	my @initial_users = _get_initial_users($fig);
	for my $user (@initial_users)
	{
	    print $wfh "$user\n";
	    print $wfh "//\n"; 
	}
	close($wfh);
	open($fh, "<$file") or die "Cannot open newly-created user database $file: $!\n";
    }

    #
    # Ensure it stays writable.
    #

    chmod(0666, $file);

    my $self = {
	users => {},
	file => $file,
    };

    local($/);
    $/ = "//\n";

    while (<$fh>)
    {
	chomp;

	my ($user, @params) = split(/\n/, $_);

	my $phash = $self->{users}->{$user} = {};

	warn "Parse gets user $user\n";

	for my $param (@params)
	{
	    my ($name, $value) = split(/\t/, $param, 2);

	    $phash->{$name} = $value;
	}
    }
    close($fh);

    bless($self, $class);

    return $self;
}

sub get_users
{
    my($self) = @_;

    return keys(%{$self->{users}});
}

sub ensure_user
{
    my($self, $user) = @_;

    if (!defined($self->{users}->{$user}))
    {
	$self->{users}->{$user} = {};
    }
}

sub get_user
{
    my($self, $user) = @_;

    return $self->{users}->{$user};
}

sub set_user_param
{
    my($self, $user, $param, $value) = @_;

    $self->{users}->{$user}->{$param} = $value;
}
    
sub get_user_param
{
    my($self, $user, $param) = @_;

    return $self->{users}->{$user}->{$param};
}

sub write
{
    my($self) = @_;
    my $fh;
    
    open($fh, ">$self->{file}") or die "UserDB::write:  could not open $self->{file} for writing: $!\n";

    while (my ($user, $params) = each (%{$self->{users}}))
    {
	print $fh "$user\n";
	while (my($k, $v) = each(%$params))
	{
	    print $fh "$k\t$v\n";
	}
	print $fh "//\n";
    }
    close($fh);
}

#
# Return a list of usernames that appear in the database.
#
# Strip master:name to just name.
#
sub _get_initial_users
{
    my($fig) = @_;
    my %names;

    my $db = $fig->db_handle();
    my $res;

    #
    # Pull names from annotations.
    #

    $res = $db->SQL("SELECT DISTINCT who FROM annotation_seeks");
    for my $ent (@$res)
    {
	my $who = $ent->[0];
	$who =~ s/^master://;
	$names{$who}++;
    }

    #
    # And from assignments
    #

    $res = $db->SQL("SELECT DISTINCT made_by FROM assigned_functions");
    for my $ent (@$res)
    {
	my $who = $ent->[0];
	$who =~ s/^master://;
	$names{$who}++;
    }

    return keys %names;
}

1;
