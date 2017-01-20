use strict;
use FIGMODEL;

package FIGMODELreaction;

=head1 FIGMODELreaction object
=head2 Introduction
Module for holding reaction related access functions
=head2 Core Object Methods

=head3 new
Definition:
	FIGMODELreaction = FIGMODELreaction->new({figmodel => FIGMODEL:parent figmodel object,id => string:reaction id});
Description:
	This is the constructor for the FIGMODELreaction object.
=cut
sub new {
	my ($class,$args) = @_;
	#Must manualy check for figmodel argument since figmodel is needed for automated checking
	if (!defined($args->{figmodel})) {
		print STDERR "FIGMODELreaction->new():figmodel must be defined to create an genome object!\n";
		return undef;
	}
	my $self = {_figmodel => $args->{figmodel}};
	bless $self;
	#Processing remaining arguments
	$args = $self->figmodel()->process_arguments($args,["figmodel","id"],{});
	if (defined($args->{error})) {
		$self->error_message("new:".$args->{error});
		return undef;	
	}
	$self->{_id} = $args->{id};
	$self->figmodel()->{_reactions}->{$self->id()} = $self;
	return $self;
}

=head3 error_message
Definition:
	string:message text = FIGMODELreaction->error_message(string::message);
Description:
=cut
sub error_message {
	my ($self,$message) = @_;
	return $self->figmodel()->error_message("FIGMODELreaction:".$self->id().":".$message);
}

=head3 figmodel
Definition:
	FIGMODEL = FIGMODELreaction->figmodel();
Description:
	Returns the figmodel object
=cut
sub figmodel {
	my ($self) = @_;
	return $self->{_figmodel};
}

=head3 id
Definition:
	string:reaction ID = FIGMODELreaction->id();
Description:
	Returns the reaction ID
=cut
sub id {
	my ($self) = @_;
	return $self->{_id};
}

=head3 ppo
Definition:
	PPOreaction:reaction object = FIGMODELreaction->ppo();
Description:
	Returns the reaction ppo object
=cut
sub ppo {
	my ($self,$inppo) = @_;
	if (defined($inppo)) {
		$self->{_ppo} = $inppo;
	}
	if (!defined($self->{_ppo})) {
		$self->{_ppo} = $self->figmodel()->database()->get_object("reaction",{id => $self->id()});
	}
	return $self->{_ppo};
}

=head3 file
Definition:
	{string:key => [string]:values} = FIGMODELreaction->file({clear => 0/1});
Description:
	Loads the reaction data from file
=cut
sub file {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{clear => 0});
	if ($args->{clear} == 1) {
		delete $self->{_file};
	}
	if (!defined($self->{_file})) {
		$self->{_file} = FIGMODELObject->new({filename=>$self->figmodel()->config("reaction directory")->[0].$self->id(),delimiter=>"\t",-load => 1});
		if (!defined($self->{_file})) {
			$self->error_message("file:could not load file");
		}
	} 
	return $self->{_file};
}

=head2 Functions involving interactions with MFAToolkit

=head3 updateReactionData
Definition:
	string:error = FIGMODELreaction->updateReactionData();
Description:
	This function uses the MFAToolkit to process the reaction and reaction data is updated accordingly
