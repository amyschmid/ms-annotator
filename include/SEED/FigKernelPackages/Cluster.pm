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
# Routines for managing SEED jobs on a cluster.
#

package Cluster::DBJobMgr;
use strict;

use base qw(Class::Accessor);

__PACKAGE__->mk_accessors(qw(table_name fig db dbh dbms lock_mode));

use constant {
    AVAIL => 0,
    TAKEN => 1,
    DONE => 2,
    FAILED => 3,
};

#
# A database-based job manager.
#
# We use a table in the database to maintain the work to be done and the work
# as completed.
#

sub new
{
    my($class, $fig, $table_name) = @_;

    #
    # Ensure table_name is valid.
    #

    if ($table_name !~ /^\w+$/)
    {
	die "Cluster::DBJobMgr::new: Table name may only consist of alphanumeric characters, no spaces allowed.";
    }

    my $db = $fig->db_handle;
    my $dbh = $db->{_dbh};
    my $dbms = $db->{_dbms};

    my $self = {
	table_name => "pjs_$table_name",
	fig => $fig,
	db => $db,
	dbh => $dbh,
	dbms => $dbms,
	lock_mode => "",
    };

    bless $self, $class;
    
    if ($dbms eq "mysql")
    {
	$self->lock_mode("for update");
    }

    return bless $self, $class;
}

sub get_work
{
    my($self, $worker) = @_;
    my $work;

    my $dbh = $self->dbh;
    my $table = $self->table_name;
    
    local $dbh->{AutoCommit} = 0;
    local $dbh->{RaiseError} = 1;

    eval {
	my $res = $dbh->selectall_arrayref("SELECT * FROM $table
					    WHERE status = ? LIMIT 1 " . $self->lock_mode,
					   undef,
					   AVAIL);
	if (not $res or @$res == 0)
	{
	    die "No work found\n";
	}

	my ($peg, $status, $job_taken, $job_finished, $output) = @{$res->[0]};
	# warn "Found peg=$peg status=$status job info $job_taken $job_finished\n";
	$dbh->do("update $table set status = ?, worker = ?, job_taken = now() where peg = ?", undef,
		 TAKEN, $worker, $peg);

	$dbh->commit();
	$work = $peg;
    };

    if ($@)
    {
	warn "Error in get_work eval: $@\n";
	$dbh->rollback();
	return;
    }
    else
    {
	return $work;
    }
}

sub work_done
{
    my($self, $work, $output) = @_;

    my $dbh = $self->dbh;
    my $table = $self->table_name;

    local $dbh->{AutoCommit} = 0;
    local $dbh->{RaiseError} = 1;

    eval {
	$dbh->do("update $table set status = ?, job_finished = now(), output = ? where peg = ?", undef,
		 DONE, $output, $work);

	$dbh->commit();
    };

    if ($@)
    {
	warn "Error in work_done eval: $@\n";
	$dbh->rollback();
	die "Invalid work request: $@";
    }
    else
    {
	return 1;
    }
    
}

sub work_done
{
    my($self, $work, $output) = @_;

    my $dbh = $self->dbh;
    my $table = $self->table_name;

    local $dbh->{AutoCommit} = 0;
    local $dbh->{RaiseError} = 1;

    eval {
	$dbh->do("update $table set status = ?, job_finished = now(), output = ? where peg = ?", undef,
		 DONE, $output, $work);

	$dbh->commit();
    };

    if ($@)
    {
	warn "Error in work_done eval: $@\n";
	$dbh->rollback();
	die "Invalid work_done request: $@";
    }
    else
    {
	return 1;
    }
    
}

sub work_aborted
{
    my($self, $work) = @_;

    my $dbh = $self->dbh;
    my $table = $self->table_name;

    local $dbh->{AutoCommit} = 0;
    local $dbh->{RaiseError} = 1;

    eval {
	$dbh->do("update $table set status = ?, job_finished = now(), output = NULL where peg = ?", undef,
		 AVAIL, $work);

	$dbh->commit();
    };

    if ($@)
    {
	warn "Error in work_aborted eval: $@\n";
	$dbh->rollback();
	die "Invalid work_aborted request:$@";
    }
    else
    {
	return 1;
    }
    
}

package Cluster::Broker;

use Cwd 'abs_path';
use File::Basename;
use Time::HiRes 'time';
use FIG_Config;
use FIG;

our $ns = "http://mcs.anl.gov/FL/Schemas/cluster_service";

use constant {
    AVAIL => 0,
    TAKEN => 1,
    DONE => 2,
    FAILED => 3,
};

use strict;
use Data::Dumper;
use File::Copy;

our $cluster_spool = "$FIG_Config::fig_disk/ClusterSpool";

=head1 Job Broker

Perl code for job broker functionality.

A broker instance maintains a database of jobs. Each job has a description
of some sort (heh), including a field defining the type of job. The plan
at this point is to not generalize the job type management, but to rather to
inclde a job type in the job table, but then to use a separate table to hold
the individual of work in each of the job types (sim-computaton, scopmap, etc).

A complication that might occur is that we wish to be able to allocate a piece
of work with a single query "get me the next available piece of work and mark
that piece as being worked on". If jobs are kept in multiple tables, this becomes
difficult. We may be able to get around this by keeping a single work table
that refers, for each piece of work, to the work type and identifier for that
workpiece.


=cut

