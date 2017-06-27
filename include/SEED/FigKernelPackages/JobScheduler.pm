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
# This is a simple job scheduler, built for the SEED environment.
#
# A job queue is maintained in the directory $FIG_Config::fig/var/JobQueue.
#
# Each entry in the queue is a directory named J_XXXX where J_XXXX is the job ID.
#
# In each entry is a file job.in which contains the input to the job. 
# The job's output and error are written to files named job.out and job.err.
# The exit status is written to a file job.exit_status.
# The job's  current queue status is kept in a file job.queue_status.
#
# The actual job to be executed is a script job.script. It is the responsibility 
# of the application enqueuing the job that the script is created with proper
# executable perms, #! lines, etc.
# 
# A new job is created using $job = $scheduler->job_create(). 
#
# The paths to the job script, in, out, and error files are obtained by
# $job->get_script_path(), get_in_path(), get_out_path(), get_err_path().
#
# Any access to a job's data must occur with the lockfile job.lock held.
#
# When a job is ready to be started, $job->enqueue() is invoked.
#
# Queue status values:
#
# X	Job not yet ready
# Q	Job queued, waiting to run.
# R	Job currently running.
# D	Job done.
# F	Job failed.
#

package JobScheduler;

use Carp;
use FIG;
use FIG_Config;
use FileHandle;
use DirHandle;
use FileLocking;
use Fcntl ':flock';
    
use strict;

my %status_strings = (X => "Not ready",
		      Q => "Queued",
		      R => "Running",
		      D => "Complete",
		      F => "Failed");
=head2 Methods

=cut

sub new
{
    my($class, $dir) = @_;

    $dir = "$FIG_Config::fig/var/JobQueue" unless $dir;

    &FIG::verify_dir("$FIG_Config::fig/var");
    #warn "Scheduler using $dir\n";
    &FIG::verify_dir($dir);

    my $self = {
	dir => $dir,
    };

    bless $self, $class;

    return $self;
}

sub job_create
{
    my($self) = @_;

    my $job_id = $self->get_next_job_id();

    my $job_dir = "$self->{dir}/$job_id";

    mkdir($job_dir) or die "Error creating job queue directory $job_dir: $!\n";

    my $job = JobScheduler::Job->new($self, $job_id, $job_dir);

    $job->set_queue_status("X");

    #
    # Create an empty stdin file.
    #
    my $in_path = $job->get_in_path();
    open(my $in_fh, ">$in_path");
    close($in_fh);

    return $job;
}

=head3 job_delete

Remove a job directory and all associated files. This will completely remove the job, so be sure you really want to do this :)

Returns 1 on success and 0 on error, and writes the error to STDERR

=cut

sub job_delete 
{
    my($self, $job)=@_;
    my $job_dir = "$self->{dir}/$job";
    unless (-e $job_dir) {print STDERR "No directory found for requested job $job\n"; return 0}
    my $result=`rm -rf $job_dir`;
    if ($result) {print STDERR "Removing caused this error:\n$result\n"; return 0}
    else {return 1}
}

=pod

=head3 get_job_to_execute

Determine the next job that is ready to run.

If one exists, returns a pair ($job, $lock_fh) where $lock_fh is the lockfile handle.

=cut

sub get_job_to_execute
{
    my($self) = @_;

    #
    # Scan the job queue looking for the next job that is ready to run.
    #


    my @jobs = $self->get_job_list();
    # warn "Candidate jobs: @jobs\n";

    #
    # Run through the jobs in order.
    #
    # We grab the lock here because we will take the first job
    # that is ready to run, and wish to hold the lock while
    # we change status to "running".
    #
    
    my($job_to_run, $job_lock);

    for my $id (@jobs)
    {
	my $job = $self->get_job($id);

	my $lock = $job->lock();

	my $status = $job->get_queue_status(1);

	if ($status eq "Q")
	{
	    #
	    # It's ready to run.
	    #
	    $job_to_run = $job;
	    $job_lock = $lock;
	    last;
	}
	else
	{
	    $lock->close();
	}
    }

    if ($job_to_run)
    {
	return ($job_to_run, $job_lock);
    }
    return undef;
}

sub get_job_list
{
    my($self) = @_;

    my $dh = new DirHandle("$self->{dir}");
    my @jobs = sort grep { /^J_\d+/ } $dh->read();

    return @jobs;
}

=pod
    
=head3 get_job($id)

Get a job object for job id $id.

=cut

sub get_job
{
    my($self, $id) = @_;

    my $job_dir = "$self->{dir}/$id";

    my $job;
    if (-d $job_dir)
    {
	$job = JobScheduler::Job->new($self, $id, $job_dir);
    }

    return $job;
}

sub get_next_job_id
{
    my($self) = @_;

    #
    # Use $dir/NextJob to get the index of the next job to be created.
    #
    # Ensure we hold the $dir/sched.lock lockfile before reading or modifying NextJob.
    #

    my $lock = $self->lock_scheduler();

    my $job_fh;
    my $job_file = "$self->{dir}/NextJob";
    my $job_id;

    if (open($job_fh, "<$job_file"))
    {
	$job_id = <$job_fh>;
	chomp($job_id);
	close($job_fh);
    }
    else
    {
	$job_id = 1000;
    }


    #
    # Write the jobfile back with an incremented id.
    #

    open($job_fh, ">$job_file") or die "Cannot write $job_file: $!\n";
    
    printf $job_fh "%d\n", $job_id + 1;

    close($job_fh);

    $lock->close();
    return sprintf("J_%05d", $job_id);
}

