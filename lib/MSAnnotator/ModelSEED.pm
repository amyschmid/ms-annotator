package MSAnnotator::ModelSEED;
require Exporter;
use File::Basename;
use HTTP::Request::Common;
use LWP::UserAgent;
use YAML 'LoadFile';
use JSON qw(encode_json decode_json);

# Load custom modules
use MSAnnotator::Base;
use MSAnnotator::Util qw(download_url);
use MSAnnotator::KnownAssemblies qw(update_records get_records);

# Export functions
our @ISA = 'Exporter';
our @EXPORT_OK = qw(modelseed_update_status modelseed_submit modelseed_get_results);

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
  # Returns a hash of keyed by modelseed_jobid:
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
  my ($ms_name, $filetypes) = @_;
  my @filenames = map { "/$user/modelseed/$ms_name/$ms_name" . $_ } @$filetypes;
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
  # Returns modelseed_jobid
  my ($rast_taxid, $ms_name) = @_;
  my $request = {
    version => '1.1',
    method => 'ProbModelSEED.ModelReconstruction',
    params => [{
        genome => "RAST:$rast_taxid",
        output_file => "$ms_name",
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
    my $msid = $asm{modelseed_jobid};
    if (!$msid) {
      next if $asm{rast_status} ne 'complete';
      # Have completed rast without a modelseed_jobid
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
      if ($msjobs->{$msid}->{status} eq 'completed') {
        $ret{$asmid}{modelseed_status} = "complete";
      } elsif ($msjobs->{$msid}->{status} eq 'failed') {
        $ret{$asmid}{modelseed_status} = 'failed';
      }
    }
  }

  # Update records
  update_records(\%ret);
  return \%ret;
}

sub modelseed_submit {
  # Given list of assembly ids
  # Checks records for rast_taxids that need model reconstruction run
  # Updates modelseed_jobid, modelseed_status,
  # NOTE:
  #   modelseed_status could already be set to failed
  #   via modelseed_update_status
  my @asmids = @_;
  my $records = get_records(@asmids);

  while (my ($asmid, $asm) = each %$records) {
    next if $asm->{rast_status} ne "complete" || $asm->{modelseed_jobid};
    next if $asm->{modelseed_status} eq "failed" || ! $asm->{rast_taxid};
    my $rast_id = $asm->{rast_taxid};
    my $ms_name = "MS$rast_id";
    my $modelseed_jobid = modelseed_modelrecon($rast_id, $ms_name);
    update_records({
      $asmid => {
        modelseed_name => $ms_name,
        modelseed_jobid => $modelseed_jobid,
        modelseed_status => "in-progress"}});
  }
}

sub modelseed_get_results {
  # Given list of assembly ids
  # Gets modelseed_name, and downloads files
  # Updates modelseed_result with smbl file
  my @asmids = @_;
  my $records = get_records(@asmids);
  my @filetypes = (".sbml", ".cpdtbl", ".rxntbl");

  while (my ($asmid, $asm) = each %$records) {
    next if $asm->{modelseed_status} ne "complete" || $asm->{modelseed_result};
    my $ms_name = $asm->{modelseed_name};
    my $local_path = $asm->{local_path};
    my $links = modelseed_downloadlinks($ms_name, \@filetypes);
    my $ms_found = 0;
    my $ms_result;

    for my $link (@$links) {
      next if $link eq "null" || !$link;
      my $filename = $local_path . "/" . basename($link);
      chmod(660, $filename) if -e $filename;
      download_url($link, $filename);
      $ms_result = $filename if !$ms_result;
      $ms_result = $filename if $filename =~ /.smbl$/i;
      $ms_found += 1;
      chmod(440, $filename);
    }

    if ($ms_found == 0) {
      croak "Error - Could not find any files to download for $ms_name\n";
    }
    update_records({$asmid => {modelseed_result => $ms_result}});
  }
}

1;
