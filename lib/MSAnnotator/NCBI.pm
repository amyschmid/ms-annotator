package MSAnnotator::NCBI;
use Text::CSV_XS;
use Digest::MD5::File 'file_md5_hex';
use List::MoreUtils 'uniq';
use Clone 'clone';

# Load custom modukes
use MSAnnotator::Base;
use MSAnnotator::Util 'download_url';

# Export functions
require Exporter;
our @ISA = 'Exporter';
our @EXPORT_OK = qw(get_assemblies);

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

  if (! -e $filename) {
    download_url($url, $filename);
    chmod 0440, $filename;
  } else {
    my $filename_new = "$filename.new";
    download_url($url, $filename_new);
    if (file_md5_hex($filename) ne file_md5_hex($filename_new)) {
      croak 
        "Error: Version of assembly_summary has changed on NCBI, ",
        "version tracking is currently unimplimented\n",
        "New version of file can be found here: $filename_new\n";
    } else {
      unlink $filename_new;
    }
  }
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

1;
