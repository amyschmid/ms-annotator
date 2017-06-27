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
# This module contains the code for the P2P update protocol.
#
# Package P2P contains the namespace declarations, and possibly toplevel utility
# routines. (get_relay ?)
#
# Package P2P::Relay contains methods for contacting the P2P relay service. The actual
# implementation of the relay service is not contained here - it is a standalone module
# that can be installed on a web server that does not have a full SEED installed.
#
# Package P2P::Requestor contains the requestor-side code for the update protocol.
#
# Package P2P::Service contains the web service implementation routines for the
# protocol.
#

package P2P;

use FIG_Config;

use AnyDBM_File;
use Fcntl;

use strict;
use Exporter;
use base qw(Exporter);

use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );

use Data::Dumper;

use vars qw(@EXPORT @EXPORT_OK);
@EXPORT = ();
@EXPORT_OK = qw($ns_p2p $ns_relay);

our $ns_p2p = "http://thefig.info/schemas/p2p_update";
our $ns_relay = "http://thefig.info/schemas/p2p_relay";

my $peg_batch_size = 1000;
my $anno_batch_size = 1000;
my $assign_batch_size = 1000;
my $fin_batch_size = 1000;

my $log_fh;
my $html_fh;

=pod

=head1 perform_update($peer, $last_update, $skip_tough_search, $update_thru, $log_file, $html_file, $assignment_policy))

Perform a peer-to-peer update with the given peer. $peer is an instance of
P2P::Requestor which can connect to the peer. It is expected that the
SEED infrastructure will create this requestor appropriately for the 
particular circumstance (direct connection, thru relay, etc).

This code executes the high-level protocol, maintaining state between
calls to the peer to exchange the actual information.

    $last_update: Search for updates since this time.
    $skip_tough_search: Do not use the time-consuming $fig->tough_search method as a last resort for peg mapping.
    $update_thru: Search for updates until this time. Undef means to search for all since $last_update.
    $log_file: Write logging information to this file.
    $html_file: Write a HTML summary to this file.
    $assignment_policy: If a list reference, contains the list of users from which we will accept assignments. If a code ref, a predicate that is passed ($peg, $timestamp, $author, $function) and returns true if the assignment should be made.

=cut

