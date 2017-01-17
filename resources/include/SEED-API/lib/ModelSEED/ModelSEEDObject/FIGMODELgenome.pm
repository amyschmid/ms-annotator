use strict;
use FIGMODEL;

package FIGMODELgenome;

=head1 FIGMODELgenome object
=head2 Introduction
Module for holding genome related access functions
=head2 Core Object Methods

=head3 new
Definition:
	FIGMODELgenome = FIGMODELgenome->new(figmodel,string:genome id);
Description:
	This is the constructor for the FIGMODELgenome object.
=cut
sub new {
	my ($class,$figmodel,$genome) = @_;
	#Error checking first
	if (!defined($figmodel)) {
		print STDERR "FIGMODELfba->new():figmodel must be defined to create an genome object!\n";
		return undef;
	}
	if (!defined($genome)) {
		$figmodel->error_message("FIGMODELfba->new():figmodel must be defined to create an genome object!");
		return undef;
	}
	my $self = {_figmodel => $figmodel,_genome => $genome};
	bless $self;
	return $self;
}

=head3 figmodel
Definition:
	FIGMODEL = FIGMODELgenome->figmodel();
Description:
	Returns the figmodel object
=cut
sub figmodel {
	my ($self) = @_;
	return $self->{_figmodel};
}

=head3 genome
Definition:
	string:genome ID = FIGMODELgenome->genome();
Description:
	Returns the genome ID
=cut
sub genome {
	my ($self) = @_;
	return $self->{_genome};
}

=head3 error_message
Definition:
	string:message text = FIGMODELgenome->error_message(string::message);
Description:
=cut
sub error_message {
	my ($self,$message) = @_;
	return $self->figmodel()->error_message("FIGMODELgenome:".$self->genome().":".$message);
}

=head3 jobid
Definition:
	PPOjob:job object of genome = FIGMODELgenome->jobid();
Description:
	Returns the RAST PPO job object for genome
=cut

sub job {
	my ($self) = @_;
	if (!defined($self->{_job})) {
		$self->{_job} = $self->figmodel()->database()->get_object("rastjob",{genome_id => $self->genome()});
		if (!defined($self->{_job})) {
			$self->{_job} = $self->figmodel()->database()->get_object("rasttestjob",{genome_id => $self->genome()});
			if (!defined($self->{_job})) {
				#$self->{_job} = $self->figmodel()->database()->get_object("mgjob",{genome_id => $self->genome()});
				#if (defined($self->{_job})) {
				#	$self->{_job}->{_source} = "MGRAST:".$self->{_job}->id();
				#}
			} else {
				$self->{_job}->{_source} = "TESTRAST:".$self->{_job}->id();
			}
		} else {
			$self->{_job}->{_source} = "RAST:".$self->{_job}->id();
		}
	}
	return $self->{_job};
}

=head3 source
Definition:
	string:source = FIGMODELgenome->source();
Description:
	Returns the source of the genome
=cut
sub source {
	my ($self) = @_;
	if (!defined($self->{_source})) {
		my $sap = $self->figmodel()->sapSvr("SEED");
		my 	$result = $sap->exists({-type => 'Genome',-ids => [$self->genome()]});
		if ($result->{$self->genome()} eq "0") {
			#Checking if genome is in the PSEED
			$sap = $self->figmodel()->sapSvr("PSEED");
			$result = $sap->exists({-type => 'Genome',-ids => [$self->genome()]});
			if ($result->{$self->genome()} eq "0") {
				#Checking if this is a RAST genome
				my $job = $self->job();
				if (defined($job)) {
					$self->{_source} = $job->{_source};
				} else {
					$self->{_source} = "UNKNOWN";
				}
			} else {
				$self->{_source} = "PSEED";
			}
		} else {
			$self->{_source} = "SEED"	
		}
	}
	return $self->{_source};
}

=head3 name
Definition:
	string:source = FIGMODELgenome->name();
Description:
	Returns the name of the genome