sub init_job_tables
{
    my($db) = @_;

    local $db->{_dbh}->{AutoCommit} = 0;

    my $serial_type;
    if ($db->{_dbms} eq "mysql")
    {
	$serial_type = "int not null auto_increment";
    }
    elsif ($db->{_dbms} eq "Pg")
    {
	$serial_type = "serial";

	$db->SQL("SET CONSTRAINTS ALL DEFERRED");
    }

    # 
    # Tables for constants.
    #

    $db->drop_table(tbl => 'js_work_type');
    $db->create_table(tbl => 'js_work_type',
		      flds => qq(id $serial_type primary key,
				 name varchar(64)
				)
		      );

    $db->drop_table(tbl => 'js_work_status');
    $db->create_table(tbl => 'js_work_status',
		     flds => qq(status int primary key,
				name varchar(64)
			       )
		     );
    
    $db->SQL("insert into js_work_status values (?, ?)", undef, AVAIL, 'AVAIL');
    $db->SQL("insert into js_work_status values (?, ?)", undef, TAKEN, 'TAKEN');
    $db->SQL("insert into js_work_status values (?, ?)", undef, FAILED, 'FAILED');
    $db->SQL("insert into js_work_status values (?, ?)", undef, DONE, 'DONE');

    #
    # A work entry belongs to a job.
    # It can have zero or more exec records associated; each exec
    # record documents an attempt to run that piece of work on
    # a particular worker. If all goes well, there will be only
    # one, but jobs get killed..
    #

    $db->drop_table(tbl => 'js_job');
    $db->create_table(tbl => 'js_job',
		      flds => qq(id $serial_type PRIMARY KEY
				 )
		      );

    #
    # Table for generating work id's so the cluster and noncluster
    # work items don't have overlapping IDs, so they can be distinguished
    # by id.
    #
    $db->drop_table(tbl => 'js_work_id');
    $db->create_table(tbl => 'js_work_id',
		      flds => qq(id $serial_type PRIMARY KEY
				 )
		      );

    $db->drop_table(tbl => 'js_cluster');
    $db->create_table(tbl => 'js_cluster',
		      flds => qq(id $serial_type primary key,
				 name varchar(255),
				 info text
				 )
		      );
				 
    $db->drop_table(tbl => 'js_worker');
    $db->create_table(tbl => 'js_worker',
		      flds => qq(id $serial_type primary key,
				 cluster_id int REFERENCES js_cluster,
				 hostname varchar(255),
				 username varchar(32),
				 pid int,
				 exe varchar(255),
				 last_heartbeat timestamp
				 )
		      );

    #
    # We use the is_cluster_work flag to implement the
    # has_cluster_work relation - there is no work that
    # is not either prolog or non-prolog work, so the
    # job_id reference here implements the has_work relation,
    # and the is_prolog_work flag partitions the work.
    #
    # If must_execute_on_cluster is not NULL, then this piece
    # of work is a cluster-work item for that cluster. It must
    # be executed before non cluster-work items.
    # In this case, work_derived_from refers to the work item
    # that was replicated to create this piece of work. This is
    # used to locate the type-specific information of this piece
    # of work.
    #
    
    $db->drop_table(tbl => 'js_work');
    $db->create_table(tbl => 'js_work',
		      flds => qq(id int PRIMARY KEY REFERENCES js_work_id,
				 job_id int REFERENCES js_job,
				 work_type int REFERENCES js_work_type,
				 status int REFERENCES js_work_status,
				 active_exec_id int,
				 output text
				)
		      );
    $db->create_index(tbl => 'js_work',
		      idx => 'js_work_idx_status',
		      flds => 'status');
    $db->create_index(tbl => 'js_work',
		      idx => 'js_work_idx_status_jobid',
		      flds => ' job_id, status');

    #
    # Execution record for a piece of work.
    #

    $db->drop_table(tbl => 'js_exec');
    $db->create_table(tbl => 'js_exec',
		      flds => qq(id $serial_type primary key,
				 work_id int REFERENCES js_work,
				 worker_id int REFERENCES js_worker,
				 status int REFERENCES js_work_status,
				 job_taken timestamp,
				 job_finished timestamp
				 )
		      );

    #
    # A piece of per-cluster work.
    # 
    # Since we don't completely know which cluster the work has to run on when it is
    # created, we use a cluster_work entry with must_execute_on_cluster = NULL to
    # hold the template for future clusters' work.
    #

    $db->drop_table(tbl => 'js_cluster_work');
    $db->create_table(tbl => 'js_cluster_work',
		      flds => qq(id int PRIMARY KEY REFERENCES js_work_id,
				 job_id int REFERENCES js_job,
				 work_type int REFERENCES js_work_type,
				 status int REFERENCES js_work_status,
				 active_exec_id int,
				 must_execute_on_cluster int REFERENCES js_cluster,
				 work_derived_from int REFERENCES js_cluster_work,
				 output text
				)
		      );
    $db->create_index(tbl => 'js_cluster_work',
		      idx => 'js_cluster_work_idx_status',
		      flds => 'status');
    $db->create_index(tbl => 'js_cluster_work',
		      idx => 'js_cluster_work_idx_exec_type',
		      flds => 'must_execute_on_cluster, work_type');



    #
    # Execution record for a piece of cluster work.
    #

    $db->drop_table(tbl => 'js_cluster_exec');
    $db->create_table(tbl => 'js_cluster_exec',
		      flds => qq(id $serial_type primary key,
				 cluster_id int REFERENCES js_cluster,
				 work_id int REFERENCES js_cluster_work,
				 worker_id int REFERENCES js_worker,
				 status int REFERENCES js_work_status,
				 job_taken timestamp,
				 job_finished timestamp
				 )
		      );

    
    $db->drop_table(tbl => 'js_worker_can_execute');
    $db->create_table(tbl => 'js_worker_can_execute',
		      flds => qq(worker_id int REFERENCES js_worker,
				 work_type int REFERENCES js_work_type
				 )
		      );
    $db->create_index(tbl => 'js_worker_can_execute',
		      idx => 'js_worker_can_execute_idx',
		      flds =>'worker_id, work_type');
    
    
    #
    # Setup for the sim jobtype.
    #
    # The stuff in here isn't really needed at runtime, but for reporting
    # or accounting info at the user level will be useful. It records the
    # semantics of the parameters of the job.
    #
    # It is also used in distributing job-specific work (the threshhold here must
    # be distributed to the clients).
    #

    $db->drop_table(tbl => 'js_job_sim');
    $db->create_table(tbl => 'js_job_sim',
		      flds => qq(id int PRIMARY KEY REFERENCES js_job,
				 nr_path varchar(255),
				 input_path varchar(255),
				 output_path varchar(255),
				 chunk_size int,
				 thresh double precision
				)
		      );

    #
    # For each piece of work, there is a js_work and a js_sim_work
    # record. The js_work record keeps track of the job-independent
    # info, the js_sim_work record keeps track of the job-dependent
    # info (here, the input sequence).
    #
    
    $db->drop_table(tbl => 'js_sim_work');
    $db->create_table(tbl => 'js_sim_work',
		      flds => qq(id int PRIMARY KEY REFERENCES js_work,
				 input_seq text
				)
		      );

    $db->SQL("insert into js_work_type (name) values ('sim')");

    #
    # File staging work.
    #

    $db->drop_table(tbl => 'js_stage_work');
    $db->create_table(tbl => 'js_stage_work',
		      flds => qq(id int PRIMARY KEY REFERENCES js_cluster_work,
				 path varchar(255)
				)
		      );

    $db->SQL("insert into js_work_type (name) values ('stage')");

    #
    # Blast NR staging work.
    #

    $db->drop_table(tbl => 'js_stage_nr_work');
    $db->create_table(tbl => 'js_stage_nr_work',
		      flds => qq(id int PRIMARY KEY REFERENCES js_cluster_work,
				 path varchar(255)
				)
		      );

    $db->SQL("insert into js_work_type (name) values ('stage_nr')");

}