sub perform_update
{
    my($fig, $peer, $last_update, $skip_tough_search, $update_thru, $log_file, $html_file,
       $assignment_policy) = @_;

    my $allow_assignment;

    $log_file = "/dev/null" unless $log_file ne "";
    open($log_fh, ">>$log_file") or die "Cannot open logfile $log_file: $!\n";
    $log_fh->autoflush(1);

    $html_file = "/dev/null" unless $html_file ne "";
    open($html_fh, ">$html_file") or die "Cannot open htmlfile $html_file: $!\n";
    $html_fh->autoflush(1);

    if (!defined($assignment_policy))
    {
	$allow_assignment = sub { 1;};
    }
    elsif (ref($assignment_policy) eq "CODE")
    {
	$allow_assignment = $assignment_policy;
    }
    elsif (ref($assignment_policy) eq "ARRAY")
    {
	my $ahash = {};
	map { $ahash->{$_}++; } @$assignment_policy;
	$allow_assignment = sub {
	    return $ahash->{$_[2]};
	};
    }
    elsif (ref($assignment_policy) eq "HASH")
    {
	$allow_assignment = sub {
	    return $assignment_policy->{$_[2]};
	};
    }
    else
    {
	print $log_fh "Invalid assignment policy $assignment_policy\n";
	die "Invalid assignment policy $assignment_policy\n";
    }
	
    my $now = localtime();
    my $last_str = localtime($last_update);
    print $html_fh <<END;
<h1>P2P Update at $now</h1>
Peer URL $peer->{url}<br>
Update from: $last_str<br>
END

    print $log_fh "Beginning P2P update at $now\n";
    print $log_fh "  Peer URL: $peer->{url}\n";
    print $log_fh "  Update from: $last_str\n";
    print $log_fh "\n";

    my $ret = $peer->request_update($last_update, $update_thru);

    if (!$ret or ref($ret) ne "ARRAY")
    {
	die "perform_update: request_update failed\n";
    }

    my($session, $target_release, $num_assignments, $num_annos, $num_pegs, $num_genomes,
       $target_time, $compatible) = @$ret;

    print "perform_update: session=$session target=@$target_release num_annos=$num_annos\n";
    print "                num_pegs=$num_pegs num_genomes=$num_genomes target_time=$target_time compat=$compatible\n";

    my @my_release = $fig->get_release_info();

    print $log_fh "Session id = $session\n";
    print $log_fh "Target release information: \n\t", join("\n\t", @$target_release), "\n";
    print $log_fh "My release information: \n\t", join("\n\t", @my_release), "\n";
    print $log_fh "$num_annos annotations\n";
    print $log_fh "$num_assignments assignments\n";
    print $log_fh "$num_pegs pegs\n";

    print $html_fh "Session id = $session<br>\n";
    print $html_fh "Target release information: <br>\n\t", join("<br>\n\t", @$target_release), "<br>\n";
    print $html_fh "My release information: <br>\n\t", join("<br>\n\t", @my_release), "<br>\n";
    print $html_fh "$num_annos annotations<br>\n";
    print $html_fh "$num_assignments assignments<br>\n";
    print $html_fh "$num_pegs pegs<br>\n";

    #
    # We now know the data release for our peer.
    #
    # Open up the peg translation cache database (a AnyDBM_File) tied
    # to %peg_cache. We needn't worry about keeping it in a directory
    # based on our current release, as it the cache directory is kept *in*
    # the current data release directory.
    #

    my $cache_handle;
    my %peg_cache;
    if ($target_release->[1] ne "")
    {
	my $cache_file = "pegcache.$target_release->[1].db";
	my $cache_dir = "$FIG_Config::fig/var/P2PQueue";
	&FIG::verify_dir("$FIG_Config::fig/var");
	$fig->verify_dir($cache_dir);

	$cache_handle = tie(%peg_cache, "AnyDBM_File", "$cache_dir/$cache_file",
			    O_CREAT | O_RDWR, 0666);
	$cache_handle or warn "Could not tie peg_cache to $cache_dir/$cache_file: $!\n";
    }

    #
    # peg_mapping is the local mapping from remote->local peg. This might
    # be replacable by peg_cache from above.
    #
    my %peg_mapping;

    
    #
    # We have  the information now to begin the update process. Retrieve the pegs.
    #

    _compute_peg_mapping($fig, $peer, $session, $num_pegs, \%peg_mapping, \%peg_cache, $cache_handle,
			 $skip_tough_search);

    eval { $cache_handle->sync();};
    untie %peg_cache;

    #
    # Create a list of locally-mapped annotations on a per-genome
    # basis.
    #

    my %genome_annos;

    #
    # %genome_assignments is a hash mapping from genome to a hashref
    # that maps  peg to function (since assignments are unique).
    #
    # (Hm. Unless two remote pegs map to the same local peg; unclear what to do
    # then. Punt for now).
    #
    my %genome_assignments;
    
    #
    # Retrieve the annotations, and generate a list of mapped annotations.
    #

    for (my $anno_start = 0; $anno_start < $num_annos; $anno_start += $anno_batch_size)
    {
	my $anno_req_len = $num_annos - $anno_start;
	$anno_req_len = $anno_batch_size if $anno_req_len > $anno_batch_size;

	print "Retrieve $anno_req_len annos at $anno_start\n";
	print $log_fh "Retrieve $anno_req_len annos at $anno_start\n";
	
	my $annos = $peer->get_annotations($session, $anno_start, $anno_req_len);

	for my $anno (@$annos)
	{
	    my($his_id, $ts, $author, $anno) = @$anno;
	    
	    my $my_id = $peg_mapping{$his_id};
	    next unless $my_id;

	    my $genome = $fig->genome_of($my_id);
	    
	    push(@{$genome_annos{$genome}}, [$my_id, $ts, $author, $anno]);
	}
    }

    #
    # Do the same for the assignments
    #

    # print Dumper($assignments);


    for (my $assign_start = 0; $assign_start < $num_assignments; $assign_start += $assign_batch_size)
    {
	my $assign_req_len = $num_assignments - $assign_start;
	$assign_req_len = $assign_batch_size if $assign_req_len > $assign_batch_size;

	print "Retrieve $assign_req_len assigns at $assign_start\n";
	print $log_fh "Retrieve $assign_req_len assigns at $assign_start\n";
	
	my $assignments = $peer->get_assignments($session, $assign_start, $assign_req_len);

	for my $assign (@$assignments)
	{
	    my($his_id, $ts, $author, $func) = @$assign;

	    my $my_id = $peg_mapping{$his_id};
	    next unless $my_id;

	    my $genome = $fig->genome_of($my_id);

	    $genome_assignments{$genome}->{$my_id} =  [$my_id, $ts, $author, $func];
	}
    }

    # print Dumper(\%genome_annos);

    #
    # Now install annotations.
    #

    for my $genome (keys(%genome_annos))
    {
	#
	# Plan:  Apply the merge_annotations.pl logic. Read the annotations
	# from the per-org annotations file, add the new ones here, sort, and remove duplicates.
	# Write the results to the annotations file.
	#
	# When we are all done, rerun the index_annotations script.
	#
	# Why not do that incrementally? Partly because the annotation_seeks table doesn't
	# have a column for the genome id, so a removal of old data would require a
	# string-match query; since a complete reindex of the annotations is pretty
	# fast (60 sec on a G4 laptop on a firewire disk), it's not clear whether the incremental
	# update would actually be a win.
	#

	my @annos = @{$genome_annos{$genome}};
	my $assignments = $genome_assignments{$genome};
	#
	# %assignment_annos is a hash from peg to the list
	# of annotations for that peg.
	#
	my %assignment_annos;
	
	my $dir = "$FIG_Config::organisms/$genome";
	my $anno_file = "$dir/annotations";
	my $anno_bak = "$dir/annotations." . time;

	my $new_count = @annos;

	#
	# Rename the annotations file to a new name based on the current time.
	#

	my $gs = $fig->genus_species($genome);
	print $html_fh "<h1>Updates for $genome ($gs)</h1>\n";

	if (-f $anno_file)
	{
	    rename($anno_file, $anno_bak) or die "Cannot rename $anno_file to $anno_bak: $!";
	    print $log_fh "Moved annotations file $anno_file to backup $anno_bak\n";
	}

	if (open(my $fh, "<$anno_bak"))
	{
	    #
	    # While we are scanning here, we look for the latest local assignment
	    # for any peg for which we are installing an assignment.
	    #
	    local($/) = "\n//\n";

	    my($chunk, $peg, $ts, $author, $anno);

	    while (defined($chunk = <$fh>))
	    {
		chomp $chunk;
		($peg, $ts, $author, $anno) = split(/\n/, $chunk, 4);
		
		if ($peg =~ /^fig\|/ and $ts =~ /^\d+$/)
		{
		    #
		    # The last field marks this as an "old" annotation (that is,
		    # already in place in this system), so we don't
		    # log its installation later.
		    #
		    my $ent = [$peg, $ts, $author, $anno, 1];
		    push(@annos, $ent);

		    if (defined($assignments->{$peg}))
		    {
			#
			# We have an incoming assignment for this peg.
			# Don't parse anything yet, but push the annotation
			# on a list so we can sort by date.
			#
			push(@{$assignment_annos{$peg}}, $ent);
		    }
		}
	    }
	    close($fh);
	}

	#
	# Determine if we are going to install an assignment.
	#

	my $cgi_url = &FIG::cgi_url();
	print $html_fh "<h2>Assignments made</h2>\n";
	print $html_fh "<table border=\"1\">\n";
	print $html_fh "<tr><th>PEG</th><th>Old assignment</th><th>New assignment</th><tr>\n";

	for my $peg (keys %$assignments)
	{
	    my(undef, $ts, $author, $func) = @{$assignments->{$peg}};

	    #
	    # Sort the existing annotations for this peg by date.
	    #
	    # Recall that this list has entries [$peg, $timestamp, $author, $anno, $old_flag]
	    #

	    my @eannos;
	    if (ref($assignment_annos{$peg}))
	    {
		@eannos = sort { $b->[1] <=> $a->[1] } @{$assignment_annos{$peg}};
	    }
	    else
	    {
		#
		# No assignment annotations found.
		#
		@eannos = ();
	    }
	    
	    # print "Assignment annos for $peg: ", Dumper(\@eannos);

	    #
	    # Filter out just the master assignments that are newer than
	    # the one we are contemplating putting in place.
	    #

	    my @cand = grep {
		($_->[1] > $ts) and ($_->[3] =~ /Set master function to/)
		} @eannos;

	    if (@cand > 0)
	    {
		#
		# Here is were some policy needs to be put in place --
		# we have a more recent annotation on the current system.
		#
		# For now, we will not install an assignment if there is any
		# newer assignment in place.
		#

		warn "Skipping assignment for $peg $func due to more recent assignment $cand[0]->[3]\n";
		print $log_fh "Skipping assignment for $peg $func due to more recent assignment $cand[0]->[3]\n";
	    }
	    else
	    {
		#
		# Nothing is blocking us. While we are testing, just slam this assignment in.
		#

		my $old = $fig->function_of($peg, 'master');

		if ($old ne $func and &$allow_assignment($peg, $ts, $author, $func))
		{
		    my $l = "$cgi_url/protein.cgi?prot=$peg";
		    print $html_fh "<tr><td><a href=\"$l\">$peg</a></td><td>$old</td><td>$func</td></tr>\n";

		    print "Assign $peg $func\n";
		    print $log_fh "Assign $peg $func\n";
		    print $log_fh "   was $old\n";
		    $fig->assign_function($peg, 'master', $func);

		}
	    }
	}

	print $html_fh "</table>\n";

	print $html_fh "<h2>Annotations added</h2>\n";
	print $html_fh "<table border=\"1\">\n";
	print $html_fh "<tr><th>PEG</th><th>Time</th><th>Author</th><th>Annotation</th></tr>\n";
	
	open(my $outfh, ">$anno_file") or die "Cannot open new annotation file $anno_file: $!\n";
	
	my $last;
	my @sorted = sort { ($a->[0] cmp $b->[0]) or ($a->[1] <=> $b->[1]) } @annos;
	my $inst = 0;
	my $dup = 0;
	foreach my $ann (@sorted)
	{
	    my $txt = join("\n", @$ann[0..3]);
	    #
	    # Drop the trailing \n if there is one; we  will add it back when we print and
	    # want to ensure the file format remains sane.
	    #
	    chomp $txt; 
	    if ($txt ne $last)
	    {
		my $peg = $ann->[0];
		my $l = "$cgi_url/protein.cgi?prot=$peg";
		if (!$ann->[4])
		{
		    print $html_fh "<tr>" . join("\n", map { "<td>$_</td>" }
						 "<a href=\"$l\">$peg</a>",
						 scalar(localtime($ann->[1])), $ann->[2], $ann->[3])
			. "</tr>\n";
		}
		
		print $outfh "$txt\n//\n";
		$last = $txt;
		# print "Inst $ann->[0] $ann->[1] $ann->[2]\n";
		$inst++;
	    }
	    else
	    {
		# print "Dup $ann->[0] $ann->[1] $ann->[2]\n";
		$dup++;
	    }
	}
	print $html_fh "</table>\n";
	close($outfh);
	chmod(0666, $anno_file) or warn "Cannot chmod 0666 $anno_file: $!\n";
	print "Wrote $anno_file. $new_count new annos, $inst installed, $dup duplicates\n";
	print $log_fh "Wrote $anno_file. $new_count new annos, $inst installed, $dup duplicates\n";
    }
    close($html_fh);
}

