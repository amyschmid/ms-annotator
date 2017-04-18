package MSAnnotator::Main;

# Load custom modules
use MSAnnotator::Base;
use MSAnnotator::Config;
use MSAnnotator::NCBI qw(get_assemblies download_assemblies);
use MSAnnotator::RAST qw(rast_submit rast_check_jobs rast_get_results);
use MSAnnotator::ModelSEED qw(ms_modelrecon ms_check_jobs ms_get_results);
use MSAnnotator::KnownAssemblies qw(update_known query_rast_jobids);

# Export functions
require Exporter;
our @ISA = 'Exporter';
our @EXPORT_OK = qw(main);

sub get_tasks {
  # Given a array of asmids
  # Returns a hash of the following form:
  #   needs_rast         => (asmids)
  #   pending_rast       => (rast_jobids)
  #   complete_rast      => (rast_taxid)
  #   needs_modelseed    => (rast_taxid)
  #   pending_modelseed  => (modelseed_ids)
  #   complete_modelseed => (modelseed_ids)
  #
  # known_assemblies are parsed as follows
  #   needs_rast:         asmids without rast_jobids
  #   pending_rast:       rast_jobids without rast_result
  #   complete_rast:      rast_jobids with a rast_result
  #   needs_modelseed:    rast_taxid without modelseed_id
  #   pending_modelseed:  modelseed_id without smbl file
  #   complete_modelseed: has smbl file
  my @asmids = @_;
  my %ret;

  my $known_asmids = get_known_jobids(@asmids);
  for my $asmid (keys %{$known_asmids}) {
    my $known_asm = $known_asmids->{$asmid};
    if (!$known_asm) {
      push @{$ret{needs_rast}}, $asmid;
    } else {
      while (my ($jobid, $asm) = each %{$known_asm}) {
        push @{$ret{complete_rast}}, $jobid if $asm->{rast_result};
        push @{$ret{complete_modelseed}}, $jobid if $asm->{modelseed_result};
        push @{$ret{needs_modelseed}}, $jobid if !$asm->{modelseed_id};
        push @{$ret{pending_rast}}, $jobid if !$asm->{rast_result};
        push @{$ret{pending_modelseed}}, $asm->{modelseed_id} if
        $asm->{modelseed_id} && !$asm->{modelseed_result};
      }
    }
  }
  return \%ret;
}

sub main {
  # Read config, determine assemblies, check against known
  # and download new assemblies
  my $config = load_config();
  my $input_assemblies = get_assemblies($config);
  my $new_assemblies = download_assemblies($config, $assemblies);

  # Get current tasks
  my @asmids = keys %{$assemblies};
  my $tasks = get_tasks(@asmids);

  # Get current RAST / MS status
  my $rast_job_status = rast_check_jobs(;
  my $ms_job_status = ms_check_jobs();
  my $ms_rast_status = ms_check_rast();

  # Check complete
  my %rast_complete = rast_get_complete(...);
  my %ms_complete = rast_get_complete(...);

  # Determine number of tasks submitted to rast/modelseed
  my @rast_running = rast_get_running(...);
  my @ms_running = ms_get_running(...);

  # Make submisions
  my %rast_submisions = rast_submit(...);
  my %ms_submissions = ms_submit(..);

  ## Print status
  #print_status(
  #  $config,
  #  $assemblies,
  #  @rast_running

}

1;