#
# Constructor for a cluster scheduler instance.
#

sub new
{
    my($class, $fig) = @_;

    my $self = {
	fig => $fig,
	db => $fig->db_handle,
	dbh => $fig->db_handle->{_dbh},
	dbms => $fig->db_handle->{_dbms},
    };

    bless $self, $class;

    return $self;
}

###############################
#
# Worker registration.
#

=head1 register_worker

Register this worker with the task manager.  It will return a worker
ID for use in future calls.  We pass the cluster name here as well,
and the cluster ID is also returned.

=cut

sub register_worker
{
    my($self, $host, $user, $pid, $exe, $cluster_id, $work_types) = @_;

    #
    # Validate work-types; should be either undef or a list.
    #

    if ($work_types and ref($work_types) ne "ARRAY")
    {
	die "Invalid type for work_types list";
    }

    #
    # We shouldn't have to worry about any concurrency issues in this code.
    # Each worker individually registers and gets its own id.
    #

    $cluster_id =~ /^\d+$/ or die "Invalid cluster id";

    my $sth = $self->{dbh}->prepare("insert into js_worker (cluster_id, hostname, username, pid, exe) values (?, ?, ?, ?, ?)");
    $sth->execute($cluster_id, $host, $user, $pid, $exe);

    my $id = $self->get_inserted_id('js_worker', $sth);

    #
    # Create the worker_can_execute entries from the work-types list.
    #

    if ($work_types)
    {
	my $qs = join(", ", map { "?" } @$work_types);

	$self->{db}->SQL(qq(INSERT INTO js_worker_can_execute
			       (SELECT ?, id
				FROM js_work_type
				WHERE name in ( $qs ))), undef, $id, @$work_types);
    }

    return $id;
}

sub lookup_cluster
{
    my($self, $name) = @_;

    my $res = $self->{db}->SQL("select id from js_cluster where name = ?", undef, $name);
    if ($res and @$res > 0)
    {
	my $id = $res->[0]->[0];
	return $id;
    }
    else
    {
	return undef;
    }
}

sub register_cluster
{
    my($self, $name, $info) = @_;

    my $id = $self->lookup_cluster($name);
    
    return $id if defined($id);

    my $sth = $self->{dbh}->prepare("insert into js_cluster (name, info) values (?, ?)");
    $sth->execute($name, $info);
    my $id = $self->get_inserted_id('js_cluster', $sth);

    #
    # We must ensure that there is a cluster-work entry for each piece
    # of work that is marked as cluster work.
    #
    # LOCKING
    #

    $self->create_cluster_work_entries_for_cluster($id);
    
    return $id;
}

sub create_cluster_work_entries_for_cluster
{
    my($self, $cluster_id) = @_;

    #
    # Find all cluster work so we can create new work entries for this cluster.
    #
 
   my $res = $self->{db}->SQL("select id, job_id, work_type from js_cluster_work where must_execute_on_cluster is null");

    my $sth = $self->{dbh}->prepare(q(INSERT INTO js_cluster_work (id, job_id, work_type, status, must_execute_on_cluster, work_derived_from)
				      VALUES (?, ?, ?, ?, ?, ?)));

    for my $ent (@$res)
    {
	my($id, $job_id, $work_type) = @$ent;

	my $nwork_id = $self->get_work_id();
	$sth->execute($nwork_id, $job_id, $work_type, AVAIL, $cluster_id, $id);
    }
}

sub create_cluster_work_entries_for_job
{
    my($self, $job_id) = @_;

    #
    # Find all clusters so we can create new work entries for this job.
    #

    my $res = $self->{db}->SQL("select id from js_cluster");

    my $job_res = $self->{db}->SQL("select id, work_type from js_cluster_work where must_execute_on_cluster is null and job_id = ?",
			      undef, $job_id);

    my $sth = $self->{dbh}->prepare(q(INSERT INTO js_cluster_work (id, job_id, work_type, status,  must_execute_on_cluster, work_derived_from)
				      VALUES (?, ?, ?, ?, ?, ?)));

    for my $ent (@$res)
    {
	my($cluster_id) = @$ent;

	for my $jent (@$job_res)
	{
	    my($work_id, $work_type) = @$jent;

	    my $nwork_id = $self->get_work_id();
	    $sth->execute($nwork_id, $job_id, $work_type, AVAIL, $cluster_id, $work_id);
	}
    }
}