#
# Compute the peg mapping for a session.
#
# $fig	 	Active FIG instance
# $peer	 	P2P peer for this session.
# $session	P2P session ID
# $peg_mapping	Hash ref for the remote -> local PEG mapping
# $peg_cache	Hash ref for the persistent remote -> local PEG mapping cache db.
# $cache_handle	AnyDBM_File handle corresponding to $peg_cache.
#
sub _compute_peg_mapping
{
    my($fig, $peer, $session, $num_pegs, $peg_mapping, $peg_cache, $cache_handle, $skip_tough_search) = @_;

    #
    # genome_map is a hash mapping from target genome id to a list of
    # pegs on the target. This is used to construct a finalize_pegs request after
    # the first phase of peg mapping.
    #
    
    my %genome_map;

    #
    # target_genome_info is a hash mapping from target genome
    # identifier to the target-side information on the genome -
    # number of contigs, number of nucleotides, checksum.
    #
    # We accumulate it here across possibly multiple batches of
    # peg retrievals in order to create a single  finalization
    # list.
    #

    my %target_genome_info;

    #
    # For very large transfers, we need to batch the peg processing.
    #

    for (my $peg_start = 0; $peg_start < $num_pegs; $peg_start += $peg_batch_size)
    {
	my $peg_req_len = $num_pegs - $peg_start;
	$peg_req_len = $peg_batch_size if $peg_req_len > $peg_batch_size;

	print "Getting $peg_req_len pegs at $peg_start\n";
	print $log_fh "Getting $peg_req_len pegs at $peg_start\n";
	my $ret = $peer->get_pegs($session, $peg_start, $peg_req_len);

	if (!$ret or ref($ret) ne "ARRAY")
	{
	    die "perform_update: get_pegs failed\n";
	}

	my($peg_list, $genome_list) = @$ret;

	for my $gent (@$genome_list)
	{
	    $target_genome_info{$gent->[0]} = $gent;
	}

	_compute_peg_mapping_batch($fig, $peer, $session, $peg_mapping, $peg_cache, $cache_handle,
				   $peg_list, \%genome_map);
    }

    #
    # We have finished first pass. Now go over the per-genome mappings that need to be made.
    #
    # $genome_map{$genome_id} is a list of pegs that reside on that genome.
    # The pegs and genome id are both target-based identifiers.
    #
    # %target_genome_info defines the list of genome information we have on the remote
    # side.
    #
    # We build a request to be passed to finalize_pegs. Each entry in the request is either
    # ['peg_genome', $peg] which means that we have a genome that corresponds to the
    # genome the peg is in. We can attempt to map via contig locations.
    #
    # If that is not the case,  we pass a request entry of ['peg_unknown', $peg]
    # which will result in the sequence data being returned.
    #

    my @finalize_req = ();

    #
    # local_genome maps a target peg identifier to the local genome id it translates to.
    #
    my %local_genome;

    for my $genome (keys(%target_genome_info))
    {
	my($tg, $n_contigs, $n_nucs, $cksum) = @{$target_genome_info{$genome}};

	$tg eq $genome or die "Invalid entry in target_genome_info for $genome => $tg, $n_contigs, $n_nucs, $cksum";

	#
	# Don't bother unless we have any pegs to look up.
	#
	next unless defined($genome_map{$genome});

	#
	# Determine if we have a local genome installed that matches precisely the
	# genome on the target side.
	#
	my $my_genome = $fig->find_genome_by_content($genome, $n_contigs, $n_nucs, $cksum);

	my $pegs = $genome_map{$genome};
	
	if ($my_genome)
	{
	    #
	    # We do have such a local genome. Generate a peg_genome request to
	    # get the location information from the target side.
	    #
	    # Also remember the local genome mapping for this peg.
	    #

	    print "$genome mapped to $my_genome\n";
	    print $log_fh "$genome mapped to $my_genome\n";
	    for my $peg (@$pegs)
	    {
		push(@finalize_req, ['peg_genome', $peg]);
		$local_genome{$peg} = $my_genome;
	    }
	    
	}
	else
	{
	    #
	    # We don't have such a genome. We need to retrieve the
	    # sequence data in order to finish mapping.
	    #
	    push(@finalize_req, map { ['peg_unknown', $_] } @$pegs);
	}
    }

    #
    # We've built our finalization request. Handle it (possibly with batching here too).
    #

    _process_finalization_request($fig, $peer, $session, $peg_mapping, $peg_cache, $cache_handle,
				 \%local_genome, \@finalize_req, $skip_tough_search);

}

