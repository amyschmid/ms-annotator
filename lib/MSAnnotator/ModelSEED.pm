package MSAnnotator::ModelSEED;
require Exporter;
use HTTP::Request::Common;
use LWP::UserAgent;
use YAML 'LoadFile';
use JSON qw(encode_json decode_json);

# Load custom modules
use MSAnnotator::Base;
use MSAnnotator::KnownAssemblies qw(update_records get_records);

# Export functions
our @ISA = 'Exporter';
our @EXPORT_OK = qw(modelseed_update_status);

# Globals
my $modelseed_url = "http://p3c.theseed.org/dev1/services/ProbModelSEED";
my $workspace_url = "http://p3.theseed.org/services/Workspace";
my $fba_url = "http://bio-data-1.mcs.anl.gov/services/ms_fba";
my $auth_url = "http://tutorial.theseed.org/Sessions/Login";
my $credential_file = "credentials.yaml";
my ($user, $token) = authenticate();

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
  return ($user, $token);
}

sub modelseed_check_jobs {
  # Returns a hash of keyed by modelseed_id:
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

  # Initialize request
  my $request = {
    version => '1.1',
    method => 'ProbModelSEED.CheckJobs',
    params => [{}]
  };

  # Authenticate
  my $ua = LWP::UserAgent->new;
  my $res = $ua->post(
    $modelseed_url,
    Authorization => $token,
    Content => encode_json($request));

  # Post and check for errors
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

sub modelseed_check_rast {
  # Returns hash of rast analyses as seen by MS keyed by rast_jobid
  # Example return value:
  #   contig_count:  int or null
  #   creation_time: time
  #   genome_id:     rast_taxid
  #   genome_name:   rast_name
  #   genome_size:   int or null
  #   id:            rast_jobid
  #   mod_time:      time
  #   owner:         user
  #   project:       usr_taxid
  #   type:          Genome

  # Initialize request
  my $request = {
    version => '1.1',
    method => 'MSSeedSupportServer.list_rast_jobs',
    params => [{}]
  };

  # Authenticate
  my $ua = LWP::UserAgent->new;
  my $res = $ua->post(
    $fba_url,
    Authorization => $token,
    Content => encode_json($request));

  # Post request
  my ($ret, $error);
  if ($res->is_success) {
    eval { $ret = decode_json($res->content)->{result}->[0] };
    $error = "Could parse request" if $@ or !$ret;
  } else {
    $error = $res->status_line;
  }

  # Ensure things went well
  if ($error) {
    croak "Error - ModelSEED CheckRast failed: $error\n";
  }

  # Have array of hashes, return hash keyed by rast_jobid
  my %ret_hash = map { $_->{id} => $_ } @{$ret};

  return \%ret_hash;
}

sub modelseed_downloadlinks {
  # Given ModelSEED analysis name
  # Return value is array of files ready to download
  my $msname = shift;
  my @filetypes = (".sbml", ".cpdtbl", ".rxntbl");
  my @filenames = map { "/$user/modelseed/$msname/$msname" . $_ } @filetypes;
  my $request = {
    version => '1.1',
    method => 'Workspace.get_download_url',
    params => [{objects => [@filenames]}]
  };

  my $ua = LWP::UserAgent->new;
  my $res = $ua->post(
    $workspace_url,
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
    croak "Error - ModelSEED DownloadLinks failed: $error\n";
  }

  return $ret;
}

sub modelseed_modelrecon {
  # Given a rast_taxid instructs modelseed to reconstruct metabolic model
  # Returns modelseed_id
  my $rast_taxid = shift;
  my $request = {
    version => '1.1',
    method => 'ProbModelSEED.ModelReconstruction',
    params => [{
        genome => "RAST:$rast_taxid",
        output_file => "MS$rast_taxid",
        media => '/chenry/public/modelsupport/media/Complete'}]
  };

  # Authenticate
  my $ua = LWP::UserAgent->new;
  my $res = $ua->post(
    $modelseed_url,
    Authorization => $token,
    Content => encode_json($request));

  # Post request and check for errors
  my ($ret, $error);
  if ($res->is_success) {
    eval { $ret = decode_json($res->content)->{result}->[0] };
    $error = "Could parse request" if $@ or !$ret;
  } else {
    $error = $res->status_line;
  }

  # Ensure things went well
  if ($error) {
    croak "Error - ModelSEED ModelReconstruction failed: $error\n";
  }

  return $ret
}

sub submit_modelrecon {
  # Given rast_jobid
  # Submits model reconstruction and returns modelseed_id
  my $rast_taxids = shift;
  for my $rast_taxid (@{$rast_taxids}) {
    my $modelseed_id = modelseed_modelrecon($rast_taxid);
    update_records($rast_taxid, {modelseed_id => $modelseed_id});
  }
}

#sub modelseed_get_results {
#  # Given array of modelseed_ids and checks status of job
#  # If the job is complete, gets model name, and downloads results
#  # Otherwise sets modelseed_result to "failed"
#  my @modelseed_ids = @_;
#  my $jobs = modelseed_checkjobs();
#
#  my $error;
#  for my $msid (@modelseed_ids) {
#    croak "Error: ModelSEED cannot find jobid $msid" if !exists $jobs->{$msid};
#    my %job = %{$jobs->{msid}};
#    if ($job{'status'} eq 'complete') {
#      my $jobname = $job{parameters}{output_file};
#      my @urls = modelseed_downloadlinks($jobnames);
#      for my $url in (@urls) {
#

sub modelseed_update_status {
  # Given a list of keys, loads assembly_records
  # If rast is complete and no ms status:
  #    checks that rast_jobid can befound via modelseed_checkrast
  #    Will fail without a modelseed_jobid if no genome is found
  # If modelseed_status is in-progress
  #    checks if there job has completed or failed
  # Also will update rast_taxid for any valid completed rast_jobids
  my @input_asmids = @_;
  my $records = get_records(@input_asmids);

  # Get current status from server
  # msrast keys are rast_jobids
  my $msjobs = modelseed_check_jobs;
  my $msrast = modelseed_check_rast;

  # Iterate through asmids and
  # Check if modelseed id is available
  my %ret;
  for my $asmid (keys %$records) {
    my %asm = %{$records->{$asmid}};
    my $rjid = $asm{rast_jobid};
    my $msid = $asm{modelseed_id};
    if (!$msid) {
      next if $asm{rast_status} ne 'complete';
      # Have completed rast without a modelseed_id
      if (!$asm{rast_taxid} and exists $msrast->{$rjid}) {
        my $msrjob = $msrast->{$rjid};
        if ($msrjob->{genome_size} ne 'null') {
          $ret{$asmid}{rast_taxid} = $msrjob->{genome_id};
        } else {
          $ret{$asmid}{modelseed_status} = 'failed';
        }
      }
    } else {
      next if $asm{modelseed_status} ne 'in-progress';
      # Have an in-progress modelseed_jobid
      if ($msjobs->{$msid}->{status} == 'completed') {
        $ret{$asmid}{modelseed_status} = "complete";
      } elsif ($msjobs->{$msid}->{status} == 'failed') {
        $ret{$asmid}{modelseed_status} = 'failed';
      }
    }
  }

  # Update records
  update_records(\%ret);
  return \%ret;
}

1;