###############################
#
# Work allocation.
#
#

=head1 get_work

Retrieve the next piece of work.

We first want to retrieve work that is part of a job that does not have any (remaining)
cluster work items. If there is no such work, attempt to retrieve a piece of
cluster work. If there is none, return a wait code.

We begin the process by creating two lists. First, a list of jobs that have cluster work to be done
(either available or currently being worked upon) on MY_CLUSTER_ID (the ID of the cluster that
the worker in question belongs to):
    
    SELECT id, job_id
    FROM js_cluster_work
    WHERE must_execute_on_cluster = MY_CLUSTER_ID and status  = AVAIL
    ORDER BY job_id, id

Second, a list of jobs that have noncluster work to do:

    SELECT id, job_id
    FROM js_work
    WHERE status = AVAIL
    ORDER BY job_id, id

We can now define our policy. The ORDER BY clauses, together with the
sequential allocation of job and work identifiers by the
auto-incrementing table keys, enforce a FIFO ordering on jobs and work
units. We choose work by picking the lowest numbered job between the
two lists.

In other words, if we have a job with noncluster work available with a
lower jobid than another job with cluster-work available, we will
allocate first to the lower job.

Similarly, if there is cluster work ready to be done for the cluster
the current worker is part of, we prefer doing that even to working on
a job that has work to be done that has a larger jobid.

Note that that the two queries above do not take into account work
that is currently in progress. We must account for the following case:

If there is no cluster work available for a particular job, and there is
noncluster work available for that job, we must check that the cluster
work for that job is actually finished:

    SELECT count(*)
    FROM js_cluster_work
    WHERE must_execute_on_cluster = MY_CLUSTER_ID and status = 1 and
	  job_id = SOMEJOB

We require that the count above be zero; otherwise we cannot allocate 
work out of SOMEJOB. If it is the case that additional jobs are
available, it is then possible to allocate work out of them, following
the rules above.

We can use grouping to determine this status in fewer queries:

   SELECT job_id, status, count(id) 
   FROM js_cluster_work
   WHERE must_execute_on_cluster = MY_CLUSTER_ID
   GROUP BY job_id, status
   ORDER_BY job_id

This gives us the complete status of cluster work for my cluster id. 

=cut

sub get_work
{
    my($self, $worker_id) = @_;
    my(@times);
    push(@times, time, '');
    my @tables = qw(js_cluster_exec
		    js_cluster_work
		    js_exec
		    js_work
		    js_worker
		    );

    $self->worker_alive($worker_id);

    #
    # A FigKernelPackages::DBrtns object
    #
    my $db = $self->{db};

    #
    # A DBI database handle.
    #
    my $dbh = $self->{dbh};

    push(@times, time, 'init');
    my $worker_info = $self->get_worker_info($worker_id);

    my $cluster_id = $worker_info->{cluster_id};

    #
    # Serialize completely for now.
    #
    
    push(@times, time, 'get info');

    local $dbh->{AutoCommit} = 0;
    $self->lock_tables(@tables);

    push(@times, time, 'lock tables');

    #
    # Determine the jobs that have cluster and noncluster work.
    #

    my $res = $db->SQL(qq(SELECT w.job_id, w.status, count(w.id)
			  FROM js_cluster_work w, js_worker_can_execute e 
			  WHERE w.must_execute_on_cluster = ? AND
			  	e.worker_id = ? AND
			  	w.work_type = e.work_type
			  GROUP BY job_id, status),
		       undef, $cluster_id, $worker_id);
    push(@times, time, 'get cluster');

    #
    # Work is a hash with key of job_id. Each value is a
    # pair
    #
    #    hash from status => count of entries
    #    noonzero if work is available
    # 
    my %work;

    for my $ent (@$res)
    {
	my($job_id, $status, $count) = @$ent;

	$work{$job_id}->[0]->{$status} = $count;
    }


    push(@times, time, 'crunch');
    my $noncluster_work = $dbh->selectcol_arrayref(qq(SELECT distinct(job_id)
						      FROM js_work w, js_worker_can_execute e
						      WHERE status = ? AND
						      	    e.worker_id = ? AND
						            w.work_type = e.work_type
						      ORDER BY job_id), undef, AVAIL, $worker_id);
    push(@times, time, 'get noncluster');
    map { $work{$_}->[1] = 1; } @$noncluster_work;
    
    # print "Got work ", Dumper(\%work);

    #
    # We can now walk %work looking for entries where there is either cluster work
    # available, or cluster work is finished and noncluster work is available, or
    # there is no cluster work and cluster work is available.
    #
    # If any of these conditions is not met, we return a waitcode.
    #

    my $ret;

    push(@times, time, 'got work');
    for my $job_id (sort keys %work)
    {
	my($cluster_hash, $noncluster_avail) = @{$work{$job_id}};

	#
	# Only assign cluster work if there is noncluster work available to be worked on.
	#
	if ($cluster_hash->{+AVAIL} > 0 and
	    $noncluster_avail)
	{
	    warn"ASSIGN cluster work for job $job_id\n";
	    $ret = $self->assign_cluster_work($job_id, $cluster_id, $worker_id);
	    last;
	}
	elsif ($cluster_hash->{+AVAIL} == 0 and
	       $cluster_hash->{+TAKEN} == 0 and
	       $noncluster_avail)
	{
	    warn "ASSIGN noncluster for job $job_id\n";
	    $ret = $self->assign_noncluster_work($job_id, $worker_id);
	    last;
	}
	elsif (!defined($cluster_hash) and $noncluster_avail)
	{
	    warn "ASSIGN noncluster (no cluster work) for job $job_id\n";
	    $ret = $self->assign_noncluster_work($job_id, $worker_id);
	    last;
	}
    }
    push(@times, time, 'assigned');

    my $last = shift(@times);
    shift(@times);
    while (@times)
    {
	my($t, $tag) = splice(@times, 0, 2);
	my $elap = 1000 * ($t - $last);
	warn sprintf "Elap $tag: %.2f ms\n", $elap;
    }


    if (!$ret)
    {
	warn "ASSIGN waitcode\n";
	$ret = $self->assign_waitcode();
    }

    $self->unlock_tables(@tables);
    $self->{dbh}->commit();
    
    return $ret;
}

