#!/usr/bin/perl -w

########################################################################
# Driver script for the model database interaction module
# Author: Christopher Henry
# Author email: chrisshenry@gmail.com
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 8/26/2008
########################################################################

use strict;
use ModelSEED::FIGMODEL;
use ModelSEED::FBAMODEL;
use SAP;
use LWP::Simple;
$|=1;

#First checking to see if at least one argument has been provided
if (!defined($ARGV[0]) || $ARGV[0] eq "help") {
    print "Function name must be specified as input arguments!\n";;
	exit(0);
}

#This variable will hold the name of a file that will be printed when a job finishes
my $FinishedFile = "NONE";
my $Status = "SUCCESS";

#Searching for recognized arguments
my $driv = driver->new();
for (my $i=0; $i < @ARGV; $i++) {
    $ARGV[$i] =~ s/___/ /g;
    $ARGV[$i] =~ s/\.\.\./(/g;
    $ARGV[$i] =~ s/,,,/)/g;
    print "\nProcessing argument: ".$ARGV[$i]."\n";
    if ($ARGV[$i] =~ m/^finish\?(.+)/) {
        $FinishedFile = $1;
    } else {
        #Splitting argument
        my @Data = split(/\?/,$ARGV[$i]);
        my $FunctionName = $Data[0];
		for (my $j=0; $j < @Data; $j++) {
			if (length($Data[$j]) == 0) {
				delete $Data[$j];
			}
		}
		
        #Calling function
        $Status .= $driv->$FunctionName(@Data);
    }
}

#Printing the finish file if specified
if ($FinishedFile ne "NONE") {
    if ($FinishedFile =~ m/^\//) {
        FIGMODEL::PrintArrayToFile($FinishedFile,[$Status]);
    } else {
        FIGMODEL::PrintArrayToFile($driv->{_figmodel}->{"database message file directory"}->[0].$FinishedFile,[$Status]);
    }
}

exit();

package driver;

sub new {
	my $self = {_figmodel => ModelSEED::FIGMODEL->new()};
	$self->{_outputdirectory} = $self->{_figmodel}->config("database message file directory")->[0];
	if (defined($ENV{"FIGMODEL_OUTPUT_DIRECTORY"})) {
		$self->{_outputdirectory} = $ENV{"FIGMODEL_OUTPUT_DIRECTORY"};
	}
    return bless $self;
}

=head3 figmodel
Definition:
	FIGMODEL = driver->figmodel();
Description:
	Returns a FIGMODEL object
=cut
sub figmodel {
	my ($self) = @_;
	return $self->{_figmodel};
}

=head3 outputdirectory
Definition:
	FIGMODEL = driver->outputdirectory();
Description:
	Returns the directory where output should be printed
=cut
sub outputdirectory {
	my ($self) = @_;
	return $self->{_outputdirectory};
}

#Individual subroutines are all listed here
sub transporters {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: transporters?(CompoundListInputFile).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    #Getting the list of compound IDs from the input file
    my $Query = FIGMODEL::LoadSingleColumnFile($Data[1],";");
    my $CompoundNum = @{$Query};
    my $TransportDataHash = $self->figmodel()->GetTransportReactionsForCompoundIDList($Query);
    my @CompoundsWithTransporters = keys(%{$TransportDataHash});
    my $NumCompoundsWithTransporters = @CompoundsWithTransporters;

    #Printing the results
    print "Transporters found for ".$NumCompoundsWithTransporters." out of ".$CompoundNum." input compound IDs.\n\n";
    print "Compound;Transporter ID;Equation\n";
    for (my $i=0; $i < @{$Query}; $i++) {
	print $Query->[$i].";";
	if (defined($TransportDataHash->{$Query->[$i]})) {
	    my @TransportList = keys(%{$TransportDataHash->{$Query->[$i]}});
	    for (my $j=0; $j < @TransportList; $j++) {
		print $TransportList[$j].";".$TransportDataHash->{$Query->[$i]}->{$TransportList[$j]}->{"EQUATION"}->[0].";";
	    }
	}
	print "\n";
    }

    return;
}

sub query {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 4) {
        print "Syntax for this command: query?(Query input file)?(Object to query)?(exact).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    #Loading the query list from file
    my $QueryList = FIGMODEL::LoadSingleColumnFile($Data[1],"\t");
    my $QueryNum = @{$QueryList};

    #Calling the query function
    my $Results = $self->figmodel()->QueryCompoundDatabase($QueryList,$Data[3],$Data[2]);

    #Printing the results
    my $MatchNum = 0;
    print "Matching ".$Data[2]." found for ".$MatchNum." out of ".$QueryNum." queries.\n\n";
    print "INDEX;QUERY;MATCHING IDs;MATCHING NAMES;MATCHING HIT VALUE\n";
    my $Count = 0;
    foreach my $Item (@{$Results}) {
	if ($Item != 0) {
	    $MatchNum++;
	    foreach my $Match (@{$Item}) {
		if (defined($Match->{"HIT VALUE"})) {
		    print $Count.";".$QueryList->[$Count].";".$Match->{"MINORGID"}->[0].";".join("|",@{$Match->{"NAME"}}).";".$Match->{"HIT VALUE"}->[0]."\n";
		} else {
		    print $Count.";".$QueryList->[$Count].";".$Match->{"MINORGID"}->[0].";".join("|",@{$Match->{"NAME"}}).";FULL WORD MATCH\n";
		}
	    }
	} else {
	    print $Count.";".$QueryList->[$Count].";NO HITS\n";
	}
	$Count++;
    }
}

sub updaterolemapping {
    my($self,@Data) = @_;

    $self->figmodel()->UpdateFunctionalRoleMappings();
}

sub createmodelfile {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: createmodelfile?(Organism ID)?(Run gap filling)?(user).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

	#Setting the user ID which indicates the owner of the model
	my $user = $self->figmodel()->user();
	if (defined($Data[3])) {
		$user = $Data[3];
	}

	#Creating the list of genomes that models should be build for
	my $List;
	if ($Data[1] =~ m/LIST-(.+)$/) {
        $List = FIGMODEL::LoadSingleColumnFile($1,"");
	} else {
		$List = [$Data[1]];
	}

	#Building the models
	for (my $i=0; $i < @{$List}; $i++) {
		$self->figmodel()->CreateSingleGenomeReactionList($List->[$i],$user,$Data[2]);
	}
	print "Model file successfully generated.\n\n";
    return "SUCCESS";
}

sub createmetagenomemodel {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: createmetagenomemodel?(Metagenome ID)?(user).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

	#Setting the user ID which indicates the owner of the model
	my $user = $self->figmodel()->user();
	if (defined($Data[3])) {
		$user = $Data[3];
	}

	#Creating the list of genomes that models should be build for
	my $List;
	if ($Data[1] =~ m/LIST-(.+)$/) {
        my $List = FIGMODEL::LoadSingleColumnFile($1,"");
	} else {
		$List = [$Data[1]];
	}

	#Building the models
	for (my $i=0; $i < @{$List}; $i++) {
		$self->figmodel()->AddMetaGenomeModelToDB($List->[$i],$user,1);
	}
	print "Model file successfully generated.\n\n";
    return "SUCCESS";
}


sub preliminaryreconstruction {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: preliminaryreconstruction?(Model ID)?(Run gap filling).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

	my $model = $self->figmodel()->get_model($Data[1]);
	if (defined($model)) {
		$model->CreateMetabolicModel($Data[2]);
	}
    return "SUCCESS";
}

