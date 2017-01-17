package MSAnnotator::Config;
require Exporter;
use YAML 'LoadFile';
use Text::CSV;

# Load custom modukes
use MSAnnotator::Base;

# Export functions
our @ISA = 'Exporter';
our @EXPORT = qw(CONFIG_FILENAME load_config);

use constant CONFIG_FILENAME => "${ENV{'PWD'}}/config.yaml";

# Read configuration and export CONFIG hash
sub load_config {
  my %config = %{LoadFile(CONFIG_FILENAME)};

  # Load annotate_file and add to config hash
  my $csv = Text::CSV->new({binary => 1, auto_diag => 1});
  my $annfn = "${ENV{'PWD'}}/$config{'taxon_file'}";
  open my $fh, "<", $annfn or croak "$!: $annfn";

  # Ensure header exists
  my @header = map { lc $_ } @{$csv->getline($fh)};
  croak "No taxon_id feild in annotate_file" if not 'taxon_id' ~~ @header;

  # Loop through and push ids to config
  $csv->column_names(@header);
  while(my $row = $csv->getline_hr($fh)) {
    push @{$config{'taxon_query'}}, $row->{'taxon_id'};
  }

  return \%config
}

1;