#
# Return a set of handles that should be used for uploading computation results.
#

sub get_upload_handles
{
    my($self, $job_id, $work_id, $worker_id, $filenames) = @_;

    $self->worker_alive($worker_id);
    my $stage_url = new URI($self->{fig}->cgi_url());
    $stage_url->path_segments($stage_url->path_segments(), "cluster_stage.cgi");

    my $ret = {};
    for my $name (@$filenames)
    {
	$stage_url->query_form(work_id => $work_id,
			       job_id => $job_id,
			       filename => $name);
	
	$ret->{$name} = $stage_url->as_string();
    }
    return $ret;
}

#
# Heartbeat.
#

sub worker_alive
{
    my($self, $worker_id) = @_;

    $self->{db}->SQL("update js_worker set last_heartbeat = NOW() where id = ?",
		     undef, $worker_id);
}

#
# Mark this work done.
#

sub work_done
{
    my($self, $job_id, $work_id, $worker_id, $output) = @_;
    
    $self->worker_alive($worker_id);
    #
    # Find the exec entry for this work. We also determine here
    # whether this is a cluster or noncluster piece of work.
    #

    local $self->{dbh}->{AutoCommit} = 0;
    $self->lock_tables(qw(js_work js_cluster_work js_exec js_cluster_exec));

    my $ncw = $self->{db}->SQL(qq(SELECT status, active_exec_id
				  FROM js_work
				  WHERE id = ? and job_id = ?),
			       undef, $work_id, $job_id);

    if (@$ncw == 1)
    {
	my($status, $exec) = @{$ncw->[0]};

	warn "noncluster done: status=$status exec=$exec output=$output\n";
	

	$self->unlock_tables(qw(js_work js_cluster_work js_exec js_cluster_exec));
	$self->{dbh}->commit();
	

	return $self->work_done_noncluster(1, $job_id, $work_id, $worker_id, $output, $status, $exec);
    }

    my $cw = $self->{db}->SQL(qq(SELECT status, active_exec_id, must_execute_on_cluster
				 FROM js_cluster_work
				 WHERE id = ? and job_id = ?),
			      undef, $work_id, $job_id);

    if (@$cw == 1)
    {
	my($status, $exec, $cluster) = @{$cw->[0]};

	warn "cluster done: status=$status exec=$exec cluster=$cluster\n";
	
	$self->unlock_tables(qw(js_work js_cluster_work js_exec js_cluster_exec));
	$self->{dbh}->commit();
	return $self->work_done_cluster(1, $job_id, $work_id, $worker_id, $output, $status, $exec, $cluster);
    }

    $self->unlock_tables(qw(js_work js_cluster_work js_exec js_cluster_exec));
    $self->{dbh}->commit();

    die "Could not find work entries";
}
#
# Mark this work as failed.
#

sub work_failed
{
    my($self, $job_id, $work_id, $worker_id, $output) = @_;
    
    $self->worker_alive($worker_id);

    #
    # Find the exec entry for this work. We also determine here
    # whether this is a cluster or noncluster piece of work.
    #

    local $self->{dbh}->{AutoCommit} = 0;
    $self->lock_tables(qw(js_work js_cluster_work js_exec js_cluster_exec));

    my $ncw = $self->{db}->SQL(qq(SELECT status, active_exec_id
				  FROM js_work
				  WHERE id = ? and job_id = ?),
			       undef, $work_id, $job_id);

    if (@$ncw == 1)
    {
	my($status, $exec) = @{$ncw->[0]};

	warn "noncluster failed: status=$status exec=$exec output=$output\n";
	
	$self->unlock_tables(qw(js_work js_cluster_work js_exec js_cluster_exec));
	$self->{dbh}->commit();
	return $self->work_done_noncluster(0, $job_id, $work_id, $worker_id, $output, $status, $exec);
    }

    my $cw = $self->{db}->SQL(qq(SELECT status, active_exec_id, must_execute_on_cluster
				 FROM js_cluster_work
				 WHERE id = ? and job_id = ?),
			      undef, $work_id, $job_id);

    if (@$cw == 1)
    {
	my($status, $exec, $cluster) = @{$cw->[0]};

	warn "cluster failed: status=$status exec=$exec cluster=$cluster\n";

	$self->unlock_tables(qw(js_work js_cluster_work js_exec js_cluster_exec));
	$self->{dbh}->commit();
	
	return $self->work_done_cluster(0, $job_id, $work_id, $worker_id, $output, $status, $exec, $cluster);
    }

    $self->unlock_tables(qw(js_work js_cluster_work js_exec js_cluster_exec));
    $self->{dbh}->commit();
    die "Could not find work entries";
}

#
# Noncluster work is complete. Mark the exec record, then mark the work record.
#

