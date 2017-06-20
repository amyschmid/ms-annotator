package MSAnnotator::Main;
use Clone 'clone';
use POSIX 'strftime';
use Text::Table;

# Load custom modules
use MSAnnotator::Base;
use MSAnnotator::Config;
use MSAnnotator::NCBI qw(get_input_asmids get_new_asmids  add_asmids);
use MSAnnotator::KnownAssemblies qw(update_records add_records get_records);
use MSAnnotator::RAST qw(rast_update_status rast_get_results rast_submit);
use MSAnnotator::ModelSEED qw(modelseed_update_status modelseed_submit modelseed_get_results);

# Export functions
require Exporter;
our @ISA = 'Exporter';
our @EXPORT_OK = qw(main);

sub get_status {
  my ($input, $asmids) = @_;
  my $records = get_records(@$asmids);
  my @rescols = qw(
    date taxids_input taxids_found ms_complete
    rast_complete running failed pending);

  # Number of input taxids found
  my %res = map { $_ => 0 } @rescols;
  $res{taxids_input} = scalar @$input;
  $res{taxids_found} = scalar @$asmids;

  # Count status
  for my $asm (values %$records) {
    $res{ms_complete} += 1 if $asm->{modelseed_result};
    $res{rast_complete} += 1 if $asm->{rast_result};
    $res{running} += 1 if $asm->{rast_status} eq "running";
    $res{running} += 1 if $asm->{modelseed_status} eq "running";
    $res{failed} += 1 if $asm->{rast_status} eq "failed";
    $res{failed} += 1 if $asm->{modelseed_status} eq "failed";
    $res{pending} += 1 if !$asm->{rast_status};
    $res{pending} += 1 if !$asm->{modelseed_status};
  }

  return \%res
}

sub print_status {
  my %args = @_;
  my $print_header = $args{print_header};
  my %status = %{$args{status}};
  $status{date} = strftime("%I:%M:%S %F   ", localtime);

  my @header_columns = qw(
    date taxids_input taxids_found ms_complete
    rast_complete running failed pending);
  my @header = map { $_ . "\n" . "-" x length($_) } @header_columns;
  $header[0] = "";

  my $tb = Text::Table->new(@header);
  $tb->load([map { $status{$_} } @header_columns]);

  if ($print_header) {
    print $tb;
  } else {
    print $tb->body();
  }
}

sub remote_tasks {
  my ($asmidref, $config) = @_;
  my @asmids = @$asmidref;

  # Get current RAST / MS  status and update assembly_records
  rast_update_status(@asmids);
  modelseed_update_status(@asmids);

  # Download complete RAST / MS analyses
  rast_get_results(@asmids);
  modelseed_get_results(@asmids);

  # Make submisions
  rast_submit(\@asmids, $config->{rast_maxjobs});
  modelseed_submit(\@asmids, $config->{modelseed_maxjobs});

  # Get status
  return get_status($config->{taxid_input}, \@asmids);
}

sub main {
  # Read config, determine assemblies, check against assembly_records, download new
  my $config = load_config();

  # Get lists of input and determine needed asmids
  my $input_asmids = get_input_asmids($config);
  my $new_asmids = get_new_asmids($input_asmids);
  add_asmids($config, $new_asmids) if %$new_asmids;

  # All ids to process
  my @asmids = keys %$input_asmids;
  my $status = remote_tasks(\@asmids, $config);
  print_status(status => $status, print_header => 1);

  while ($status->{running} + $status->{pending} > 1) {
    sleep $config->{sleeptime};
    $status = remote_tasks(\@asmids, $config);
    print_status(status => $status, print_header => 0);
  }

  say "All jobs completed!";
}

1;
