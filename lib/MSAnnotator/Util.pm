package MSAnnotator::Util;
require Exporter;
use File::Basename;
use LWP::Simple qw(getstore is_error);
use Digest::MD5::File 'file_md5_hex';

# Load custom modules
use MSAnnotator::Base

# Export functions
our @ISA = 'Exporter';
our @EXPORT_OK = qw(download_check download_url);

sub download_url {
  # Downloads remote file, otherwise prints error
  my ($url, $filename) = @_;
  my $res = getstore($url, $filename);
  croak "Error: Downnload file. Got $res for:\n  $url" if is_error($res);
}

sub download_check {
  # Downloads remote file, checks md5 if $filename aldready exists
  my ($url, $filename) = @_;
  
  if (! -e $filename) {
    download_url($url, $filename);
  } else {
    my $filename_new = "$filename.new";
    download_url($url, $filename_new);
    if (file_md5_hex($filename) ne file_md5_hex($filename_new)) {
      my $basename = basename $filename;
      croak 
        "Error: version mismatch\n  A newer version found for\n",
        "    file: $basename\n    from: $url\n",
        "  Version tracking is currently unimplimented.\n",
        "  New version of this file can be found here:\n    $filename_new\n";
    } else {
      unlink $filename_new;
    }
  }
}

1;