sub work_done_noncluster
{
    my($self, $success, $job_id, $work_id, $worker_id, $output, $old_status, $exec) = @_;

    my $db = $self->{db};


    $db->SQL(qq(UPDATE js_exec
		SET status = ?, job_finished = NOW()
		WHERE id = ?),
	     undef,
	     $success ? DONE : FAILED,
	     $exec);
    
    $db->SQL(qq(UPDATE js_work
		SET status = ?, output = ?
		WHERE id = ?),
	     undef, 
	     $success ? DONE : AVAIL,
	     $output,
	     $work_id);

    return 1;
}


sub work_done_cluster
{
    my($self, $success, $job_id, $work_id, $worker_id, $old_status, $output, $exec, $cluster) = @_;

    my $db = $self->{db};

    $db->SQL(qq(UPDATE js_cluster_exec
		SET status = ?, job_finished = NOW()
		WHERE id = ?),
	     undef,
	     $success ? DONE : FAILED,
	     $exec);
    
    $db->SQL(qq(UPDATE js_cluster_work
		SET status = ?
		WHERE id = ?),
	     undef,
	     $success ? DONE : AVAIL,
	     $work_id);

}

###############################
#
# Job setup code.
#
#


=head1 setup_sim_job

Set up for a new similarity computation.

We are given a NR filename, a fasta input filename, a chunk size,
and an optional BLAST threshhold.

We create a new sim_job record for this job, and create a spool directory
for it. The NR and fasta input are copied to the spool directory.

The fasta is carved up into chunk_size blocks of sequences. js_work and js_sim_work
records are created for each of the blocks.

=cut

sub setup_sim_job
{
    my($self, $nr, $input, $chunk_size, $thresh) = @_;

    if (!defined($thresh))
    {
	$thresh = 1.0e-5;
    }

    &FIG::verify_dir($cluster_spool);

    #
    # Find the job type for sims.
    #

    my $sim_job_type;
    my $res = $self->{db}->SQL("select id from js_work_type where name = 'sim'");
    if ($res and @$res > 0)
    {
	$sim_job_type = $res->[0]->[0];
    }
    else
    {
	die "Cannot determine job type for sim jobs.";
    }

    #
    # Create the job record for this run.
    #

    #
    # Feh.
    #

    my $sth;
    if ($self->{dbms} eq "Pg")
    {
	$sth = $self->{dbh}->prepare("insert into js_job default values ");
    }
    else
    {
	$sth = $self->{dbh}->prepare("insert into js_job () values ()");
    }
    
    $sth->execute();
    my $id = $self->get_inserted_id('js_job', $sth);

    warn "Got new id $id\n";

    my $sth = $self->{dbh}->prepare("insert into js_job_sim (id, chunk_size, thresh) values (?, ?, ?)");
    $sth->execute($id, $chunk_size, $thresh);

    #
    # Create the spool directory.
    #

    my $spool = "$cluster_spool/sim_$id";

    &FIG::verify_dir($spool);

    my $nr_file = "$spool/nr";
    my $input_file = "$spool/fasta";
    my $output_dir = "$spool/out";
    &FIG::verify_dir($output_dir);

    $nr = abs_path($nr);
    $input = abs_path($input);

    #
    # for now, symlink so we don't have to wait on copy.
    #

    if (-f $nr_file)
    {
	unlink($nr_file) or die "Could not remove old nr file $nr_file: $!\n";
    }

    if (-s $nr > 100000)
    {
	symlink($nr, $nr_file);
    }
    else
    {
	copy($nr, $nr_file);
    }

    if (-f $input_file)
    {
	unlink($input_file) or die "Could not remove old input file $input_file: $!\n";
    }
    
    if (-s $input > 100000)
    {
	symlink($input, $input_file);
    }
    else
    {
	copy($input, $input_file);
    }

    $self->{db}->SQL("update js_job_sim set nr_path = ?, input_path = ?, output_path = ? where id = ?",
		     undef, $nr_file, $input_file, $output_dir, $id);

    $self->add_nr_input_file($id, $nr_file);
    $self->add_input_file($id, $input_file);
    #
    # We know enough now to chunk up the job and create the work entries.
    #

    open(my $fasta_fh, "<$input_file");

    local($/) = "\n>";

    sub add_work_chunk
    {
	my($chunk) = @_;

	my $chunk_txt = join("\n", @$chunk) . "\n";

	my $work_id = $self->get_work_id();
	
	my $sth = $self->{dbh}->prepare("insert into js_work (id, job_id, work_type, status) values (?, ?, ?, ?)");
	$sth->execute($work_id, $id, $sim_job_type, AVAIL);
	# print "Created work $work_id\n";

	$self->{db}->SQL("insert into js_sim_work values (?, ?)", undef, $work_id, $chunk_txt);
    }

    my @cur_chunk;
    
    while (<$fasta_fh>)
    {
	chomp;

	#
	# Zorch the leading > we get on the first line.
	#

	s/^>//g;

	#
	# And add it back; the chomp removes it.
	#
	push(@cur_chunk, ">$_");

	if (@cur_chunk == $chunk_size)
	{
	    add_work_chunk(\@cur_chunk);
	    @cur_chunk = ();
	}
	
    }
    if (@cur_chunk > 0)
    {
	add_work_chunk(\@cur_chunk);
    }
    close($fasta_fh);

    #
    # If we know of any clusters, we need to create the cluster-work entris
    # for this job.
    #

    $self->create_cluster_work_entries_for_job($id, $sim_job_type);

}



###############################
#
# Utilities.
#
#

sub assign_waitcode
{
    my($self) = @_;

    return {
	work_name => "wait",
	job_specific => {}
    };
}

=head1 assign_cluster_work

Assign a piece of cluster work from job $job_id to worker $worker_id.

=cut

