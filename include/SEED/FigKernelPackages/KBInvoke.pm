
package KBInvoke;

use MIME::Base64;
use URI::Escape;
use Data::Dumper;
use POSIX;
use strict;
use LWP::UserAgent;
use JSON::XS;

my $get_time = sub { time, 0 };
eval {
    require Time::HiRes;
    $get_time = sub { Time::HiRes::gettimeofday() };
};

#
# Simple JSON-RPC KBase style RPC invocation module.
#
# Usage:
#
# my $client = KBInvoke->new($service_url, $service_name, $auth_token);
#
# my $res = $client->call("method_name", param1, param2, ...)
#
# We also have simple helpers for getting auth tokens.
#
# $token = KBInvoke::rast_server_login($username, $override_user, $override_pass)
#


use base 'Class::Accessor';
__PACKAGE__->mk_accessors(qw(service_url service_name auth_token ua));

sub new
{
    my($class, $service_url, $service_name, $auth_token) = @_;

    my $self = {
	service_url => $service_url,
	service_name => $service_name,
	auth_token => $auth_token,
	ua => LWP::UserAgent->new(),
	json => JSON::XS->new,
	headers => [],
	id => int(rand(1000000)),
    };

    if ($ENV{KBRPC_TAG})
    {
	$self->{kbrpc_tag} = $ENV{KBRPC_TAG};
    }
    else
    {
	my ($t, $us) = &$get_time();
	$us = sprintf("%06d", $us);
	my $ts = strftime("%Y-%m-%dT%H:%M:%S.${us}Z", gmtime $t);
	$self->{kbrpc_tag} = "C:$0:$self->{hostname}:$$:$ts";
    }
    push(@{$self->{headers}}, 'Kbrpc-Tag', $self->{kbrpc_tag});

    if ($ENV{KBRPC_METADATA})
    {
	$self->{kbrpc_metadata} = $ENV{KBRPC_METADATA};
	push(@{$self->{headers}}, 'Kbrpc-Metadata', $self->{kbrpc_metadata});
    }

    if ($ENV{KBRPC_ERROR_DEST})
    {
	$self->{kbrpc_error_dest} = $ENV{KBRPC_ERROR_DEST};
	push(@{$self->{headers}}, 'Kbrpc-Errordest', $self->{kbrpc_error_dest});
    }

    if ($auth_token)
    {
	push(@{$self->{headers}}, Authorization => $auth_token);
    }

    my $timeout = $ENV{CDMI_TIMEOUT} || (30 * 60);	 
    $self->{ua}->timeout($timeout);


    return bless $self, $class;
}

sub call
{
    my($self, $method, @args) = @_;

    my $method = $self->{service_name}  . "." . $method;

    my $obj = {
	jsonrpc => '2.0',
	method => $method,
	params => \@args,
	id => $self->{id}++,
    };

    my $content = $self->{json}->encode($obj);

    my $res = $self->{ua}->post($self->{service_url},
				Content_Type => "application/json",
				Content => $content,
				Accept => "application/json",
				@{$self->{headers}});
    

    if (!$res->is_success)
    {
	die "KBInvoke call failed to $method: " . $res->content;
    }
    my $txt = $res->content;
    my $ret = $self->{json}->decode($txt);

    if ($ret->{error})
    {
	die $ret->{error};
    }

    return wantarray ? @{$ret->{result}} : $ret->{result}->[0];
    
}

sub rast_server_login
{
    my($target_username, $override_user, $override_pass) = @_;

    my $ua = LWP::UserAgent->new;

#    my $url = "http://rast.nmpdr.org/goauth/token";
    my $url = "https://p3.theseed.org/goauth/token";

    my $tu = uri_escape($target_username);
    my $res = $ua->get("$url?grant_type=client_credentials&user_for_override=$tu",
		      "Authorization", "Basic " . encode_base64("$override_user:$override_pass"));
							      
    if (!$res->is_success)
    {
	die "rast_server_login failed: " . $res->content;
    }
    my $txt = $res->content;
    my $dec = decode_json($txt);
    return $dec->{access_token};
}

sub rast_user_login
{
    my($username, $password) = @_;
    my $url = "https://p3.theseed.org/goauth/token";
    return globus_login($url, $username, $password);
}

sub kbase_user_login
{
    my($username, $password) = @_;
    my $url = "https://nexus.api.globusonline.org/goauth/token";
    return globus_login($url, $username, $password);
}

sub globus_login
{
    my($url, $username, $password) = @_;

    my $ua = LWP::UserAgent->new;

    my $res = $ua->get("$url?grant_type=client_credentials",
		      "Authorization", "Basic " . encode_base64("$username:$password"));
							      
    if (!$res->is_success)
    {
	die "rast_user_login failed: " . $res->content;
    }
    my $txt = $res->content;
    my $dec = decode_json($txt);
    return $dec->{access_token};
}

sub patric_user_login
{
    my($username, $password) = @_;

    my $content = {
	username => $username,
	password =>$ password,
    };

    my $ua = LWP::UserAgent->new;

    my $url = "https://user.patricbrc.org/authenticate";

    my $res = $ua->post($url, $content);
							      
    if (!$res->is_success)
    {
	if ($res->code == 401)
	{
	    die "patric_user_login: invalid password";
	}
	else
	{	      
	    die "patric_user_login failed: " . $res->status_code . " " . $res->content;
	}
    }

    return $res->content;
}

1;
