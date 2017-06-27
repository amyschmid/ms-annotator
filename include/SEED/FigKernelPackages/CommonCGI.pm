package CommonCGI;

=head1 Common CGI routines

With the advent of the more advanced server infrastructure using FCGI and
persistent servers it is important to be able to support multiple CGI
applications without burdening each application with the required support
code for the new infrastructure. To this end the CommonCGI module
encapsulates the logic required for initializing the CGI execution environment
and invoking the application's code when the CGI request is set up.

The basic outline of an application is as follows:
   
   use CommonCGI;
   
   my $cgi_handler = CommonCGI->new(max_requests => 50);
   
   $cgi_handler->run(\&main);
    
   sub main {
       my($cgi) = @_;
       # handle one web request as normal, using $cgi as the input parameters
   }

=head2 CommonCGI->new

The constructor for CommonCGI takes the following optional parameters:

=over 4

=item max_requests => N

Limit a single persistent process to at most N requests. After processing
N requests, the C<run> method returns.

=item fcgi_listen_port => N

Instead of listening for FastCGI on stdin, create a listener on port N.

=back

=cut

use strict;
use Data::Dumper;
use IO::Socket;
use Errno;

use CGI;

my $have_async_fcgi;
my $have_fcgi;
eval {
    require CGI::Fast;
    $have_fcgi = 1;
};
eval {
    require Net::Async::FastCGI;
    require IO::Handle;
    require IO::Async::Loop;
    require IO::Async::Handle;
    require IO::Async::Timer::Periodic;
    require IO::Async::Signal;
    require CGI::Fast;
    $have_async_fcgi = 1;
};

sub new
{
    my($class, %opts) = @_;
    my $self = {
	options => \%opts,
    };

    bless $self, $class;
}

sub run
{
    my($self, $exec_coderef, $on_error_coderef) = @_;

    my $sockname = getsockname(\*STDIN);
    my $is_socket = defined($sockname);

    if (($self->{options}->{fcgi_listen_port} || $is_socket) && ! $ENV{REQUEST_METHOD})
    {
	if ($have_async_fcgi)
	{
	    $self->run_async_fcgi($exec_coderef, $on_error_coderef);
	}
	elsif ($have_fcgi && ! $ENV{REQUEST_METHOD})
	{
	    $self->run_sync_fcgi($exec_coderef, $on_error_coderef);
	}
	else
	{
	    die "FCGI not configured but we were started with a socket on stdin\n";
	}
    }
    else
    {
	$self->run_cgi($exec_coderef, $on_error_coderef);
    }
}

sub run_cgi
{
    my($self, $exec_coderef, $on_error_coderef) = @_;
    
    my $cgi = new CGI;
    eval {
	&$exec_coderef($cgi);
    };
    if ($@)
    {
	my $error = $@;
	my $page = &$on_error_coderef($error);
	print $page;
    }
}

sub run_sync_fcgi
{
    my($self, $exec_coderef, $on_error_coderef) = @_;
    
    my $max_requests = $self->{options}->{max_requests} || 50;
    my $n_requests = 0;

    warn "begin loop\n";
    while (($max_requests == 0 || $n_requests < $max_requests))
    {
	my $cgi = CGI::Fast->new();

	if (!$cgi)
	{
	    print STDERR "CGI:Fast returns null, leaving loop\n";
	    last;
	}

	$n_requests++;
	
	eval {
	    &$exec_coderef($cgi);
	};

	if ($@)
	{
	    my $error = $@;
	    my $page = &$on_error_coderef($error);
	    print $page;
	}
    }
}

sub run_async_fcgi
{
    my($self, $exec_coderef, $on_error_coderef) = @_;

    my $loop = IO::Async::Loop->new();
    my $timer = IO::Async::Timer::Periodic->new(interval => 10,
						on_tick => sub {
						    print STDERR "Tick\n";
						});
    $timer->start();
    $loop->add($timer);

    my $n_requests = 0;
    my $fcgi = Net::Async::FastCGI->new(on_request => sub {
					    my($fcgi, $req) = @_;
					    AsyncFcgiReq($loop, $fcgi, $req, $exec_coderef, $on_error_coderef);
					    $n_requests++;
					});

    $loop->add($fcgi);

    my $fcgi_listener;
    if (defined(my $port = $self->{options}->{fcgi_listen_port}))
    {
	$fcgi->listen(service => $port,
		      socktype => 'stream',
		      host => '0.0.0.0',
		      on_resolve_error => sub { die("Cannot resolve - $_[0]"); },
		      on_listen_error  => sub { die("Cannot listen"); },
		      );
		      
    }
    else
    {
	open($fcgi_listener, "<&", \*STDIN);
	close(STDIN);

	$fcgi->configure(handle => $fcgi_listener);
    }
    
    $fcgi->configure(default_encoding => undef);

    my $max_requests = $self->{options}->{max_requests} || 50;
    
    while ($max_requests == 0 || $n_requests < $max_requests)
    {
	$loop->loop_once();
    }

    $fcgi_listener->close() if $fcgi_listener;

    #
    # Wait for asynchronous processing of outstanding FastCGI requests to clear.
    # 
    while (1)
    {
	my $n = scalar grep { ref($_) eq 'Net::Async::FastCGI::ServerProtocol' } $loop->notifiers();
	print "$n:\n";
	print "\t", ref($_), "\n" foreach $loop->notifiers;
	last if ($n < 1);
	print "waiting: $n\n";
	$loop->loop_once();
    }
}

sub AsyncFcgiReq
{
    my($loop, $fcgi, $req, $exec_coderef, $on_error_coderef) = @_;

    my $params = $req->params;
    local %ENV;

    $ENV{$_} = $params->{$_} foreach keys %$params;

    CGI::initialize_globals();

    #
    # Redirect stdin to stdin from fcgi call
    #
    
    my $in = $req->read_stdin;

    print STDERR "got stdin $in\n";
    close(STDIN);
    open(STDIN, "<", \$in);
    my $cgi = CGI->new();
    close(STDIN);

    print STDERR Dumper(\%ENV, $in, $params, $cgi);

    #
    # Redirect stdout to buffer.
    #
    
    my $output = "";
    open(my $save_stdout, ">&", \*STDOUT);
    close(STDOUT);
    open(STDOUT, ">", \$output);

    #
    # Redirect stderr to another buffer
    #
    
    open(my $save_stderr, ">&", \*STDERR);
    my $stderr_buf;
    close(STDERR);
    open(STDERR, ">", \$stderr_buf);
    
    eval {
	&$exec_coderef($cgi);
    };
    my $error = $@;

    #
    # Restore stderr
    #
    close(STDERR);
    open(STDERR, ">&", $save_stderr);
    close($save_stderr);

    #
    # Restore stdout
    #
    
    close(STDOUT);
    open(STDOUT, ">&", $save_stdout);
    close($save_stdout);
    
    if ($error)
    {
	$output = &$on_error_coderef($error);
    }

#    print STDERR "STDERR: <<<$stderr_buf>>>\n";

    #	print STDERR "GOT stdout <<<<\n$output\n>>>>\n";
    $req->print_stdout($output);
    $req->print_stderr($stderr_buf);
    $req->finish();
}

1;