=cut
sub name {
	my ($self) = @_;
	if (!defined($self->{_name})) {
		my $source = $self->source();
		$self->{_name} = "Unknown";
		if ($source eq "SEED" || $source eq "PSEED") {
			my $sapObject = $self->figmodel()->sapSvr($source);
			my $result = $sapObject->genome_names({-ids => [$self->genome()]});
			if (defined($result->{$self->genome()})) {
				$self->{_name} = $result->{$self->genome()};	
			}
		} elsif ($source eq "RAST" || $source eq "TESTRAST") {
			$self->parse_taxonomy_file();
		}
	}
	return $self->{_name};
}

=head3 taxonomy
Definition:
	string:source = FIGMODELgenome->taxonomy();
Description:
	Returns the taxonomy of the genome
=cut
sub taxonomy {
	my ($self) = @_;
	if (!defined($self->{_taxonomy})) {
		my $source = $self->source();
		$self->{_taxonomy} = "Unknown";
		if ($source eq "SEED" || $source eq "PSEED") {
			my $sapObject = $self->figmodel()->sapSvr($source);
			my $result = $sapObject->taxonomy_of({-ids => [$self->genome()]});
			if (defined($result->{$self->genome()})) {
				$self->{_taxonomy} = join("|",@{$result->{$self->genome()}});
			}
		} elsif ($source eq "RAST" || $source eq "TESTRAST") {
			$self->parse_taxonomy_file();
		}
	}
	return $self->{_taxonomy};
}

=head3 parse_taxonomy_file()
Definition:
	string:source = FIGMODELgenome->parse_taxonomy_file();
Description:
=cut
sub parse_taxonomy_file {
	my ($self) = @_;
	my $completetaxonomy;
	if ($self->source() eq "RAST") {
		$completetaxonomy = $self->figmodel()->database()->load_single_column_file("/vol/rast-prod/jobs/".$self->job()->id()."/TAXONOMY","\t")->[0];
	} elsif ($self->source() eq "TESTRAST") {
		$completetaxonomy = $self->figmodel()->database()->load_single_column_file("/vol/rast-test/jobs/".$self->job()->id()."/TAXONOMY","\t")->[0];
	}
	$completetaxonomy =~ s/;\s/;/g;
	my @taxonomyArray = split(/;/,$completetaxonomy);
	$self->{_name} = pop(@taxonomyArray);
	$self->{_taxonomy} = join("|",@taxonomyArray);
}

=head3 owner
Definition:
	string:source = FIGMODELgenome->owner();
Description:
	Returns the owner of the genome
=cut
sub owner {
	my ($self) = @_;
	if (!defined($self->{_owner})) {
		my $source = $self->source();
		if ($source eq "SEED" || $source eq "PSEED") {
			$self->{_owner} = "master";
		} elsif ($source eq "RAST") {
			$self->{_owner} = $self->figmodel()->database()->load_single_column_file("/vol/rast-prod/jobs/".$self->job()->id()."/USER","\t")->[0]
		} elsif ($source eq "TESTRAST") {
			$self->{_owner} = $self->figmodel()->database()->load_single_column_file("/vol/rast-test/jobs/".$self->job()->id()."/USER","\t")->[0]
		}
	}
	return $self->{_owner};
}

=head3 size
Definition:
	string:source = FIGMODELgenome->size();
Description:
	Returns the size of the genome
=cut
sub size {
	my ($self) = @_;
	if (!defined($self->{_size})) {
		$self->{_size} = $self->fig()->genome_szdna($self->genome());
	}
	return $self->{_size};
}

=head3 fig
Definition:
	FIG:fig object = FIGMODELgenome->fig();
Description:
	Returns the fig object for the genome
=cut
sub fig {
	my ($self) = @_;
	if (!defined($self->{_fig})) {
		if ($self->source() =~ m/RAST/ && defined($self->job())) {
			if ($self->source() =~ m/TEST/) {
				$self->{_fig} = new FIGV("/vol/rast-test/jobs/".$self->job()->id()."/rp/".$self->genome());
			} else {
				$self->{_fig} = new FIGV("/vol/rast-prod/jobs/".$self->job()->id()."/rp/".$self->genome());
			}
		} else {
			$self->{_fig} = new FIG;
		}
	}
	return $self->{_fig};	
}

=head3 feature_table
Definition:
	FIGMODELTable:feature table = FIGMODELgenome->feature_table(0/1:get sequences);