sub lock_scheduler
{
    my($self) = @_;

    my $fh = claim_lockfile("$self->{dir}/sched.lock");

    return $fh;
}

=pod

=head3 get_status()

Return the current status of jobs in the scheduler.
This will be a list of [job_id, status code, status string] tuples.

=cut

sub get_status
{
    my($self) = @_;

    my @jobs = $self->get_job_list();

    my @ret;

    for my $id (@jobs)
    {
	my $job = $self->get_job($id);
	my $stat = $job->get_queue_status();
	push(@ret, [$id, $stat, $status_strings{$stat}]);
    }
    return @ret;
}

=pod

=head3 claim_lockfile($file)

Open $file and invoke flock(LOCK_EX) on it.

Returns the open filehandle, to be closed when the lock is to be released.

=cut
sub claim_lockfile
{
    shift if UNIVERSAL::isa($_[0],__PACKAGE__);
    my($file) = @_;

    my $fh = new FileHandle;

    sysopen($fh, $file, O_RDWR | O_CREAT) or confess "Cannot open lockfile $file: $!\n";

    flock($fh, LOCK_EX) or die "Cannot flock $file: $!\n";

    return $fh;
}

package JobScheduler::Job;

use strict;
use Errno;

sub new
{
    my($class, $scheduler, $id, $dir) = @_;

    my $self = {
	dir => $dir,
	scheduler => $scheduler,
	id => $id,
    };

    bless $self, $class;

    return $self;
}

sub lock
{
    my($self) = @_;

    return JobScheduler::claim_lockfile("$self->{dir}/job.lock");
}

sub enqueue
{
    my($self, $dont_lock) = @_;

    $self->set_queue_status("Q", $dont_lock);
}

sub get_id
{
    my($self) = @_;

    return $self->{id};
}
    

=pod

=head3 run($lock_fh)

Run this job. $lock_fh is the filehandle for the current lock on this job. The lock
will be released when the method exits.

=cut

sub run
{
    my($self, $lock_fh) = @_;

    $lock_fh = $self->lock() unless $lock_fh;

    #
    # Fork a process to run the job. It will chdir to the 
    # spool directory, and redirect stdin/out/err to the correct
    # files.
    #

    #
    # First make sure we can execute the job script.
    #

    open(my $log, ">>$self->{dir}/job.log");
    
    my $script = $self->get_script_path();
    if (! -x $script)
    {
	print $log "Job script $script not executable\n";
	warn "Job script $script not executable\n";
	$self->set_queue_status("F", 1);
	$lock_fh->close();
	return;
    }

    $self->set_queue_status("R", 1);

    #
    # Fork a child.
    #

    my $pid = fork;

    if ($pid == 0)
    {
	open(STDIN, "<" . $self->get_in_path());
	open(STDOUT, ">" . $self->get_out_path());
	open(STDERR, ">" . $self->get_err_path());

	chdir($self->{dir});

	$lock_fh->close();

	exec($script);

	exit 1;
    }

    open(my $fh, ">$self->{dir}/monitor.pid");
    print $fh "$$\n";
    close($fh);

    open(my $fh, ">$self->{dir}/job.pid");
    print $fh "$pid\n";
    close($fh);

    $lock_fh->close();

    #
    # Wait for the child to finish.
    #

    my $wpid = waitpid($pid, 0);
    my $stat = $?;

    print $log "Child $wpid finished with status $stat\n";
    warn "Child $wpid finished with status $stat\n";

    my $lock = $self->lock();

    unlink("$self->{dir}/monitor.pid");
    unlink("$self->{dir}/job.pid");

    if ($stat == 0)
    {
	$self->set_queue_status("D", 1);
    }
    else
    {
	$self->set_queue_status("F", 1);
    }

    open(my $fh, ">$self->{dir}/job.exit_status");
    print $fh "$stat\n";
    close($fh);

    $lock->close();
    
}

sub set_queue_status
{
    my($self, $status, $dont_lock) = @_;

    my $lock = $self->lock() unless $dont_lock;

    open(my $fh, ">$self->{dir}/job.queue_status") or
	die "Cannot write $self->{dir}/job.queue_status: $!\n";

    print $fh "$status\n";
    close($fh);

    $lock->close() if $lock;
}

sub get_queue_status
{
    my($self, $dont_lock) = @_;

    my $lock = $self->lock() unless $dont_lock;
    my $status;

    if (open(my $fh, "<$self->{dir}/job.queue_status"))
    {

	$status = <$fh>;
	chomp($status);
	close($fh);
    }
    else
    {
	if ($!{ENOENT})
	{
	    #
	    # No status file is the same as "X".
	    #

	    $status = "X";
	}
	else
	{
	    die "Cannot read $self->{dir}/job.queue_status: $!\n";
	}
    }

    $status = "X" if $status eq "";
    

    $lock->close() if $lock;

    return $status;
}

sub get_script_path
{
    my($self) = @_;

    return "$self->{dir}/job.script";
}
    
sub get_in_path
{
    my($self) = @_;

    return "$self->{dir}/job.in";
}
    
sub get_out_path
{
    my($self) = @_;

    return "$self->{dir}/job.out";
}
    
sub get_err_path
{
    my($self) = @_;

    return "$self->{dir}/job.err";
}
    

1;