sub assign_cluster_work
{
    my($self, $job_id, $cluster_id, $worker_id) = @_;

    my $res = $self->{db}->SQL(qq(SELECT w.id, w.work_type, n.name, w.work_derived_from
				  FROM js_cluster_work w, js_work_type n
				  WHERE
				  	w.status = ? AND
				  	w.work_type = n.id AND
				  	w.job_id = ? AND
				  	w.must_execute_on_cluster = ?
				  ORDER BY w.id
				  LIMIT 1
				 ), undef, AVAIL, $job_id, $cluster_id);
    if (not $res or @$res == 0)
    {
	die "assign_cluster_work: work lookup failed\n";
    }
    my($work_id, $work_type, $work_name, $derived_from) = @{$res->[0]};

    #
    # Create an execution record for this assignment.
    #

    my $sth = $self->{dbh}->prepare(qq(INSERT INTO js_cluster_exec (work_id, cluster_id, worker_id,
								    status, job_taken)
				       VALUES (?, ?, ?, ?, NOW())));
    $sth->execute($work_id, $cluster_id, $worker_id, TAKEN);
    my $exec_id = $self->get_inserted_id('js_cluster_exec', $sth);

    #
    # Now update the work record.
    #

    $self->{db}->SQL(qq(UPDATE js_cluster_work
			SET status = ?, active_exec_id = ?
			WHERE id = ?), undef, TAKEN, $exec_id, $work_id);

    return $self->construct_work_return($job_id, $worker_id, $work_id, $derived_from,
					$exec_id, $work_type, $work_name);
}


sub assign_noncluster_work
{
    my($self, $job_id, $worker_id) = @_;

    my $res = $self->{db}->SQL(qq(SELECT w.id, w.work_type, n.name
				  FROM js_work w, js_work_type n
				  WHERE
				  	w.status = ? AND
				  	w.work_type = n.id AND
				  	w.job_id = ? 
				  ORDER BY w.id
				  LIMIT 1
				 ), undef, AVAIL, $job_id);

    if (not $res or @$res == 0)
    {
	die "assign_cluster_work: work lookup failed\n";
    }
    my($work_id, $work_type, $work_name) = @{$res->[0]};

    #
    # Create an execution record for this assignment.
    #

    my $sth = $self->{dbh}->prepare(qq(INSERT INTO js_exec (work_id, worker_id, status, job_taken)
				       VALUES (?, ?, ?, NOW())));
    $sth->execute($work_id, $worker_id, TAKEN);
    my $exec_id = $self->get_inserted_id('js_exec', $sth);

    #
    # Now update the work record.
    #

    $self->{db}->SQL(qq(UPDATE js_work
			SET status = ?, active_exec_id = ?
			WHERE id = ?), undef, TAKEN, $exec_id, $work_id);

    return $self->construct_work_return($job_id, $worker_id, $work_id, $work_id,
					$exec_id, $work_type, $work_name);
}

=head1

Construct the work assignment to be returned from a get_work
request. This routine is given all of the particulars for a pice 
of work, including the name of the worktype. We attempt to create
the return by invoking $self->constuct_work_for_TYPE.

(Better design likely needed for this, but this is proof of principle code.)

$actual_work_id is the work_id that has the type-specific work attached. This
will be different than $work_id in the case of cluster work, where a base
piece of work is snapshotted for each cluster; the type-specific work information
remains attached to the base work.

=cut

sub construct_work_return
{
    my($self, $job_id, $worker_id, $work_id, $actual_work_id, $exec_id, $work_type, $work_name) = @_;

    #
    # Construct the return struct. It has the following fields at all times;
    # per-work-type methods are allowed to add/modify as desired.
    #
    my $ret = {
	job_id => $job_id,
	worker_id => $worker_id,
	work_id => $work_id,
	exec_id => $exec_id,
	work_name => $work_name,
	job_specific => {},
    };

    my $ok = eval {
	$work_name =~ /^\w+$/ or die "Invalid work_name $work_name";
	my $method = "construct_work_for_$work_name";
	$self->$method($ret->{job_specific}, $job_id, $worker_id, $work_id, $actual_work_id, $exec_id);
    };

    if (!$ok)
    {
	warn "construct_work_return: work-specific construction for $work_name failed: $@";
    }

    return $ret;
}

sub construct_work_for_stage_nr
{
    my($self, $return_struct, $job_id, $worker_id, $work_id, $actual_work_id, $exec_id) = @_;

    #
    # For staging, we return the URL by which the client will retrieve the file.
    #

    my $stage_url = new URI($self->{fig}->cgi_url());
    $stage_url->path_segments($stage_url->path_segments(), "cluster_stage.cgi");
    $stage_url->query_form(work_id => $actual_work_id,
			   job_id => $job_id);

    my $res = $self->{dbh}->selectcol_arrayref("select path from js_stage_nr_work where id = ?",
					       undef, $actual_work_id);

    $return_struct->{file} = basename($res->[0]);
    $return_struct->{url} = $stage_url->as_string();
}

sub construct_work_for_stage
{
    my($self, $return_struct, $job_id, $worker_id, $work_id, $actual_work_id, $exec_id) = @_;

    #
    # For staging, we return the URL by which the client will retrieve the file.
    #

    my $stage_url = new URI($self->{fig}->cgi_url());
    $stage_url->path_segments($stage_url->path_segments(), "cluster_stage.cgi");
    $stage_url->query_form(work_id => $actual_work_id,
			   job_id => $job_id);

    my $res = $self->{dbh}->selectcol_arrayref("select path from js_stage_work where id = ?",
					       undef, $actual_work_id);

    $return_struct->{file} = basename($res->[0]);
    $return_struct->{url} = $stage_url->as_string();

}

=head1 construct_work_for_sim

Job-specific work return method.

=cut
    
