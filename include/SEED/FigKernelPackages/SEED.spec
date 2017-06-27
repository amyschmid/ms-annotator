module SEED
{
    typedef structure {
	string fid;
	int beg;
	int end;
	int size;
	string strand;
	string contig;
	string location;
	string function;
	string type;
	int set_number;
	int offset_beg;
	int offset_end;
	int offset;
	list<tuple<string key, string value>> attributes;
    } feature_compare_info;
    
    typedef structure {
	int beg;
	int end;
	int mid;
	string org_name;
	string pinned_peg_strand;
	string genome_id;
	string pinned_peg;
	list<feature_compare_info> features;
    } genome_compare_info;
    typedef list<genome_compare_info> compared_regions;

    typedef structure {
	list<string> pin;
	int n_genomes;
	int width;

	/*
	 * How are the pinned features aligned on the focus?
	 * center / start / stop
	 */
	string pin_alignment;

	/* How to compute pin
	 * sim - by precomputed similarity
	 * kmer - kmers in common
	 */
	string pin_compute_method;

	float sim_cutoff;

	/*
	 * Limit returned result to the given genomes.
	 */
	list<string> limit_to_genomes;
	
	/* How to collapse close genomes:
	 * iden - collapse identical tax id
	 * close - collapse close genomes
	 * all - show all genomes
	 */
	string close_genome_collapse;

	/*
	 * How to color the pegs.
	 * sim - by similarity
	 * kmer - by kmers in common
	 * function - by function
	 */
	string coloring_method;
	float color_sim_cutoff;

	/*
	 * How to sort the genomes.
	 * similarity - by similarity
	 * phylogenetic_distance - by phylogenetic distance to focus peg
	 * phylogeny - by phylogeny
	 */
	string genome_sort_method;

	list<string> features_for_cdd;
    } compare_options;

    funcdef compare_regions(compare_options opts) returns (compared_regions);

    funcdef compare_regions_for_peg(string peg, int width, int n_genomes, string coloring_method) returns (compared_regions);

    funcdef get_ncbi_cdd_url(string feature) returns (string url);
    funcdef compute_cdd_for_row(genome_compare_info pegs) returns (list<feature_compare_info> cdds);
    funcdef compute_cdd_for_feature(feature_compare_info feature) returns (list<feature_compare_info> cdds);

    funcdef get_palette(string palette_name) returns (list<tuple<int r, int g, int b>> colors);

    typedef string genome_id;
    typedef string feature_id;
    typedef structure
    {
	int success;
	string text;
    } assignment_result;

    typedef string location;
    typedef string translation;

    funcdef get_function(list<feature_id> fids) returns (mapping<feature_id, string> functions);
    funcdef assign_function(mapping<feature_id, string> functions, string user, string token)
	returns (mapping<feature_id, assignment_result> result);

    funcdef get_location(list<feature_id> fids) returns (mapping<feature_id, location> locations);
    funcdef get_translation(list<feature_id> fids) returns (mapping<feature_id, translation> translations);

    funcdef is_real_feature(list<feature_id> fids) returns (mapping<feature_id, int> results);

    funcdef get_genome_features(list<genome_id> genomes, string type) returns (mapping<genome_id genome, list<feature_id> fids>  features);

    funcdef get_genomes()  returns (list<tuple<genome_id genome_id, string genome_name, string domain>> genomes);
};