Description:
	Returns a table of features in the genome
=cut
sub feature_table {
	my ($self,$getSequences,$models) = @_;
	if (!defined($self->{_features})) {
		#Getting essentiality data
		my $sets = $self->figmodel()->database()->get_objects("esssets",{GENOME=>$self->genome()});
		#Checking if genome is in the SEED, PSEED, RAST, or test-RAST
		my $source = $self->source();
		#Getting genome feature table
		$self->{_features} = new FIGMODELTable(["ID","GENOME","ESSENTIALITY","ALIASES","TYPE","LOCATION","LENGTH","DIRECTION","MIN LOCATION","MAX LOCATION","ROLES","SOURCE","SEQUENCE"],$self->figmodel()->config("database message file directory")->[0]."Features-".$self->genome().".txt",["ID","ALIASES","TYPE","ROLES","GENOME"],"\t","|",undef);
		$self->{_features}->{_source} = $source;
		$self->{_features}->{_owner} = $self->figmodel()->user();
		if ($source eq "SEED" || $source eq "PSEED") {
			my $sap = $self->figmodel()->sapSvr($source);
			#Getting feature list for genome
			my $featureHash = $sap->all_features({-ids => $self->genome()});
			my $featureList = $featureHash->{$self->genome()};
			#Getting functions for each feature
			my $functions = $sap->ids_to_functions({-ids => $featureList});
			#Getting locations for each feature
			my $locations = $sap->fid_locations({-ids => $featureList});
			#Getting aliases
			my $aliases;
			#my $aliases = $sap->fids_to_ids({-ids => $featureList,-protein => 1});
			#Getting sequences for each feature
			my $sequences;
			if (defined($getSequences) && $getSequences == 1) {
				$sequences = $sap->ids_to_sequences({-ids => $featureList,-protein => 1});
			}
			#Placing data into feature table
			for (my $i=0; $i < @{$featureList}; $i++) {
				my $row = {ID => [$featureList->[$i]],GENOME => [$self->genome()],TYPE => ["peg"]};
				if ($featureList->[$i] =~ m/\d+\.([^\.]+)\.\d+$/) {
					$row->{TYPE}->[0] = $1;
				}
				if (defined($locations->{$featureList->[$i]}->[0]) && $locations->{$featureList->[$i]}->[0] =~ m/(\d+)([\+\-])(\d+)$/) {
					if ($2 eq "-") {
						$row->{"MIN LOCATION"}->[0] = ($1-$3);
						$row->{"MAX LOCATION"}->[0] = ($1);
						$row->{LOCATION}->[0] = $1."_".($1-$3);
						$row->{DIRECTION}->[0] = "rev";
						$row->{LENGTH}->[0] = $3;
					} else {
						$row->{"MIN LOCATION"}->[0] = ($1);
						$row->{"MAX LOCATION"}->[0] = ($1+$3);
						$row->{LOCATION}->[0] = $1."_".($1+$3);
						$row->{DIRECTION}->[0] = "for";
						$row->{LENGTH}->[0] = $3;
					}
				}
				if (defined($aliases->{$featureList->[$i]})) {
					my @types = keys(%{$aliases->{$featureList->[$i]}});
					for (my $j=0; $j < @types; $j++) {
						push(@{$row->{ALIASES}},@{$aliases->{$featureList->[$i]}->{$types[$j]}});
					}
				}
				if (defined($functions->{$featureList->[$i]})) {
					push(@{$row->{ROLES}},$self->figmodel()->roles_of_function($functions->{$featureList->[$i]}));
				}
				if (defined($getSequences) && $getSequences == 1 && defined($sequences->{$featureList->[$i]})) {
					$row->{SEQUENCE}->[0] = $sequences->{$featureList->[$i]};
				}
				$self->{_features}->add_row($row);
			}
		} else {
			#Inserting the data from the two dimensional array into the table object
			if (!defined($self->fig())) {
				return undef;	
			}
			my $GenomeData = $self->fig()->all_features_detailed_fast($self->genome());
			foreach my $Row (@{$GenomeData}) {
				my $RoleArray;
				if (defined($Row->[6])) {
					push(@{$RoleArray},$self->figmodel()->roles_of_function($Row->[6]));
				} else {
					$RoleArray = ["NONE"];
				}
				my $AliaseArray;
				push(@{$AliaseArray},split(/,/,$Row->[2]));
				my $Sequence;
				if (defined($getSequences) && $getSequences == 1) {
					$Sequence = $self->fig()->get_translation($Row->[0]);
				}
				my $Direction ="for";
				my @temp = split(/_/,$Row->[1]);
				if ($temp[@temp-2] > $temp[@temp-1]) {
					$Direction = "rev";
				}
				my $newRow = $self->{_features}->add_row({"ID" => [$Row->[0]],"GENOME" => [$self->genome()],"ALIASES" => $AliaseArray,"TYPE" => [$Row->[3]],"LOCATION" => [$Row->[1]],"DIRECTION" => [$Direction],"LENGTH" => [$Row->[5]-$Row->[4]],"MIN LOCATION" => [$Row->[4]],"MAX LOCATION" => [$Row->[5]],"SOURCE" => [$self->{_features}->{_source}],"ROLES" => $RoleArray});
				if (defined($Sequence) && length($Sequence) > 0) {
					$newRow->{SEQUENCE}->[0] = $Sequence;
				}
			}
		}
		if (defined($self->{_features})) {
			for (my $i=0; $i < $self->{_features}->size(); $i++) {
				my $row = $self->{_features}->get_row($i);
				if (defined($sets->[0])) {
					if ($row->{ID}->[0] =~ m/(peg\.\d+)/) {
						my $gene = $1;
						for (my $i=0; $i < @{$sets}; $i++) {
							my $essGene = $self->figmodel()->database()->get_object("essgenes",{FEATURE=>$gene,ESSENTIALITYSET=>$sets->[$i]->id()});
							if (defined($essGene)) {
								push(@{$row->{ESSENTIALITY}},$sets->[$i]->MEDIA().":".$essGene->essentiality());
							}
						}
					}
				}
			}
		}
	}
	#Adding model data to feature table
	if (defined($models)) {
		for (my $i=0; $i < @{$models}; $i++) {
			my $mdl = $self->figmodel()->get_model($models->[$i]);
			my $geneHash = $mdl->featureHash();
			my @genes = keys(%{$geneHash});
			for (my $j=0; $j < @genes; $j++) {
				my $row = $self->{_features}->get_row_by_key("fig|".$self->genome().".".$genes[$j],"ID");
				if (defined($row)) {
					$row->{$models->[$i]} = $geneHash->{$genes[$j]};
				}	
			}
		}
	}
	return $self->{_features};
}

