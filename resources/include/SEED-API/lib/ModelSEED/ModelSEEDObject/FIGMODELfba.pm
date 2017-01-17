use strict;
use FIGMODEL;

package FIGMODELfba;

=head1 FIGMODELfba object
=head2 Introduction
Module for holding FBA formulations, running FBA, and parsing results
=head2 Core Object Methods

=head3 new
Definition:
	FIGMODELfba = FIGMODELfba->new(figmodel,{parameters=>{}:parameters,filename=>string:filename,geneKO=>[string]:gene ids,rxnKO=>[string]:reaction ids,model=>string:model id,media=>string:media id,parameter_files=>[string]:parameter files});
Description:
	This is the constructor for the FIGMODELfba object. Arguments specify FBA to simplify code, but are optional
=cut
sub new {
	my ($class,$args) = @_;
	#Error checking first
	if (!defined($args->{figmodel})) {
		print STDERR "FIGMODELfba->new():figmodel must be defined to create an fba object!\n";
		return undef;
	}
	my $self = {_figmodel => $args->{figmodel}};
	bless $self;
	if (defined($args->{geneKO})) {
		$self->{_geneKO} = $args->{geneKO};
	}
	if (defined($args->{rxnKO})) {
		$self->{_rxnKO} = $args->{rxnKO};
	}
	if (defined($args->{parameter_files})) {
		$self->{_parameter_files} = $args->{parameter_files};
	}
	if (defined($args->{model})) {
		$self->{_model} = $args->{model};
	}
	if (defined($args->{media})) {
		$self->{_media} = $args->{media};
	}
	if (defined($args->{parameters})) {
		$self->{_parameters} = $args->{parameters};
	}
	if (defined($args->{filename})) {
		$self->{_filename} = $args->{filename};
	}
	return $self;
}

=head2 CONSTANTS ASSOCIATED WITH MODULE

=head3 problemParameters
Definition:
	[string]:parameters stored in the problem output file = FIGMODELfba->problemParameters();
Description:
	This function returns a list of the parameters stored in the problem output file
=cut
sub problemParameters {
	my ($self) = @_;
	return ["geneKO","rxnKO","parsingFunction","model","media","parameter_files","parameters"];
}

=head2 UTILITY FUNCTIONS ASSOCIATED WITH MODULE

=head3 figmodel
Definition:
	FIGMODELfba = FIGMODELfba->figmodel();
Description:
	Returns the parent FIGMODEL object
=cut
sub figmodel {
	my ($self) = @_;
	return $self->{_figmodel};
}

=head2 JOB HANDLING FUNCTIONS

=head3 queueFBAJob
Definition:
	{jobid => integer} = FIGMODELfba = FIGMODELfba->queueFBAJob();
Description:
	This function creates a folder in the MFAToolkitOutput folder specifying the run then adds the run to the job queue and returns the job id
=cut
sub queueFBAJob {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{queue => "cplex",priority => 3});
	if (defined($args->{error})) {return {error => $args->{error}};}
	my $out = $self->createProblemDirectory();
	if (defined($out->{error})) {return $out;}
	return $self->figmodel()->add_job_to_queue({command => "runfba?".$self->filename(),queue => $args->{queue},priority => $args->{priority}});
}

=head3 returnFBAJobResults
Definition:
	{}:results = FBAMODEL->returnFBAJobResults({jobid => integer:job id});
Description:
	This function checks the job queue for completed jobs
Example:
=cut
sub returnFBAJobResults {
	my($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["jobid"],{});
	if (defined($args->{error})) {return {error => $args->{error}};}
	#Getting the job associated with the input ID
	my $job = $self->figmodel()->database()->get_object("job",{_id => $args->{jobid}});
	if (!defined($job)) {
		return {error => "returnFBAJobResults:input job ID not found in database"};	
	}
	if ($job->STATE() eq "0") {
		return {status => "queued"};
	} elsif ($job->STATE() eq "1") {
		return {status => "running"};
	} elsif ($job->STATE() eq "2") {
		my $studyResults;
		if ($job->COMMAND() =~ m/runfba\?(.+)/) {
			$studyResults->{results} = $self->loadResultsFromProblemDirectory({filename => $1});
			$studyResults->{status} = "complete";
		} else {
			$studyResults->{error} = "returnFBAJobResults:command not recognized";
			$studyResults->{status} = "failed";
		}
		return $studyResults;
	}
}

