package MSAnnotator::Util;
require Exporter;
use LWP::Simple qw(getstore is_error);

# Load custom modules
use MSAnnotator::Base

# Export functions
our @ISA = 'Exporter';
our @EXPORT_OK = qw(download_url );

sub download_url {
  # Downloads remote file, otherwise prints error
  my ($url, $filename) = @_;
  my $res = getstore($url, $filename);
  croak "Error: Downloading file, got $res for:\n  $url" if is_error($res);
}

1;