#
# Process one batch of PEGs.
#
# Same args as _compute_peg_mapping, with the addition of:
#
# 	$peg_list	List of pegs to be processed
#	$genome_map	Hash maintaining list of genomes with their pegs.
#	$target_genome_info	Hash maintaining overall list of target-side genome information.
#
sub _compute_peg_mapping_batch
{
    my($fig, $peer, $session, $peg_mapping, $peg_cache, $cache_handle,
       $peg_list, $genome_map, $target_genome_info) = @_;
    
    #
    # Walk the list of pegs as returned from get_pegs() and determine what has to
    # be done.
    #
    # If the entry is ['peg', $peg], we can use the peg ID as is.
    #
    # If the entry is ['peg_info', $peg, $alias_list, $genome], the peg
    # has the given aliases, and is in the given genome.
    #
    for my $peg_info (@$peg_list)
    {
	my($key, $peg, @rest) = @$peg_info;

	if ($key eq 'peg')
	{
	    #
	    # Peg id is directly usable.
	    #
	    $peg_mapping->{$peg} = $peg;
	}
	elsif ($key eq 'peg_info')
	{
	    #
	    # Peg id not directly usable. See if we have it in the cache.
	    #

	    if ((my $cached = $peg_cache->{$peg}) ne "")
	    {
		#
		# Cool, we've cached the result. Use it.
		#

		$peg_mapping->{$peg} = $cached;
		# warn "Found cached mapping $peg => $cached\n";
		next;
	    }

	    #
	    # It is not cached. Attempt to resolve by means of alias IDs.
	    #

	    my($alias_list, $genome_id) = @rest;

	    for my $alias (@$alias_list)
	    {
		my $mapped = $fig->by_alias($alias);
		if ($mapped)
		{
		    print "$peg maps to $mapped via $alias\n";
		    print $log_fh "$peg maps to $mapped via $alias\n";
		    $peg_mapping->{$peg}= $mapped;
		    $peg_cache->{$peg} = $mapped;
		    last;
		}
	    }

	    #
	    # If we weren't able to resolve by ID,
	    # add to %genome_map as a PEG that will need
	    # to be resolved by means of contig location.
	    #

	    if (!defined($peg_mapping->{$peg}))
	    {
		push(@{$genome_map->{$genome_id}}, $peg);
		print "$peg did not map on first pass\n";
		print $log_fh "$peg did not map on first pass\n";
	    }
	}
    }

    #
    # Flush the cache to write out any computed mappings.
    #
    eval { $cache_handle->sync();};

}