=cut
sub updateReactionData {
	my ($self) = @_;
	if (!defined($self->ppo())) {
		return $self->error_message("updateReactionData:could not find ppo object");
	}
	my $error = $self->processReactionWithMFAToolkit();#This is where the interaction with the MFAToolkit occurs
	if (defined($error)) {
		return $error;
	}
	my $data = $self->file({clear=>1});#Reloading the file data for the compound, which now has the updated data
	my $translations = {DELTAG => "deltaG",DELTAGERR => "deltaGErr","THERMODYNAMIC REVERSIBILITY" => "thermoReversibility",STATUS => "status",TRANSATOMS => "transportedAtoms"};#Translating MFAToolkit file headings into PPO headings
	foreach my $key (keys(%{$translations})) {#Loading file data into the PPO
		if (defined($data->{$key}->[0])) {
			my $function = $translations->{$key};
			$self->ppo()->$function($data->{$key}->[0]);
		}
	}
	if (defined($self->figmodel()->config("acceptable unbalanced reactions"))) {
		if ($self->ppo()->status() =~ m/OK/) {
			for (my $i=0; $i < @{$self->figmodel()->config("acceptable unbalanced reactions")}; $i++) {
				if ($self->figmodel()->config("acceptable unbalanced reactions")->[$i] eq $self->id()) {
					$self->ppo()->status("OK|".$self->ppo()->status());
					last;
				}	
			}
		}
		for (my $i=0; $i < @{$self->figmodel()->config("permanently knocked out reactions")}; $i++) {
			if ($self->figmodel()->config("permanently knocked out reactions")->[$i] eq $self->id() ) {
				if ($self->ppo()->status() =~ m/OK/) {
					$self->ppo()->status("BL");
				} else {
					$self->ppo()->status("BL|".$self->ppo()->status());
				}
				last;
			}	
		}
		for (my $i=0; $i < @{$self->figmodel()->config("spontaneous reactions")}; $i++) {
			if ($self->figmodel()->config("spontaneous reactions")->[$i] eq $self->id() ) {
				$self->ppo()->status("SP|".$self->ppo()->status());
				last;
			}
		}
		for (my $i=0; $i < @{$self->figmodel()->config("universal reactions")}; $i++) {
			if ($self->figmodel()->config("universal reactions")->[$i] eq $self->id() ) {
				$self->ppo()->status("UN|".$self->ppo()->status());
				last;
			}
		}
		if (defined($self->figmodel()->config("reversibility corrections")->{$self->id()})) {
			$self->ppo()->status("RC|".$self->ppo()->status());
		}
		if (defined($self->figmodel()->config("forward only reactions")->{$self->id()})) {
			$self->ppo()->status("FO|".$self->ppo()->status());
		}
		if (defined($self->figmodel()->config("reverse only reactions")->{$self->id()})) {
			$self->ppo()->status("RO|".$self->ppo()->status());
		}
	}
	return undef;
}

=head3 processReactionWithMFAToolkit
Definition:
	string:error message = FIGMODELreaction->processReactionWithMFAToolkit();
Description:
	This function uses the MFAToolkit to process the entire reaction database. This involves balancing reactions, calculating thermodynamic data, and parsing compound structure files for charge and formula.
	This function should be run when reactions are added or changed, or when structures are added or changed.
	The database should probably be backed up before running the function just in case something goes wrong.
=cut
sub processReactionWithMFAToolkit {
	my($self) = @_;
	#Backing up the old file
	system("cp ".$self->figmodel()->config("reaction directory")->[0].$self->id()." ".$self->figmodel()->config("database root directory")->[0]."ReactionDB/oldreactions/".$self->id());
	#Getting unique directory for output
	my $filename = $self->figmodel()->filename();
	#Eliminating the mfatoolkit errors from the compound and reaction files
	my $data = $self->file();
	$data->{EQUATION}->[0] = $self->ppo()->equation();
	$data->remove_heading("MFATOOLKIT ERRORS");
	$data->remove_heading("STATUS");
	$data->remove_heading("TRANSATOMS");
	$data->remove_heading("DBLINKS");
	$data->save();
	#Running the mfatoolkit
	system($self->figmodel()->GenerateMFAToolkitCommandLineCall($filename,"processdatabase","NONE",["ArgonneProcessing"],{"load compound structure" => 0,"Calculations:reactions:process list" => "LIST:".$self->id()},"DBProcessing-".$self->id()."-".$filename.".log"));
	#Copying in the new file
	if (-e $self->figmodel()->config("MFAToolkit output directory")->[0].$filename."/reactions/".$self->id()) {
		system("cp ".$self->figmodel()->config("MFAToolkit output directory")->[0].$filename."/reactions/".$self->id()." ".$self->figmodel()->config("reaction directory")->[0].$self->id());
	} else {
		return $self->error_message("processReactionWithMFAToolkit:could not find output reaction file");
	}
	$self->figmodel()->clearing_output($filename,"DBProcessing-".$self->id()."-".$filename.".log");
	return undef;
}

1;