=head3 createProblemDirectory
Definition:
	{key => value}:results = FIGMODELfba->createProblemDirectory({directory => string:directory name});
Description:
	This function prints the problem meta data into the specified directory
=cut
sub createProblemDirectory {
	my($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{filename => $self->filename()});
	if (defined($args->{error})) {return {error => $args->{error}};}
	if (!defined($args->{filename})) {
		$args->{filename} = $self->figmodel()->filename();
	}
	$self->filename($args->{filename});
	my $problemParameters = $self->problemParameters();
	system("mkdir ".$self->directory());
	$self->{_problemObject} = FIGMODELObject->new({filename => $self->directory()."/ProblemData.txt",delimiter => "\t",headings => [],-load => 0});
	my $headings;
	for (my $i=0; $i < @{$problemParameters}; $i++) {
		if ($problemParameters->[$i] eq "parameters" && defined($self->{_parameters})) {
			foreach my $parameter (keys(%{$self->{_parameters}})) {
				push(@{$headings},"parameters:".$parameter);
				$self->{_problemObject}->{"parameters:".$parameter}->[0] = $self->{_parameters}->{$parameter};
			}
		} elsif (defined($self->{"_".$problemParameters->[$i]})) {
			push(@{$headings},$problemParameters->[$i]);
			if ($problemParameters->[$i] eq "parameter_files") {
				$self->{_problemObject}->{$problemParameters->[$i]} = $self->{"_".$problemParameters->[$i]};
			} else {
				$self->{_problemObject}->{$problemParameters->[$i]}->[0] = $self->{"_".$problemParameters->[$i]};
			}
		}
	}
	$self->{_problemObject}->headings($headings);
	$self->{_problemObject}->save();
	return {};
}	

=head3 loadProblemDirectory
Definition:
	{key => value}:results = FIGMODELfba->loadProblemDirectory({filename => string:filename});
Description:
	This function loads the problem meta data in the specified directory
=cut
sub loadProblemDirectory {
	my($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["filename"],{});
	if (defined($args->{error})) {return {error => $args->{error}};}
	$self->filename($args->{filename});
	$self->{_problemObject} = FIGMODELObject->new({filename=>$self->directory()."/ProblemData.txt",delimiter=>"\t",-load => 1});
	if (!defined($self->{_problemObject})) {
		return {error => "loadProblemDirectory:could not load file ".$self->filename()};
	}
	my $headings = $self->{_problemObject}->headings();
	for (my $i=0; $i < @{$headings}; $i++) {
		if ($headings->[$i] =~ m/parameters:/) {
			my @temp = split(/:/,$headings->[$i]);
			$self->{_parameters}->{$temp[1]} = $self->{_problemObject}->{$headings->[$i]}->[0];
		} elsif ($headings->[$i] eq "parameter_files") {
			$self->{"_".$headings->[$i]} = $self->{_problemObject}->{$headings->[$i]};
		} elsif (length($headings->[$i]) > 0) {
			$self->{"_".$headings->[$i]} = $self->{_problemObject}->{$headings->[$i]}->[0];
		}
	}
	return {};
}

=head3 runProblemDirectory
Definition:
	{} = FIGMODELfba->runProblemDirectory({filename => string:filename});
Description:
	This function loads the problem in the specified directory and uses the problem meta data to run the MFAToolkit
=cut
sub runProblemDirectory {
	my($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["filename"],{});
	if (defined($args->{error})) {return {error => $args->{error}};}
	my $results = $self->loadProblemDirectory($args);
	if (defined($results->{error})) {return $results;}
	return $self->runFBA();
}

=head3 loadProblemDirectoryResults
Definition:
	{key => value}:results = FIGMODELfba->loadProblemDirectoryResults({filename => string:filename});
Description:
	This function loads the problem in the specified directory and uses the problem meta data to parse the appropriate results
=cut
sub loadProblemDirectoryResults {
	my($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["filename"],{});
	if (defined($args->{error})) {return {error => $args->{error}};}
	my $results = $self->loadProblemDirectory($args);
	if (defined($results->{error})) {return $results;}
	my $function = $self->parsingFunction();
	if (!defined($function)) {return {error => "loadProblemDirectoryResults:no parsing algorithm found for specified problem"};}
	return $self->$function();
}