sub _process_finalization_request
{
    my($fig, $peer, $session, $peg_mapping, $peg_cache, $cache_handle,
       $local_genome, $finalize_req, $skip_tough_search) = @_;

    #
    # Immediately return unless there's something to do.
    #
    return unless ref($finalize_req) and @$finalize_req > 0;

    while (@$finalize_req > 0)
    {
	my @req = splice(@$finalize_req, 0, $fin_batch_size);

	print "Invoking finalize_pegs on ", int(@req), " pegs\n";
	print $log_fh "Invoking finalize_pegs on ", int(@req), " pegs\n";
	my $ret = $peer->finalize_pegs($session, \@req);

	if (!$ret or ref($ret) ne "ARRAY")
	{
	    die "perform_update: finalize_pegs failed\n";
	}

	#
	# The return is a list of either location entries or
	# sequence data. Attempt to finish up the mapping.
	#

	my(%sought, %sought_seq);
	

	my $dbh = $fig->db_handle();
	for my $entry (@$ret)
	{
	    my($what, $peg, @rest) = @$entry;

	    if ($what eq "peg_loc")
	    {
		my($strand, $start, $end, $cksum, $seq) = @rest;

		#
		# We have a contig location. Try to find a matching contig
		# here, and see if it maps to something.
		#

		my $my_genome = $local_genome->{$peg};
		my $local_contig = $fig->find_contig_with_checksum($my_genome, $cksum);
		if ($local_contig)
		{
		    #
		    # Now look up the local peg. We match on the end location; depending on the strand
		    # the feature is on, we want to look at either minloc or maxloc.
		    #

		    my($start_loc, $end_loc);

		    if ($strand eq '-')
		    {
			$start_loc = 'maxloc';
			$end_loc = 'minloc';
		    }
		    else
		    {
			$start_loc = 'minloc';
			$end_loc = 'maxloc';
		    }

		    my $res = $dbh->SQL(qq!SELECT id, $start_loc from features
					   WHERE $end_loc = $end and genome = '$my_genome' and
					   contig = '$local_contig'
					!);

		    if ($res and @$res > 0)
		    {
			my $id;
			if (@$res == 1)
			{
			    #
			    # Found a unique mapping.
			    #
			    $id = $res->[0]->[0];
			}
			else
			{
			    #
			    # Multiple mappings found. See if one matches the
			    # start location. If it doesn't, pick the one that
			    # is closest in length.
			    #

			    my @lens;
    
			    for my $res_ent (@$res)
			    {
				my($rid, $rloc) = @$res_ent;

				push(@lens, [$rid, abs($rloc - $end - ($start - $end))]);
				warn "Matching $rid $rloc to $start\n";
				if ($rloc == $start)
				{
				    $id = $rid;
				    warn "Matched $rid\n";
				    last;
				}
			    }

			    if (!$id)
			    {
				my @slens = sort { $a->[1] <=> $b->[1]} @lens;
				my $len;
				($id, $len) = @{$slens[0]};
				warn "No unique match found, picking closest match $id (len=$len)\n";
			    }
			}
			
			$peg_mapping->{$peg} = $id;
			$peg_cache->{$peg} = $id;
			print "Mapped $peg to $id via contigs\n";
		    }
		    else
		    {
			print "failed: $peg  $my_genome and contig $local_contig start=$start end=$end strand=$strand\n";
			print $log_fh "failed: $peg  $my_genome and contig $local_contig start=$start end=$end strand=$strand\n";
			print $html_fh "Contig match failed: $peg $my_genome contig $local_contig start $start end $end strand $strand<br>\n";
			$sought{$peg}++;
			$sought_seq{$peg} = $seq;
		    }
		}
		else
		{
		    print "Mapping failed for $my_genome checksum $cksum\n";
		    print $log_fh "Mapping failed for $my_genome checksum $cksum\n";
		    print $html_fh "Mapping failed for $my_genome checksum $cksum<br>\n";
		    $sought{$peg}++;
		    $sought_seq{$peg} = $seq;
		}
	    }
	    elsif ($what eq "peg_seq")
	    {
		my($seq) = @rest;

		$sought{$peg}++;
		$sought_seq{$peg} = $seq;
	    }
	}

	#
	# Now see if we need to do a tough search.
	#

	if (keys(%sought) > 0 and !$skip_tough_search)
	{
	    my %trans;

	    print "Starting tough search\n";
	    print $log_fh "Starting tough search\n";

	    $fig->tough_search(undef, \%sought_seq, \%trans, \%sought);
	    print "Tough search translated: \n";
	    print $log_fh "Tough search translated: \n";
	    while (my($tpeg, $ttrans) = each(%trans))
	    {
		print "  $tpeg -> $ttrans\n";
		print $log_fh "  $tpeg -> $ttrans\n";
		$peg_mapping->{$tpeg} = $ttrans;
		$peg_cache->{$tpeg} = $ttrans;
	    }
	}
    }
}

#############
#
# P2P Relay 
#
#############


package P2P::Relay;
use strict;

use Data::Dumper;
use SOAP::Lite;

use P2P;

sub new
{
    my($class, $url) = @_;

    my $creds = [];
					      
    my $proxy = SOAP::Lite->uri($P2P::ns_relay)->proxy([$url,
							credentials => $creds]);
    
    my $self = {
	url => $url,
	proxy => $proxy,
    };
    return bless($self, $class);
}

sub enumerate_annotation_systems
{
    my($self) = @_;

    return $self->{proxy}->enumerate_annotation_systems()->result;
}

sub fetch_queries
{
    my($self, $id) = @_;

    my $reply = $self->{proxy}->fetch_queries($id);

    if ($reply->fault)
    {
	print "Failed to fetch queries: ", $reply->faultcode, " ", $reply->faultstring, "\n";
	return undef;
    }

    return $reply->result;
}

sub deposit_answer
{
    my($self, $id, $key, $answer) = @_;

    my $reply = $self->{proxy}->deposit_answer($id, $key,
					       SOAP::Data->type('base64')->value($answer));

    if ($reply->fault)
    {
	print "deposit_answer got fault: ", $reply->faultcode, " ", $reply->faultstring, "\n";
	return undef;
    }	
    
    return $reply;
}

=pod

=head1 await_result

Await the result from a possibly-asynchronous soap request.

Look at the reply that we have. If it's a deferred reply, loop polling
the relay for the actual result.

We determine if the reply is a deferred reply by examining the namespace
URI of the response. A response will be generated from the relay's namespace,
rather than that of the application itself.

=cut

