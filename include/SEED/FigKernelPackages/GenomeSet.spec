module GenomeSet {
	
    typedef string genome_id;

    typedef structure {
	genome_id id;
	string name;
	int rast_job_id;
	int taxonomy_id;
	string taxonomy_string;
    } Genome;


    typedef string genome_set_id;
    typedef string genome_set_name;
    
    typedef structure {
	genome_set_id id;
	genome_set_name name;
	string owner;
	string last_modified_date;
	string created_date;
	string created_by;

	list<Genome> items;
    } GenomeSet;

    funcdef enumerate_user_sets(string username) returns (list<tuple<genome_set_id, genome_set_name>>);
    funcdef enumerate_system_sets() returns (list<tuple<genome_set_id, genome_set_name>>);

    funcdef set_get(genome_set_id) returns (GenomeSet);
    funcdef set_create(genome_set_name, string username) returns (genome_set_id);
    funcdef set_delete(genome_set_id) returns ();
    funcdef set_add_genome(genome_set_id id, Genome genome) returns ();
    funcdef set_remove_genome(genome_set_id id, genome_id genome) returns ();
    funcdef set_clear(genome_set_id) returns ();
    
};