=head2 DATA ACCESS AND EDITING ROUTINES

=head3 parsingFunction
Definition:
	string = FIGMODELfba->parsingFunction(string);
Description:
	Getter setter for the function used to parse results for the current job
=cut
sub parsingFunction {
	my ($self,$input) = @_;
	if (defined($input)) {
		$self->{_parsingFunction} = $input;
	}
	return $self->{_parsingFunction};
}

=head3 filename
Definition:
	string = FIGMODELfba->filename(string);
Description:
	Getter setter for the filename for the current job
=cut
sub filename {
	my ($self,$input) = @_;
	if (defined($input)) {
		$self->{_filename} = $input;
	}
	return $self->{_filename};
}

=head3 directory
Definition:
	string = FIGMODELfba->directory();
Description:
	Retrieves the directory where the FBA problem data will be printed
=cut
sub directory {
	my ($self) = @_;
	return $self->figmodel()->config("MFAToolkit output directory")->[0].$self->filename();
}


=head3 add_gene_ko
Definition:
	void = FIGMODELfba->add_gene_ko([string]:gene ids);
Description:
	This function adds a list of genes to be knocked out in the FBA
=cut
sub add_gene_ko {
	my ($self,$geneList) = @_;
	if (defined($geneList->[0]) && lc($geneList->[0]) ne "none") {
		if (defined($self->{_geneKO}) && length($self->{_geneKO}) > 0) {
			$self->{_geneKO} .= ";";	
		} else {
			$self->{_geneKO} = "";
		}
		$self->{_geneKO} .= join(";",@{$geneList});
	}
}

=head3 clear_gene_ko
Definition:
	void = FIGMODELfba->clear_gene_ko();
Description:
	This function clears the list of genes to be knocked out in the FBA
=cut
sub clear_gene_ko {
	my ($self) = @_;
	delete $self->{_geneKO};
}

=head3 add_reaction_ko
Definition:
	void = FIGMODELfba->add_reaction_ko([string]:reaction ids);
Description:
	This function adds a list of reactions to be knocked out in the FBA
=cut
sub add_reaction_ko {
	my ($self,$rxnList) = @_;
	if (defined($rxnList->[0]) && lc($rxnList->[0]) ne "none") {
		if (defined($self->{_rxnKO}) && length($self->{_rxnKO}) > 0) {
			$self->{_rxnKO} .= ";";	
		} else {
			$self->{_rxnKO} = "";
		}
		$self->{_rxnKO} .= join(";",@{$rxnList});
	}
}

=head3 clear_reaction_ko
Definition:
	void = FIGMODELfba->clear_reaction_ko();
Description:
	This function clears the list of reactions to be knocked out in the FBA
=cut
sub clear_reaction_ko {
	my ($self) = @_;
	delete $self->{_rxnKO};
}

=head3 add_parameter_files
Definition:
	void = FIGMODELfba->add_parameter_files([string]:parameter file list);
Description:
	This function adds a list of parameter files
=cut
sub add_parameter_files {
	my ($self,$fileList) = @_;
	if (defined($fileList->[0]) && lc($fileList->[0]) ne "none") {
		if (defined($self->{_parameter_files}) && length($self->{_parameter_files}) > 0) {
			$self->{_parameter_files} .= ";";	
		} else {
			$self->{_parameter_files} = "";
		}
		$self->{_parameter_files} .= join(";",@{$fileList});
	}
}

=head3 parameter_files
Definition:
	[string]:parameter file list = FIGMODELfba->parameter_files([string]:parameter file list);
Description:
	Getter setter function for parameter files
=cut
sub parameter_files {
	my ($self,$fileList) = @_;
	if (defined($fileList->[0]) && lc($fileList->[0]) ne "none") {
		$self->{_parameter_files} = join(";",@{$fileList});
	}
	return $self->{_parameter_files};
}

=head3 clear_parameter_files
Definition:
	void = FIGMODELfba->clear_parameter_files();
Description:
	This function clears the list of parameter files