sub await_result
{
    my($self, $reply) = @_;

    while (1)
    {
	#
	# Retrieve the namespace of the response, which is the first
	# element in the body of the message.
	#
	my $ns = $reply->namespaceuriof('/Envelope/Body/[1]');
	# print "Reply ns=$ns want $P2P::ns_relay\n";

	if ($ns eq $P2P::ns_relay)
	{
	    my $val = $reply->result;
	    # print "got val=", Dumper($val);
	    if ($val->[0] eq 'deferred')
	    {
		#
		# Sleep a little, then try to retrieve the response.
		#
		
		sleep(1);
		my $id = $val->[1];

		print "Retrieving reply\n";
		$reply = $self->{proxy}->call_completed($id);
	    }
	    else
	    {
		#
		# We're not sure what to do here..
		#
		return undef;
	    }
	}
	else
	{
	    #
	    # We got an actual response. Return it.
	    #

	    return $reply;
	}
    }
}

#############
#
# P2P Requestor
#
#############

package P2P::Requestor;
use strict;

use Data::Dumper;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );

use SOAP::Lite;

#use SOAP::Lite +trace => [qw(transport dispatch result debug)];
use P2P;

#
# Create a new Requestor. It contains a reference to the FIG instance
# so that we can run the protocol completely from in here.
#

sub new
{
    my($class, $fig, $url, $peer_id, $relay, $credentials) = @_;

    $credentials = [] unless ref($credentials);

    my $proxy = SOAP::Lite->uri($ns_p2p)->proxy($url, timeout => 3600);

    for my $cred (@$credentials)
    {
	$proxy->transport->credentials(@$cred);
    }
    
    my $self = {
	fig => $fig,
	url => $url,
	peer_id => $peer_id,
	proxy => $proxy,
	relay => $relay,
    };
    return bless($self, $class);
}

#
# First step: Request an update.
#
# We need to determine some notion of what our release is, since we are not
# currently tagging them explicitly. Until we delve into this more,
# I am going to return a null release, which means the same-release
# optimization won't be able to kick in.
#
# We also need to determine the last time we got an update from this
# system. 
#

sub request_update
{
    my($self, $last_update, $update_thru) = @_;

    my $rel = [$self->{fig}->get_release_info()];

    if (!defined($last_update))
    {
	$last_update = $self->{fig}->get_peer_last_update($self->{peer_id});
    }

    print "Requesting update via $self->{proxy}\n";
    my $reply = $self->{proxy}->request_update($rel, $last_update, $update_thru);
    # print "Got reply ", Dumper($reply);

    if ($self->{relay})
    {
	$reply = $self->{relay}->await_result($reply);
    }

    if ($reply->fault)
    {
	print "request_update triggered fault: ", $reply->faultcode, " ", $reply->faultstring, "\n";
	return undef;
    }

    return $reply->result;
}

=pod

=head1 get_pegs($session_id, $start, $length)


=cut

sub get_pegs
{
    my($self, $session_id, $start, $length) = @_;

    return $self->call("get_pegs", $session_id, $start, $length);
}

sub finalize_pegs
{
    my($self, $session_id, $request) = @_;

    return $self->call("finalize_pegs", $session_id, $request);
}

sub get_annotations
{
    my($self, $session_id, $start, $length) = @_;

    return $self->call("get_annotations", $session_id, $start, $length);
}

sub get_assignments
{
    my($self, $session_id, $start, $length) = @_;

    return $self->call("get_assignments", $session_id, $start, $length);
}

sub call
{
    my($self, $func, @args) = @_;

    my $t0 = [gettimeofday()];
    print "Calling $func\n";
    my $reply = $self->{proxy}->$func(@args);
    my $t1 = [gettimeofday()];

    my $elap = tv_interval($t0, $t1);
    print "Call to $func took $elap\n";
    
    if ($self->{relay})
    {
	$reply = $self->{relay}->await_result($reply);
    }

    if ($reply->fault)
    {
	print "$func triggered fault: ", $reply->faultcode, " ", $reply->faultstring, "\n";
	return undef;
    }

    return $reply->result;
}
    

#############
#
# P2P Service
#
# Code in this module is invoked on the target on behalf of a requestor.
#
#############

package P2P::Service;

use Data::Dumper;

use FIG;
use FIG_Config;
use strict;

use File::Temp qw(tempdir);
use File::Basename;

