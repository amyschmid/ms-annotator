package MSAnnotator::NCBI;
use Text::CSV_XS;
use List::MoreUtils 'uniq';
use Clone 'clone';
use Parallel::ForkManager;

# Load custom modukes
use MSAnnotator::Base;
use MSAnnotator::Util 'download_check';

# Export functions
require Exporter;
our @ISA = 'Exporter';
our @EXPORT_OK = qw(get_assemblies download_assemblies);

# Header in expected order
use constant ASSEMBLY_HEADER => (
  "assembly_accession",
  "bioproject",
  "biosample",
  "wgs_master",
  "refseq_category",
  "taxid",
  "species_taxid",
  "organism_name",
  "infraspecific_name",
  "isolate",
  "version_status",
  "assembly_level",
  "release_type",
  "genome_rep",
  "seq_rel_date",
  "asm_name",
  "submitter",
  "gbrs_paired_asm",
  "paired_asm_comp",
  "ftp_path",
  "excluded_from_refseq");

sub get_assembly_summary {
  # Check if summary file exits
  # Download if needed, otherwise check md5
  my ($filename, $url) = @_;
  download_check($url, $filename);
  chmod 0440, $filename;
}

sub load_ncbi_assemblies {
  # Returns a hash keyed by ftp location
  # Values are a hash corresponding to column names
  my $filename = shift;
  my @assembly_header = (ASSEMBLY_HEADER);

  my $csv = Text::CSV->new({sep => "\t", binary => 1, auto_diag => 1});
  open my $fh, "<", $filename or croak "$!: $filename\n";

  # Look for header
  my @header;
  while (my $line = <$fh>) {
    $line =~ s/^#\s+//;
    $csv->parse($line);
    my @line_parsed = $csv->fields();
    if (@line_parsed ~~ @assembly_header) {
      @header = @line_parsed;
      last;
    } 
  }

  # Ensure something was found
  croak "Error: Unexpected header format in NCBI assembly file\n" if !@header;
  
  # Make return hash
  my %ret;
  $csv->column_names(@header);
  while (my $row = $csv->getline_hr($fh)) {
    my $key = (split('/', $row->{ftp_path}))[-1];
    croak "Error: Duplicate assembly ids found\n" if exists $ret{$key};
    $ret{$key} = clone $row;
  }
  close $fh;
  return \%ret;
}

sub get_assemblies {
  # Returns list of assemblies associated with all any / all taxids entered
  # First all species_taxid are identified, then all assemblies are returned
  my $config = shift;

  # Ensure assembly_summary exists
  get_assembly_summary(
    $config->{ncbi_assemblies_file},
    $config->{ncbi_assemblies_url});

  my $assemblies = load_ncbi_assemblies(
    $config->{ncbi_assemblies_file});

  # Identify all species taxids, using keys of hash to keep unique values
  my %taxid_species;
  my @taxid_in = @{$config->{taxid_input}};
  for my $asm (values %{$assemblies}) {
    if ($asm->{taxid} ~~ @taxid_in or $asm->{species_taxid} ~~ @taxid_in) {
      $taxid_species{$asm->{species_taxid}} = undef;
    }
  }

  my %assemblies_keep;
  my @taxid_keep = keys %taxid_species;
  for my $asm_key (keys %{$assemblies}) {
    if ($assemblies->{$asm_key}->{species_taxid} ~~ @taxid_keep) {
      $assemblies_keep{$asm_key} = clone $assemblies->{$asm_key};
    }
  }
  return \%assemblies_keep;
}

sub download_assembly {
  # Download assembly from NCBI
  # See 
  my ($asmid, $baseurl, $data_dir) = @_;
  my $download_path = $data_dir . "/" . $asmid;
  my @filetypes = (
    "_assembly_report.txt",
    "_assembly_stats.txt",
    "_genomic.gbff.gz");

  mkdir $download_path if ! -e $download_path;
  for my $ft (@filetypes) {
    my $filename = $download_path . "/" . $asmid . $ft;
    my $url = $baseurl . "/" . $asmid . $ft;
    download_check($url, $filename);
  }
}

sub download_assemblies {
  my ($config, $assemblies) = @_;
  my $pm = new Parallel::ForkManager(10);
  for my $asmid (keys %{$assemblies}) {
    $pm->start and next;
    download_assembly(
      $asmid,
      $assemblies->{$asmid}->{ftp_path},
      $config->{data_dir});
    $pm->finish;
  }
}

1;
