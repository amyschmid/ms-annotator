package MSAnnotator::NCBI;
use Digest::MD5::File 'file_md5_hex';

# Load custom modukes
use MSAnnotator::Base;
use MSAnnotator::Util 'download_url';

# Export functions
require Exporter;
our @ISA = 'Exporter';
our @EXPORT_OK = qw(get_assembly_summary);

sub get_assembly_summary {
  # Check if summary file exits
  # Download if needed, otherwise check md5
  my $config = shift;
  my $filename = $config->{ncbi_assemblies_file};
  my $url = $config->{ncbi_assemblies_url};

  if (! -e $filename) {
    download_url($url, $filename);
    chmod 0440, $filename;
  } else {
    my $filename_new = "$filename.new";
    download_url($url, $filename_new);
    if (file_md5_hex($filename) ne file_md5_hex($filename_new)) {
      croak 
        "Version of assembly_summary has changed on NCBI, ",
        "version tracking is currently unimplimented\n";
    } else {
      unlink $filename_new;
    }
  }
}

sub get_taxon_query {
  my $config = shift;
  my $assembly_file = $config->{assembly_file};
  my @taxon_input = @{$config->{taxon_input}};
}
  
1;