sub request_update
{
    my($class, $his_release, $last_update, $update_thru)= @_;

    #
    # Verify input.
    #

    if ($last_update !~ /^\d+$/)
    {
	die "request_update: last_update must be a number (not '$last_update')\n";
    }

    if ($update_thru eq "")
    {
	$update_thru = time + 10000;
    }

    #
    # Create a new session id and a spool directory to use for storage
    # of information about it. This can go in the tempdir since it is
    # not persistent.
    #
    
    &FIG::verify_dir("$FIG_Config::temp/p2p_spool");
    my $spool_dir = tempdir(DIR  => "$FIG_Config::temp/p2p_spool");

    #my $spool_dir = "$FIG_Config::temp/p2p_spool/test";
    &FIG::verify_dir($spool_dir);

    my $session_id = basename($spool_dir);
    my $now = time;

    #
    # Gather the list of pegs and annotations for the update.
    #

    my $fig = new FIG;

    my $all_genomes = [$fig->genomes];

    my %all_genomes = map { $_ => 1 } @$all_genomes;

    my %pegs;

    #
    # We keep track of usernames that have been seen, so that
    # we can both update our local user database and
    # we can report them to our peer.
    #

    my %users;
    
    my $num_annos = 0;
    my $num_genomes = 0;
    my $num_pegs = 0;
    my $num_assignments = 0;

    my $anno_fh;
    open($anno_fh, ">$spool_dir/annos");

    my $peg_fh;
    open($peg_fh, ">$spool_dir/pegs");

    my $genome_fh;
    open($genome_fh, ">$spool_dir/genomes");

    my $assign_fh;
    open($assign_fh, ">$spool_dir/assignments");

    #
    # We originally used a query to get the PEGs that needed to have annotations
    # sent. Unfortunately, this performed very poorly due to all of the resultant
    # seeking around in the annotations files.
    #
    # The code below just runs through all of the anno files looking for annos.
    #
    # A better way to do this would be to do a query to retrieve the genome id's for
    # genomes that have updates. The problem here is that the annotation_seeks
    # table doesn't have an explicit genome field.
    #
    # Surprisingly, to me anyway, the following query appers to run quickly, in both
    # postgres and mysql:
    #
    # SELECT distinct(substring(fid from 5 for position('.peg.' in fid) - 5))
    # FROM annotation_seeks
    # WHERE dateof > some-date.
    #
    # The output of that can be parsed to get the genome id and just those
    # annotations files searched.
    #

    for my $genome (@$all_genomes)
    {
	my $num_annos_for_genome = 0;
	my %assignment;
	
	my $genome_dir = "$FIG_Config::organisms/$genome";
	next unless -d $genome_dir;

	my $afh;
	if (open($afh, "$genome_dir/annotations"))
	{
	    my($fid, $anno_time, $who, $anno_text);
	    local($/);
	    $/ = "//\n";
	    while (my $ann = <$afh>)
	    {
		chomp $ann;
	    
		if ((($fid, $anno_time, $who, $anno_text) =
		     ($ann =~ /^(fig\|\d+\.\d+\.peg\.\d+)\n(\d+)\n(\S+)\n(.*\S)/s)) and
		    $anno_time > $last_update and
		    $anno_time < $update_thru)
		    
		{
		    #
		    # Update users list.
		    #

		    $users{$who}++;
		    
		    #
		    # Look up aliases if we haven't seen this fid before.
		    #

		    if (!defined($pegs{$fid}))
		    {
			my @aliases = $fig->feature_aliases($fid);

			print $peg_fh join("\t", $fid, $genome, @aliases), "\n";
			$num_pegs++;
		    }

		    print $anno_fh "$ann//\n";

		    $pegs{$fid}++;

		    $num_annos_for_genome++;
		    $num_annos++;

		    #
		    # While we're here, see if this is an assignment. We check in the
		    # %assignment hash, which is keyed on fid, to see if we already
		    # saw an assignment for this fid. If we have, we keep this one only if
		    # the assignment time on it is later than the one we saw already.
		    #
		    # We are only looking at master assignments for now. We will need
		    # to return to this issue and reexamine it, but in order to move
		    # forward I am only matching master assignments.
		    #

		    if ($anno_text =~ /Set master function to\n(\S[^\n]+\S)/)
		    {
			my $func = $1;

			my $other = $assignment{$fid};

			#
			# If we haven't seen an assignment for this fid,
			# or if it the other assignment has a timestamp that
			# is earlier than this one, set the assignment.
			#

			if (!defined($other) or
			    ($other->[1] < $anno_time))
			{
			    $assignment{$fid} = [$fid, $anno_time, $who, $func];
			}
		    }
		}
	    }
	    close($afh);

	    #
	    # Write out the assignments that remain.
	    #

	    for my $fid (sort keys(%assignment))
	    {
		print $assign_fh join("\t", @{$assignment{$fid}}), "\n";
		$num_assignments++;
	    }
	}

	
	#
	# Determine genome information if we have annotations for this one.
	#

	if ($num_annos_for_genome > 0)
	{
	    $num_genomes++;
	    if (open(my $cfh, "<$genome_dir/COUNTS"))
	    {
		if ($_ = <$cfh>)
		{
		    chomp;
		    my($cgenome, $n_contigs, $total_nucs, $cksum) = split(/\t/, $_);
		    if ($cgenome ne $genome)
		    {
			warn "Hm, $genome has a COUNTS file with genome=$cgenome that does not match\n";
		    }
		    else
		    {
			print $genome_fh join("\t",
					      $genome, $num_annos_for_genome, $n_contigs,
					      $total_nucs, $cksum), "\n";
		    }
		}
	    }
	}

    }
    close($anno_fh);
    close($peg_fh);
    close($genome_fh);
    close($assign_fh);

    print "Pegs: $num_pegs\n";
    print "Genomes: $num_genomes\n";
    print "Annos: $num_annos\n";

    #
    # Check compatibility.
    #

    my $my_release = [$fig->get_release_info()];

    #
    # Release id is $my_release->[1].
    #

    my $compatible;
    if ($my_release->[1] ne "" and $his_release->[1] ne "")
    {
	#
	# Both releases must be defined for them to be compatible.
	#
	# At some point we need to consider the derived-release issue.
	#

	$compatible = $my_release->[1] eq $his_release->[1];
    }
    else
    {
	$compatible = 0;
    }

    open(my $fh, ">$spool_dir/INFO");
    print $fh "requestor_release\t$his_release\n";
    print $fh "last_update\t$last_update\n";
    print $fh "update_thru\t$update_thru\n";
    print $fh "cur_update\t$now\n";
    print $fh "target_release\t$my_release\n";
    print $fh "compatible\t$compatible\n";
    print $fh "num_pegs\t$num_pegs\n";
    print $fh "num_genomes\t$num_genomes\n";
    print $fh "num_annos\t$num_annos\n";
    print $fh "num_assignments\t$num_assignments\n";
    close($fh);

    #
    # Construct list of users, and pdate local user database.
    #

    my @users = keys(%users);
    # $fig->ensure_users(\@users);

    return [$session_id, $my_release, $num_assignments, $num_annos, $num_pegs, $num_genomes,
	    $now, $compatible, \@users];
}