=cut
sub clear_parameter_files {
	my ($self) = @_;
	delete $self->{_parameter_files};
}

=head3 model
Definition:
	string:model id = FIGMODELfba->model(string:model id);
Description:
	Getter setter function for model
=cut
sub model {
	my ($self,$model) = @_;
	if (defined($model)) {
		$self->{_model} = $model;
	}	
	return $self->{_model};
}

=head3 media
Definition:
	string:media id = FIGMODELfba->media(string:media id);
Description:
	Getter setter function for media condition
=cut
sub media {
	my ($self,$media) = @_;
	if (defined($media)) {
		$self->{_media} = $media;
	}	
	return $self->{_media};
}

=head3 parameters
Definition:
	{string:parameter type => string:value} = FIGMODELfba->parameters({string:parameter type => string:value});
Description:
	Getter setter function for parameters
=cut
sub parameters {
	my ($self,$parameters) = @_;
	if (defined($parameters)) {
		$self->{_parameters} = $parameters;
	}
	if (!defined($self->{_parameters})) {
		$self->{_parameters} = {};
	}
	return $self->{_parameters};
}

=head3 set_parameters
Definition:
	void = FIGMODELfba->set_parameters({string:parameter,string:value});
Description:
	This function sets the value of an MFA parameter
=cut
sub set_parameters {
	my ($self,$parameters) = @_;
	my @keys = keys(%{$parameters});
	for (my $i=0; $i < @keys; $i++) {
		$self->{_parameters}->{$keys[$i]} = $parameters->{$keys[$i]};
	}
}

=head3 clear_parameters
Definition:
	void = FIGMODELfba->clear_parameters();
Description:
	This function clears all set parameters
=cut
sub clear_parameters {
	my ($self,$parameters) = @_;
	delete $self->{_parameters};
}

=head3 runFBA
Definition:
	string:directory = FIGMODELfba->runFBA();
Description:
	This function uses the MFAToolkit to run FBA
=cut
sub runFBA {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{filename => $self->filename()});
	if (defined($args->{error})) {return {error => $args->{error}};}
	if (defined($args->{filename})) {
		$self->filename($args->{filename});
	} else {
		$self->filename($self->figmodel()->filename());
	}
	if (defined($self->{_rxnKO})) {
		$self->set_parameter("Reactions to knockout",$self->{_rxnKO});
	}
	if (defined($self->{_geneKO})) {
		$self->set_parameter("Genes to knockout",$self->{_geneKO});
	}
	my $command = $self->figmodel()->GenerateMFAToolkitCommandLineCall($self->filename(),$self->model(),$self->media(),$self->parameter_files(),$self->parameters(),"fbaLog_".$self->filename().".txt",undef,undef);
	system($command);
	return {};
}

=head2 FBA STUDY FUNCTIONS

=head3 setCombinatorialDeletionStudy
=item Definition:
	{} = FIGMODELfba->setCombinatorialDeletionStudy({maxDeletions => integer});
=item Description:
=cut
sub setCombinatorialDeletionStudy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{maxDeletions => 1});
	$self->set_parameters({"Combinatorial deletions"=>$args->{maxDeletions}});
	$self->parsingFunction("parseCombinatorialDeletionStudy");
	return {};
}

=head3 parseCombinatorialDeletionStudy
=item Definition:
	{string:gene set => double:growth} = FIGMODELfba->parseCombinatorialDeletionStudy(string:directory);
=item Description:
	Parses the results of the combinatorial deletion study. Returns undefined if no results could be found in the specified directory
=cut
sub parseCombinatorialDeletionStudy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["filename"],{});
	if (defined($args->{error})) {return {error => $args->{error}};}
	$self->filename($args->{filename});
	if (-e $self->directory()."/MFAOutput/CombinationKO.txt") {
		my $data = $self->database()->load_multiple_column_file($self->directory()."/MFAOutput/CombinationKO.txt","\t");
		my $result;
		for (my $i=0; $i < @{$data}; $i++) {
			if (defined($data->[$i]->[1])) {
				$result->{$data->[$i]->[0]} = $data->[$i]->[1];
			}	
		}
		return $result;
	}
	return {error => "parseCombinatorialDeletionStudy:could not find specified output directory"};
}

