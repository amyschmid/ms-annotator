package MSAnnotator::ModelSEED;
require Exporter;
use HTTP::Request::Common;
use LWP::UserAgent;
use YAML 'LoadFile';
use JSON qw(encode_json decode_json);

# Load custom modules
use MSAnnotator::Base;
use MSAnnotator::KnownAssemblies qw(update_known get_known_assemblies);

# Export functions
our @ISA = 'Exporter';
our @EXPORT_OK = qw(ms_checkjobs);

# Globals
my $modelseed_url = "http://p3c.theseed.org/dev1/services/ProbModelSEED";
my $auth_url = "http://tutorial.theseed.org/Sessions/Login";
my $credential_file = "credentials.yaml";
my $token = authenticate();

sub authenticate {
  # Mimicing the login method found here:
  # https://github.com/ModelSEED/PATRICClient/blob/master/lib/Bio/P3/Workspace/ScriptHelpers.pm
  my ($user, $password) = @{LoadFile($credential_file)}{qw(user password)};
  my $ua = LWP::UserAgent->new;
  my $res = $ua->post($auth_url, [
      user_id => $user,
      password => $password,
      status => 1,
      cookie => 1,
      fields => "name,user_id,token"]);

  # Make request
  my ($error, $token);
  if ($res->is_success) {
    eval { $token = decode_json($res->content)->{'token'} };
    $error = "Could parse request" if $@ or !$token;
  } else {
    $error = $res->status_line;
  }

  # Ensure things went well
  if ($error) {
    croak "Error - ModelSEED authentication failed: $error\n";
  }

  return $token;
}

sub ms_checkjobs {
  my $ua = LWP::UserAgent->new;
  my $request = {
    version => '1.1',
    method => 'ProbModelSEED.CheckJobs',
    params => [{}]
  };

  my $res = $ua->post(
    $modelseed_url,
    Authorization => $token,
    Content => encode_json($request));

  my ($ret, $error);
  if ($res->is_success) {
    eval {$ret = decode_json($res->content)};
    $error = "Could parse request" if $@ or !$ret;
  } else {
    $error = $res->status_line;
  }

  # Ensure things went well
  if ($error) {
    croak "Error - ModelSEED CheckJobs failed: $error\n";
  }

  return $ret;
}




1;
