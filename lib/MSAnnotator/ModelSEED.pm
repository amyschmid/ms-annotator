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
my $fba_url = "http://bio-data-1.mcs.anl.gov/services/ms_fba";
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
  # Returns a hash of keyed by id:
  #   app: RunProbModelSEEDJob
  #   status: completed or failed
  #   submit_time: 2017-03-07T15:03:15.496-06:00
  #   start_time: 2017-03-07T15:03:15.753-06:00
  #   stderr_shock_node: 812c27c8-eaa0-4258-a46a-92a73860a0bd
  #   stdout_shock_node: 812c27c8-eaa0-4258-a46a-92a73860a0bd
  #   workspace: /jp102/modelseed/
  #   awe_stderr_shock_node: http://p3.theseed.org/services/shock_api/node/1817541d-eba4-4a3e-920f-0ce4de662e32
  #   awe_stdout_shock_node: http://p3.theseed.org/services/shock_api/node/093b60fa-369e-4627-8c51-d430acc65a0d
  #   id: 39901a7e-db09-4812-9f2c-977d046451f7
  #   completed_time: 0001-01-01T00:00:00Z
  #   parameters:
  #     command: ModelReconstruction
  #     arguments:
  #       output_file: modelseed_name
  #       media: /chenry/public/modelsupport/media/Complete
  #       genome: rast_taxid

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
    eval { $ret = decode_json($res->content)->{result}->[0] };
    $error = "Couldn't parse request" if $@ or !$ret;
  } else {
    $error = $res->status_line;
  }

  # Ensure things went well
  if ($error) {
    croak "Error - ModelSEED CheckJobs failed: $error\n";
  }

  return $ret;
}

sub ms_checkrast {
  # Returns hash of rast analyses as seen by MS keyed by rast_jobid
  # Example return value:
  #   contig_count:  int or null
  #   creation_time: time
  #   genome_id:     rast_jobid
  #   genome_name:   rast_name
  #   genome_size:   int or null
  #   id:            rast_jobid
  #   mod_time:      time
  #   owner:         user
  #   project:       usr_taxid
  #   type:          Genome

  my $ua = LWP::UserAgent->new;
  my $request = {
    version => '1.1',
    method => 'MSSeedSupportServer.list_rast_jobs',
    params => [{}]
  };

  my $res = $ua->post(
    $fba_url,
    Authorization => $token,
    Content => encode_json($request));

  my ($ret, $error);
  if ($res->is_success) {
    eval { $ret = decode_json($res->content)->{result}->[0] };
    $error = "Could parse request" if $@ or !$ret;
  } else {
    $error = $res->status_line;
  }

  # Ensure things went well
  if ($error) {
    croak "Error - ModelSEED CheckJobs failed: $error\n";
  }

  # Have array of hashes, return hash keyed by rast_jobid
  my %ret_hash = map { $_->{id} => $_ } @{$ret};

  return \%ret_hash;
}





1;