sub construct_work_for_sim
{
    my($self, $return_struct, $job_id, $worker_id, $work_id, $actual_work_id, $exec_id) = @_;

    my $out = $self->{dbh}->selectcol_arrayref(qq(SELECT input_seq
						  FROM js_sim_work
						  WHERE id = ?), undef, $actual_work_id);
    if (not $out or @$out != 1)
    {
	die "construct_work_for_sim: query did not return expected results for actual_work_id=$actual_work_id";
    }

    $return_struct->{input_seq} = $out->[0];

    #
    # We also lookup the BLAST threshhold information from the job.
    #
    
    my $out = $self->{dbh}->selectcol_arrayref(qq(SELECT thresh
						  FROM js_job_sim
						  WHERE id = ?), undef, $job_id);
    if (not $out or @$out != 1)
    {
	die "construct_work_for_sim: job query did not return expected results for job_id=$job_id";
    }

    $return_struct->{blast_thresh} = $out->[0];
}

=head1 open_staging_file

Open a filehandle to the file we are staging to a client.

We are given the job_id and work_id that define the file. If there are any
problems, return undef (or die if there is an error message).

=cut

sub open_staging_file
{
    my($self, $job_id, $work_id) = @_;

    #
    # Determine what kind of staging this was.
    #
    
    my $out = $self->{dbh}->selectcol_arrayref(qq(SELECT wt.name 
						  FROM js_cluster_work w, js_work_type wt
						  WHERE wt.id = w.work_type AND
						  	w.job_id = ? AND
						  	w.id = ?),
					       undef, $job_id, $work_id);
    $out and @$out == 1 or
	die "open_staging_file: job query did not return expected results for work_id=$work_id";

    my $work_type = $out->[0];

    my $out = $self->{dbh}->selectcol_arrayref(qq(SELECT path
						  FROM js_${work_type}_work 
						  WHERE id = ? ), undef, $work_id);
    if (not $out or @$out != 1)
    {
	die "open_staging_file: job query did not return expected results for work_id=$work_id";
    }

    my $fh;
    my $size;
    my $file = $out->[0];

    $size = -s $file;

    if (open($fh, "<$file"))
    {
	return ($fh, $size, basename($file));
    }
    else
    {
	die "open_staging_file: could not open file: $!";
    }
    
}

=head1 open_output_file

Open a filehandle to the file we are writing as output from a worker.

We are given the job_id and work_id that define the file. If there are any
problems, return undef (or die if there is an error message).

=cut

sub open_output_file
{
    my($self, $job_id, $work_id, $filename) = @_;

    my $job_dir = "$cluster_spool/job_$job_id";
    &FIG::verify_dir($job_dir);
    my $work_dir = "$job_dir/work_$work_id";
    &FIG::verify_dir($work_dir);
    
    my $local_path = "$work_dir/" . basename($filename);

    my $fh;
    if (open($fh, ">$local_path"))
    {
	return $fh;
    }
    else
    {
	die "Cannot open $local_path: $!";
    }
}

=head1 add_input_file

Add a file to the set of files to be staged for input to a job. Returns the file id.

=cut

sub add_input_file
{
    my($self, $job_id, $path) = @_;

    my $stage_job_type;
    my $res = $self->{db}->SQL("select id from js_work_type where name = 'stage'");
    if ($res and @$res > 0)
    {
	$stage_job_type = $res->[0]->[0];
    }
    else
    {
	die "Cannot determine job type for sim jobs.";
    }

    my $work_id = $self->get_work_id();
    
    my $sth = $self->{dbh}->prepare("insert into js_cluster_work (id, job_id, work_type, status) values (?, ?, ?, ?)");

    $sth->execute($work_id, $job_id, $stage_job_type, AVAIL);
    
    $self->{db}->SQL("insert into js_stage_work values (?, ?)", undef, $work_id, $path);
}

sub add_nr_input_file
{
    my($self, $job_id, $path) = @_;

    my $stage_job_type;
    my $res = $self->{db}->SQL("select id from js_work_type where name = 'stage_nr'");
    if ($res and @$res > 0)
    {
	$stage_job_type = $res->[0]->[0];
    }
    else
    {
	die "Cannot determine job type for sim jobs.";
    }

    my $work_id = $self->get_work_id();

    my $sth = $self->{dbh}->prepare("insert into js_cluster_work (id, job_id, work_type, status) values (?, ?, ?, ?)");

    $sth->execute($work_id, $job_id, $stage_job_type, AVAIL);
    
    $self->{db}->SQL("insert into js_stage_nr_work values (?, ?)", undef, $work_id, $path);
}

sub get_work_id
{
    my($self) = @_;
    my $sth;
    if ($self->{dbms} eq "Pg")
    {
	$sth = $self->{dbh}->prepare("insert into js_work_id default values ");
    }
    else
    {
	$sth = $self->{dbh}->prepare("insert into js_work_id () values ()");
    }
    $sth->execute();
    my $work_id = $self->get_inserted_id('js_work_id', $sth);
    return $work_id;
}


sub lock_tables
{
    my($self, @tables) = @_;

    if ($self->{dbms} eq "Pg")
    {
	$self->{db}->SQL("LOCK TABLE " . join(", ", @tables));
    }
    else
    {
    }
}

sub unlock_tables
{
    my($self, @tables) = @_;

    if ($self->{dbms} eq "Pg")
    {

    }
    else
    {
    }
}

sub get_inserted_id
{
    my($self, $table, $sth) = @_;
    if ($self->{dbms} eq "Pg")
    {
	my $oid = $sth->{pg_oid_status};
	my $ret = $self->{db}->SQL("select id from $table where oid = ?", undef, $oid);
	return $ret->[0]->[0];
    }
    elsif ($self->{dbms} eq "mysql")
    {
	my $id = $self->{dbh}->{mysql_insertid};
	# print "mysql got $id\n";
	return $id;
    }
}

sub get_worker_info
{
    my($self, $id) = @_;

    my $res = $self->{dbh}->selectall_hashref("select * from js_worker where id = ?",
					      'id', undef, $id);
    return $res->{$id};
}



1;