sub calculatemodelchanges {
    my($self,@Data) = @_;
    if (@Data < 4) {
        print "Syntax for this command: calculatemodelchanges?(Model ID)?(filename)?(message).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $model = $self->figmodel()->get_model($Data[1]);
	if (defined($model)) {
		$model->calculate_model_changes(undef,$Data[3],undef,undef,$Data[2]);
		return "SUCCESS" 
	}
    return "CRASH";
}

sub processmodel {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: processmodel?(Model ID)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $mdl = $self->figmodel()->get_model($Data[1]);
	if (defined($mdl)) {
		$mdl->processModel();
	}
}

sub setmodelstatus {
	my($self,@Data) = @_;
	if (@Data < 4) {
        print "Syntax for this command: processmodel?(Model ID)?(status)?(message)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $mdl = $self->figmodel()->get_model($Data[1]);
	if (defined($mdl)) {
		$mdl->set_status($Data[2],$Data[3]);
	}
}

sub updatestatsforgapfilling {
	my($self,@Data) = @_;
	if (@Data < 3) {
        print "Syntax for this command: updatestatsforgapfilling?(Model ID)?(elapsed time)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $mdl = $self->figmodel()->get_model($Data[1]);
	if (defined($mdl)) {
		$mdl->update_stats_for_gap_filling($Data[2]);
	}
}

sub printmodelobjective {
    my($self,@Data) = @_;
    #/vol/rast-prod/jobs/(job number)/rp/(genome id)/
    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: printmodelobjective?(Model ID)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    if ($Data[1] =~ m/LIST-(.+)$/) {
        my $List = FIGMODEL::LoadSingleColumnFile($1,"");
        for (my $i=0; $i < @{$List}; $i++) {
            $self->figmodel()->PrintModelGapFillObjective($List->[$i]);
        }
        return "SUCCESS";
    } else {
        $self->figmodel()->PrintModelGapFillObjective($Data[1]);
        return "SUCCESS";
    }
}

sub translatemodel {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: translatemodel?(Organism ID).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->TranslateModelGeneIDs($Data[1]);

    print "Model file successfully translated.\n\n";
}

sub datagapfill {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: datagapfill?(Model ID).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    #Running the gap filling algorithm
    print "Running gapfilling on ".$Data[1]."\n";
    my $model = $self->figmodel()->get_model($Data[1]);
	if (defined($model) && $model->GapFillingAlgorithm() == $self->figmodel()->success()) {
        print "Data gap filling successfully completed!\n";
        return "SUCCESS";
    }

    print "Error encountered during data gap filling!\n";
    return "FAIL";
}

sub optimizeannotations {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: optimizeannotations?(Organism ID).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    #Optimizing the annotations
    if ($Data[1] =~ m/LIST-(.+)$/) {
        my $List = FIGMODEL::LoadSingleColumnFile($1,"");
        $self->figmodel()->OptimizeAnnotation($List);
    }
}

sub implementannoopt {
    my($self,@Data) = @_;

    if (@Data < 2) {
		print "Syntax for this command: implementannoopt?(Filename).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->AdjustAnnotation($Data[1]);
}

sub simulateexperiment {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 3) {
        print "Syntax for this command: simulateexperiment?(Model name)?(experiment specification)?(Solver)?(Classify).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    #Getting the list of models to be analyzed
    my @ModelList;
    if ($Data[1] =~ m/LIST-(.+)/) {
        my $List = FIGMODEL::LoadSingleColumnFile($1,"");
        if (defined($List)) {
            push(@ModelList,@{$List});
        }
    } else {
        push(@ModelList,$Data[1]);
    }

    #Checking if the user asked to classify the reactions as well
    if (defined($Data[4] && $Data[4] eq "Classify")) {
        $self->figmodel()->{"RUN PARAMETERS"}->{"Classify reactions during simulation"} = 1;
    }

    #Creating a table to store the results of the analysis
    my $ResultsTable = new ModelSEED::FIGMODEL::FIGMODELTable(["Model","Total data","Total biolog","Total gene KO","False positives","False negatives","Correct positives","Correct negatives","Biolog False positives","Biolog False negatives","Biolog Correct positives","Biolog Correct negatives","KO False positives","KO False negatives","KO Correct positives","KO Correct negatives"],$self->figmodel()->{"database message file directory"}->[0]."SimulationResults-".$Data[2].".txt",[],";","|",undef);

    #Calling the model function that runs the experiment
    for (my $i=0; $i < @ModelList; $i++) {
        print "Processing ".$ModelList[$i]."\n";
        #Creating a table to store the results of the analysis
        my $ClassificationResultsTable = new ModelSEED::FIGMODEL::FIGMODELTable(["Database ID","Positive","Negative","Postive variable","Negative variable","Variable","Blocked"],$self->figmodel()->{"database message file directory"}->[0]."ClassificationResults-".$ModelList[$i]."-".$Data[2].".txt",[],";","|",undef);
        my ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$ErrorVector,$HeadingVector) = $self->figmodel()->get_model($ModelList[$i])->RunAllStudiesWithDataFast($Data[2]);
        if ($Data[2] eq "All") {
            #Getting the directory for the model
            (my $Directory,$ModelList[$i]) = $self->figmodel()->GetDirectoryForModel($ModelList[$i]);
            #Printing the original performance vector
            FIGMODEL::PrintArrayToFile($Directory.$ModelList[$i]."-OPEM".".txt",[$ErrorVector]);
        }
        my @ErrorArray = split(/;/,$ErrorVector);
        my @HeadingArray = split(/;/,$HeadingVector);
        my $NewRow = {"Model" => [$ModelList[$i]],"Total data" => [$FalsePostives+$FalseNegatives+$CorrectNegatives+$CorrectPositives],"Total biolog" => [0],"Total gene KO" => [0],"False positives" => [$FalsePostives],"False negatives", => [$FalseNegatives],"Correct positives" => [$CorrectPositives],"Correct negatives" => [$CorrectNegatives],"Biolog False positives" => [0],"Biolog False negatives" => [0],"Biolog Correct positives" => [0],"Biolog Correct negatives" => [0],"KO False positives" => [0],"KO False negatives" => [0],"KO Correct positives" => [0],"KO Correct negatives" => [0]};
        for (my $j=0; $j < @HeadingArray; $j++) {
            if ($HeadingArray[$j] =~ m/^Media/) {
                $NewRow->{"Total biolog"}->[0]++;
                if ($ErrorArray[$j] == 0) {
                    $NewRow->{"Biolog Correct positives"}->[0]++;
                } elsif ($ErrorArray[$j] == 1) {
                    $NewRow->{"Biolog Correct negatives"}->[0]++;
                } elsif ($ErrorArray[$j] == 2) {
                    $NewRow->{"Biolog False positives"}->[0]++;
                } elsif ($ErrorArray[$j] == 3) {
                    $NewRow->{"Biolog False negatives"}->[0]++;
                }
            } elsif ($HeadingArray[$j] =~ m/^Gene\sKO/) {
                $NewRow->{"Total gene KO"}->[0]++;
                if ($ErrorArray[$j] == 0) {
                    $NewRow->{"KO Correct positives"}->[0]++;
                } elsif ($ErrorArray[$j] == 1) {
                    $NewRow->{"KO Correct negatives"}->[0]++;
                } elsif ($ErrorArray[$j] == 2) {
                    $NewRow->{"KO False positives"}->[0]++;
                } elsif ($ErrorArray[$j] == 3) {
                    $NewRow->{"KO False negatives"}->[0]++;
                }
            }
        }
        $ResultsTable->add_row($NewRow);
        if (defined($Data[4] && $Data[4] eq "Classify")) {
            my @ReactionIDList = keys(%{$self->figmodel()->{"Simulation classification results"}});
            for (my $i=0; $i < @ReactionIDList; $i++) {
                $ClassificationResultsTable->add_row({"Database ID" => [$ReactionIDList[$i]],"Positive" => [$self->figmodel()->{"Simulation classification results"}->{$ReactionIDList[$i]}->{"P"}],"Negative" => [$self->figmodel()->{"Simulation classification results"}->{$ReactionIDList[$i]}->{"N"}],"Postive variable" => [$self->figmodel()->{"Simulation classification results"}->{$ReactionIDList[$i]}->{"PV"}],"Negative variable" => [$self->figmodel()->{"Simulation classification results"}->{$ReactionIDList[$i]}->{"NV"}],"Variable" => [$self->figmodel()->{"Simulation classification results"}->{$ReactionIDList[$i]}->{"V"}],"BLOCKED" => [$self->figmodel()->{"Simulation classification results"}->{$ReactionIDList[$i]}->{"B"}]});
            }
            $ClassificationResultsTable->save();
        }
        undef $ClassificationResultsTable;
    }

    #Printing the results
    $ResultsTable->save();

    return 0;
}

sub simulatestrains {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: simulatestrains?(Model name)?(Strain)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    my $StrainList;
    my $MediaHash;
    my $IntervalTable = $self->figmodel()->database()->GetDBTable("INTERVAL TABLE");
    for (my $i=0; $i < $IntervalTable->size(); $i++) {
        push(@{$StrainList},$IntervalTable->get_row($i)->{"ID"}->[0]);
        for (my $j=0; $j < @{$IntervalTable->get_row($i)->{"GROWTH"}}; $j++) {
            my @Temp = split(/:/,$IntervalTable->get_row($i)->{"GROWTH"}->[$j]);
            if (-e $self->figmodel()->config("Media directory")->[0].$Temp[0].".txt") {
                $MediaHash->{$Temp[0]} = 1;
            }
        }
    }
	my $StrainTable = $self->figmodel()->database()->GetDBTable("STRAIN TABLE");
    for (my $i=0; $i < $StrainTable->size(); $i++) {
        push(@{$StrainList},$StrainTable->get_row($i)->{"ID"}->[0]);
        for (my $j=0; $j < @{$StrainTable->get_row($i)->{"GROWTH"}}; $j++) {
            my @Temp = split(/:/,$StrainTable->get_row($i)->{"GROWTH"}->[$j]);
            if (-e $self->figmodel()->config("Media directory")->[0].$Temp[0].".txt") {
                $MediaHash->{$Temp[0]} = 1;
            }
        }
    }
    my $MediaList;
    push(@{$MediaList},keys(%{$MediaHash}));
	push(@{$MediaList},("Spizizen-No-citrate","Fabret-No-citrate","Complete"));
    $self->figmodel()->SimulateIntervalKO($StrainList,$Data[1],$MediaList);
}

sub studyunviablestrain {
	my($self,@Data) = @_;
	print "Syntax for this command: studyunviablestrain?(Model name)?(Strain)?(Media)\n\n";
	if (!defined($Data[3])) {
		$Data[3] = "Complete";
	}
	if (!defined($Data[1])) {
		$Data[1] = "iBsu1103";
	}
	if (!defined($Data[2]) || $Data[2] eq "ALL") {
		$self->figmodel()->study_unviable_strains($Data[1]);
	} else {
		my $output = $self->figmodel()->diagnose_unviable_strain($Data[1],$Data[2],$Data[3]);
		if (!defined($output)) {
			$self->figmodel()->error_message("ModelDriver:studyunviablestrain:Could not find results from analysis of strain.");
			return "FAIL";
		}
		print "Coesssential rections:".$output->{"COESSENTIAL_REACTIONS"}->[0]."\n";
		print "Rescue media:".$output->{"RESCUE_MEDIA"}->[0]."\n";
	}
    return "SUCCESS";
}

sub comparemodels {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
	if (@Data >= 2 && $Data[1] =~ m/LIST-(.+)/) {
		my $List = FIGMODEL::LoadSingleColumnFile($1,"");
		my $CombinedResults;
        foreach my $Pair (@{$List}) {
            push(@{$CombinedResults->{"COMPARISON"}},$Pair);
            my ($ModelOne,$ModelTwo) = split(/-/,$Pair);
            my $ComparisonResults = $self->figmodel()->CompareModels($ModelOne,$ModelTwo);
            my @KeyList = keys(%{$ComparisonResults});
            foreach my $Key (@KeyList) {
                my $Number = shift(@{$ComparisonResults->{$Key}});
                my $Items = join(",",@{$ComparisonResults->{$Key}});
                $Key =~ s/$ModelOne/A/g;
                $Key =~ s/$ModelTwo/B/g;
                push(@{$CombinedResults->{$Key}},$Number);
                push(@{$CombinedResults->{"Items ".$Key}},$Items);
            }
		}
		FIGMODEL::SaveHashToHorizontalDataFile($self->figmodel()->{"database message file directory"}->[0]."ModelComparison.txt",";",$CombinedResults);
        my $EquivalentReactionArray;
        my @ReactionArray = keys(%{$self->figmodel()->{"EquivalentReactions"}});
        my $ReactionTable = $self->figmodel()->GetDBTable("REACTIONS");
        foreach my $Reaction (@ReactionArray) {
            my @EquivalentReactions = keys(%{$self->figmodel()->{"EquivalentReactions"}->{$Reaction}});
            foreach my $EquivReaction (@EquivalentReactions) {
                my $LoadedReaction = $self->figmodel()->LoadObject($Reaction);
                my $LoadedEquivReaction = $self->figmodel()->LoadObject($EquivReaction);
                if (!defined($self->figmodel()->{"ModelReactions"}->{$Reaction}) && !defined($self->figmodel()->{"ForeignReactions"}->{$EquivReaction})) {
                    push(@{$EquivalentReactionArray},$Reaction.";".$EquivReaction.";".$LoadedReaction->{"DEFINITION"}->[0].";".$LoadedEquivReaction->{"DEFINITION"}->[0].";".$self->figmodel()->{"EquivalentReactions"}->{$Reaction}->{$EquivReaction}->{"Count"}.";".$self->figmodel()->{"EquivalentReactions"}->{$Reaction}->{$EquivReaction}->{"Source"});
                }
            }
        }
        FIGMODEL::PrintArrayToFile($self->figmodel()->{"database message file directory"}->[0]."EquivalentReactions.txt",$EquivalentReactionArray);
        $self->figmodel()->{"Global A exclusive roles"}->save();
		$self->figmodel()->{"Global A exclusive reactions"}->save();
		$self->figmodel()->{"Global A reversible"}->save();
		$self->figmodel()->{"Global B exclusive roles"}->save();
		$self->figmodel()->{"Global B exclusive reactions"}->save();
		$self->figmodel()->{"Global B reversible"}->save();
		$self->figmodel()->{"Global directionality conflicts"}->save();
    } elsif (@Data >= 3) {
		my $ComparisonResults = $self->figmodel()->CompareModels($Data[1],$Data[2]);
		FIGMODEL::SaveHashToHorizontalDataFile($self->figmodel()->{"database message file directory"}->[0].$Data[1]."-".$Data[2].".txt",";",$ComparisonResults);
	} else {
		print "Syntax for this command: comparemodels?(Model one)?(Model two) or comparemodels?LIST-(name of file with ; delimited pairs).\n\n";
        exit(1);
	}

    #Printing run success line
    print "Model comparison successful.\n\n";
}

sub makehistogram {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: makehistogram?(Input filename)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    if ($Data[1]) {
        my $DataArrayRef = FIGMODEL::LoadSingleColumnFile($Data[1],"");
        my $HistoHashRef = FIGMODEL::CreateHistogramHash($DataArrayRef);
        FIGMODEL::SaveHashToHorizontalDataFile($self->figmodel()->{"database message file directory"}->[0]."HistogramOutput.txt","\t",$HistoHashRef);
    }

    #Printing run success line
    print "Histogram generation successful.\n\n";
}

sub classifyreactions {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: classifyreactions?(Model name)?(Media)?(Preserve results in model database).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    #Handling default media
    if (!defined($Data[2])) {
        $Data[2] = "Complete";
    }

	#Model list
    my $ModelList;
	if ($Data[1] eq "ALL") {
		for (my $i=0; $i < $self->figmodel()->number_of_models(); $i++) {
			push(@{$ModelList},$self->figmodel()->get_model($i));
		}
	} else {
		my @temparray = split(/;/,$Data[1]);
		for (my $i=0; $i < @temparray; $i++) {
			push(@{$ModelList},$self->figmodel()->get_model($temparray[$i]));
		}
	}

	#Running classification
	my $Success = "SUCCESS:";
    my $Fail = "FAIL:";
    foreach my $Model (@{$ModelList}) {
        print "Now processing model: ".$Model->id()."\n";
		my ($rxnclasstable,$cpdclasstable) = $Model->classify_model_reactions($Data[2],$Data[3]);
        $rxnclasstable->save($self->outputdirectory().$Model->id()."-".$Data[2]."-ReactionClasses.tbl");
        $cpdclasstable->save($self->outputdirectory().$Model->id()."-".$Data[2]."-CompoundClasses.tbl");
        #Checking that the table is defined and the output file exists
        if (!defined($rxnclasstable)) {
            $Fail .= $Model->id().";";
        } else {
            $Success .= $Model->id().";";
        }
    }
	print $Success."\n".$Fail."\n";
	return "SUCCESS";
}

sub buildbiomass {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 1) {
        print "Syntax for this command: buildbiomass?(Model name)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

	#Model list
    my $ModelList;
    my @temparray = split(/;/,$Data[1]);
    for (my $i=0; $i < @temparray; $i++) {
	push(@{$ModelList},$self->figmodel()->get_model($temparray[$i]));
    }

    foreach my $Model (@{$ModelList}) {
        print "Now processing model: ".$Model->id()."\n";
	$Model->BuildSpecificBiomassReaction();
    }
}

sub predictessentiality {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: predictessentiality?(Model name)?(Media).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    #Handling default media
    if (!defined($Data[2])) {
        $Data[2] = "Complete";
    }

    #Model list
    my $ModelList;
    my $Success = "SUCCESS:";
    my $Fail = "FAIL:";
    if ($Data[1] eq "ALL") {
        my $ModelTable = $self->figmodel()->GetDBTable('MODELS');
        for (my $i=0; $i < $ModelTable->size(); $i++) {
            push(@{$ModelList},$ModelTable->get_row($i)->{id}->[0]);
        }
    } else {
        push(@{$ModelList},split(/[;,]/,$Data[1]));
    }

    #Processing model list
    foreach my $Model (@{$ModelList}) {
        print "Now processing model: ".$Model."\n";
        my $modelObject = $self->figmodel()->get_model($Model);
        my $result = $self->figmodel()->RunFBASimulation($Model,"SINGLEKO",undef,undef,[$Model],[$Data[2]]);
        #Checking that the table is defined and the output file exists
        if (!defined($result)) {
            $Fail .= $Model.";";
        } elsif (defined($result->get_row(0)->{"ESSENTIALGENES"})) {
            $self->figmodel()->database()->print_array_to_file($modelObject->directory()."EssentialGenes-".$Model."-".$Data[2].".tbl",[join("\n",@{$result->get_row(0)->{"ESSENTIALGENES"}})]);
            $Success .= $Model.";";
        }
    }
}

sub processreaction {
	my($self,@Data) = @_;
    if (@Data < 2) {
        print "Syntax for this command: processreaction?(reaction).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	if ($Data[1] eq "ALL") {
		my $objs = $self->figmodel()->database()->get_objects("reaction");
		for (my $i=0; $i < @{$objs}; $i++) {
			print "Reaction ".$i.":".$objs->[$i]->id()."\n";
			my $rxn = $self->figmodel()->get_reaction($objs->[$i]->id());
			$rxn->updateReactionData();
		}
	} else {
		my $rxn = $self->figmodel()->get_reaction($Data[1]);
		if (defined($rxn)) {
			$rxn->updateReactionData();
		}
	}
}

#Function for combining identical reactions in the database
sub findredundantreactions {
    my($self,@Data) = @_;
	$self->figmodel()->rebuild_reaction_database_table();
}

#Function for combining identical compounds in the database
sub findredundantcompounds {
    my($self,@Data) = @_;
	$self->figmodel()->rebuild_compound_database_table();
}

#Inspected: working as intended
sub updatedatabase {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 4) {
        print "Syntax for this command: updatedatabase?(Add new objects?)?(Process compounds)?(Process reactions).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    if ($Data[2] eq "yes") {
        if ($Data[1] eq "yes") {
            $self->figmodel()->UpdateCompoundDatabase(1);
        } else {
            $self->figmodel()->UpdateCompoundDatabase(0);
        }
    }
    if ($Data[3] eq "yes") {
        if ($Data[1] eq "yes") {
            $self->figmodel()->UpdateReactionDatabase(1);
        } else {
            $self->figmodel()->UpdateReactionDatabase(0);
        }
    }
}

sub updategenomestats {
    my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: updategenomestats?(genome ID).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    my $list;
    if ($Data[1] eq "models") {
    	my $objects = $self->figmodel()->database()->get_objects("model");
    	my $hash;
    	for (my $i=0; $i < @{$objects}; $i++) {
    		$hash->{$objects->[$i]->genome()} = 1;
    	}
    	push(@{$list},keys(%{$hash}));
    } else {
   		push (@{$list},split(/,/,$Data[1]));
    }
    for (my $i=275; $i < @{$list}; $i++) {
    	print "Updating stats on: ".$list->[$i]."\n";
    	my $genome = $self->figmodel()->get_genome($list->[$i]);
   		$genome->update_genome_stats();
    }
}

#Inspected: appears to be working
sub printmodellist {
    my($self,@Data) = @_;

    my $ModelList = $self->figmodel()->GetListOfCurrentModels();
    print "Current model list for SEED:\n";
    for (my $i=0; $i < @{$ModelList}; $i++) {
        print $ModelList->[$i]."\n";
    }
}

#Inspected: appears to be working
sub printmedialist {
    my($self,@Data) = @_;

    my $MediaList = $self->figmodel()->GetListOfMedia();
    print "Current media list for SEED:\n";
    for (my $i=0; $i < @{$MediaList}; $i++) {
        print $MediaList->[$i]."\n";
    }
}

#Inspected: working as intended
sub addnewcompoundcombination {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 3) {
        print "Syntax for this command: addnewcompoundcombination?(Compound ID one)?(Compound ID two).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->AddNewPendingCompoundCombination($Data[1].";".$Data[2]);
}

sub backupdatabase {
    my($self,@Data) = @_;

    $self->figmodel()->BackupDatabase();
}

#Partially inspected: will complete inspection upon next KEGG update
sub syncwithkegg {
    my($self,@Data) = @_;

    $self->figmodel()->SyncWithTheKEGG();
}

#Inspected: working as intended
sub syncmolfiles {
    my($self,@Data) = @_;

    $self->figmodel()->SyncDatabaseMolfiles();
}

sub updatesubsystemscenarios {
    my($self,@Data) = @_;

    $self->figmodel()->ParseHopeSEEDReactionFiles();
}

sub combinemappingsources {
    my($self,@Data) = @_;

    $self->figmodel()->CombineRoleReactionMappingSources();
}

sub loadgapfillsolution {
    my($self,@Data) = @_;
	#Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: loadgapfillsolution?(tansfer files)?(filename)?(Start)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    $self->figmodel()->retrieve_load_gapfilling_results($Data[1],$Data[2],$Data[3]);
}

sub gapfillmodel {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: gapfillmodel?(Model ID)?(do not clear existing solution)?(print LP file rather than solving).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    #Gap filling the model
    my $model = $self->figmodel()->get_model($Data[1]);
	if (defined($model)) {
		$model->GapFillModel($Data[2],$Data[3]);
	} elsif (-e $Data[1]) {
		my $list = $self->figmodel()->database()->load_single_column_file($Data[1]);
		for (my $i=0; $i < @{$list}; $i++) {
			my $model = $self->figmodel()->get_model($list->[$i]);
			if (defined($model)) {
				$model->GapFillModel($Data[2],$Data[3]);
			}
		}
	}
	if (defined($Data[3]) && $Data[3] == 1) {
		#Moving files to ranger
		system("scp -i ~/.ssh/id_rsa2 ".$self->config("LP file directory")->[0]."* tg-login.ranger.tacc.teragrid.org:/work/01276/chenry/JobDirectory/LPFiles2/");
	}

    return "SUCCESS";
}

sub schedulegapfill {
	my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: schedulegapfill?(Model ID)?(do not clear existing solution)?(print LP file rather than solving).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    $self->figmodel()->add_job_to_queue({command => "gapfillmodel?".$Data[1],queue => "cplex"});
}

sub buildlinktbl {
	 my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 3) {
        print "Syntax for this command: buildlinktbl?(entity 1)?(entity 2).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	$self->figmodel()->database()->build_link_file($Data[1],$Data[2]);
    return "SUCCESS";
}

sub testsolutions {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 4) {
        print "Syntax for this command: testsolutions?(Model ID)?(Index)?(GapFill)?(Number of processors).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    #Setting the processor index
    my $ProcessorIndex = -1;
    if (defined($Data[2])) {
        $ProcessorIndex = $Data[2];
    }

    #Setting the number of processors
    my $NumProcessors = $self->figmodel()->{"Solution testing processors"}->[0];
    if (defined($Data[4])) {
        $NumProcessors = $Data[4];
    }

    #Running the test algorithm
    print "Testing solutions for ".$Data[1]." with ".$NumProcessors." processors.\n";
    $self->figmodel()->TestSolutions($Data[1],$NumProcessors,$ProcessorIndex,$Data[3]);

    #Checking that the error matrices have really been generated
    (my $Directory,$Data[1]) = $self->figmodel()->GetDirectoryForModel($Data[1]);
    if (!-e $Directory.$Data[1]."-".$Data[3]."EM.txt") {
        return "ERROR MATRIX FILE NOT GENERATED!";
    } elsif (!-e $Directory.$Data[1]."-OPEM.txt") {
        return "ORIGINAL PERFORMANCE FILE NOT FOUND!"
    }

    return "SUCCESS";
}

sub manualgapfill {
    my($self,@Data) = @_;

	#Checking the argument to ensure all required parameters are present
    if (@Data < 6) {
        print "Syntax for this command: manualgapfill?(Model ID)?(Label)?(Media)?(Reaction list)?(filename).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

	my $model = $self->figmodel()->get_model($Data[1]);
	my $GapFillResultTable = $model->datagapfill([$Data[2].":".$Data[3].":".$Data[4]]);
	if (!defined($GapFillResultTable)) {
		return "FAIL";
	}
	$GapFillResultTable->save($Data[5]);
	my $ErrorMatrix = $model->TestSolutions(undef,$GapFillResultTable);
	print join("\n",@{$ErrorMatrix});

	return "SUCCESS";
}

sub changemodelbiomass {
	my($self,@Data) = @_;
    if (@Data < 3) {
        print "Syntax for this command: changemodelbiomass?(Model ID)?(Biomass reaction).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $model = $self->figmodel()->get_model($Data[1]);
	if (defined($model)) {
		$model->biomassReaction($Data[2]);
	}	
}

sub changemodelautocompletemedia {
	my($self,@Data) = @_;
    if (@Data < 3) {
        print "Syntax for this command: changemodelautocompletemedia?(Model ID)?(Autocompletion media).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $model = $self->figmodel()->get_model($Data[1]);
	if (defined($model)) {
		$model->autocompleteMedia($Data[2]);
	}
}

sub manualgapgen {
    my($self,@Data) = @_;

	#Checking the argument to ensure all required parameters are present
    if (@Data < 4) {
        print "Syntax for this command: manualgapgen?(Model ID)?(Media)?(Reaction list).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $model = $self->figmodel()->get_model($Data[1]);
	my $GapGenResultTable = $model->datagapgen($Data[2],$Data[3]);
	if (!defined($GapGenResultTable)) {
		return "FAIL";
	}
	$GapGenResultTable->save();
	return "SUCCESS";
}

sub optimizedeletions {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 5) {
        print "Syntax for this command: optimizedeletions?(Model ID)?(Media)?(Min deletions)?(Max deletions).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    (my $Directory,my $ModelName) = $self->figmodel()->GetDirectoryForModel($Data[1]);

    my $UniqueFilename = $self->figmodel()->filename();

    system($self->figmodel()->{"MFAToolkit executable"}->[0].' parameterfile Parameters/DeletionOptimization.txt resetparameter "Minimum number of deletions" '.$Data[3].' resetparameter "Maximum number of deletions" '.$Data[4].' resetparameter "user bounds filename" "Media/'.$Data[2].'.txt" resetparameter output_folder "'.$UniqueFilename.'/" LoadCentralSystem "'.$Directory.$ModelName.'.txt" > '.$self->figmodel()->{"Reaction database directory"}->[0]."log/".$UniqueFilename.'.log');
}

sub rungapgeneration {
    my($self,@Data) = @_;
    #Checking the argument to ensure all required parameters are present
    if (@Data < 3) {
        print "Syntax for this command: rungapgeneration?(Model ID)?(Media)?(Reaction list)?(No KO list)?(Experiment)?(Solution limit).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    #Getting the model
    my $model = $self->figmodel()->get_model($Data[1]);
    if (!defined($model)) {
    	return "FAIL";
    }
    #Running gap generation
    my $solutions = $model->GapGenModel($Data[2],$Data[3],$Data[4],$Data[5],$Data[6]);
    if (defined($solutions)) {
    	print "Solutions:\n".join("\n",@{$solutions})."\n";
    	return "SUCCESS";
    }
    return "FAIL";
}

sub gathermodelstats {
    my($self,@Data) = @_;

    if (@Data < 2) {
        my $ModelTable = $self->figmodel()->GetDBTable("MODEL LIST");
        for (my $i=0; $i < $ModelTable->size(); $i++) {
            $self->figmodel()->get_model($ModelTable->get_row($i)->{"MODEL ID"}->[0])->update_model_stats();
        }
    } else {
		$self->figmodel()->get_model($Data[1])->update_model_stats();
    }
}

sub rundeletions {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: rundeletions?model.\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    #The first argument should always be the model (or model list), all subsequent arguments are optional
    my $List;
    if ($Data[1] =~ m/LIST-(.+)$/) {
        $List = FIGMODEL::LoadSingleColumnFile($1,"");
    } elsif ($Data[1] eq "ALL") {
        my $ModelData = $self->figmodel()->GetListOfCurrentModels();
        for (my $i=0; $i < @{$ModelData}; $i++) {
            push(@{$List},$ModelData->[$i]->{"MODEL ID"}->[0]);
        }
    } else {
        push(@{$List},$Data[1]);
    }

    #Setting the media
    my $Media = "Complete";
    if (defined($Data[2])) {
        $Media = $Data[2];
    }

    #Running MFA on the model list
    my $Results;
    for (my $i=0; $i < @{$List}; $i++) {
        my $DeletionResultsTable = $self->figmodel()->PredictEssentialGenes($List->[$i],$Media);
        my $OrganismID = $self->figmodel()->genomeid_of_model($List->[$i]);
        if (defined($DeletionResultsTable)) {
            #Printing essentiality data in the model directory
            (my $Directory,$List->[$i]) = $self->figmodel()->GetDirectoryForModel($List->[$i]);
            my $Filename = $Directory.$Media."-EssentialGenes.txt";
            if (open (OUTPUT, ">$Filename")) {
                for (my $j=0; $j < $DeletionResultsTable->size(); $j++) {
                    if ($DeletionResultsTable->get_row($j)->{"Insilico growth"}->[0] < 0.0000001) {
                        print OUTPUT "fig|".$OrganismID.".".$DeletionResultsTable->get_row($j)->{"Experiment"}->[0]."\n";
                        push(@{$Results->{$List->[$i]}},$DeletionResultsTable->get_row($j)->{"Experiment"}->[0]);
                    }
                }
                close(OUTPUT);
            }
        }
    }

    #Printing combined results of the entire run in the log directory
    my $Filename = $self->figmodel()->{"database message file directory"}->[0]."GeneEssentialityAnalysisResults.txt";
    if (open (OUTPUT, ">$Filename")) {
        my @ModelList = keys(%{$Results});
        print OUTPUT "Model;Number of essential genes;Essential genes\n";
        foreach my $Item (@ModelList) {
            my $NumberOfEssentialGenes = @{$Results->{$Item}};
            print OUTPUT $Item.";".$NumberOfEssentialGenes.";".join(",",@{$Results->{$Item}})."\n";
        }
        close(OUTPUT);
    }
    print "Model deletions successfully completed.\n\n";
}

sub installdb {
    my($self,@Data) = @_;

    $self->figmodel()->InstallDatabase();
}

sub editdb {
    my($self,@Data) = @_;

    if (@Data < 2) {
        print "Syntax for this command: editdb?edit commands filename.\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->EditDatabase($Data[1]);
}

sub getessentialitydata {
    my($self,@Data) = @_;

    $self->figmodel()->GetSEEDEssentialityData();
}

sub getgapfillingdependancy {
    my($self,@Data) = @_;
    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: getgapfillingdependancy?(Model ID).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    my $List = [$Data[1]];
    if ($Data[1] =~ m/LIST-(.+)$/) {
        $List = FIGMODEL::LoadSingleColumnFile($1,"");
    }
    for (my $i=0; $i < @{$List}; $i++) {
		my $mdl = $self->figmodel()->get_model($List->[$i]);
		if (defined($mdl)) {
			$mdl->IdentifyDependancyOfGapFillingReactions();
		}
	}
}

sub runmfa {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: runmfa?(Filename)?(Model ID)?(Media)?(Parameters)?(Parameter files).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    #Getting a unique filename for the model
    my $Filename = $self->figmodel()->filename();

    #Parsing the parameter file list
    my $Parameterfiles = undef;
    if (defined($Data[5])) {
        push(@{$Parameterfiles},split(/\|/,$Data[5]));
    }

    #Parsing out the parameter-value pairs
    my $ParameterValueHash = undef;
    if (defined($Data[4])) {
        my @PairArray = split(/\|/,$Data[4]);
        for (my $i=0; $i < @PairArray; $i++) {
            if (defined($PairArray[$i+1])) {
                $ParameterValueHash->{$PairArray[$i]} = $PairArray[$i+1];
                $i++;
            }
        }
    }

    #Running the mfatoolkit
    system($self->figmodel()->GenerateMFAToolkitCommandLineCall($Filename,$Data[2],$Data[3],$Parameterfiles,$ParameterValueHash,undef,undef,undef));

    #If the problem report file exists, we copy this file over to the supplied filename
    if (-e $self->figmodel()->{"MFAToolkit output directory"}->[0].$Filename."/MFAOutput/ProblemReports.txt") {
        system("cp \"".$self->figmodel()->{"MFAToolkit output directory"}->[0].$Filename."/MFAOutput/ProblemReports.txt\" \"".$Data[1]."\"");
    }

}

sub printgenomealiases {
	my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
		print "Syntax for this command: printgenomealiases?(genome ID).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
    my $genomeList;
    if (-e $Data[1]) {
    	$genomeList = $self->figmodel()->database()->load_single_column_file($Data[1]);
    } else {
    	push(@{$genomeList},split(/[;,]/,$Data[1]));
    }
    my $output = ["Genome;Peg ID;Aliases"];
    for (my $i=0; $i < @{$genomeList}; $i++) {
    	my $features = $self->figmodel()->GetGenomeFeatureTable($genomeList->[$i]);
    	for (my $j=0; $j < $features->size(); $j++) {
    		my $row = $features->get_row($j);
    		if ($row->{ID}->[0] =~ m/(peg\.\d+)/) {
    			push(@{$output},$genomeList->[$i].";".$1.";".join("|",@{$row->{ALIASES}}));
    		}
    	}
    }
    $self->figmodel()->database()->print_array_to_file($self->outputdirectory()."GenomeAliases.txt",$output);
    return "SUCCESS";
}

sub printmodelrxnfiles {
	my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
		print "Syntax for this command: printmodelrxnfiles?(Model ID).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
    my $models;
    if ($Data[1] eq "ALL" || !defined($Data[1])) {
		$models = $self->figmodel()->get_models();
	} else {
		$models = $self->figmodel()->get_models({id => $Data[1]});
	}
	for (my $i=0; $i < @{$models}; $i++) {
		if (defined($models->[$i])) {
			$models->[$i]->PrintModelSimpleReactionTable();
		}
	}
    return "SUCCESS";
}

sub printmodelcompounds {
	my($self,@Data) = @_;
	#Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
		print "Syntax for this command: printmodelcompounds?(Model ID).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
    my $mdl = $self->figmodel()->get_model($Data[1]);
    my $cpdTbl = $mdl->compound_table();
    $cpdTbl->save($self->figmodel()->config("database message file directory")->[0]."Compounds-".$Data[1].".tbl");
}

#sub metabolomics {
#	my($self,@Data) = @_;
#	if (@Data < 3) {
#		print "Syntax for this command: metabolomics?(Model ID)?(filename).\n\n";
#		return "ARGUMENT SYNTAX FAIL";
#    }
#	my $models = ["iJR904","Seed83333.1","iAF1260"];
#	my $results = FIGMODELTable->new(["Reactions","Definition","Equation","Ecoli","iJR904","Seed83333.1","iAF1260","# changed","# reactants up","# reactants down","# products up","# products down","Up reactants","Down reactants","Up products","Down products","Pathways"],"/home/chenry/Metabolomics.txt",["Reactions"],";","|",undef);
#	my $data = $self->figmodel()->database()->load_multiple_column_file($Data[2],"\t");
#	for (my $i=0; $i < @{$data}; $i++) {
#		my $cpdid = $data->[$i]->[0];
#		my $rxnObjs = $self->figmodel()->database()->get_objects("cpdrxn",{COMPOUND=>$cpdid});
#		for (my $j=0; $j < @{$rxnObjs}; $j++) {
#			my $rxnID = $rxnObjs->REACTION();
#			my $row = $results->get_row_by_key($rxnObjs->REACTION(),"Reactions",1);
#			if (!defined($row->{"# changed"}->[0])) {
#				$row->{"# changed"}->[0] = 0;
#				$row->{"# reactants up"}->[0] = 0;
#				$row->{"# reactants down"}->[0] = 0;
#				$row->{"# products up"}->[0] = 0;
#				$row->{"# products down"}->[0] = 0;
#				$row->{"Ecoli"}->[0] = 0;
#				for (my $k=0; $k < @{$models}; $k++) {
#					my $mdlRxnData = $self->figmodel()->get_model($models->[$k])->get_reaction_data($rxnID);
#					if (defined($mdlRxnData)) {
#						$row->{"Ecoli"}->[0]++;
#						$row->{$models->[$k]}->[0] = $mdlRxnData->{DIRECTIONALITY}->[0];
#					}
#				}
#			}
#		}
#	}
#	
#    my $mdl = $self->figmodel()->get_model($Data[1]);
#    my $cpdTbl = $mdl->compound_table();
#    my $rxnTbl = $mdl->reaction_table();
#    for (my $i=0; $i < @{$data}
#    
#    
#    
#    $cpdTbl->save($self->figmodel()->config("database message file directory")->[0]."Compounds-".$Data[1].".tbl");	
#}

sub reconciliation {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 3) {
		print "Syntax for this command: reconciliation?(Model ID)?(Gap fill)?(Stage).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    #Calling the combination function
    if (defined($Data[3]) && $Data[3] =~ m/COMBINE/ && $Data[1] =~ m/LIST-(.+)/) {
        my @TempArray = split(/:/,$Data[3]);
        my $List = FIGMODEL::LoadSingleColumnFile($1,"");
        my $Result = $self->figmodel()->CombineAllReconciliation($List,$Data[2],$TempArray[1],$TempArray[2],$TempArray[3],$TempArray[4]);
        if (defined($Result)) {
            $Result->save();
            return "SUCCESS";
        }
        return "FAIL";
    }

    if (!defined($Data[2])) {
        $Data[2] = 1;
    }

    $self->figmodel()->get_model($Data[1])->SolutionReconciliation($Data[2],$Data[3]);
}

sub integrategrowmatchsolution{
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 4) {
		print "Syntax for this command: integrategrowmatchsolution?(Model ID)?(GrowMatch solution file)?(NewModelFilename).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    #Loading GrowMatch solution file
    (my $Directory,my $ModelName) = $self->figmodel()->GetDirectoryForModel($Data[1]);
    if (!(-e $Directory.$Data[2])) {
        print "Could not find grow match solution file!\n";
        return;
    }
    my $ReactionArray;
    my $DirectionArray;
    my $SolutionData = FIGMODEL::LoadMultipleColumnFile($Directory.$Data[2],";");
    for (my $i=0; $i < @{$SolutionData}; $i++) {
        push(@{$ReactionArray},$SolutionData->[$i]->[0]);
        push(@{$DirectionArray},$SolutionData->[$i]->[1]);
    }

    #Creating the new model file
    my $Changes = $self->figmodel()->IntegrateGrowMatchSolution($Data[1],$Directory.$Data[3],$ReactionArray,$DirectionArray,"GROWMATCH",1,1);
    $self->figmodel()->PrintModelLPFile(substr($Data[3],0,length($Data[3])-4));
    if (defined($Changes)) {
        my @ChangeKeyList = keys(%{$Changes});
        for (my $i=0; $i < @ChangeKeyList; $i++) {
            print $ChangeKeyList[$i].";".$Changes->{$ChangeKeyList[$i]}."\n";
        }
    }
}

sub repairmodelfiles {
    my($self,@Data) = @_;

    my $Models = $self->figmodel()->GetListOfCurrentModels();

    for (my $i=0; $i < @{$Models}; $i++) {
        my $Model = $self->figmodel()->database()->GetDBModel($Models->[$i]->{"MODEL ID"}->[0]);
        FIGMODEL::SaveTable($Model);
    }
}

sub addcompoundstomedia {
    my($self,@Data) = @_;

    my @Filenames = glob($self->figmodel()->{"Media directory"}->[0]."*");
	for (my $i=0; $i < @Filenames; $i++) {
		if ($Filenames[$i] =~ m/\.txt/) {
			my $MediaTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($Filenames[$i],";","",0,["VarName"]);
            if (!defined($MediaTable->get_row_by_key("cpd00099","VarName"))) {
                $MediaTable->add_row({"VarName" => ["cpd00099"],"VarType" => ["DRAIN_FLUX"],"VarCompartment" => ["e"],"Min" => [-100],"Max" => [100]});
            }
            if (!defined($MediaTable->get_row_by_key("cpd00058","VarName"))) {
                $MediaTable->add_row({"VarName" => ["cpd00058"],"VarType" => ["DRAIN_FLUX"],"VarCompartment" => ["e"],"Min" => [-100],"Max" => [100]});
            }
            if (!defined($MediaTable->get_row_by_key("cpd00149","VarName"))) {
                $MediaTable->add_row({"VarName" => ["cpd00149"],"VarType" => ["DRAIN_FLUX"],"VarCompartment" => ["e"],"Min" => [-100],"Max" => [100]});
            }
            if (!defined($MediaTable->get_row_by_key("cpd00030","VarName"))) {
                $MediaTable->add_row({"VarName" => ["cpd00030"],"VarType" => ["DRAIN_FLUX"],"VarCompartment" => ["e"],"Min" => [-100],"Max" => [100]});
            }
            if (!defined($MediaTable->get_row_by_key("cpd00034","VarName"))) {
                $MediaTable->add_row({"VarName" => ["cpd00034"],"VarType" => ["DRAIN_FLUX"],"VarCompartment" => ["e"],"Min" => [-100],"Max" => [100]});
            }
            if (!defined($MediaTable->get_row_by_key("cpd10515","VarName"))) {
                $MediaTable->add_row({"VarName" => ["cpd10515"],"VarType" => ["DRAIN_FLUX"],"VarCompartment" => ["e"],"Min" => [-100],"Max" => [100]});
            }
            $MediaTable->save();
		}
	}
}

sub addbiologtransporters {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
		print "Syntax for this command: addbiologtransporters?(Model ID).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->AddBiologTransporters($Data[1]);
}

sub runblast {
	my($self,@Data) = @_;
    #Checking the argument to ensure all required parameters are present
    if (@Data < 3) {
		print "Syntax for this command: runblast?(search genome)?(query genome)?(query gene).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
	$self->figmodel()->run_blast_on_gene($Data[2],$Data[3],$Data[1]);
}

sub printgenomefeatures {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
		print "Syntax for this command: printgenomefeatures?(genome ID)?(filename)?(print sequences).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    #Setting the filename
    my $Filename = $self->figmodel()->{"database message file directory"}->[0]."Features-".$Data[1].".txt";
    if (defined($Data[2])) {
        $Filename = $Data[2];
    }

    #Getting the feature table
    my $FeaturesTable = $self->figmodel()->GetGenomeFeatureTable($Data[1],$Data[3]);
    #Printing the table
    $FeaturesTable->save($Filename);
}



sub parsebiolog {
    my($self,@Data) = @_;

    $self->figmodel()->ParseBiolog();
}

sub openwebpage {
    my($self,@Data) = @_;

    for (my $i=1; $i < 311; $i++) {
        my $url = "http://tubic.tju.edu.cn/deg/information.php?ac=DEG10140";
        if ($i < 10) {
            $url .= "00".$i;
        } elsif ($i < 100) {
            $url .= "0".$i;
        } else {
            $url .= $i;
        }
        my $pid = fork();
        if ($pid == 0) {
            my $Page = get $url;
            if (defined($Page) && $Page =~ m/(GI:\d\d\d\d\d\d\d\d)/) {
               print $1."\n";
            }
            exit 0;
        } else {
            sleep(5);
            if (kill(9,$pid) == 1) {
                $i--;
            }
        }

    }
}

sub testdatabasebiomass {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
		print "Syntax for this command: testdatabasebiomass?(Biomass reaction)?(Media)?(Balanced reactions only).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    my $Biomass = $Data[1];
    my $Media = "Complete";
    if (defined($Data[2])) {
        $Media = $Data[2];
    }
    my $BalancedReactionsOnly = 1;
    if (defined($Data[3])) {
        $BalancedReactionsOnly = $Data[3];
    }
    my $ProblemReportTable = $self->figmodel()->TestDatabaseBiomassProduction($Biomass,$Media,$BalancedReactionsOnly);

    if (!defined($ProblemReportTable)) {
        print "No problem report returned. An error occurred!\n";
        return;
    }

    if (defined($ProblemReportTable->get_row(0)) && defined($ProblemReportTable->get_row(0)->{"Objective"}->[0])) {
        if ($ProblemReportTable->get_row(0)->{"Objective"}->[0] == 10000000 || $ProblemReportTable->get_row(0)->{"Objective"}->[0] < 0.0000001) {
            print "No biomass was generated. Could not produce the following biomass precursors:\n";
            if (defined($ProblemReportTable->get_row(0)->{"Individual metabolites with zero production"})) {
                print join("\n",split(/\|/,$ProblemReportTable->get_row(0)->{"Individual metabolites with zero production"}->[0]))."\n";
			}
        } else {
            print "Biomass successfully generated with objective value of: ".$ProblemReportTable->get_row(0)->{"Objective"}->[0]."\n";
        }
    }
}

sub rollbackmodel {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
		print "Syntax for this command: rollbackmodel?(Model).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->RollBackModel($Data[1]);
}

sub getgapfillingstats {
    my($self,@Data) = @_;

    if (@Data < 2) {
		print "Syntax for this command: getgapfillingstats?(List filename).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
    my $List = FIGMODEL::LoadSingleColumnFile($Data[1],"");

    $self->figmodel()->GatherGapfillingStatistics(@{$List});
}

sub collectmolfiles {
    my($self,@Data) = @_;

    if (@Data < 3) {
		print "Syntax for this command: collectmolfiles?(List filename)?(Output directory).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
    my $List = FIGMODEL::LoadSingleColumnFile($Data[1],"");

    for (my $i=0; $i < @{$List}; $i++) {
        if (-e $self->figmodel()->{"Argonne molfile directory"}->[0]."pH7/".$List->[$i].".mol") {
            system("cp ".$self->figmodel()->{"Argonne molfile directory"}->[0]."pH7/".$List->[$i].".mol ".$Data[2].$List->[$i].".mol");
        } elsif (-e $self->figmodel()->{"Argonne molfile directory"}->[0].$List->[$i].".mol") {
            system("cp ".$self->figmodel()->{"Argonne molfile directory"}->[0].$List->[$i].".mol ".$Data[2].$List->[$i].".mol");
        }
    }
}

sub testmodelgrowth {
    my($self,@Data) = @_;

    if (@Data < 3) {
		print "Syntax for this command: testmodelgrowth?(Model ID)?(Media)?(Additional parameters)?(Flux file)?(Save LP file).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    my $List;
    if ($Data[1] =~ m/LIST-(.+)/) {
        $List = FIGMODEL::LoadSingleColumnFile($1,"");
    } elsif ($Data[1] eq "ALL") {
    	my $models = $self->figmodel()->get_models();
    	for (my $i=0; $i < @{$models}; $i++) {
    		push(@{$List},$models->[$i]->id());
		}
    } else {
        $List = [$Data[1]];
    }

	my $growthModels = [];
	my $noGrowthModels = [];
    for (my $i=0; $i < @{$List}; $i++) {
    	print "Testing ".$List->[$i].": ";
 		my $Version = "";
        my $Parameters;
		if (defined($Data[3])) {
			my @DataArray = split(/\|/,$Data[3]);
			foreach my $Item (@DataArray) {
				if ($Item =~ m/^V/) {
					$Version = $Item;
				} elsif ($Item =~ m/RKO:(.+)/) {
					$Parameters->{"Reactions to knockout"} = $1;
				} elsif ($Item =~ m/GKO:(.+)/) {
					$Parameters->{"Genes to knockout"} = $1;
				} elsif ($Item =~ m/OBJ:(.+)/) {
					$Parameters->{"objective"} = $1;
				} elsif ($Item =~ m/MetOptRxn:(.+)/) {
					$Parameters->{"metabolites to optimize"} = "REACTANTS;".$1;
				}
			}
		}
 		my $model = $self->figmodel()->get_model($List->[$i].$Version);
 		my $result = $model->calculate_growth($Data[2],$self->outputdirectory(),$Parameters,$Data[5]);
 		print $result."\n";
 		if ($result =~ m/NOGROWTH/) {
 			push(@{$noGrowthModels},$List->[$i].$Version);
 		} else {
 			push(@{$growthModels},$List->[$i].$Version);
 		}
    }
    
    print "\nGrowth models:".join(",",@{$growthModels})."\n\nNo growth models:".join(",",@{$noGrowthModels})."\n";
    return "SUCCESS";
}

sub buildmetagenomemodel {
    my($self,@Data) = @_;

    if (@Data < 2) {
		print "Syntax for this command: buildmetagenomemodel?(Metagenome name).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->CreateMetaGenomeReactionList($Data[1]);
}

sub buildbiomassreaction {
    my($self,@Data) = @_;

    if (@Data < 2) {
		print "Syntax for this command: buildbiomassreaction?(genome ID).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->BuildSpecificBiomassReaction($Data[1],undef);
}

sub updatestats {
    my($self,@Data) = @_;

    if (@Data < 2) {
		print "Syntax for this command: updatestats?(model ID).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
    my $List;
    if ($Data[1] =~ m/LIST-(.+)$/) {
        $List = FIGMODEL::LoadSingleColumnFile($1,"");
    } else {
        push(@{$List},$Data[1]);
    }
    for (my $i=0; $i < @{$List}; $i++) {
        my $model = $self->figmodel()->get_model($List->[$i]);
		if (defined($model)) {
			$model->update_model_stats();
		}
    }
    print "Model stats successfully updated.\n\n";
    return "SUCCESS";
}

sub addreactions {
     my($self,@Data) = @_;

    if (@Data < 2) {
		print "Syntax for this command: addreactions?(reaction IDs).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

	my $ReactionTable = $self->figmodel()->database()->LockDBTable("REACTIONS");
	my @IDArray = split(/,/,$Data[1]);
	for (my $i=0; $i < @IDArray; $i++) {
		my $object = $self->figmodel()->LoadObject($IDArray[$i]);
		if (defined($object) || defined($object->{"EQUATION"}->[0])) {
			(my $direction,my $code,my $reverseEquation,my $equation,my $newCompartment,my $error) = $self->figmodel()->ConvertEquationToCode($object->{"EQUATION"}->[0]);
			my $row = $ReactionTable->get_row_by_key($IDArray[$i],"DATABASE");
			if (!defined($row)) {
				$ReactionTable->add_row({"DATABASE"=>[$object->{"DATABASE"}->[0]],"NAME"=>$object->{NAME},"EQUATION"=>[$equation],"CODE"=>[$code],"MAIN EQUATION"=>[$equation],"REVERSIBILITY"=>$object->{"THERMODYNAMIC REVERSIBILITY"},"ARGONNEID"=>[$object->{"DATABASE"}->[0]]})
			} else {
				$row->{NAME} = $object->{NAME};
				$row->{EQUATION} = [$equation];
				$row->{CODE} = [$code];
				$row->{"MAIN EQUATION"} = [$equation];
				$row->{REVERSIBILITY} = $object->{"THERMODYNAMIC REVERSIBILITY"};
				$row->{ARGONNEID} = [$object->{"DATABASE"}->[0]];
			}
		}
	}
	if (defined($ReactionTable)) {
		$ReactionTable->save();
		$ReactionTable = $self->figmodel()->database()->UnlockDBTable("REACTIONS");
	}
    return "SUCCESS";
}

sub addcompounds {
     my($self,@Data) = @_;

    if (@Data < 2) {
		print "Syntax for this command: addcompounds?(compound IDs).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

	my $CompoundTable = $self->figmodel()->database()->LockDBTable("COMPOUNDS");
	my @IDArray = split(/,/,$Data[1]);
	for (my $i=0; $i < @IDArray; $i++) {
		if (!defined($CompoundTable->get_row_by_key($IDArray[$i],"DATABASE"))) {
			my $object = $self->figmodel()->LoadObject($IDArray[$i]);
			if ($object ne "0" && defined($object->{"NAME"})) {
				for (my $j=0; $j < @{$object->{"NAME"}}; $j++) {
					if (length($object->{"NAME"}->[$j]) > 0) {
						$object->{"NAME"}->[$j] =~ s/;/-/g;
						push(@{$object->{"SEARCHNAME"}},$self->figmodel()->ConvertToSearchNames($object->{"NAME"}->[$j]));
					}
				}
				$CompoundTable->add_row({"SEARCHNAME"=>$object->{"SEARCHNAME"},"STRINGCODE"=>$object->{"STRINGCODE"},"ARGONNEID"=>$object->{"DATABASE"},"DATABASE"=>$object->{"DATABASE"},"NAME"=>$object->{NAME},"FORMULA"=>$object->{FORMULA},"CHARGE"=>$object->{CHARGE}})
			}
		}
	}
	if (defined($CompoundTable)) {
		$CompoundTable->save();
		$CompoundTable = $self->figmodel()->database()->UnlockDBTable("COMPOUNDS");
	}
    return "SUCCESS";
}

sub checkbroadessentiality {
    my($self,@Data) = @_;

    if (@Data < 2) {
		print "Syntax for this command: checkbroadessentiality?(Model ID)?(Num processors)?(Filename).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    if (!defined($Data[2])) {
        $Data[2] = 50;
    }

    $self->figmodel()->CheckReactionEssentiality($Data[1],$Data[2],$Data[3]);
}

sub gathersbmlfiles {
    my($self) = @_;
    my $mdlObjs = $self->figmodel()->database()->get_objects("model",{public=>1});
    for (my $i=0; $i < @{$mdlObjs}; $i++) {
    	my $mdl = $self->figmodel()->get_model($mdlObjs->[$i]->id());
    	if (-e $mdl->directory().$mdlObjs->[$i]->id().".xml") {
    		system("cp ".$mdl->directory().$mdlObjs->[$i]->id().".xml /home/chenry/SBMLFiles/".$mdlObjs->[$i]->id().".xml");
    	}	
    }
}

sub gathermodelfiles {
    my($self,@Data) = @_;
    if (@Data < 3) {
		print "Syntax for this command: gathermodelfiles?(model list file)?(Output folder).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
 	my $list = $self->figmodel()->database()->load_single_column_file($Data[1]);
 	for (my $i=0; $i < @{$list}; $i++) {
 		my $mdl = $self->figmodel()->get_model($list->[$i]);
 		if (defined($mdl)) {
 			$mdl->PrintModelSimpleReactionTable();
 			system("cp ".$mdl->directory()."ReactionTbl-".$mdl->id().".txt ".$Data[2]."ReactionTbl-".$mdl->id().".txt");
 		}
 	}
}

sub printrxncpddb {
    my($self,@Data) = @_;
    if (@Data < 2) {
		print "Syntax for this command: printrxncpddb?(Output folder).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
 	$self->figmodel()->printReactionDBTable($Data[1]);
 	$self->figmodel()->printCompoundDBTable($Data[1]);
}

sub printaliases {
	my($self) = @_;
 	my $objs = $self->figmodel()->database()->get_objects("rxnals");
 	my $rxnHash;
 	my $typeHash;
 	for (my $i=0; $i < @{$objs}; $i++) {
 		push(@{$rxnHash->{$objs->[$i]->REACTION()}->{$objs->[$i]->type()}},$objs->[$i]->alias());
 		$typeHash->{$objs->[$i]->type()} = 1;
 	}
 	my @types = keys(%{$typeHash});
 	my $output = ["REACTION ID;".join(";",@types)];
 	my @rxnArray = sort(keys(%{$rxnHash}));
 	for (my $i=0; $i < @rxnArray; $i++) {
 		my $line = $rxnArray[$i];
 		for (my $j=0; $j < @types; $j++) {
 			$line .= ";";
 			if (defined($rxnHash->{$rxnArray[$i]}->{$types[$j]})) {
 				$line .= join("|",@{$rxnHash->{$rxnArray[$i]}->{$types[$j]}});
 			}
 		}
 		push(@{$output},$line);
 	}
 	$self->figmodel()->database()->print_array_to_file("/home/chenry/RxnAliases.txt",$output);
 	$objs = $self->figmodel()->database()->get_objects("cpdals");
 	my $cpdHash;
 	$typeHash = {};
 	for (my $i=0; $i < @{$objs}; $i++) {
 		push(@{$cpdHash->{$objs->[$i]->COMPOUND()}->{$objs->[$i]->type()}},$objs->[$i]->alias());
 		$typeHash->{$objs->[$i]->type()} = 1;
 	}
 	@types = keys(%{$typeHash});
 	$output = ["COMPOUND ID;".join(";",@types)];
 	my @cpdArray = sort(keys(%{$cpdHash}));
 	for (my $i=0; $i < @cpdArray; $i++) {
 		my $line = $cpdArray[$i];
 		for (my $j=0; $j < @types; $j++) {
 			$line .= ";";
 			if (defined($cpdHash->{$cpdArray[$i]}->{$types[$j]})) {
 				$line .= join("|",@{$cpdHash->{$cpdArray[$i]}->{$types[$j]}});
 			}
 		}
 		push(@{$output},$line);
 	}
 	$self->figmodel()->database()->print_array_to_file("/home/chenry/CpdAliases.txt",$output);
}

sub gathergrowmatchprogress {
    my($self,@Data) = @_;

    if (@Data < 3) {
		print "Syntax for this command: gathergrowmatchprogress?(model list file)?(Output folder).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    if (!-e $Data[1]) {
        return "LIST NOT FOUND";
    }
    my $List = ModelSEED::FIGMODEL::LoadSingleColumnFile($Data[1],"");

    my $Queue = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->figmodel()->{"Queue filename"}->[0],";","",0,undef);
    my $Running = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->figmodel()->{"Running job filename"}->[0],";","",0,undef);
    my $StatusTable = ModelSEED::FIGMODEL::FIGMODELTable->new(["Genome","Gap fill","GF testing","GF reconciliation","GF reconciliation testing","GF combination","GF model","GF reaction KO","Gap gen","GG testing","GG reconciliation","GG reconciliation testing","GG combination","GG model"],$Data[2]."Status.txt",undef,";","",undef);
    for (my $i=0; $i < @{$List}; $i++) {
        my $NewRow = {"Genome" => [$List->[$i]]};
        my ($Directory,$Dummy) = $self->figmodel()->GetDirectoryForModel($List->[$i]);
        my $FilenameArray = [$List->[$i]."-GFS.txt",$List->[$i]."-GFEM.txt",$List->[$i]."-GFReconciliation.txt",$List->[$i]."-GFSREM.txt","GapFillingSolution.txt",$List->[$i]."VGapFilled.txt",$List->[$i]."VGapFilled-ReactionKOResult.txt",$List->[$i]."VGapFilled-GGS.txt",$List->[$i]."VGapFilled-GGEM.txt",$List->[$i]."VGapFilled-GGReconciliation.txt",$List->[$i]."VGapFilled-GGSREM.txt","GapGenSolution.txt",$List->[$i]."VOptimized.txt"];
        my $CommandArray = ["datagapfill","testsolutions.+(GF\$|GF\?)","reconciliation.+1\$","testsolutions.+(GFSR\$|GFSR\?)","","integrategrowmatchsolution.+VGapFilled","checkbroadessentiality","rungapgeneration","testsolutions.+(GG\$|GG\?)","reconciliation.+0\$","testsolutions.+(GGSR\$|GGSR\?)","","integrategrowmatchsolution.+VOptimized"];
        my $KeyArray = ["Gap fill","GF testing","GF reconciliation","GF reconciliation testing","GF combination","GF model","GF reaction KO","Gap gen","GG testing","GG reconciliation","GG reconciliation testing","GG combination","GG model"];
        for (my $j=0; $j < @{$FilenameArray}; $j++) {
            #First checking if the job is queued or running
            my $ModelID = $List->[$i];
            my $Command = $CommandArray->[$j];
            if (length($Command) > 0) {
                for (my $k=0; $k < $Running->size(); $k++) {
                    my $Row = $Running->get_row($k);
                    if (defined($Row->{"COMMAND"}) && $Row->{"COMMAND"}->[0] =~ m/$ModelID/ && $Row->{"COMMAND"}->[0] =~ m/$Command/) {
                        $NewRow->{$KeyArray->[$j]} = ["Running"];
                    }
                }
                for (my $k=0; $k < $Queue->size(); $k++) {
                    my $Row = $Queue->get_row($k);
                    if (defined($Row->{"COMMAND"}) && $Row->{"COMMAND"}->[0] =~ m/$ModelID/ && $Row->{"COMMAND"}->[0] =~ m/$Command/) {
                        $NewRow->{$KeyArray->[$j]} = ["Queued"];
                    }
                }
            }
            #Next checking if the output file of the job exists
            if (!defined($NewRow->{$KeyArray->[$j]}) && -e $Directory.$FilenameArray->[$j]) {
                my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($Directory.$FilenameArray->[$j]);
                $NewRow->{$KeyArray->[$j]} = [FIGMODEL::Date($mtime)];
                if ($FilenameArray->[$j] =~ m/$ModelID/) {
                    system("cp ".$Directory.$FilenameArray->[$j]." ".$Data[2].$FilenameArray->[$j]);
                } else {
                    system("cp ".$Directory.$FilenameArray->[$j]." ".$Data[2].$List->[$i].$FilenameArray->[$j]);
                }
            } elsif (!defined($NewRow->{$KeyArray->[$j]}) && $FilenameArray->[$j] =~ m/VGapFilled/) {
                my $TempFilename = $FilenameArray->[$j];
                $TempFilename =~ s/VGapFilled//;
                if (-e $TempFilename) {
                    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($Directory.$TempFilename);
                    $NewRow->{$KeyArray->[$j]} = [FIGMODEL::Date($mtime)];
                    if ($TempFilename =~ m/$ModelID/) {
                        system("cp ".$Directory.$TempFilename." ".$Data[2].$TempFilename);
                    } else {
                        system("cp ".$Directory.$TempFilename." ".$Data[2].$List->[$i].$TempFilename);
                    }
                }
            } elsif (!defined($NewRow->{$KeyArray->[$j]})) {
                $NewRow->{$KeyArray->[$j]} = ["NA"];
            }
        }
        $StatusTable->add_row($NewRow);
    }

    $StatusTable->save();
}

sub deleteoldfiles {
    my($self,@Data) = @_;
    if (@Data < 3) {
		print "Syntax for this command: deleteoldfiles?(directory)?(max age).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    my @FileList = glob($Data[1]."*");
    for (my $i=0; $i < @FileList; $i++) {
        my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($FileList[$i]);
        if ((time() - $mtime) > 3600*$Data[2]) {
            if (-e $FileList[$i]) {
                unlink($FileList[$i]);
            } else {
                system("rm -rf ".$FileList[$i]);
            }
        }
    }
}

sub addstoichcorrection {
    my($self,@Data) = @_;
    if (@Data < 2) {
		print "Syntax for this command: addstoichcorrection?(change filename).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    my $List = FIGMODEL::LoadSingleColumnFile($Data[1],"");
    foreach my $Line (@{$List}) {
        my @Temp = split("\t",$Line);
        if (@Temp >= 2) {
            print $self->figmodel()->AddStoichiometryCorrection($Temp[0],$Temp[1]);
        }
    }

    return "SUCCESS";
}

sub printreactionroles {
    my($self,@Data) = @_;

    my $Reactions = $self->figmodel()->GetDBTable("REACTIONS");

    my $Table = ModelSEED::FIGMODEL::FIGMODELTable->new(["REACTION","EQUATION","ROLES","MODEL ROLES"],$self->outputdirectory()."ReactionRoles.txt",undef,"\t","|",undef);
    for (my $i=0; $i < $Reactions->size(); $i++) {
        my $Reaction = $Reactions->get_row($i)->{"DATABASE"}->[0];
        my $NewRow = {"REACTION" => [$Reaction]};
        my $Object = $self->figmodel()->LoadObject($Reaction);
        if ($Object ne "0" && defined($Object->{"DEFINITION"}->[0])) {
            $NewRow->{"EQUATION"}->[0] = $Object->{"DEFINITION"}->[0];
        }
        my $Data = $self->figmodel()->roles_of_reaction($Reaction);
        if (defined($Data)) {
           $NewRow->{"ROLES"} = $Data;
        }
        my @ModelRoles = $self->figmodel()->GetDBTable("ROLE MAPPING TABLE")->get_rows_by_key($Reaction,"REACTION");
        if (@ModelRoles > 0) {
            push(@{$NewRow->{"MODEL ROLES"}},@ModelRoles);
        }
        $Table->add_row($NewRow);
    }
    $Table->save();
}

sub rscript {
    my($self,@Data) = @_;

    if (@Data < 4) {
		print "Syntax for this command: rscript?(start)?(stop)?(script)?(size).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    my $ScriptFolder = "/home/chenry/RScripts/";
    my $Size = 100;
    if (defined($Data[4])) {
    	$Size = $Data[4];
    }
    my $Start = $Data[1];
    my $Stop = $Data[2];
    my $Script = $Data[3];
    my $Outputpath = $ScriptFolder."Output/".$Data[3]."/";

    #Making sure the script is there
    if (!-e $ScriptFolder.$Script) {
        print STDERR "Script not found:".$ScriptFolder.$Script."\n";
        return "FAIL";
    }

    #Scheduling the other sub jobs before performing the first job itself
    if ($Start eq "SCHEDULE") {
        if (!-d $Outputpath) {
            system("mkdir ".$Outputpath);
        }
        for (my $i=0; $i < int($Stop/$Size); $i++) {
            system($self->figmodel()->config("scheduler executable")->[0]." \"add:rscript?".($i*$Size)."?".($i*$Size+$Size)."?".$Script.":BACK:fast:chenry\"");
        }
        return "SUCCESS";
    } elsif ($Start eq "COMBINE") {
        my $CombinedOutput = ["Index\tAnswer"];
        for (my $k=0; $k < $Stop; $k++) {
            if (-e $Outputpath.$k.".txt") {
                my $Answer = "";
                my $Count = 0;
                my $Input = FIGMODEL::LoadSingleColumnFile($Outputpath.$k.".txt","");
                for (my $j=0; $j < @{$Input}; $j++) {
                    if ($Input->[$j] =~ m/^Answer:/) {
                        $Answer = $Input->[$j+1];
                        last;
                    } elsif ($Input->[$j] =~ m/^\sstable/) {
                       $Count++;
                    }
                }
                if (length($Answer) == 0) {
                    push(@{$CombinedOutput},$k."\tFAIL:".$Count);
                } else {
                    push(@{$CombinedOutput},$k."\t".$Answer);
                }
            }
        }
        FIGMODEL::PrintArrayToFile($ScriptFolder."Output".$Script,$CombinedOutput);
        return "SUCCESS";
    }

    for (my $i=$Start; $i < $Stop; $i++) {
        my $Input = FIGMODEL::LoadSingleColumnFile($ScriptFolder.$Script,"");
        my $NewFilename = $Outputpath.substr($Script,0,length($Script)-4).$i.".txt";
        for (my $j=0; $j < @{$Input}; $j++) {
            if ($Input->[$j] =~ m/seed\((\d+)\)/) {
                $Input->[$j] = "set.seed(".($1+2187*$i).")";
                last;
            }
        }

        FIGMODEL::PrintArrayToFile($NewFilename,$Input);
        my $outputFolder = "/scratch/";
        if (!-d $outputFolder) {
        	$outputFolder = $ScriptFolder."Output/";
        }
        if (!-d $outputFolder.$Script."/") {
	        system("mkdir ".$outputFolder.$Script."/");
        }
        system("/home/chenry/Software/R-2.9.0/bin/R --vanilla < ".$NewFilename." > ".$outputFolder.$Script."/".$i.".txt");
        if ($outputFolder eq "/scratch/") {
        	system("cp /scratch/".$Script."/".$i.".txt ".$Outputpath.$i.".txt");
        	system("rm -rf /scratch/".$Script."/".$i.".txt");
        }
    }
    return "SUCCESS";
}

sub movemodels {
    my($self,@Data) = @_;

    my @Filenames = glob($self->figmodel()->{"organism directory"}->[0]."*");
    for (my $i=0; $i < @Filenames; $i++) {
        system("rm -rf ".$Filenames[$i]."/Model");
    }
}

sub createdblp {
    my($self,@Data) = @_;
    if (defined($Data[1])) {
        $self->figmodel()->get_model($Data[1])->PrintModelLPFile();
    } else {
        $self->figmodel()->PrintDatabaseLPFiles();
    }
}

sub consolidatemedia {
    my($self,@Data) = @_;

    $self->figmodel()->database()->ConsolidateMediaFiles();
}

sub runmodelcheck {
    my($self,@Data) = @_;
    #/vol/rast-prod/jobs/(job number)/rp/(genome id)/
    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: runmodelcheck?(Organism ID).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    if ($Data[1] =~ m/LIST-(.+)$/) {
        my $List = FIGMODEL::LoadSingleColumnFile($1,"");
        $self->figmodel()->RunModelChecks($List);
        #for (my $i=0; $i < @{$List}; $i++) {
        #    print $List->[$i]."\n";
        #    $self->figmodel()->RunModelChecks($List->[$i]);
        #}
    } else {
        $self->figmodel()->RunModelChecks($Data[1]);
    }
}

sub runmfalite {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 3) {
        print "Syntax for this command: runmfalite?(Job file)?(Output file).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    system($self->figmodel()->{"mfalite executable"}->[0]." ".$self->figmodel()->{"Reaction database directory"}->[0]."masterfiles/MediaTable.txt ".$Data[1]." ".$Data[2]);
}

sub test {
    my($self,@Data) = @_;
	my $fbamodel = ModelSEED::FBAMODEL->new();
	$fbamodel->test();
}

sub addmapping {
    my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: addmapping?(filename).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    my $List = $self->figmodel()->database()->load_single_column_file($Data[1],"");
    my @mappingData = split(/\t/,$List->[0]);
    my $rxns;
    my $roles;
    my $types;
    push(@{$rxns},split(/\|/,$mappingData[0]));
    push(@{$roles},split(/\|/,$mappingData[1]));
    push(@{$types},split(/\|/,$mappingData[2]));
    $self->figmodel()->add_reaction_role_mapping($rxns,$roles,$types);
}

sub compilesimulations {
    my($self,@Data) = @_;

    if (@Data < 2) {
        print "Syntax for this command: compilesimulations?(genome list).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    my $List = $self->figmodel()->database()->load_single_column_file($Data[1],"");
    for (my $i=0; $i < @{$List}; $i++) {
        $self->figmodel()->CompileSimulationData($List->[$i]);
    }

    $self->figmodel()->{"CACHE"}->{"SimulationCompilationTable"}->save();
}

sub refreshkeggmapdata {
    my($self,@Data) = @_;

    $self->figmodel()->kegg_summary_data();
}

sub filteressentials {
    my($self,@Data) = @_;

    if (@Data < 3) {
        print "Syntax for this command: filteressentials?(essential list)?(list to be filtered).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    my $Essentials = FIGMODEL::LoadMultipleColumnFile($Data[1],",");
    my $ToFilter = FIGMODEL::LoadMultipleColumnFile($Data[2],",");
    my $Filtered;

    for (my $i=0; $i < @{$ToFilter}; $i++) {
        my $Set = $ToFilter->[$i];
        my $IsEssential = 0;
        for (my $j=0; $j < @{$Essentials}; $j++) {
            my $IsCurrentlyEssential = 1;
            for (my $k=0; $k < @{$Essentials->[$j]}; $k++) {
                my $IsFound = 0;
                for (my $m=0; $m < @{$Set}; $m++) {
                    if ($Set->[$m] eq $Essentials->[$j]->[$k]) {
                        $IsFound = 1;
                        last;
                    }
                }
                if ($IsFound == 0) {
                    $IsCurrentlyEssential = 0;
                    last;
                }
            }
            if ($IsCurrentlyEssential == 1) {
                $IsEssential = 1;
                last;
            }
        }
        if ($IsEssential == 0) {
            push(@{$Filtered},$Set);
        }
    }

    FIGMODEL::PrintTwoDimensionalArrayToFile($self->outputdirectory()."Filtered.txt",$Filtered,",");
}

sub testgapgensolution {
    my($self,@Data) = @_;

    if (@Data < 3) {
        print "Syntax for this command: testgapgensolution?(model)?(filename)?(Cumulative).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    if ($Data[1] =~ m/LIST-(.+)/) {
        my $List = FIGMODEL::LoadSingleColumnFile($1,"");
        for (my $i=0; $i < @{$List}; $i++) {
            $self->figmodel()->TestGapGenReconciledSolution($List->[$i],$Data[2],$Data[3]);
        }
    } else {
        $self->figmodel()->TestGapGenReconciledSolution($Data[1],$Data[2],$Data[3]);
    }

    if ($Data[2] eq "GG" || $Data[2] eq "GF") {
        $self->figmodel()->{$Data[2]." solution testing table"}->save();
    }
}

sub compilegrowmatch {
    my($self,@Data) = @_;

    if (@Data < 3) {
        print "Syntax for this command: compilegrowmatch?(gap fill list)?(gap gen list).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->get_growmatch_stats(FIGMODEL::LoadSingleColumnFile($Data[1],""),"GF");
    $self->figmodel()->get_growmatch_stats(FIGMODEL::LoadSingleColumnFile($Data[2],""),"GG");
}

sub CPLEXpatternsearch {
    my($self,@Data) = @_;

    shift(@Data);
    system("/home/devoid/kmers/bin/cplexpatternsearch.sh ".join(" ",@Data));
}

sub getgapfillcandidates {
    my($self,@Data) = @_;

    if (@Data < 2) {
        print "Syntax for this command: getgapfillcandidates?(model).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    #Model list
    my $ModelList;
    my $Success = "SUCCESS:";
    my $Fail = "FAIL:";
    if ($Data[1] eq "ALL") {
        my $ModelTable = $self->figmodel()->GetDBTable('MODEL LIST');
        for (my $i=0; $i < $ModelTable->size(); $i++) {
            push(@{$ModelList},$ModelTable->get_row($i)->{"MODEL ID"}->[0]);
        }
    } else {
        push(@{$ModelList},split(/;/,$Data[1]));
    }

    #Processing model list
    foreach my $Model (@{$ModelList}) {
        my $result = $self->figmodel()->find_genes_for_gapfill_reactions([$Model]);
        #Checking that the table is defined and the output file exists
        if (!defined($result)) {
            $Fail .= $Model.";";
        } else {
        	my $mdlObj = $self->figmodel()->get_model($Model);
            $result->save($mdlObj->directory()."GapFillCandidates.txt");
            $Success .= $Model.";";
        }
    }

    #Printing and returning run results
    print $Success.$Fail."\n";
    return $Success.$Fail;
}

sub findsimilargenomes {
    my($self,@Data) = @_;

    if (@Data < 2) {
        print "Syntax for this command: findsimilargenomes?(genome ID)?(Compare roles)?(Compare models).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->ranked_list_of_genomes($Data[1],$Data[2],$Data[3]);
}

sub importmodel {
    my($self,@Data) = @_;
    if (@Data < 2) {
        print "Syntax for this command: importmodel?(model name)?(genome id)?(source)?(owner).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	if (!defined($Data[2])) {
		$Data[2] = "NONE";
	}
	if (!defined($Data[3])) {
		$Data[3] = "PM00000000";
	}
	if (!defined($Data[4])) {
		$Data[4] = $self->figmodel()->user();
	}
	$self->figmodel()->import_modelfile($Data[1],{genome => [$Data[2]],source => [$Data[3]],overwrite => [1],owner => [$Data[4]]});

	return "SUCCESS";
}

sub rundefaultfba {
    my($self,@Data) = @_;

    if (@Data < 2) {
        print "Syntax for this command: rundefaultfba?(model name)?(media).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

	my $model = $self->figmodel()->get_model($Data[1]);
	$model->run_default_model_predictions($Data[2]);
	return "SUCCESS";
}

sub run_microarray_analysis {
    my($self,@Data) = @_;

    if (@Data < 6) {
        print "Syntax for this command: run_microarray_analysis?(model name)?(media)?(folder)?(index)?(gene call).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    
    #Getting the model
    my $model = $self->figmodel()->get_model($Data[1]);
	if (!defined($model)) {
		return "FAIL:".$Data[1]." model not found in database!";
	}
    
    #Processing the gene call file if it was a file
    if (defined($Data[5]) && -e $Data[5]) {
    	#Loading the gene calls
    	my $data = $self->figmodel()->database()->load_multiple_column_file($Data[5],"\t");
    	#Getting labels for gene calls
    	my $labels;
    	my $geneCalls;
    	for (my $i=1; $i < @{$data->[0]}; $i++) {
    		push(@{$labels},$data->[0]->[$i]);
    		$geneCalls->[$i-1] = $labels->[$i-1].";".($i-1);
    	}
    	#Setting gene coefficients
    	for (my $i=1; $i < @{$data}; $i++) {
    		#Determining gene for each row of calls
    		my $gene;
    		if ($data->[$i]->[0] =~ m/(peg\.\d+)/) {
    			$gene = $1;
    		}
    		for (my $j=1; $j < @{$data->[$i]}; $j++) {
    			if ($data->[$i]->[$j] < 0) {
    				$geneCalls->[$j-1] .= ";".$gene.":-1";
    			} elsif ($data->[$i]->[$j] > 0) {
    				$geneCalls->[$j-1] .= ";".$gene.":1";
    			}
    		}
    	}
    	#Running the MFAToolkit
    	my $output = ["Label;Media;Called on model on;Called on model off;Called grey model on;Called grey model off;Called off model on;Called off model off"];
    	for (my $i=0; $i < @{$labels}; $i++) {
    		my ($label,$media,$OnOn,$OnOff,$GreyOn,$GreyOff,$OffOn,$OffOff) = $model->run_microarray_analysis($Data[2],$labels->[$i],$i,$geneCalls->[$i]);
    		push(@{$output},$label.";".$media.";".$OnOn.";".$OnOff.";".$GreyOn.";".$GreyOff.";".$OffOn.";".$OffOff);
    	}
    	$self->figmodel()->database()->print_array_to_file($self->outputdirectory()."MicroarrayAnalysis-".$Data[1]."-".$Data[2].".txt",$output);
    	return "SUCCESS";
    }

	my ($label,$media,$activeGenes,$inactiveGenes,$nuetralGenes,$geneConflicts,$jobID,$index) = $model->run_microarray_analysis($Data[2],$Data[3],$Data[4],$Data[5]);
	return "SUCCESS";
}

sub find_minimal_pathways {
    my($self,@Data) = @_;

    if (@Data < 3) {
        print "Syntax for this command: find_minimal_pathways?(model name)?(objective)?(media)?(Solution number)?(All reversible)?(Additional exchanges).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

	my $model = $self->figmodel()->get_model($Data[1]);
	if (!defined($model)) {
		return "FAIL:".$Data[1]." model not found in database!";
	}
	if (defined($Data[6])) {
		my @array = split(/;/,$Data[6]);
		if ($Data[1] eq "iAF1260") {
			$Data[6] = "cpd03422[c]:-100:100;cpd01997[c]:-100:100;cpd11416[c]:-100:0;cpd15378[c]:-100:0;cpd15486[c]:-100:0";
		} else {
			$Data[6] = $self->figmodel()->config("default exchange fluxes")->[0];
		}
		for (my $i=0; $i <@array;$i++) {
			if ($array[$i] !~ m/\[\w\]/) {
				$array[$i] .= "[c]";
			}
			$Data[6] .= ";".$array[$i].":0:100";
		}
	}
	$model->find_minimal_pathways($Data[3],$Data[2],$Data[4],$Data[5],$Data[6]);

	return "SUCCESS";
}

sub find_minimal_pathways_two {
    my($self,@Data) = @_;

    if (@Data < 3) {
        print "Syntax for this command: find_minimal_pathways?(model name)?(objective)?(media)?(Solution number)?(All reversible)?(Additional exchanges).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

	my $model = $self->figmodel()->get_model($Data[1]);
	if (!defined($model)) {
		return "FAIL:".$Data[1]." model not found in database!";
	}
	if (defined($Data[6])) {
		my @array = split(/;/,$Data[6]);
		if ($Data[1] eq "iAF1260") {
			$Data[6] = "cpd03422[c]:-100:100;cpd01997[c]:-100:100;cpd11416[c]:-100:0;cpd15378[c]:-100:0;cpd15486[c]:-100:0";
		} else {
			$Data[6] = $self->figmodel()->config("default exchange fluxes")->[0];
		}
		for (my $i=0; $i <@array;$i++) {
			if ($array[$i] !~ m/\[\w\]/) {
				$array[$i] .= "[c]";
			}
			$Data[6] .= ";".$array[$i].":0:100";
		}
	}
	$model->find_minimal_pathways_two($Data[3],$Data[2],$Data[4],$Data[5],$Data[6]);

	return "SUCCESS";
}

sub adjustingdirection {
    my($self,@Data) = @_;

    if (@Data < 3) {
        print "Syntax for this command: adjustingdirection?(reaction)?(direction)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

	$self->figmodel()->AdjustReactionDirectionalityInDatabase($Data[1],$Data[2]);
	return "SUCCESS";
}

sub getsims {
    my($self,@Data) = @_;

    if (@Data < 2) {
        print "Syntax for this command: getsims?(gene ID)?(filter genome)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

	my @sim_results = $self->figmodel()->fig()->sims( $Data[1], 10000, 0.00001, "fig");
	my $genome = "->fig\\|".$Data[2];
	print "New peg\tPercent ID\tAlignment\tQuery length\tPeg length\tE-score\tFunction\n";
	for (my $i=0; $i < @sim_results; $i++) {
		if (!defined($Data[2]) || $sim_results[$i] =~ m/$genome/) {
			print $sim_results[$i]->[1]."\t".$sim_results[$i]->[2]."\t".$sim_results[$i]->[3]."\t".$sim_results[$i]->[11]."\t".$sim_results[$i]->[12]."\t".$sim_results[$i]->[10]."\t".$self->figmodel()->fig()->function_of($sim_results[$i]->[1])."\n";
		}
	}
	return "SUCCESS";
}

sub classifydbrxn {
    my($self,@Data) = @_;

    if (@Data < 2) {
        print "Syntax for this command: classifydbrxn?(biomass)?(media)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	if (!defined($Data[2])) {
		$Data[2] = "Complete";
	}
	my ($CompoundTB,$ReactionTB) = $self->figmodel()->classify_database_reactions($Data[2],$Data[1]);
	$ReactionTB->save($self->outputdirectory()."ReactionClasses.txt");
	$CompoundTB->save($self->outputdirectory()."CompoundClasses.txt");
	return "SUCCESS";
}

sub determinebiomassessentials {
    my($self,@Data) = @_;

    if (@Data < 2) {
        print "Syntax for this command: determinebiomassessentials?(biomass)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	$self->figmodel()->determine_biomass_essential_reactions($Data[1]);
	return "SUCCESS";
}

sub buildskeletonfiles {
    my($self,@Data) = @_;

    if (@Data < 3) {
        print "Syntax for this command: buildskeletonfiles?(directory)?(genome)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	$self->figmodel()->PrepSkeletonDirectory($Data[1],$Data[2]);
	return "SUCCESS";
}

sub collectmodelstats {
	my($self,@Data) = @_;

	my $ResultTable = ModelSEED::FIGMODEL::FIGMODELTable->new(["MODEL","TOTAL GENES","MODEL GENES","ESSENTIAL GENES","TOTAL REACTIONS","GAP FILLED REACTIONS","DEAD REACTIONS","ACTIVE REACTIONS","ESSENTIAL REACTIONS","TOTAL COMPOUNDS","DEAD COMPOUNDS","TRANSPORTABLE COMPOUNDS","ESSENTIAL NUTRIENTS"],$self->figmodel()->config("Reaction database directory")->[0]."MiscDataTables/ModelFBAStats.tbl",["MODEL"],";","|",undef);
    for (my $i=0; $i < $self->figmodel()->number_of_models(); $i++) {
		my $model = $self->figmodel()->get_model($i);
		if (defined($model->stats())) {
			my $NewRow = {"MODEL"=>[$model->id()],"MODEL GENES"=>[$model->stats()->{"Genes with reactions"}->[0]],"ESSENTIAL NUTRIENTS"=>[0],"TRANSPORTABLE COMPOUNDS"=>[0],"DEAD COMPOUNDS"=>[0],"ESSENTIAL REACTIONS"=>[0],"ACTIVE REACTIONS"=>[0],"DEAD REACTIONS"=>[0],"ESSENTIAL GENES"=>[0],"TOTAL GENES"=>[$model->stats()->{"Total genes"}->[0]],"TOTAL REACTIONS"=>[$model->stats()->{"Number of reactions"}->[0]],"GAP FILLED REACTIONS"=>[$model->stats()->{"Gap filling reactions"}->[0]],"TOTAL COMPOUNDS"=>[$model->stats()->{"Metabolites"}->[0]]};
			my $essentialgenes = $model->get_essential_genes("Complete");
			if (defined($essentialgenes)) {
				$NewRow->{"ESSENTIAL GENES"}->[0] = @{$essentialgenes};
			}
			my $reactionclasses = $model->reaction_class_table();
			if (defined($reactionclasses)) {
				for (my $i=0; $i < $reactionclasses->size();$i++) {
					my $row = $reactionclasses->get_row($i);
					if ($row->{MEDIA}->[0] =~ m/Complete/) {
						if ($row->{CLASS}->[0] eq "Dead" || $row->{CLASS}->[0] eq "Blocked") {
							$NewRow->{"DEAD REACTIONS"}->[0]++;
						} elsif ($row->{CLASS}->[0] =~ m/variable/i) {
							$NewRow->{"ACTIVE REACTIONS"}->[0]++;
						} elsif ($row->{CLASS}->[0] eq "Positive" || $row->{CLASS}->[0] eq "Negative") {
							$NewRow->{"ESSENTIAL REACTIONS"}->[0]++;
						}
					}
				}
			}
			my $compoundclasses = $model->compound_class_table();
			if (defined($compoundclasses)) {
				for (my $i=0; $i < $compoundclasses->size();$i++) {
					my $row = $compoundclasses->get_row($i);
					if ($row->{MEDIA}->[0] =~ m/Complete/) {
						if ($row->{COMPOUND}->[0] =~ m/e/) {
							$NewRow->{"TRANSPORTABLE COMPOUNDS"}->[0]++;
							if ($row->{CLASS}->[0] eq "Positive" || $row->{CLASS}->[0] eq "Negative") {
								$NewRow->{"ESSENTIAL NUTRIENTS"}->[0]++;
							}
						} elsif ($row->{CLASS}->[0] eq "Dead") {
							$NewRow->{"DEAD COMPOUNDS"}->[0]++;
						}
					}
				}
			}
			$ResultTable->add_row($NewRow);
		}
	}
	$ResultTable->save();

	return "SUCCESS";
}

sub runjosescript {
	my($self,@Data) = @_;

	if (@Data < 2) {
        print "Syntax for this command: runjosescript?(model ID)?(tb)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $directory = "/home/jplfaria/".$Data[1]."ConstraintStudies/";
	my $exe = "MFAToolkitScript".$Data[1].".pl";
	if (defined($Data[2]) && $Data[2] eq "tb") {
		$exe = "TightBoundsMFAToolkitScript".$Data[1].".pl";
	}
	system("perl ".$directory.$exe);

	return "SUCCESS";
}

sub patchmodels {
	my($self,@Data) = @_;
	shift(@Data);
	my $modelList = [@Data];
	$self->figmodel()->patch_models($modelList);
}

sub modelfunction {
	my($self,@Data) = @_;
	shift(@Data);
	my $function = shift(@Data);
	my $modelList = [@Data];
	$self->figmodel()->call_model_function($function,$modelList);
}

sub comparemodelgenes {
	my($self,@Data) = @_;

	if (@Data < 3) {
        print "Syntax for this command: comparemodelgenes?(model one)?(model two)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	$self->figmodel()->CompareModelGenes($Data[1],$Data[2]);
}

sub comparemodelreactions {
	my($self,@Data) = @_;

	if (@Data < 3) {
        print "Syntax for this command: comparemodelreactions?(model one)?(model two)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my ($CommonReactions,$EquivalentAReactions,$EquivalentBReactions,$ModelAReactions,$ModelBReactions) = $self->figmodel()->CompareModelReactions($Data[1],$Data[2]);
	my $output;
	push(@{$output},"Common reactions:".join(",",keys(%{$CommonReactions})));
	push(@{$output},$Data[1]." reactions:".join(",",keys(%{$ModelAReactions})));
	push(@{$output},$Data[2]." reactions:".join(",",keys(%{$ModelBReactions})));
	push(@{$output},$Data[1]." reactions:".join(",",keys(%{$EquivalentAReactions})));
	push(@{$output},$Data[2]." reactions:".join(",",keys(%{$EquivalentBReactions})));
	$self->figmodel()->database()->print_array_to_file($self->figmodel()->config("database message file directory")->[0].$Data[1]."-".$Data[2]."-ReactionComparison.tbl",$output);
}

sub searchgenomeforfeatures {
	my($self,@Data) = @_;
	
	if (@Data < 4) {
        print "Syntax for this command: searchgenomeforfeatures?(genome list file)?(feature list file)?(output filename)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    
    if (!-e $Data[1]) {
    	return "FAIL";
    }
    my $genomes = $self->figmodel()->database()->load_single_column_file($Data[1]);
    
    if (!-e $Data[2]) {
    	return "FAIL";
    }
    my $features = $self->figmodel()->database()->load_single_column_file($Data[2]);
    
    my $tbl = new ModelSEED::FIGMODEL::FIGMODELTable(["Feature","Genome","Gene","Alias","Role"],$Data[3],["Feature","Genome","Gene","Alias","Role"],"\t","|",undef);
	for (my $i=0; $i < @{$genomes}; $i++) {
		my $featuretbl = $self->figmodel()->GetGenomeFeatureTable($genomes->[$i]);
		for (my $j=0; $j < $featuretbl->size(); $j++) {
			my $row = $featuretbl->get_row($j);
			my $added = 0;
			for (my $k=0; $k < @{$row->{ROLES}}; $k++) {
				for (my $m=0; $m < @{$features}; $m++) {
					my $temp = $features->[$m];
					if ($row->{ROLES}->[$k] =~ m/$temp/i) {
						$tbl->add_row({"Feature"=>[$temp],"Genome"=>[$genomes->[$i]],"Gene"=>[$row->{ID}->[0]],"Alias"=>$row->{ALIASES},"Role"=>[$row->{ROLES}->[$k]]});
						$added = 1;
						last;
					}
				}
				if ($added == 1) {
					last;
				}
			}
		}
	}
	
	$tbl->save();
}

sub updatelinks {
	my($self,@Data) = @_;
	
	shift(@Data);
	my $entities;
	push(@{$entities},@Data);
	$self->figmodel()->database()->update_link_table($entities);
}

sub printroleclass {
	my($self,@Data) = @_;
	
	if (@Data < 2) {
        print "Syntax for this command: printroleclass?(role list filename)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    
    my $output;
	my $filename = $Data[1];
	my $roles = $self->figmodel()->database()->load_single_column_file($filename);
	for (my $i=0; $i < @{$roles}; $i++) {
		my $subsystems = $self->figmodel()->subsystems_of_role($roles->[$i]);
		my $temp = $roles->[$i];
		if (defined($subsystems)) {
			$temp .= "\t".join("|",@{$subsystems})."\t";
			my $newClass;
			for (my $j=0; $j < @{$subsystems};$j++) {
				if ($j > 0) {
					$temp .= "|";
					$newClass .= "|";
				}
				my $class = $self->figmodel()->class_of_subsystem($subsystems->[$j]);
				$newClass .= $class->[1];
				$temp .= $class->[0];
			}
			$temp .= "\t".$newClass;
		}
		push(@{$output},$temp);
	}
	$self->figmodel()->database()->print_array_to_file($self->figmodel()->config("database message file directory")->[0]."RoleClasses.txt",$output);
}

sub loadppo {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: loadppo?(object type)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	$self->figmodel()->database()->load_ppo($Data[1]);
}

sub loadbofrxn {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: loadbofrxn?(reaction ID)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	$self->figmodel()->database()->add_biomass_reaction_from_file($Data[1]);
}

sub joseFVARuns {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: joseFVARuns?(model)?(media)?(simple thermo)?(thermo)?(reversibility)?(Regulation)?(add to queue)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	if (defined($Data[7]) && $Data[7] == 1) {
		$self->figmodel()->add_job_to_queue({command => "joseFVARuns?".$Data[1]."?".$Data[2]."?".$Data[3]."?".$Data[4]."?".$Data[5]."?".$Data[6],queue => "fast"});
		return "SUCCESS";
	}
	my $ParameterValueHash = {"find tight bounds"=>1};
	my $UniqueFilename = $Data[1]."_".$Data[2];
	if ($Data[3] == 1) {
		$UniqueFilename .= "_SimpleThermo";
		$ParameterValueHash->{"Thermodynamic constraints"} = 1;
		$ParameterValueHash->{"simple thermo constraints"} = 1;
	} elsif ($Data[4] == 1) {
		$UniqueFilename .= "_Thermo";
		$ParameterValueHash->{"Thermodynamic constraints"} = 1;
		$ParameterValueHash->{"simple thermo constraints"} = 0;
		$ParameterValueHash->{"Account for error in delta G"} = 0;
		$ParameterValueHash->{"error multiplier"} = 4;
		$ParameterValueHash->{"Compounds excluded from potential constraints"} = "cpd02152;cpd02140;cpd02893;cpd00343;cpd02465;cpd00638";
	}
	if ($Data[5] == 0) {
		$UniqueFilename .= "_AllRevers";
		$ParameterValueHash->{"Make all reactions reversible in MFA"} = 1;
	}
	if ($Data[6] > 0) {
		$UniqueFilename .= "_Regulation";
		$ParameterValueHash->{"Make all reactions reversible in MFA"} = 1;
		$ParameterValueHash->{"Gene dictionary"} = "0";
        $ParameterValueHash->{"Add regulatory constraint to problem"} = "1";
		$ParameterValueHash->{"Base compound regulation on media files"} = "0";
        $ParameterValueHash->{"Regulatory constraint file"} = "/home/jplfaria/iJR904ConstraintStudies/EColiRegulation.txt";
        $ParameterValueHash->{"Regulation conditions"} = "/home/jplfaria/iJR904ConstraintStudies/EcoliConditionsRichMedia.txt";
		if ($Data[6] == 2) {
			$ParameterValueHash->{"Base compound regulation on media files"} = "1";
		}
	}
	system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$Data[1].".txt",$Data[2],["ProductionMFA"],$ParameterValueHash,"/home/chenry/".$UniqueFilename.".out"));
	return "SUCCESS";	
}

sub getbbh {
	my($self,@Data) = @_;
	if (@Data < 3) {
        print "Syntax for this command: getbbh?(filename with genome list)?(output directory)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    my $genomes = $self->figmodel()->database()->load_single_column_file($Data[1]);
    for (my $i=0; $i < @{$genomes}; $i++) {
    	my $results;
    	my @bbhs = FIGRules::BatchBBHs("fig|".$genomes->[$i].".peg.%", 0.00001, @{$genomes});
    	for (my $j=0; $j < @bbhs; $j++) {
    		if ($bbhs[$j][0] =~ m/fig\|(\d+\.\d+)\.(peg\.\d+)/) {
    			my $genome = $1;
    			my $peg = $2;
    			if ($bbhs[$j][1] =~ m/fig\|(\d+\.\d+)\.(peg\.\d+)/) {
    				my $mgenome = $1;
	    			my $mpeg = $2;
	    			if (defined($results->{$peg}->{$mgenome})) {
	    				$results->{$peg}->{$mgenome} .= "&".$mpeg.":".$bbhs[$j][2];
	    			} else {
	    				$results->{$peg}->{$mgenome} = $mpeg.":".$bbhs[$j][2];
	    			}
    			}
    		}
    	}
    	my @genes = sort(keys(%{$results}));
    	my $fileout = $Data[2].$genomes->[$i].".bbh";
    	open (OUTPUT, ">$fileout");
    	print OUTPUT "Reference Gene;".join(";",@{$genomes})."\n";
    	for (my $j=0; $j < @genes; $j++) {
    		print OUTPUT $genes[$j];
    		for (my $k=0; $k < @{$genomes}; $k++) {
    			print OUTPUT ";";	
    			if (defined($results->{$genes[$j]}->{$genomes->[$k]})) {
    				print OUTPUT $results->{$genes[$j]}->{$genomes->[$k]};
    			}
    		}
    		print OUTPUT "\n";
    	}
		close(OUTPUT);
    }
}

sub runfigmodelfunction {
	my($self,@Data) = @_;
	my $function = shift(@Data);
	$function = shift(@Data);
	$self->figmodel()->$function(@Data);
}

sub runcombinationko {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: runcombinationko?(model ID)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    if ($Data[1] eq "ALL") {
    	my @modelList = glob("/vol/model-dev/MODEL_DEV_DB/ReactionDB/tempmodels/*");
    	for (my $i=0; $i < @modelList; $i++) {
    		if ($modelList[$i] =~ m/([^\/]+)\.txt/) {
    			$self->figmodel()->add_job_to_queue({command => "runcombinationko?".$1,queue => "cplex"});
    		}
    	}
    	return "SUCCESS";
    } elsif ($Data[1] eq "GATHER") {
    	my @modelList = glob("/vol/model-dev/MODEL_DEV_DB/ReactionDB/tempmodels/*");
    	for (my $i=0; $i < @modelList; $i++) {
    		if ($modelList[$i] =~ m/([^\/]+)\.txt/) {
    			if (-e "/vol/model-dev/MODEL_DEV_DB/ReactionDB/MFAToolkitOutputFiles/ComboKO".$1."/MFAOutput/CombinationKO.txt") {
    				system("cp /vol/model-dev/MODEL_DEV_DB/ReactionDB/MFAToolkitOutputFiles/ComboKO".$1."/MFAOutput/CombinationKO.txt /home/chenry/ComboKOResults/".$1.".out");
    			}
    		}
    	}
    	return "SUCCESS";
    }
    system($self->figmodel()->GenerateMFAToolkitCommandLineCall("ComboKO".$Data[1],$Data[1].".txt","Complete",["ProductionMFA"],{"database"=>"Vitkup","uptake limits"=>"C:10","Combinatorial deletions"=>2},"ComboKO".$Data[1].".txt",undef,undef));
}	

sub parsecombineddbfiles {
	my($self,@Data) = @_;
	if (@Data < 3) {
        print "Syntax for this command: parsecombineddbfiles?(filename)?(model directory)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    #Parsing and printing compounds
    my $filedata = $self->figmodel()->database()->load_multiple_column_file($Data[1]."-compounds.txt","\t");
    for (my $i=1; $i < @{$filedata}; $i++) {
    	if (defined($filedata->[$i]->[3])) {
    		my $output = ["DATABASE\t".$filedata->[$i]->[0]];
    		$output->[1] = "NAME\t".$filedata->[$i]->[1];
    		$output->[1] =~ s/\|/\t/g;
    		$output->[2] = "FORMULA\t".$filedata->[$i]->[2];
    		$output->[3] = "CHARGE\t".$filedata->[$i]->[3];
    		$self->figmodel()->database()->print_array_to_file($self->figmodel()->directory()."ReactionDB/tempcompounds/".$filedata->[$i]->[0],$output);
    	}
    }
	#Parsing and printing reactions
	$filedata = $self->figmodel()->database()->load_multiple_column_file($Data[1]."-reactions.txt","\t");
    for (my $i=1; $i < @{$filedata}; $i++) {
    	if (defined($filedata->[$i]->[2])) {
    		my $output = ["DATABASE\t".$filedata->[$i]->[0]];
    		$output->[1] = "NAME\t".$filedata->[$i]->[1];
    		$output->[1] =~ s/\|/\t/g;
    		$output->[2] = "EQUATION\t".$filedata->[$i]->[2];
    		$self->figmodel()->database()->print_array_to_file($self->figmodel()->directory()."ReactionDB/tempreactions/".$filedata->[$i]->[0],$output);
    	}
    }
    #Adjusting the model files
    my @filenames = glob($Data[2]."*");
    for (my $i=0; $i < @filenames; $i++) {
    	my $data = $self->figmodel()->database()->load_single_column_file($filenames[$i]);
    	unshift(@{$data},"REACTIONS");
    	$data->[1] =~ s/DATABASE/LOAD/;
    	if ($filenames[$i] =~ m/ReactionTbl-(.+)/) {
    		$self->figmodel()->database()->print_array_to_file($self->figmodel()->directory()."ReactionDB/tempmodels/".$1,$data);
    	}    
    }
}

sub deletemodel {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: deletemodel?(model)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    my $mdl = $self->figmodel()->get_model($Data[1]);
    if (defined($mdl)) {
    	$mdl->delete();
    }
}

sub cleanup {
	my($self,@Data) = @_;
	$self->figmodel()->cleanup();
}

sub processpipeline {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: processpipeline?(model number)?(owner)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	$self->figmodel()->process_models($Data[1],$Data[2]);
}

sub maintenance {
	my($self,@Data) = @_;
	$self->figmodel()->daily_maintenance();
}

sub checkformappingchange {
	my($self,@Data) = @_;
	$self->figmodel()->mapping()->check_for_role_changes();
}

sub parcegenbankfile {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: parcegenbankfile?(filename)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $genbankData = $self->figmodel()->database()->load_single_column_file($Data[1],"");
	my $currentGene;
	my $geneArray;
	my $start;
	my $end;
	for (my $i=0; $i < @{$genbankData}; $i++) {
		my $type;
		my $id;
		if ($genbankData->[$i] =~ m/\/locus_tag="(.+)"/) {
			$type = "locus";
			$id = $1;
		} elsif ($genbankData->[$i] =~ m/\/gene="(.+)"/) {
			$type = "gene";
			$id = $1;
		} elsif ($genbankData->[$i] =~ m/\/db_xref="GI:(.+)"/) {
			$type = "GI";
			$id = $1;
		} elsif ($genbankData->[$i] =~ m/\/db_xref="GOA:(.+)"/) {
			$type = "GOA";
			$id = $1;
		} elsif ($genbankData->[$i] =~ m/\/db_xref="InterPro:(.+)"/) {
			$type = "InterPro";
			$id = $1;
		} elsif ($genbankData->[$i] =~ m/\/db_xref="SubtiList:(.+)"/) {
			$type = "SubtiList";
			$id = $1;
		} elsif ($genbankData->[$i] =~ m/\/db_xref="UniProtKB\/Swiss\-Prot:(.+)"/) {
			$type = "UniProt";
			$id = $1;
		} elsif ($genbankData->[$i] =~ m/\/product="(.+)"/) {
			$type = "Function";
			$id = $1;
		} elsif ($genbankData->[$i] =~ m/(\d+)\.\.(\d+)/) {
			$start = $1;
			$end = $2;
		}
		if (defined($type)) {
			if ($type eq "locus" || $type eq "gene") {
				if (defined($currentGene->{$type}) && $currentGene->{$type} ne $id) {
					push(@{$geneArray},$currentGene);
					$currentGene = {start=>$start,end=>$end};
				}
				if (!defined($currentGene->{start})) {
					$currentGene = {start=>$start,end=>$end};
				}
			}
			$currentGene->{$type} = $id;
		}	
	}
	my $output = ["Locus\tGene name\tGI\tGOA\tInterPro\tSubtiList\tUniProt\tFunction\tStart\tStop"];
	for (my $i=0; $i < @{$geneArray}; $i++) {
		my $newLine;
		$currentGene = $geneArray->[$i];
		if (defined($currentGene->{locus})) {
			$newLine .= $currentGene->{locus};
		}
		$newLine .= "\t";
		if (defined($currentGene->{gene})) {
			$newLine .= $currentGene->{gene};
		}
		$newLine .= "\t";
		if (defined($currentGene->{GI})) {
			$newLine .= $currentGene->{GI};
		}
		$newLine .= "\t";
		if (defined($currentGene->{GOA})) {
			$newLine .= $currentGene->{GOA};
		}
		$newLine .= "\t";
		if (defined($currentGene->{InterPro})) {
			$newLine .= $currentGene->{InterPro};
		}
		$newLine .= "\t";
		if (defined($currentGene->{SubtiList})) {
			$newLine .= $currentGene->{SubtiList};
		}
		$newLine .= "\t";
		if (defined($currentGene->{UniProt})) {
			$newLine .= $currentGene->{UniProt};
		}
		$newLine .= "\t";
		if (defined($currentGene->{Function})) {
			$newLine .= $currentGene->{Function};
		}
		$newLine .= "\t";
		if (defined($currentGene->{start})) {
			$newLine .= $currentGene->{start};
		}
		$newLine .= "\t";
		if (defined($currentGene->{end})) {
			$newLine .= $currentGene->{end};
		}
		push(@{$output},$newLine);
	}
	$self->figmodel()->database()->print_array_to_file("/home/chenry/GenbankGeneList.txt",$output);
	my $tbl = $self->figmodel()->GetGenomeFeatureTable("224308.1");
	$tbl->save("/home/chenry/Features.txt");
}

sub translatelocations {
	my($self,@Data) = @_;
	my $inputList = $self->figmodel()->database()->load_single_column_file("/home/chenry/input.txt","");
	my $input;
	my $origLoc;
	for (my $i=1; $i < @{$inputList}; $i++) {
		my @array = split(/\t/,$inputList->[$i]);
		if (defined($array[2])) {
			$origLoc->{$array[0]}->{start} = $array[1];
			$origLoc->{$array[0]}->{stop} = $array[2];
			$input->{$array[0]} = "224308.1:NC_000964_".$array[1]."+".($array[2]-$array[1]);
		}
	}
	my $sapObject = SAP->new();
	my $results = $sapObject->locs_to_dna({-locations => $input,-fasta=>1});
	my @ids = keys(%{$results});
	system "formatdb -i /home/chenry/bsub.fasta -p F";
	open( OUT, ">/home/chenry/output.txt") || die "could not open";
	for (my $i=0; $i < @ids; $i++) {
		print $i."\n";
		print OUT $ids[$i]."\t".$origLoc->{$ids[$i]}->{start}."\t".$origLoc->{$ids[$i]}->{stop}."\t";
		open( TMP, ">/home/chenry/temp.in") || die "could not open";
		print TMP  $results->{$ids[$i]};
		close(TMP);
		open(BLAST,"blastall -i /home/chenry/temp.in -d /home/chenry/bsub.fasta -p blastn -FF -e 1.0e-5 |")
				|| die "could not blast";
		my $db_seq_out = &gjoparseblast::next_blast_subject(\*BLAST,1);
		my $newStart = -1;
		my $newStop = -1;
		if (defined($db_seq_out->[6]->[0])) {
			for (my $k=0; $k < @{$db_seq_out->[6]}; $k++) {
				my $candidateStart = $db_seq_out->[6]->[$k]->[12]-$db_seq_out->[6]->[$k]->[9]+1;
				if (abs($newStart-$origLoc->{$ids[$i]}->{start}) > abs($candidateStart-$origLoc->{$ids[$i]}->{start})) {
					$newStart = $candidateStart;
					$newStop = $db_seq_out->[6]->[$k]->[13]+($db_seq_out->[2]-$db_seq_out->[6]->[$k]->[10])+1;
				}
			}
		}
		print OUT $newStart."\t".$newStop."\n";
	}
	close(OUT);
}

sub printconversiontables {
	my($self,@Data) = @_;
	my $inputList = $self->figmodel()->database()->load_single_column_file("/home/chenry/translations.txt","");
	my $sets;
	my $allheadings;
	my $setID;
	my @setHeadings;
	print "Reading input\n";
	for (my $i=0; $i < @{$inputList}; $i++) { 
		if ($inputList->[$i] =~ m/NEWSET:(.+)/) {
			$setID = $1;
			$i++;
			push(@{$allheadings->{$setID}},split(/\t/,$inputList->[$i]));
		} else {
			my @data = split(/\t/,$inputList->[$i]);
			my $newItem;
			for (my $j=0; $j < @data; $j++) {
				$newItem->{$allheadings->{$setID}->[$j]} = $data[$j];
			}
			push(@{$sets->{$setID}},$newItem);
		}
	}
	print "Comparing lists\n";
	my @setList = keys(%{$sets});
	for (my $i=0; $i < @setList; $i++) {
		print $i."\n";
		for (my $k=0; $k < @{$sets->{$setList[$i]}}; $k++) {
			if (defined($sets->{$setList[$i]}->[$k]->{start}) && defined($sets->{$setList[$i]}->[$k]->{stop})) {
				for (my $j=0; $j < @setList; $j++) {
					if ($i != $j) {
						for (my $m=0; $m < @{$sets->{$setList[$j]}}; $m++) {
							if (defined($sets->{$setList[$j]}->[$m]->{start}) && defined($sets->{$setList[$j]}->[$m]->{stop})) {
								if ($sets->{$setList[$j]}->[$m]->{start} <= $sets->{$setList[$i]}->[$k]->{stop} && $sets->{$setList[$j]}->[$m]->{stop} >= $sets->{$setList[$i]}->[$k]->{start}) {
									for (my $n=0; $n < @{$allheadings->{$setList[$j]}}; $n++) {
										if ($allheadings->{$setList[$j]}->[$n] ne "start" && $allheadings->{$setList[$j]}->[$n] ne "stop") {
											if (defined($sets->{$setList[$j]}->[$m]->{$allheadings->{$setList[$j]}->[$n]}) && length($sets->{$setList[$j]}->[$m]->{$allheadings->{$setList[$j]}->[$n]}) > 0) {
												if (defined($sets->{$setList[$i]}->[$k]->{$setList[$j]." ".$allheadings->{$setList[$j]}->[$n]})) {
													$sets->{$setList[$i]}->[$k]->{$setList[$j]." ".$allheadings->{$setList[$j]}->[$n]} .= "|".$sets->{$setList[$j]}->[$m]->{$allheadings->{$setList[$j]}->[$n]};
												} else {
													$sets->{$setList[$i]}->[$k]->{$setList[$j]." ".$allheadings->{$setList[$j]}->[$n]} = $sets->{$setList[$j]}->[$m]->{$allheadings->{$setList[$j]}->[$n]};	
												}
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
	print "Printing results\n";
	for (my $i=0; $i < @setList; $i++) {
		print $i."\n";
		open( OUT, ">/home/chenry/Sets".$setList[$i].".txt") || die "could not open";
		for (my $n=0; $n < @{$allheadings->{$setList[$i]}}; $n++) {
			print OUT $allheadings->{$setList[$i]}->[$n]."\t";
		}
		for (my $j=0; $j < @setList; $j++) {
			if ($i != $j) {
				for (my $n=0; $n < @{$allheadings->{$setList[$j]}}; $n++) {
					if ($allheadings->{$setList[$j]}->[$n] ne "start" && $allheadings->{$setList[$j]}->[$n] ne "stop") {
						print OUT $setList[$j]." ".$allheadings->{$setList[$j]}->[$n]."\t";
					}
				}
			}
		}
		print OUT "\n";
		for (my $k=0; $k < @{$sets->{$setList[$i]}}; $k++) {
			for (my $n=0; $n < @{$allheadings->{$setList[$i]}}; $n++) {
				if (defined($sets->{$setList[$i]}->[$k]->{$allheadings->{$setList[$i]}->[$n]})) {
					print OUT $sets->{$setList[$i]}->[$k]->{$allheadings->{$setList[$i]}->[$n]};
				}
				print OUT "\t";
			}
			for (my $j=0; $j < @setList; $j++) {
				if ($i != $j) {
					for (my $n=0; $n < @{$allheadings->{$setList[$j]}}; $n++) {
						if ($allheadings->{$setList[$j]}->[$n] ne "start" && $allheadings->{$setList[$j]}->[$n] ne "stop") {
							if (defined($sets->{$setList[$i]}->[$k]->{$setList[$j]." ".$allheadings->{$setList[$j]}->[$n]})) {
								print OUT $sets->{$setList[$i]}->[$k]->{$setList[$j]." ".$allheadings->{$setList[$j]}->[$n]};
							}
							print OUT "\t";
						}
					}
				}
			}
			print OUT "\n";
		}
		close(OUT);
	}
}

sub printstraingenes {
	my($self,@Data) = @_;
	my $intList = $self->figmodel()->database()->load_single_column_file("/home/chenry/IntervalData.txt","");
	my $strainList = $self->figmodel()->database()->load_single_column_file("/home/chenry/StrainData.txt","");
	my $headings;
	my $intervalData;
	push(@{$headings},split(/\t/,$intList->[0]));
	shift(@{$headings});
	for (my $i=1; $i < @{$intList}; $i++) {
		my @data = split(/\t/,$intList->[$i]);
		if (defined($data[0])) {
			for (my $j=0; $j < @{$headings}; $j++) {
				$intervalData->{$data[0]}->{$headings->[$j]} = $data[$j+1];
			}
		}
	}
	open( OUT, ">/home/chenry/StrainOutput.txt") || die "could not open";
	print OUT "Strain";
	for (my $k=0; $k < @{$headings}; $k++) {
		print OUT "\t".$headings->[$k];
	}
	print OUT "\n";
	for (my $i=1; $i < @{$strainList}; $i++) {
		my @data = split(/\t/,$strainList->[$i]);
		if (defined($data[1])) {
			my @intervals = split(/\|/,$data[1]);
			my $genes;
			for (my $j=0; $j < @intervals; $j++) {
				for (my $k=0; $k < @{$headings}; $k++) {
					if (defined($intervalData->{$intervals[$j]}->{$headings->[$k]})) {
						my @geneList = split(/\|/,$intervalData->{$intervals[$j]}->{$headings->[$k]});
						for (my $m=0; $m < @geneList; $m++) {
							$genes->{$headings->[$k]}->{$geneList[$m]} = 1;
						}
					}
				}	
			}
			print OUT $data[0];
			for (my $k=0; $k < @{$headings}; $k++) {
				print OUT "\t";
				if (defined($genes->{$headings->[$k]})) {
					print OUT join("|",keys(%{$genes->{$headings->[$k]}}));
				}
			}
			print OUT "\n";
		}
	}
	close(OUT);
}

sub setupgenecallstudy {
	my($self,@Data) = @_;
	if (@Data < 4) {
        print "Syntax for this command: setupGeneCallStudy?(model)?(media)?(call file)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $geneCalls;
	my $fileData = $self->figmodel()->database()->load_single_column_file($Data[3]);
	for (my $i=1; $i < @{$fileData}; $i++) {
		my @array = split(/\t/,$fileData->[$i]);
		if (@array >= 2) {
			$geneCalls->{$array[0]} = $array[1];
		}
	}
	my $fbaObj = ModelSEED::FIGMODEL::FIGMODELfba->new({figmodel => $self->figmodel(),model => $Data[1],media => $Data[2],parameter_files=>["ProductionMFA"]});
	$fbaObj->setGeneActivityAnalysis({geneCalls => $geneCalls});
	my $output = $fbaObj->queueFBAJob();
	print "Job ID:".$output->{jobid}."\n";
	return "SUCCESS";
}

sub runfba {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: runfba?(filename)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $fbaObj = ModelSEED::FIGMODEL::FIGMODELfba->new({figmodel => $self->figmodel()});
	my $result = $fbaObj->runProblemDirectory({filename => $Data[1]});
	if (defined($result->{error})) {
		return "FAILED:".$result->{error};	
	}
	return "SUCCESS";
}

sub updatecpdnames {
	my($self) = @_;
	$self->figmodel()->UpdateCompoundNamesInDB();
	return "SUCCESS";
}
