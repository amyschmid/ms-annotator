#
#  match_to_axes.pm
#
#  Use CodonUsageTable.pm instead;
#
#  Very ugly, but I have not figured out the pretty way to do this:
#
package match_to_axes;
use CodonUsageTable;

sub codon_usage_table_styles    { CodonUsageTable::codon_usage_table_styles( @_ ) }
sub codon_usage_columns_to_html { CodonUsageTable::codon_usage_columns_to_html( @_ ) }
sub axis_match_table_columns    { CodonUsageTable::axis_match_table_columns( @_ ) }
sub count_sets_axis_matches     { CodonUsageTable::count_sets_axis_matches( @_ ) }
sub axis_match_table_cells      { CodonUsageTable::axis_match_table_cells( @_ ) }
sub axis_match_cell_color       { CodonUsageTable::axis_match_cell_color( @_ ) }
sub freq_match_table_column     { CodonUsageTable::freq_match_table_column( @_ ) }
sub count_sets_freq_matches     { CodonUsageTable::count_sets_freq_matches( @_ ) }
sub freq_match_table_cell       { CodonUsageTable::freq_match_table_cell( @_ ) }
sub freq_match_cell_color       { CodonUsageTable::freq_match_cell_color( @_ ) }
sub id_def_table_columns        { CodonUsageTable::id_def_table_columns( @_ ) }

1;