=head3 stats
Definition:
	[string:data]:stats array = FIGMODELgenome->stats(string:key);
Description:
=cut
sub stats {
	my ($self,$stat) = @_;
	my $stats = $self->genome_stats();
	if (!defined($stats) || !defined($stats->{$stat})) {
		$self->error_message("stats:".$stat.":statistic does not exist!");
		return undef;
	}
	return $stats->{$stat};
}

=head3 genome_stats
Definition:
	FIGMODELTable:feature table = FIGMODELgenome->genome_stats();
Description:
=cut
sub genome_stats {
	my ($self) = @_;
	if (!defined($self->{_stats})) {
		my $stats = $self->figmodel()->database()->GetDBTable("GENOME STATS");
		if (defined($stats)) {
			my $row = $stats->get_row_by_key($self->genome(),"GENOME");
			if (defined($row)) {
				$self->{_stats} = $row;
			}
		}
	}
	if (!defined($self->{_stats})) {
		#Checking if the input genome ID is a metagenome
		my $GenomeStats = {GENOME => [$self->genome()],
							NAME => ["UNKNOWN"],
							TAXONOMY => ["UNKNOWN"],
							SIZE => ["NA"],
							SOURCE => ["UNKNOWN"],
							OWNER => ["UNKNOWN"],
							"TOTAL GENES" => [0],
							"GRAM POSITIVE GENES" => [0],
							"GRAM NEGATIVE GENES" => [0],
							CLASS => ["Unknown"],
							"GENES WITH FUNCTIONS" => [0],
							"SUBSYSTEM GENES" => [0],
							"NON SUBSYSTEM GENES" => [0]};
	
		#Getting the table of genes and roles from the database
		my $GenomeData = $self->feature_table();
		if (!defined($GenomeData)) {
			$self->error_message("FIGMODELgenome:generate_genome_stats:Could not load features table!");
			return $GenomeStats;
		}
		$GenomeStats->{NAME}->[0] = $self->name();
		delete($GenomeStats->{TAXONOMY});
		push(@{$GenomeStats->{TAXONOMY}},split(/\|/,$self->taxonomy()));
		$GenomeStats->{SOURCE}->[0] = $self->source();
		$GenomeStats->{SIZE}->[0] = $self->size();
		$GenomeStats->{OWNER}->[0] = $self->owner();
	
		#Additional stats will be collected and stored in these tables
		my $GeneTable = FIGMODELTable->new(["ID","ALIASES","MIN LOCATION","MAX LOCATION","ROLES","SUBSYSTEMS","SUBSYSTEM CLASS"],$self->figmodel()->config("temp file directory")->[0]."GeneTable.txt",["ID"],";","|",undef);
		my $RoleTable = FIGMODELTable->new(["ID","GENES","SUBSYSTEMS","SUBSYSTEM CLASS"],$self->figmodel()->config("temp file directory")->[0]."RoleTable.txt",["ID"],";","|",undef);
		my $SubsystemTable = FIGMODELTable->new(["ID","GENES","ROLES","CLASS 1","CLASS 2"],$self->figmodel()->config("temp file directory")->[0]."SubsystemTable.txt",["ID"],";","|",undef);
	
		#Looping through the genes and gathering statistics
		for (my $j=0; $j < $GenomeData->size(); $j++) {
			my $GeneData = $GenomeData->get_row($j);
			if (defined($GeneData) && $GeneData->{"ID"}->[0] =~ m/(peg\.\d+)/) {
				$GeneData->{"ID"}->[0] = $1;
				$GeneTable->add_row($GeneData);
				$GenomeStats->{"TOTAL GENES"}->[0]++;
				#Checking that the gene has roles
				if (defined($GeneData->{"ROLES"}->[0])) {
					my @Roles = @{$GeneData->{"ROLES"}};
					delete $GeneData->{"ROLES"};
					foreach my $Role (@Roles) {
						if ($self->figmodel()->role_is_valid($Role) != 0) {
							push(@{$GeneData->{"ROLES"}},$Role);
							#Checking if the role is already in the role table
							my $RoleData = $RoleTable->get_row_by_key($Role,"ID",1);
							#Adding the gene to the gene list for the role
							push(@{$RoleData->{"GENES"}},$GeneData->{"ID"}->[0]);
							#Looking for role subsystems
							my $GeneSubsystems = $self->figmodel()->subsystems_of_role($Role);
							if (defined($GeneSubsystems)) {
								#Adding subsystem data
								foreach my $Subsystem (@{$GeneSubsystems}) {
									$GenomeData->add_data($GeneData,"SUBSYSTEMS",$Subsystem,1);
									$RoleTable->add_data($RoleData,"SUBSYSTEMS",$Subsystem,1);
									#Checking if the subsystem is already in the role table
									my $SubsystemData = $SubsystemTable->get_row_by_key($Subsystem,"ID",1);
									#Adding the role and gene to the subsystem
									$SubsystemTable->add_data($SubsystemData,"ROLES",$Role,1);
									$SubsystemTable->add_data($SubsystemData,"GENES",$GeneData->{"ID"}->[0],1);
									#Getting subsystem class
									my $SubsystemClass = $self->figmodel()->class_of_subsystem($Subsystem);
									if (defined($SubsystemClass->[0]) || defined($SubsystemClass->[1])) {
										#Adding subsystem class to gene, role, and subsystem
										if (defined($SubsystemClass->[0])) {
											$SubsystemTable->add_data($SubsystemData,"CLASS 1",$SubsystemClass->[0],1);
											$GeneTable->add_data($GeneData,"SUBSYSTEM CLASS",$SubsystemClass->[0],1);
											$RoleTable->add_data($RoleData,"SUBSYSTEM CLASS",$SubsystemClass->[0],1);
										}
										if (defined($SubsystemClass->[1])) {
											$SubsystemTable->add_data($SubsystemData,"CLASS 1",$SubsystemClass->[1],1);
										}
										if ($SubsystemClass->[0] =~ m/Gram\-Negative/ || $SubsystemClass->[1] =~ m/Gram\-Negative/) {
											$GenomeStats->{"GRAM NEGATIVE GENES"}->[0]++;
										} elsif ($SubsystemClass->[0] =~ m/Gram\-Positive/ || $SubsystemClass->[1] =~ m/Gram\-Positive/) {
											$GenomeStats->{"GRAM POSITIVE GENES"}->[0]++;
										}
									}
								}
							}
						}
					}
				}
				if (defined($GeneData->{"ROLES"})) {
					$GenomeStats->{"GENES WITH FUNCTIONS"}->[0]++;
				}
				if (defined($GeneData->{"SUBSYSTEMS"})) {
					$GenomeStats->{"SUBSYSTEM GENES"}->[0]++;
				} else {
					$GenomeStats->{"NON SUBSYSTEM GENES"}->[0]++;
				}
			}
		}
		$GenomeStats->{"Roles in subsystems"}->[0] = 0;
		$GenomeStats->{"Roles not in subsystems"}->[0] = 0;
		for (my $i=0; $i < $RoleTable->size(); $i++) {
			if (defined($RoleTable->get_row($i)->{"SUBSYSTEMS"})) {
				$GenomeStats->{"Roles in subsystems"}->[0]++;
			} else {
				$GenomeStats->{"Roles not in subsystems"}->[0]++;
			}
		}
		$GenomeStats->{"Roles in genome"}->[0] = $RoleTable->size();
		$GenomeStats->{"Subsystems in genome"}->[0] = $SubsystemTable->size();
		#Setting the genome class
		foreach my $Class (@{$self->figmodel()->config("class list")}) {
			if (defined($self->{$Class}->{$self->genome()})) {
				$GenomeStats->{"CLASS"}->[0] = $Class;
				last;
			} else {
				for (my $i=0; $i < @{$self->figmodel()->config($Class." families")}; $i++) {
					my $family = $self->figmodel()->config($Class." families")->[$i];
					if ($GenomeStats->{NAME}->[0] =~ m/$family/) {
						$GenomeStats->{"CLASS"}->[0] = $Class;
						last;
					}
				}
			}
		}
		if ($GenomeStats->{"CLASS"}->[0] eq "Unknown") {
			if ($GenomeStats->{SOURCE}->[0] eq "MGRAST") {
				if ($GenomeStats->{"GRAM NEGATIVE GENES"}->[0] > 0) {
					$GenomeStats->{"CLASS"}->[0] = "Gram negative";
					if ($GenomeStats->{"GRAM POSITIVE GENES"}->[0] > 0) {
						$GenomeStats->{"CLASS"}->[0] = "Mixed gram negative and gram positive";
					}
				} elsif ($GenomeStats->{"GRAM POSITIVE GENES"}->[0] > 0) {
					$GenomeStats->{"CLASS"}->[0] = "Gram positive";
				}
			} elsif ($GenomeStats->{"GRAM NEGATIVE GENES"}->[0] > $GenomeStats->{"GRAM POSITIVE GENES"}->[0]) {
				$GenomeStats->{"CLASS"}->[0] = "Gram negative";
			} elsif ($GenomeStats->{"GRAM NEGATIVE GENES"}->[0] < $GenomeStats->{"GRAM POSITIVE GENES"}->[0]) {
				$GenomeStats->{"CLASS"}->[0] = "Gram positive";
			}
		}
		#Adding the stats to the genome stats table
		$self->figmodel()->database()->update_row("GENOME STATS",$GenomeStats,"GENOME");
		$self->{_stats} = $GenomeStats;
	}
	return $self->{_stats};
}

sub active_subsystems {
	my ($self) = @_;
	return $self->fig()->active_subsystems($self->genome());
}

sub totalGene {
	my ($self) = @_;
	return $self->stats("TOTAL GENES")->[0];
}

1;