=head3 setMinimalMediaStudy
=item Definition:
	string:error = FIGMODELfba->setMinimalMediaStudy(optional integer:number of formulations);
=item Description:
=cut
sub setMinimalMediaStudy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{numberOfFormulations => 1});
	$self->set_parameters({"determine minimal required media" => 1,"Recursive MILP solution limit" => $args->{numberOfFormulations}});
	$self->parsingFunction("parseMinimalMediaResults");
	return {};
}

=head3 parseMinimalMediaResults
=item Definition:
	$results = FIGMODELfba->parseMinimalMediaResults(string:directory);
                  
	$results = {essentialNutrients => [string]:nutrient IDs,
				optionalNutrientSets => [[string]]:optional nutrient ID sets}
=item Description:
=cut
sub parseMinimalMediaStudy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["filename"],{});
	if (defined($args->{error})) {return {error => $args->{error}};}
	$self->filename($args->{filename});
	if (-e $self->directory()."/MFAOutput/MinimalMediaResults.txt") {
		my $data = $self->figmodel()->database()->load_single_column_file($self->directory()."/MFAOutput/MinimalMediaResults.txt","\t");
		my $result;
		push(@{$result->{essentialNutrients}},split(/;/,$data->[1]));
		for (my $i=3; $i < @{$data}; $i++) {
			if ($data->[$i] !~ m/^Dead/) {
				my $temp;
				push(@{$temp},split(/;/,$data->[$i]));
				push(@{$result->{optionalNutrientSets}},$temp);
			} else {
				last;
			}	
		}
		return $result;
	}
	return {error => "parseMinimalMediaStudy:could not find specified output directory"};
}

=head3 setGeneActivityAnalysis
=item Definition:
	string:error = FIGMODELfba->setGeneActivityAnalysis({geneCalls => {string:gene ID => double:negative for off/positive for on/zero for unknown}});
=item Description:
=cut
sub setGeneActivityAnalysis {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["geneCalls"],{numberOfFormulations => 1});
	if (defined($args->{error})) {return {error => $args->{error}};}
	my $geneCallData = $self->model().";1";
	foreach my $gene (keys(%{$args->{geneCalls}})) {
		$geneCallData .= ";".$gene.":".$args->{geneCalls}->{$gene};
	}
	$self->set_parameters({"Microarray assertions" => $geneCallData,"Recursive MILP solution limit" => $args->{numberOfFormulations}});
	$self->parsingFunction("parseGeneActivityAnalysis");
	return {};
}

=head3 parseGeneActivityAnalysis
=item Definition:
	$results = FIGMODELfba->parseGeneActivityAnalysis({filename => string});
                  
	$results = {biomass => double:predicted growth only returned when job is finished,
				flux => {string => double}:hash of model entities mapped to corresponding fluxes,
				geneActivity => {On_On => [string:gene IDs],Off_Off => [string:gene IDs],On_Off => [string:gene IDs],Off_on => [string:gene IDs],On => [string:gene IDs],Off => [string:gene IDs]}:
	}
=item Description:
=cut
sub parseGeneActivityAnalysis {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["filename"],{});
	if (defined($args->{error})) {return {error => $args->{error}};}
	$self->filename($args->{filename});
	if (-e $self->directory()."MicroarrayOutput.txt") {
		my $data = $self->figmodel()->database()->load_single_column_file($self->directory()."MicroarrayOutput.txt");
		if (!defined($data->[1])) {
			return {error => "parseGeneActivityAnalysis:output file did not contain necessary data"};
		}
		my @temp = split(/;/,$data->[1]);
		if (@temp < 8) {
			return {error => "parseGeneActivityAnalysis:output file did not contain necessary data"};	
		}
		my $result;
		push(@{$result->{On_On}},split(/,/,$temp[2]));
		push(@{$result->{On_Off}},split(/,/,$temp[3]));
		push(@{$result->{On}},split(/,/,$temp[4]));
		push(@{$result->{Off}},split(/,/,$temp[5]));
		push(@{$result->{Off_on}},split(/,/,$temp[6]));
		push(@{$result->{Off_Off}},split(/,/,$temp[7]));
		return $result;
	}
	return {error => "parseGeneActivityAnalysis:could not find output file for gene activity study"};
}


1;