sub get_pegs
{
    my($self, $session_id, $start, $len) = @_;
    my(%session_info);

    my $spool_dir = "$FIG_Config::temp/p2p_spool/$session_id";

    -d $spool_dir or die "Invalid session id $session_id";

    #
    # Read in the cached information for this session.
    #

    open(my $info_fh, "<$spool_dir/INFO") or die "Cannot open INFO file: $!";
    while (<$info_fh>)
    {
	chomp;
	my($var, $val) = split(/\t/, $_, 2);
	$session_info{$var} = $val;
    }
    close($info_fh);

    #
    # Sanity check start and length.
    #

    if ($start < 0 or $start >= $session_info{num_pegs})
    {
	die "Invalid start position $start";
    }

    if ($len < 0 or ($start + $len - 1) >= $session_info{num_pegs})
    {
	die "Invalid length $len";
    }

    #
    # Open file, spin to the starting line, then start reading.
    #

    open(my $peg_fh, "<$spool_dir/pegs") or die "Cannot open pegs file: $!";

    my $peg_output = [];
    my $genome_output = [];

    my $peg_num = 0;
    my $genomes_to_show = [];
    my %genomes_to_show;

    my($fid, $genome, @aliases);
       
    while (<$peg_fh>)
    {
	next if ($peg_num < $start);

	last if ($peg_num > ($start + $len));

	chomp;

	#
	# OK, this is a peg to process.
	# It's easy if we're compatible.
	#

	($fid, $genome, @aliases) = split(/\t/, $_);

	if ($session_info{compatible})
	{
	    push(@$peg_output, ['peg', $fid]);
	}
	else
	{
	    if (!$genomes_to_show{$genome})
	    {
		push(@$genomes_to_show, $genome);
		$genomes_to_show{$genome}++;
	    }
	    push(@$peg_output, ['peg_info', $fid, [@aliases], $genome]);
	}
    }
    continue
    {
	$peg_num++;
    }

    #
    # Read the genomes file, returning information about genomes referenced
    # in the pegs returned.
    #

    my $n_left = @$genomes_to_show;

    open(my $gfh, "<$spool_dir/genomes") or die "Cannot open genomes file: $!";
    while ($n_left > 0 and $_ = <$gfh>)
    {
	chomp;

	my($genome, $n_annos, $n_contigs, $n_nucs, $cksum) = split(/\t/);

	if ($genomes_to_show{$genome})
	{
	    push(@$genome_output, [$genome, $n_contigs, $n_nucs, $cksum]);
	    $n_left--;
	}
    }
    close($gfh);

    return [$peg_output, $genome_output];
}

sub finalize_pegs
{
    my($self, $session, $request) = @_;
    my($out);

    my $fig = new FIG;

    #
    # Walk the request handling appropriately. This is fairly easy, as it
    # is just a matter of pulling either sequence or location/contig data.
    #

    for my $item (@$request)
    {
	my($what, $peg) = @$item;

	if ($what eq "peg_genome")
	{
	    #
	    # Return the location and contig checksum for this peg.
	    #
	    # We also include the sequence in case the contig mapping doesn't work.
	    #

	    my $loc = $fig->feature_location($peg);
	    my $contig = $fig->contig_of($loc);
	    my $cksum = $fig->contig_checksum($fig->genome_of($peg), $contig);
	    my $seq = $fig->get_translation($peg);

	    push(@$out, ['peg_loc', $peg,
			$fig->strand_of($peg),
			$fig->beg_of($loc), $fig->end_of($loc),
			$cksum, $seq]);

	}
	elsif ($what eq "peg_unknown")
	{
	    my $seq = $fig->get_translation($peg);
	    push(@$out, ['peg_seq', $peg, $seq]);
	}
    }
    return $out;
}
    

sub get_annotations
{
    my($self, $session_id, $start, $len) = @_;

    #
    # This is now easy; just run thru the saved annotations and return.
    #

    my(%session_info);

    my $spool_dir = "$FIG_Config::temp/p2p_spool/$session_id";

    -d $spool_dir or die "Invalid session id $session_id";

    #
    # Read in the cached information for this session.
    #

    open(my $info_fh, "<$spool_dir/INFO") or die "Cannot open INFO file: $!";
    while (<$info_fh>)
    {
	chomp;
	my($var, $val) = split(/\t/, $_, 2);
	$session_info{$var} = $val;
    }
    close($info_fh);

    #
    # Sanity check start and length.
    #

    if ($start < 0 or $start >= $session_info{num_annos})
    {
	die "Invalid start position $start";
    }

    if ($len < 0 or ($start + $len - 1) >= $session_info{num_annos})
    {
	die "Invalid length $len";
    }

    #
    # Open file, spin to the starting line, then start reading.
    #

    open(my $anno_fh, "<$spool_dir/annos") or die "Cannot open annos file: $!";

    my $anno_output = [];

    my $anno_num = 0;

    local $/ = "//\n";
    while (<$anno_fh>)
    {
	next if ($anno_num < $start);

	last if ($anno_num > ($start + $len));

	chomp;

	my($id, $date, $author, $anno) = split(/\n/, $_, 4);

	push(@$anno_output, [$id, $date, $author, $anno]);
    }
    continue
    {
	$anno_num++;
    }

    return $anno_output;
}

sub get_assignments
{
    my($self, $session_id, $start, $len) = @_;

    #
    # This is now easy; just run thru the saved assignments and return.
    #

    my(%session_info);

    my $spool_dir = "$FIG_Config::temp/p2p_spool/$session_id";

    -d $spool_dir or die "Invalid session id $session_id";

    #
    # Read in the cached information for this session.
    #

    open(my $info_fh, "<$spool_dir/INFO") or die "Cannot open INFO file: $!";
    while (<$info_fh>)
    {
	chomp;
	my($var, $val) = split(/\t/, $_, 2);
	$session_info{$var} = $val;
    }
    close($info_fh);

    #
    # Sanity check start and length.
    #

    if ($start < 0 or $start >= $session_info{num_assignments})
    {
	die "Invalid start position $start";
    }

    if ($len < 0 or ($start + $len - 1) >= $session_info{num_assignments})
    {
	die "Invalid length $len";
    }

    #
    # Open file, spin to the starting line, then start reading.
    #

    open(my $assign_fh, "<$spool_dir/assignments") or die "Cannot open assignments file: $!";

    my $assign_output = [];

    my $assign_num = 0;

    while (<$assign_fh>)
    {
	next if ($assign_num < $start);

	last if ($assign_num > ($start + $len));

	chomp;

	my($id, $date, $author, $func) = split(/\t/, $_, 4);

	push(@$assign_output, [$id, $date, $author, $func]);
    }
    continue
    {
	$assign_num++;
    }

    return $assign_output;
}

1;
