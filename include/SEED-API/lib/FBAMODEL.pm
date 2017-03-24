#!/usr/bin/perl -w
use strict;

#
# Copyright (c) 2003-2006 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
#
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License.
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#
package ModelSEED::FBAMODEL;

    use strict;
    use ModelSEED::FIGMODEL;
	use Tracer;
    use SeedUtils;
    use ServerThing;
    use DBMaster;


=head1 FBA Model Function Object

This file contains the functions and utilities used by the FBAMODEL Server
(B<MODEL_server.cgi>). The L</Primary Methods> represent function
calls direct to the server. These all have a signature similar to the following.

    my $document = FBAMODEL->function_name($args);

where C<$MODELservObject> is an object created by this module, C<$args> is a parameter
structure, and C<function_name> is the FBAMODEL Server function name. The
output is a structure.

=head2 Special Methods

=head3 new

Definition:
	FBAMODEL::FBAMODEL object = FBAMODEL->new();

Description:
    Creates a new FBAMODEL function object. The function object is used to invoke the server functions.

=cut
sub new {
    my ($class) = @_;
    my $FBAMODELObject;
	$FBAMODELObject->{_figmodel} = ModelSEED::FIGMODEL->new();
	bless $FBAMODELObject, $class;
    return $FBAMODELObject;
}

=head3 figmodel

Definition:

	FIGMODEL::figmodel object = FBAMODEL->figmodel();

Description:

    Returns the FIGMODEL object required to get model data from the server

=cut
sub figmodel {
    my ($self) = @_;
	return $self->{_figmodel};
}

=head3 methods

Definition:

	FIGMODEL::figmodel object = FBAMODEL->methods();

Description:

    Returns a list of the methods for the class

=cut
sub methods {
    my ($self) = @_;
	if (!defined($self->{_methods})) {
		$self->{_methods} = ["get_reaction_id_list",
			"get_reaction_data",
			"get_biomass_reaction_data",
			"get_compound_id_list",
			"get_compound_data",
			"get_media_id_list",
			"get_media_data",
			"get_model_id_list",
			"get_model_data",
			"get_model_reaction_data",
			"classify_model_entities",
			"simulate_all_single_gene_knockout",
			"simulate_model_growth",
			"get_model_reaction_classification_table",
            "get_role_to_complex",
            "get_complex_to_reaction",
            "get_model_essentiality_data",
            "get_experimental_essentiality_data",
            "fba_calculate_minimal_media",
            "pegs_of_function",
            "rename_functional_role"];
	}
	return $self->{_methods};
}

=head3 configure_environment

Definition:

	FIGMODEL::figmodel object = FBAMODEL->configure_environment();

Description:

    Configures the environment of for the MFAToolkit

=cut
sub configure_environment {
    my ($self,$args) = @_;
	$ENV{'ILOG_LICENSE_FILE'} = '/home/chenry/Software/ilm/access.ilm';
	$ENV{'ARGONNEDB'} = '/vol/model-dev/MODEL_DEV_DB/ReactionDB/';
	return $args;
}

=head3 authenticate_user

Definition:

	FIGMODEL::figmodel object = FBAMODEL->authenticate_user( { user => string:username,password => string:password} );

Description:

    Determines if user data was input and points to a valid account

=cut
sub authenticate_user {
    my ($self,$args) = @_;
	if (defined($args->{user}) && defined($args->{password})) {
		$self->figmodel()->authenticate({username => $args->{user},password => $args->{password}});
	} elsif (defined($args->{cgi})) {
		$self->figmodel()->authenticate({cgi => $args->{cgi}});
	}
	return $args;
}

=head3 process_arguments

Definition:

	{key=>value} = FBAMODEL->process_arguments( {key=>value},[string:mandatory arguments] );

Description:

    Processes arguments to authenticate users and perform other needed tasks

=cut
sub process_arguments {
    my ($self,$args,$mandatoryArguments) = @_;
    if (defined($mandatoryArguments)) {
    	for (my $i=0; $i < @{$mandatoryArguments}; $i++) {
    		if (!defined($args->{$mandatoryArguments->[$i]})) {
				if (!defined($args->{error})) {
	    			$args->{error} = "Mandatory argument ".$mandatoryArguments->[$i]." not provided";
				} else {
					$args->{error} .= "; mandatory argument ".$mandatoryArguments->[$i]." not provided";
				}
    		}
    	}
    }
	return $self->authenticate_user($self->configure_environment($args));
}

=head3 error_message

Definition:

	{error=>error message} = FBAMODEL->error_message(string:error message);

Description:

    Returns the errors message when FBAMODEL functions fail

=cut
sub error_message {
    my ($self,$error) = @_;
    return {error=>$error};
}

=head2 Methods that access data from the database

=head3 get_reaction_id_list

Definition:

	{ string::model ids => [string::reaction ids] } = FBAMODEL->get_reaction_id_list( {"id" => [string::model id] } );

Description:

Takes as input a hash with key "id" pointing to a list of model IDs. If no
ids are input or if the id "ALL" is submitted, this function will return
a list of all reaction IDs in the database.  Returns a hash with the
model IDs as keys pointing to arrays of the reaction IDs in the models.

Example:

    my $ConfigHashRef = { "id" => ["Seed83333.1", "iJR904"] };
    my $resultsHashRef = $FBAModel->get_reaction_id_list($ConfigHashRef);
    $resultsHashRef == { "iJR904" => [ "rxn00001", "rxn00002", ...],
                         "Seed83333.1" => [ "rxn00003", "rxn00007", ...],
                       }

=cut
sub get_reaction_id_list {
	my ($self, $args) = @_;
	$args = $self->process_arguments($args);
	#List of IDs to be returned will be stored here
	my $ids;
	#First checking that the "id" key exists
	if (!defined($args->{id})) {
		$ids = ["ALL"];
	} else {
		#Checking if the hash contains a single ID instead of a reference to an array of IDs
		if (ref($args->{id}) ne "ARRAY") {
			push(@{$ids},$args->{id});
		} else {
			push(@{$ids},@{$args->{id}});
		}
	}
	#If IDs is ["ALL"], we return an array of all reaction objects
	my $output;
	for (my $i=0; $i < @{$ids}; $i++) {
		if ($ids->[$i] eq "ALL") {
			my $objects = $self->figmodel()->database()->get_objects("reaction");
			for (my $j=0; $j < @{$objects}; $j++) {
				push(@{$output->{$ids->[$i]}},$objects->[$j]->id());
			}
		} elsif (defined($self->figmodel()->get_model($ids->[$i]))) {
			my $tbl = $self->figmodel()->get_model($ids->[$i])->reaction_table();
			if (defined($tbl)) {
				for (my $j=0; $j < $tbl->size(); $j++) {
					push(@{$output->{$ids->[$i]}},$tbl->get_row($j)->{LOAD}->[0]);
				}
			}
		}
	}
	#Returning the output
	return $output;
}

=head3 get_reaction_data

Definition:

    { string::reaction ids => { string::keys => [ string::data ]
                                }
      } = FBAMODEL->get_reaction_data( { "id" => [string::reaction ids],
                                         "model" => [string::model ids]
                                     } );

Description:

Takes as input a a hash with key "id" pointing to a list of
reaction IDs and (optionally) the key "model" pointing to a list
of model ids.

Returns a hash with the input IDs as keys pointing to hashes with the
reaction data.  The keys in the reaction data hash are "DATABASE" pointing
to the reaction ID, "NAME" pointing to an array of reaction names,
"EQUATION" pointing to the reaction stoichiometry, "ENZYME" pointing
to an array of reaction EC numbers, "PATHWAY" pointing to an array of
the metabolic pathways the reaction is involved in, "REVERSIBILITY"
pointing to the predicted reversibility for the reaction, "DELTAG"
pointing to the predicted gibbs free energy change of the reaction,
"DELTAGERR" point to the uncertainty in the predicted free energy change,
and "KEGGID" pointing to the ID of the reaction in the KEGG database.

Example:

    my $configHashRef = { "id" => ["rxn00001","rxn00002"...],
                          "model" => ["iJR904","Seed83333.1"]
                        };
    my $resultHashRef = $FBAmodel->get_reaction_data($configHashRef);
    $resultHashRef == { "rxn00001" => { "DATABASE" => ["rxn00001"],
                                        "EQUATION" => ["A + B => C + D"],
                                        "Seed83333.1" => {"DIRECTIONALITY" => ["<="],
                                        "COMPARTMENT" => ["c"],
                                        "ASSOCIATED PEG" => ["peg.1+peg.2","peg.30"],
                                      },
                        "rxn00002" => ...,
                       }
 

=cut
sub get_reaction_data {
	my ($self, $args) = @_;
	$args = $self->process_arguments($args);
	#Getting all reactions from the database
	my $idHash;
	my $objects = $self->figmodel()->database()->get_objects("reaction");
	for (my $i=0; $i < @{$objects}; $i++) {
		$idHash->{$objects->[$i]->id()} = $objects->[$i];
	}
	#Checking id list
	my $ids;
	if (!defined($args->{id})) {
		$args->{id}->[0] = "ALL";
	} elsif (ref($args->{id}) ne "ARRAY") {
		push(@{$ids},$args->{id});
	} else {
		push(@{$ids},@{$args->{id}});
	}
	if ($args->{id}->[0] eq "ALL") {
		push(@{$ids},keys(%{$idHash}));
	}
	#Collecting reaction data for ID list
	my $output;
	for (my $i=0; $i < @{$ids}; $i++) {
		my $row;
		if ($ids->[$i] =~ m/rxn\d\d\d\d\d/ && defined($idHash->{$ids->[$i]})) {
			my $obj = $idHash->{$ids->[$i]};
			$row = {DATABASE => [$ids->[$i]],
					NAME => [$obj->name()],
					EQUATION => [$obj->equation()],
					CODE => [$obj->equation()],
					"MAIN EQUATION" => [$obj->equation()],
					REVERSIBILITY => [$obj->thermoReversibility()],
					DELTAG => [$obj->deltaG()],
					DELTAGERR => [$obj->deltaGErr()]};
			#Adding KEGG map data
			my $mapHash = $self->figmodel()->get_map_hash($args);
			if (defined($mapHash->{$ids->[$i]})) {
				foreach my $diagram (keys(%{$mapHash->{$ids->[$i]}})) {
					push(@{$row->{"PATHWAY"}},$mapHash->{$ids->[$i]}->{$diagram}->name());
					push(@{$row->{"KEGG MAPS"}},"map".$mapHash->{$ids->[$i]}->{$diagram}->altid());
				}
			}
			#Adding KEGG data
			my $keggobjs = $self->figmodel()->database()->get_objects("rxnals",{REACTION => $ids->[$i],type => "KEGG"});
			for (my $j=0; $j < @{$keggobjs}; $j++) {
				push(@{$row->{KEGGID}},$keggobjs->[$j]->alias());
			}
			if (defined($obj->enzyme()) && length($obj->enzyme()) > 0) {
				my $enzyme = substr($obj->enzyme(),1,length($obj->enzyme())-2);
				push(@{$row->{ENZYME}},split(/\|/,$enzyme));	
			}
		} elsif ($ids->[$i] =~ m/bio\d\d\d\d\d/) {
			my $obj = $self->figmodel()->database()->get_object("bof",{id=>$ids->[$i]});
			$row = {DATABASE => [$ids->[$i]],
					NAME => ["Biomass"],
					EQUATION => [$obj->equation()],
					CODE => [$obj->equation()],
					"MAIN EQUATION" => [$obj->equation()],
					PATHWAY => ["Macromolecule biosynthesis"],
					REVERSIBILITY => ["=>"]};
		}
		if (defined($row)) {
			$output->{$ids->[$i]} = $row;
			if (defined($args->{model})) {
				for (my $j=0; $j < @{$args->{model}}; $j++) {
					my $model = $self->figmodel()->get_model($args->{model}->[$j]);
					if (defined($model)) {
						my $data = $model->get_reaction_data($ids->[$i]);
						if (defined($data)) {
							$output->{$ids->[$i]}->{$args->{model}->[$j]} = $data;
						}
					}
				}
			}
		}
	}
	return $output;
}

=head3 get_biomass_reaction_data

Definition:

    {string:model id => { string::keys => [ string::data ]} }
     = FBAMODEL->get_reaction_data({"model" => [string::model ids]});

Description:

Takes as input a list of model IDs for which biomass reaction data will be
returned.

Returns a hash with the input IDs as keys pointing to hashes with the
reaction data.  The keys in the reaction data hash are "DATABASE" pointing
to the reaction ID, "NAME" pointing to an array of reaction names,
"EQUATION" pointing to the reaction stoichiometry, "ENZYME" pointing
to an array of reaction EC numbers, "PATHWAY" pointing to an array of
the metabolic pathways the reaction is involved in, "REVERSIBILITY"
pointing to the predicted reversibility for the reaction, "DELTAG"
pointing to the predicted gibbs free energy change of the reaction,
"DELTAGERR" point to the uncertainty in the predicted free energy change,
and "KEGGID" pointing to the ID of the reaction in the KEGG database.

Example:

    my $input = { "model" => ["iJR904","Seed83333.1"]};
    my $result = $FBAmodel->get_reaction_data($configHashRef);

=cut

sub get_biomass_reaction_data {
	my ($self, $args) = @_;
	$args = $self->process_arguments($args);
	if (!defined($args->{model})) {
		return {error=>["No model ID provided"]};	
	}
	my $result;
	for (my $i=0; $i < @{$args->{model}}; $i++) {
		my $mdlObj = $self->figmodel()->database()->get_object("model",{id=>$args->{model}->[$i]});
		if (defined($mdlObj)) {
			my $biomass = $mdlObj->biomassReaction();
			my $bioObj = $self->figmodel()->database()->get_object("bof",{id=>$biomass});
			if (defined($bioObj)) {
				$result->{$args->{model}->[$i]} = {"DATABASE" => [$biomass],
	                                        	  "EQUATION" => [$bioObj->equation()],
	                                        	  "cofactorPkg" => [$bioObj->cofactorPackage()],
	                                        	  "lipidPkg" => [$bioObj->lipidPackage()],
	                                        	  "cellWallPkg" => [$bioObj->cellWallPackage()],
	                                        	  "unknownPkg" => [$bioObj->unknownPackage()],
	                                        	  "energy" => [$bioObj->energy()],
	                                        	  "protein" => [$bioObj->protein()],
	                                        	  "DNA" => [$bioObj->DNA()],
	                                        	  "RNA" => [$bioObj->RNA()],
	                                        	  "lipid" => [$bioObj->lipid()],
	                                        	  "cellWall" => [$bioObj->cellWall()],
	                                        	  "cofactor" => [$bioObj->cofactor()],
	                                        	  $args->{model}->[$i] => {"DIRECTIONALITY" => ["=>"],
	                                        					  "COMPARTMENT" => ["c"],
	                                        					  "ASSOCIATED PEG" => ["BOF"]}}
			} else {
				push(@{$result->{error}},"Biomass reaction ".$biomass." for model ".$args->{model}->[$i]." not found in database");
			}
		} else {
			push(@{$result->{error}},$args->{model}->[$i]." either nonexistant or nonaccessible");
		}
	}
	return $result;
}

=head3 get_compound_id_list

Definition:

	{ string::model id => [string::compound ids] } = FBAMODEL->get_compound_id_list({"id" => [string::model id]});

Description:

Takes as input a hash with the key "id" pointing to a list of model IDs.
If no ids are input or if the id "ALL" is submitted, this function will
return a list of all compound IDs in the database.

Returns a hash with the input IDs as keys pointing to
arrays of the compound IDs in the models.

Example:
    
    my $configHashRef = { "id" => ["Seed83333.1", "iJR904"] };
    my $retValHashRef = $FBAModel->get_compound_id_list($configHashRef);
    
    $retValHashRef == { "iJR904" => ["cpd00001", "cpd00002", ...],
                        "Seed83333.1" => ["cpd00003", "cpd00007"],
                      }

=cut
sub get_compound_id_list {
	my ($self, $args) = @_;
	$args = $self->process_arguments($args);
	#List of IDs to be returned will be stored here
	my $ids;
	#First checking that the "id" key exists
	if (!defined($args->{id})) {
		$ids = ["ALL"];
	} else {
		#Checking if the hash contains a single ID instead of a reference to an array of IDs
		if (ref($args->{id}) ne "ARRAY") {
			push(@{$ids},$args->{id});
		} else {
			push(@{$ids},@{$args->{id}});
		}
	}
	#If IDs is ["ALL"], we return an array of all reaction objects
	my $output;
	for (my $i=0; $i < @{$ids}; $i++) {
		if ($ids->[$i] eq "ALL") {
			my $objects = $self->figmodel()->database()->get_objects("compound");
			for (my $j=0; $j < @{$objects}; $j++) {
				push(@{$output->{$ids->[$i]}},$objects->[$j]->id());
			}
		} elsif (defined($self->figmodel()->get_model($ids->[$i]))) {
			my $tbl = $self->figmodel()->get_model($ids->[$i])->compound_table();
			if (defined($tbl)) {
				for (my $j=0; $j < $tbl->size(); $j++) {
					push(@{$output->{$ids->[$i]}},$tbl->get_row($j)->{DATABASE}->[0]);
				}
			}
		}
	}
	#Returning the output
	return $output;
}

=head3 get_compound_data

Definition:

	{ string::compound ids => { string::keys => [ string::data ],
                              }
    } = FBAMODEL->get_compound_data( { "id" => [string::compound ids],
                                       "model" => [string::model ids]
                                   } );

Description:

Takes as input a hash with the key "id" pointing to a list of
compound IDs and (optionally) the key "model" pointing to a
list of model ids.

Returns a hash with the input IDs as keys pointing a hash with the
compound data. The keys in the compound data hash are "DATABASE" pointing
to the ID of the compound in the database, "NAME" pointing to an array of
names for the compound, "FORMULA" pointing to the molecular formula of
the compound at pH7, "CHARGE" pointing to the charge of the compound at
pH7, "STRINGCODE" pointing to a unique string that encodes the compound
structure, and "KEGGID" pointing to an array of KEGG ID for the compound.

Example:

    my $configHashRef = { "id" => ["rxn00001", "rxn00002", ...],
                          "model" => ["iJR904", "Seeed83333.1", ...]
                        };
    my $retValHashRef = $FBAModel->get_compound_data($configHashRef);
    
    $retValHashRef == { "rxn00001" => { "DATABASE" => ["rxn00001"],
                                        "EQUATION" => ["A + B => C + D"],
                                        "Seed83333.1" => {
                                            "DIRECTIONALITY" => ["<="],
                                            "COMPARTMENT" => ["c"],
                                            "ASSOCIATED PEG" => ["peg.1+peg.2","peg.30"],
                                        }
                                      }
                      }

=cut
sub get_compound_data {
	my ($self, $args) = @_;
	$args = $self->process_arguments($args);
	#Getting the FIGMODELTable with all compounds
    my $FullTable = $self->figmodel()->database()->GetDBTable("COMPOUNDS");
	#Checking that the compound table is defined
	if (!defined($FullTable)) {
		return undef;
	}
	#List of IDs to be returned will be stored here
	my $ids;
	#First checking that the "id" key exists
	if (!defined($args->{id}) || $args->{id}->[0] eq "ALL") {
		for (my $i=0; $i < $FullTable->size(); $i++) {
			push(@{$ids},$FullTable->get_row($i)->{DATABASE}->[0]);
		}
	} else {
		#Checking if the hash contains a single ID instead of a reference to an array of IDs
		if (ref($args->{id}) ne "ARRAY") {
			push(@{$ids},$args->{id});
		} else {
			push(@{$ids},@{$args->{id}});
		}
	}
	#Collecting reaction data for ID list
	my $output;
	for (my $i=0; $i < @{$ids}; $i++) {
		my $row = $FullTable->get_row_by_key($ids->[$i],"DATABASE");
		if (defined($row)) {
			$output->{$ids->[$i]} = $row;
			if (defined($args->{model})) {
				for (my $j=0; $j < @{$args->{model}}; $j++) {
					my $model = $self->figmodel()->get_model($args->{model}->[$j]);
					if (defined($model)) {
						my $data = $model->get_compound_data($ids->[$i]);
						if (defined($data)) {
							$output->{$ids->[$i]}->{$args->{model}->[$j]} = $data;
						}
					}
				}
			}
		}
	}
	return $output;
}

=head3 get_media_id_list

Definition:
	[string::media ids] = FBAMODEL->get_media_id_list();

Description:

	Takes no input. Returns an array reference of the IDs for all media
	formulations stored in the SEED biochemistry database.	These are
	the only media formulations on which flux balance analysis may
	be performed.

Example:

    my $media = $FBAModel->get_media_id_list();
    @$media == [ "ArgonneLBMedia", "Carbon-D-Glucose", ...];

=cut
sub get_media_id_list {
	my ($self, $args) = @_;
	$args = $self->process_arguments($args);
	my $output;
	my $FullTable = $self->figmodel()->database()->GetDBTable("MEDIA");
	if (!defined($FullTable)) {
		return undef;
	}
	for (my $i=0; $i < $FullTable->size(); $i++) {
		push(@{$output},$FullTable->get_row($i)->{NAME}->[0]);
	}
	return $output;
}

=head3 get_media_data

Definition:

	{ string::media ids => { string::key => [string::data] } } = FBAMODEL->get_media_data({"id" => [string::media ids] });

Description:

	Takes as input a hash with the key "id" pointing to an array of
	media ids. Returns a hash with the media ids pointing to a hash
	containing the media data.

Example:

    my $media = ["Carbon-D-Glucose", "ArgonneLBMedia"];
    my $retValHashRef = $FBAModel->get_media_data($media);
    $retValHashRef == { "Carbon-D-Glucose" => { "Compounds" => [ "cpd00001", "cpd00002", ...],
                                                "Compartments" => ["e", "e", ...],
                                                "Max"       => [ 100, 100, ...],
                                                "Min"       => [ -100, -100, ...],
                                              },
                         "ArgonneLBMedia" => { ... },
                       }  

=cut
sub get_media_data {
	my ($self, $args) = @_;
	$args = $self->process_arguments($args);
	#TODO
	#Getting the FIGMODELTable with all compounds
    my $FullTable = $self->figmodel()->database()->get_table("MEDIA");
	#Checking that the compound table is defined
	if (!defined($FullTable)) {
		return undef;
	}
	#List of IDs to be returned will be stored here
	my $ids;
	#First checking that the "id" key exists
	if (!defined($args->{id}) || $args->{id}->[0] eq "ALL") {
		for (my $i=0; $i < $FullTable->size(); $i++) {
			push(@{$ids},$FullTable->get_row($i)->{NAME}->[0]);
		}
	} else {
		#Checking if the hash contains a single ID instead of a reference to an array of IDs
		if (ref($args->{id}) ne "ARRAY") {
			push(@{$ids},$args->{id});
		} else {
			push(@{$ids},@{$args->{id}});
		}
	}
	#Collecting reaction data for ID list
	my $output;
	for (my $i=0; $i < @{$ids}; $i++) {
		my $row = $FullTable->get_row_by_key($ids->[$i],"NAME");
		if (defined($row)) {
			$output->{$ids->[$i]} = $row;
		}
	}
	return $output;
}

=head3 get_model_id_list

Definition:

	[string::model ids] = FBAMODEL->get_model_id_list( {"user" => string, "password" => string} );

Description:
	Takes as input a hash with the key "user" pointing to the
	username of a RAST account and the key "password" pointing
	to the password from the same RAST account. 

    Returns an array containing the names of all models owned by the user.
    If no input is provided, the function returns an array containing
    the names of all public models.

=cut
sub get_model_id_list {
	my ($self, $args) = @_;
	$args = $self->process_arguments($args);
	my $output;
	my $objs = $self->figmodel()->database()->get_objects("model");
	for (my $i=0; $i < @{$objs}; $i++) {
		push(@{$output},$objs->[$i]->id());
	}
	return $output;
}

=head3 get_model_data

Definition:

	{ string::model ids => { string::key => [string::data] } } 
        = FBAMODEL->get_model_data( { "id"   => [string::model ids],
                                      "user" => string,
                                      "password" => string,
                                  } );

Description:

Takes as input a hash with the key "id" pointing to an array of model
ids and the optional key "user" pointing to a RAST account along with
the key "password" pointing to the password for the RAST account,

Returns a hash with the model ids as keys pointing to a hash containing
the model data. User ID and password must be provided to access data
for private models.

Example:

    my $inputHashRef = { "id" => ["Seed83333.1", "iJR904"],
                         "user" => "Alice",
                         "password" => "eval",
                       };
    my $retValHashRef = $FBAModel->get_model_data($inputHashRef);
    
    $retValHashRef == { "Seed83333.1" => { "Genome" => "83333.1",
                                           "Name" => "E. coli",
                                           "Source" => "SEED"...},
                        ...}

=cut

sub get_model_data {
	my ($self, $args) = @_;
	$args = $self->process_arguments($args);
	#Checking that at least one id was input
	if (!defined($args->{id})) {
		return undef;
	}
	#Getting the id list
	my $ids;
	if (ref($args->{id}) ne "ARRAY") {
		$ids = [$args->{id}];
	} else {
		$ids = $args->{id};
	}
	#Cycling through IDs and storing model data
	my $output;
	for (my $i=0; $i < @{$ids}; $i++) {
		#Getting the model object
		my $modelobj = $self->figmodel()->get_model($ids->[$i]);
		if (defined($modelobj)) {
			$output->{$ids->[$i]} = {Genome => "ID:".$modelobj->genome(),Name => $modelobj->name(),Source => $modelobj->source()};
		}
	}
	return $output;
}

=head3 get_model_reaction_data

Definition:

	$output = FBAMODEL->get_model_reaction_data($input);
	
	$input = {	id => string:model ID,			ID of model to be accessed. Mandatory argument.
				user => string:username,		RAST username. Mandatory only for private models.
				password => string:password,	RAST password. Mandatory only for private models.
				-abbrev_eq => 0/1,				"1" requests printing of equations with abbreviations. Optional with default of "0".
				-name_eq => 0/1,					"1" requests printing of equations with abbreviations. Optional with default of "0".
				-id_eq => 0/1,					"1" requests printing of equations with abbreviations. Optional with default of "0".
				-direction => 0/1,				"1" requests printing of equations with abbreviations. Optional with default of "1".
				-compartment => 0/1,				"1" requests printing of equations with abbreviations. Optional with default of "1".
				-pegs => 0/1,					"1" requests printing of equations with abbreviations. Optional with default of "1".
				-notes => 0/1,					"1" requests printing of equations with abbreviations. Optional with default of "0".
				-reference => 0/1}				"1" requests printing of equations with abbreviations. Optional with default of "0".

	$output = { string:model ID => [{DATABASE => [string:reaction ID],
									 ABBREVIATION EQ => [string:reaction equation with compound abbreviation],
									 NAME EQ => [string:reaction equation with compound names],
									 DIRECTION => [string:direction of reaction],
									 COMPARTMENT => [string:compartment of reaction],
									 PEGS => [string:sets of genes forming complexes that catalyze reaction],
									 NOTES => [string:notes for reaction in model],
									 REFERENCE => [string:literature reference for reaction]}]};

Description:

	This function is used to obtain a table of data relating to all reactions included in a metabolic model.
	The arguments specify what data should be included in the output.
	Username and password must be provided to obtain data for private models.

=cut

sub get_model_reaction_data {
	my ($self, $args) = @_;
	$args = $self->process_arguments($args,["id"]);
	if (defined($args->{error})) {
		return $self->error_message($args->{error});
	}
	my $mdl = $self->figmodel()->get_model($args->{id});
	if (!defined($mdl)) {
		return $self->error_message("get_model_reaction_data:could not access model ".$args->{id});
	}
	my $tbl = $mdl->generate_reaction_data_table($args);
	if (!defined($tbl)) {
		return $self->error_message("get_model_reaction_data:could not access reactions for model ".$args->{id});
	}
	my $output;
	for (my $i=0; $i < $tbl->size(); $i++) {
		push(@{$output},$tbl->get_row($i));	
	}
	my $headings;
	push(@{$headings},$tbl->headings());
	return {data => $output,headings => $headings};
}

=head3 get_model_essentiality_data

=item Definition:

	$results = FBAMODEL->get_model_essentiality_data($arguments);
	
	$arguments = {"model" => [string]:model ids,
				  "user" => string:user login,
				  "password" => string:password}
	
	$results = {string:model ids => 
			    	{string:media ids => 
			    		{"essential" => [string]:gene ids}
			    	}
    			}
    
=item Description:
	
	Returns available gene essentiality predictions for the input set of models.

=cut

sub get_model_essentiality_data {
	my ($self,$args) = @_;
    $args = $self->process_arguments($args);
	my $results;
    if (defined($args->{model})) {
    	for (my $i=0; $i < @{$args->{model}}; $i++) {
    		my $modelObj = $self->figmodel()->get_model($args->{model}->[$i]);
    		if (defined($modelObj)) {
    			my $dataTable = $modelObj->essentials_table();
    			if (defined($dataTable)) {
					for (my $j=0; $j < $dataTable->size(); $j++) { 
						my $row = $dataTable->get_row($j);
						if (defined($row->{"ESSENTIAL GENES"}->[0]) && defined($row->{MEDIA}->[0])) {
							push(@{$results->{$args->{model}->[$i]}->{$row->{MEDIA}->[0]}->{essential}},@{$row->{"ESSENTIAL GENES"}});
						}
					}
				}
    		}
    	}
    }
    return $results;
}

=head3 get_experimental_essentiality_data

=item Definition:

	$results = FBAMODEL->get_experimental_essentiality_data($arguments);
	
	$arguments = {"genome" => [string]:genome ids,
				  "user" => string:user login,
				  "password" => string:password}
	
	$results = {string:genome ids => 
			    	{string:media ids => 
			    		{"essential" => [string]:gene ids,
			    		 "nonessential" => [string]:gene ids}
			    	}
    			}
    
=item Description:
	
	Returns available gene essentiality data for the input set of genomes.

=cut

sub get_experimental_essentiality_data {
	my ($self,$args) = @_;
    $args = $self->process_arguments($args);
	my $results;
    if (defined($args->{genome})) {
    	for (my $i=0; $i < @{$args->{genome}}; $i++) {
    		my $dataTable = $self->figmodel()->GetEssentialityData($args->{genome}->[$i]);
			if (defined($dataTable)) {
				for (my $j=0; $j < $dataTable->size(); $j++) { 
					my $row = $dataTable->get_row($j);
					if (defined($row->{Essentiality}->[0]) && defined($row->{Media}->[0])) {
						if ($row->{Essentiality}->[0] eq "essential" || $row->{Essentiality}->[0] eq "potential essential") {
							push(@{$results->{$args->{genome}->[$i]}->{$row->{Media}->[0]}->{essential}},$row->{Gene}->[0]);
						} elsif ($row->{Essentiality}->[0] eq "nonessential" || $row->{Essentiality}->[0] eq "potential nonessential") {
							push(@{$results->{$args->{genome}->[$i]}->{$row->{Media}->[0]}->{nonessential}},$row->{Gene}->[0]);
						}
					}
				}
			}
    	}
    }
    return $results;
}


=head3 fba_calculate_minimal_media

=item Definition:

	$results = FBAMODEL->fba_calculate_minimal_media($arguments);
	
	$arguments = {model" 				=> string:model id,
				  geneKO 				=> [string]:list of genes to be knocked out in study,
				  reactionKO 			=> [string]:list of reactions to be knocked out in study,
				  numFormulations 		=> integer:number of distinct formulations that should be calculated,
				  user 					=> string:user login,
				  password 				=> string:password}
	
	$results = {essential => [string]:compound ids,
			    nonessential => [[string]]:compound ids}}
    
=item Description:
	
	Identifies minimal media formulations for the input models.

=cut

sub fba_calculate_minimal_media {
	my ($self,$args) = @_;
    $args = $self->process_arguments($args,["model"]);
	if (defined($args->{error})) {
		return {error => $args->{error}};
	}
	my $mdl = $self->figmodel()->get_model($args->{model});
	if (!defined($mdl)) {
		return {error => "Input model ".$args->{model}." not found or inaccessible in the database"};	
	}
    my $reactionKO;
    if (defined($args->{reactionKO})) {
    	$reactionKO = $args->{reactionKO};
    }
    my $geneKO;
    if (defined($args->{geneKO})) {
    	$geneKO = $args->{geneKO};
    }
    my $numFormulations = 10;
    if (defined($args->{numFormulations})) {
    	$numFormulations = $args->{numFormulations};
    }
    return $mdl->fbaCalculateMinimalMedia($numFormulations,$reactionKO,$geneKO);
}

=head3 get_model_reaction_classification_table

=item Definition: 

    { string::model IDs => [ reaction => [string::reaction ID],
                             media => [string::media IDs],
                             class => [string::essential|active|inactive|dead],
                             class_directionality => [string::=>|<=|<=>],
                             min_flux => [double],
                             max_flux => [double]
                           ]
    } = FBAMODEL->get_model_reaction_classification_table( { model    => [string::model ids],
                                                           user     => string::username,
                                                           password => string::password 
                                                       } );


=item Description:

    my $returnArrayRef = $FBAModel->get_model_reaction_classification_table($configHash);

Where C<$configHash> is a hash reference with the following syntax:

    my $configHash = {    "model"    => [ "Seed83333.1", "iJR904.1" ],
                          "user"     => "bob",
                          "password" => "password123",
                    });

C<$returnArrayRef> is a hash reference with model ID strings as keys. The
value of each model ID is an array reference with the following syntax:

    "reaction" => an array reference with one element, the string of the reaction id.
    "media"    => an array reference containing media ID strings.
    "class"    => an array reference of the class of the reaction, ordered by the media condition column.
    "class_directionality" => an array reference of the class of the reaction, ordered by the media condition column.
    "min_flux" => minimum flux through each reaction in each media condition in the media colum.
    "max_flux" => maximum flux through each reaction in each media condition in the media column. 

This function naturally pairs with the L<C<classify_model_entities()>|/"classify_model_entities"> 
function which runs new classification analysis on additional media
conditions and adds the output to the archived table of classifications
if the C<$archiveResults> tag is set to. The function accepts as input
a hash with the key "model" pointing to an array of model IDs for
which classification tables should be returned.  The function returns
a hash with the model IDs acting as the keys pointing to a table of
classification data.

=cut

sub get_model_reaction_classification_table {
	my ($self, $args) = @_;
	$args = $self->process_arguments($args);
	#Checking that some model ID has been submitted
	if (!defined($args->{model})) {
		return undef;
	}
	
	#First logging in the user if a username is provided
	$self->figmodel()->authenticate_user($args->{username},$args->{password});
	
	#Now retreiving the specified models from the database
	my $output;
	for (my $i=0; $i < @{$args->{model}}; $i++) {
		my $model = $self->figmodel()->get_model($args->{model}->[$i]);
		if (defined($model)) {
			my $tbl = $model->reaction_class_table();
			for (my $j=0; $j < $tbl->size(); $j++) {
				my $row = $tbl->get_row($j);
				my $class;
				my $classdir;
				for (my $k=0; $k < @{$row->{CLASS}}; $k++) {
					if ($row->{CLASS}->[$k] eq "Positive") {
						push(@{$class},"essential");
						push(@{$classdir},"=>");
					} elsif ($row->{CLASS}->[$k] eq "Dead") {
						push(@{$class},"dead");
						push(@{$classdir},"NA");
					} elsif ($row->{CLASS}->[$k] eq "Negative") {
						push(@{$class},"essential");
						push(@{$classdir},"<=");
					} elsif ($row->{CLASS}->[$k] eq "Positive variable") {
						push(@{$class},"active");
						push(@{$classdir},"=>");
					} elsif ($row->{CLASS}->[$k] eq "Negative variable") {
						push(@{$class},"active");
						push(@{$classdir},"<=");
					} elsif ($row->{CLASS}->[$k] eq "Variable") {
						push(@{$class},"active");
						push(@{$classdir},"<=>");
					} elsif ($row->{CLASS}->[$k] eq "Blocked") {
						push(@{$class},"inactive");
						push(@{$classdir},"NA");
					}
				}
				push(@{$output->{$args->{model}->[$i]}},{reaction => [$row->{REACTION}->[0]],media => $row->{MEDIA}, class => $class, class_directionality => $classdir, min_flux => $row->{MIN}, max_flux => $row->{MAX}});
			}
		}
	}
	
	#Returning the output
	return $output;
}

sub get_role_to_complex {
    my ($self,$args) = @_;
    $args = $self->process_arguments($args);
    my $roles = $self->figmodel()->database()->get_objects("role");
    my $roleHash = {};
    for(my $i=0; $i<@$roles; $i++) {
        next unless(defined($roles->[$i]->id()) && defined($roles->[$i]->name())); 
        $roleHash->{$roles->[$i]->id()} = $roles->[$i]->name();
    }
    my $complexTable = [];
    my $cpxs = $self->figmodel()->database()->get_objects("cpxrole");
    for(my $i=0; $i<@$cpxs; $i++) {
        next unless(defined($cpxs->[$i]->COMPLEX()) && defined($cpxs->[$i]->ROLE()) &&
                    defined($cpxs->[$i]->type()) && defined($roleHash->{$cpxs->[$i]->ROLE()}));
        push(@$complexTable, { "Complex Id" => $cpxs->[$i]->COMPLEX(),
                               "Functional Role" => $roleHash->{$cpxs->[$i]->ROLE()},
                               "Complex Type"    => $cpxs->[$i]->type(),
                            }); 
    }
    return $complexTable; 
}

sub get_complex_to_reaction {
    my ($self,$args) = @_;
    $args = $self->process_arguments($args);
    my $objs = $self->figmodel()->database()->get_objects("rxncpx",{'master' => 1});
    my $complexToReactionTable = [];
    for(my $i=0; $i<@$objs; $i++) {
        next unless(defined($objs->[$i]->REACTION()) && defined($objs->[$i]->COMPLEX()));
        push(@$complexToReactionTable, { 'Complex Id' => $objs->[$i]->COMPLEX(),
                                         'Reaction Id'=> $objs->[$i]->REACTION() });
    }
    return $complexToReactionTable;
}

=head2 Flux Balance Analysis Methods

=head3 classify_model_entities

Definition:

    [ { id      => string,
        media   => string,
        reactionKO  => string,
        geneKO      => string,
        entities    => [ string::reaction and transportable compounds ids],
        classes => [string::classes],
        "min flux" => [float::minimum flux],
        "max flux" => [float::maximum flux]
    } ] = FBAMODEL->classify_model_entities(
        { "parameters" => [ { id         => string,
                              media      => string,
                              reactionKO => [string::reaction ids],
                              geneKO     => [string::gene ids],
                              archiveResults => [0|1],
                          } ],
           "user" => string,
           "password" => string
    });

Description:

Takes as input a hash with the key "parameters" pointing to
an array of hashes with analysis parameters, the key "user"
pointing to the username associated with a RAST account, and
the key "password" pointing to the password associated with the
RAST account.

The analysis parameters are stored in hashes where the keys are the
parameter names pointing to the parameter values.  Only one parameter
is required: "id" pointing to the name of the model to be analyzed.
Optional parameters include "media" pointing to the name of the media
for the simulation (default is complete media), "reactionKO" pointing
to a ";" delimited list of reactions to be knocked out (default is no
reactions knocked out), and "geneKO" pointing to a ";" delimited list
of the genes to be knocked (default is no genes knocked out).

Returns an array of the input analysis parameters with the additional
key values "entities" (which points to an array of the reactions and
transportable compounds in the model), "classes" (which points to an
array of the class each reaction/compound was assigned to), "max flux"
(which points to an array of the maximum possible flux through each
reaction/compound), and "min flux" (which points to an array of the
minimum possible flux through each reaction/compound) 

If the	"entities" key is undefined in the output, this means
the specified model did not grow in the specified conditions.

Example:

    my $ConfigHashRef = {"model" => [{"id" => "Seed83333.1",
                                      "media" => "Carbon-D-Glucose",
                                      "reactionKO" => "rxn00001;rxn00002",
                                      "geneKO" => "peg.1,peg.2"}],
                         "user" => "reviewer",
                         "password" => "eval"};
    my $retValArrayRef = $FBAModel->classify_model_entities($ConfigHashRef);
    $retValArrayRef == [{ "id" => "Seed83333.1",
                          "media" => "Carbon-D-Glucose",
                          "reactionKO" => "rxn00001;rxn00002",
                          "geneKO" => "peg.1,peg.2",
                          "reactions" => ["rxn00001","rxn00002"....],
                          "classes" => ["essential =>","essential<=",...],
                          "max flux" => [100,-10...],
                          "min flux" => [10,-100...],
                       }]

=cut
sub classify_model_entities {
	my ($self, $args) = @_;
	$args = $self->process_arguments($args);
	#Checking that at least one parameter was input
	if (!defined($args->{parameters})) {
		return undef;
	}
	#Getting parameter array
	my $parameters;
	if (ref($args->{parameters}) ne "ARRAY") {
		$parameters = [$args->{parameters}];
	} else {
		$parameters = $args->{parameters};
	}
	#Cycling through parameters and running fba studies
	my $output;
	for (my $i=0; $i < @{$parameters}; $i++) {
		if (defined($parameters->[$i]->{id})) {
			if (!defined($parameters->[$i]->{media})) {
				$parameters->[$i]->{media} = "Complete";
			}
			my $modelobj = $self->figmodel()->get_model($parameters->[$i]->{id});
			if (defined($modelobj)) {
				my $archiveResults = 0;
				if (defined($parameters->[$i]->{archiveResults}) && !defined($parameters->[$i]->{reactionKO}) && !defined($parameters->[$i]->{geneKO})) {
					$archiveResults = 1;
				}
				my ($rxnclasstable,$cpdclasstable) = $modelobj->classify_model_reactions($parameters->[$i]->{media},$archiveResults,$parameters->[$i]->{reactionKO},$parameters->[$i]->{geneKO});
				if (defined($rxnclasstable)) {
					for (my $j=0; $j < $rxnclasstable->size();$j++) {
						my $row = $rxnclasstable->get_row($j);
						push(@{$parameters->[$i]->{entities}},$row->{REACTION}->[0]);
						push(@{$parameters->[$i]->{classes}},$row->{CLASS}->[0]);
						push(@{$parameters->[$i]->{"min flux"}},$row->{MIN}->[0]);
						push(@{$parameters->[$i]->{"max flux"}},$row->{MAX}->[0]);
					}
				}
				if (defined($cpdclasstable)) {
					for (my $j=0; $j < $cpdclasstable->size();$j++) {
						my $row = $cpdclasstable->get_row($j);
						if ($row->{CLASS}->[0] ne "Unknown") {
							push(@{$parameters->[$i]->{entities}},$row->{COMPOUND}->[0]);
							push(@{$parameters->[$i]->{classes}},$row->{CLASS}->[0]);
							push(@{$parameters->[$i]->{"min flux"}},$row->{MIN}->[0]);
							push(@{$parameters->[$i]->{"max flux"}},$row->{MAX}->[0]);
						}
					}
				}
				push(@{$output},$parameters->[$i]);
			}
		}
	}
	return $output;
}

=head3 simulate_all_single_gene_knockout

=item Definition:

	[ { id          => string,
        media       => string,
        reactionKO  => string,
        geneKO      => string,
        "essential genes"   => [string::peg ids],
        "nonessential genes"=> [string::peg ids],
      } ] 
    = MODELserv->simulate_all_single_gene_knockout( { 
        "parameters" => [ { id     => string,
                            media  => string, 
                            reactionKO => string,
                            geneKO => string,
                        } ],
        "user" => string,
        "password" => string
    });

=item Description:

Takes as input a hash with the key "parameters" pointing to
an array of hashes with analysis parameters, the key "user"
pointing to the username associated with a RAST account, and
the key "password" pointing to the password associated with the
RAST account. 

The analysis parameters is a hash reference containing the following required and optional key/value pairs:

"id" pointing to the string ID of the model to be analyzed. (Required)

"media" pointing to the name of the media for the simulation (default is complete media).

"reactionKO" pointing to a ";" delimited list of reactions to be knocked out (default is no reactions knocked out).

"geneKO" pointing to a ";" delimited list of the genes to be knocked (default is no genes knocked out).

Returns an array of the input analysis parameters with the additional key
values are "essential genes" and "non essential genes" If the  "essential
genes" and "nonessential genes" keys are undefined in the output, this
means the specified model did not grow in the specified conditions.

=item Example:

    my $configHashRef = { "parameters" => [{ "id" => "Seed83333.1",
                                             "media" => "Carbon-D-Glucose",
                                             "reactionKO" => "rxn00001;rxn00002",
                                             "geneKO" => "peg.1,pge.2"}],
                          "user"       => "bob",
                          "password"   => "password123",
                        };
    my $retValArrayRef = $FBAModel->simulate_all_single_gene_knockout($configHashRef);

    $retValArrayRef == [ {"id" => "Seed83333.1",
                          "media" => "Carbon-D-Glucose",
                          "reactionKO" => "rxn00001;rxn00002",
                          "geneKO" => "peg.1,peg.2",
                          "essential genes" => ["peg.10","peg.45"...],
                          "nonessential genes" => ["peg.1", "peg.2"...],
                       }]

=cut
sub simulate_all_single_gene_knockout {
	my ($self, $args) = @_;
	$args = $self->process_arguments($args);
	#Checking that at least one parameter was input
	if (!defined($args->{parameters})) {
		return undef;
	}
	#Getting parameter array
	my $parameters;
	if (ref($args->{parameters}) ne "ARRAY") {
		$parameters = [$args->{parameters}];
	} else {
		$parameters = $args->{parameters};
	}
	#Cycling through parameters and running fba studies
	my $output;
	for (my $i=0; $i < @{$parameters}; $i++) {
		if (defined($parameters->[$i]->{id})) {
			if (!defined($parameters->[$i]->{media})) {
				$parameters->[$i]->{media} = "Complete";
			}
			my $modelobj = $self->figmodel()->get_model($parameters->[$i]->{id});
			if (defined($modelobj)) {
				my $reactionKO;
				my $geneKO;
				if (defined($parameters->[$i]->{reactionKO})) {
					$reactionKO = [$parameters->[$i]->{reactionKO}];
				}
				if (defined($parameters->[$i]->{geneKO})) {
					$geneKO = [$parameters->[$i]->{geneKO}];
				}
				my $result = $self->figmodel()->RunFBASimulation("FBAMODEL:simulate_all_single_gene_knockout:".$modelobj->id(),"SINGLEKO",$reactionKO,$geneKO,[$modelobj->id()],[$parameters->[$i]->{media}]);
				if (defined($result) && defined($result->get_row(0)->{"ESSENTIALGENES"})) {
					$parameters->[$i]->{"essential genes"} = $result->get_row(0)->{"ESSENTIALGENES"};
					$parameters->[$i]->{"nonessential genes"} = $result->get_row(0)->{"NONESSENTIALGENES"};
				}
				push(@{$output},$parameters->[$i]);
			}
		}
	}
	return $output;
}

=head3 simulate_model_growth
    
=item Definition:

    [ { id          =>  string,
        media       =>  string,
        reactionKO  =>  string,
        geneKO      =>  string,
        growth      =>  double,
        entities    =>  [ string::reaction or transportable compounds ids],
        fluxes      =>  [double]
    } ] 
    = FBAMODEL->simulate_model_growth( {"parameters" => [ { id      => string,
                                                            media   => string,
                                                            reactionKO => string,
                                                            geneKO  => string,
                                                        } ],
                                        "user"       => string,
                                        "password"   => string,
                                     } );

=item Description:

Takes as input a hash with: the key "parameters" pointing to an array of
hashes with L<analysis parameters|/"analysis parameters">, the key "user" pointing to the username
associated with a RAST account, and the key "password" pointing to the
password associated with the RAST account.

=over 

=item analysis parameters 

This is a hash reference with the following keys:

id : The string ID of the model to be analyzed. Required.

media : The name of the media for the simulation (default is complete media).

reactionKO : A ";" delimited list of reactions to be knocked out (default is no reactions knocked out).

geneKO : A ";" delimited list of the genes to be knocked (default is no genes knocked out).

=back

Returns an array of the input analysis parameters with the additional
key values "growth" (which points to a float with the optimal growth
of the model in the specified conditions), "entities" (which points to
the reactions and transportable compounds in the model), and "fluxes"
(which points to the flux through each reaction).

=item Example
    
    my $configHash = {"parameters" => [ { "id"      => "Seed83333.1",  
                                          "media"   => "Carbon-D-Glucose",
                                          "reactionKO" => "rxn00001;rxn00002",
                                          "geneKO"  => "peg.1,peg.2",
                                      } ],
                      "user"       => "alice",
                      "password"   => "password123"};
    my $arrayRefRetVal = $FBAModel->simulate_model_growth($configHash);

=cut

sub simulate_model_growth {
	my ($self, $args) = @_;
	$args = $self->process_arguments($args);
	#Checking that at least one parameter was input
	if (!defined($args->{parameters})) {
		return undef;
	}
	#Getting parameter array
	my $parameters;
	if (ref($args->{parameters}) ne "ARRAY") {
		$parameters = [$args->{parameters}];
	} else {
		$parameters = $args->{parameters};
	}
	#Cycling through parameters and running fba studies
	my $output;
	for (my $i=0; $i < @{$parameters}; $i++) {
		if (defined($parameters->[$i]->{id})) {
			if (!defined($parameters->[$i]->{media})) {
				$parameters->[$i]->{media} = "Complete";
			}
			my $modelobj = $self->figmodel()->get_model($parameters->[$i]->{id});
			if (defined($modelobj)) {
				my $reactionKO;
				my $geneKO;
				if (defined($parameters->[$i]->{reactionKO})) {
					$reactionKO = [$parameters->[$i]->{reactionKO}];
				}
				if (defined($parameters->[$i]->{geneKO})) {
					$geneKO = [$parameters->[$i]->{geneKO}];
				}
				my $result = $self->figmodel()->RunFBASimulation("FBAMODEL:simulate_model_growth:".$modelobj->id(),"GROWTH",$reactionKO,$geneKO,[$modelobj->id()],[$parameters->[$i]->{media}]);
				if (defined($result) && defined($result->get_row(0)->{"FLUXES"})) {
					$parameters->[$i]->{"growth"} = $result->get_row(0)->{"OBJECTIVE"}->[0];
					if (defined($result->get_row(0)->{"TYPES"}) && defined($result->get_row(0)->{"ENTITIES"}) && defined($result->get_row(0)->{"FLUXES"})) {
						my ($types,$entities,$fluxes);
						push(@{$types},split(/,/,$result->get_row(0)->{"TYPES"}->[0]));
						push(@{$entities},split(/,/,$result->get_row(0)->{"ENTITIES"}->[0]));
						push(@{$fluxes},split(/,/,$result->get_row(0)->{"FLUXES"}->[0]));
						for (my $j=0; $j < @{$types}; $j++) {
							if ($types->[$j] eq "FLUX" || $types->[$j] eq "DRAIN_FLUX") {
								push(@{$parameters->[$i]->{"entities"}},$entities->[$j]);
								push(@{$parameters->[$i]->{"fluxes"}},$fluxes->[$j]);
							}
						}
					}
				}
				push(@{$output},$parameters->[$i]);
			}
		}
	}
	return $output;
}

=head2 Admin Control Methods

=head3 rename_functional_role

=item Definition:

    string:error message = FBAMODEL->rename_functional_role({originalRoleName => string, newRoleNames => [string], keepOriginal => 0/1, user => string, password => string});

=item Description:
	
	Changes the name of the input "originalRoleName" to one or more new names input as an array in "newRoleNames". If multiple names are input, all mappings involving the original functional role are replicated.
	If the input flage "keepOriginal" exists and is set to "1", then new roles are created with the new names while the orignal role is retained. 
	All mappings with the original role are retained but also copied with the new names.
	This is an administrative function with access limited to Model SEED administrators.

=cut

sub rename_functional_role {
    my ($self,$args) = @_;
    $args = $self->process_arguments($args);
    if ($self->figmodel()->admin() != 1) {
    	return "Cannot use this function without Model SEED administrator privelages";	
    }
    if (!defined($args->{originalRoleName})) {
    	return "No original role name provided";	
    }
    my $roleObj = $self->figmodel()->database()->get_object("role",{name => $args->{originalRoleName}});
    if (!defined($roleObj)) {
    	my $searchName = $self->figmodel()->convert_to_search_role($args->{originalRoleName});
    	$roleObj = $self->figmodel()->database()->get_object("role",{searchname => $searchName});
    }
    if (!defined($roleObj)) {
    	return "Specified original role was not found";	
    }
    my $additionalNames;
    
    if (defined($args->{newRoleNames}) && @{$args->{newRoleNames}} > 0) {
    	for (my $i=0; $i < @{$additionalNames}; $i++) {
    		#Checking that the new role doesn't already exist
    		my $newSearchName = $self->figmodel()->convert_to_search_role($additionalNames->[$i]);
    		if (!defined($self->figmodel()->database()->get_object("role",{searchname => $newSearchName}))) {
    			#Creating the new roles
    			my $newRoleID = $self->figmodel()->database()->check_out_new_id("role");
    			my $newRole = $self->figmodel()->database()->create_object("role",{id => $newRoleID,name => $additionalNames->[$i],searchname => $newSearchName});
    			#Replicating the mappings with the new role
    			$self->figmodel()->replicate_role_mappings($roleObj->id(),$newRoleID);
    		}
    	}
    }
    if (!defined($args->{keepOriginal}) || $args->{keepOriginal} == 0) {
    	$self->figmodel()->delete_role_and_mappings($roleObj->id());
    }
    return undef;
}

=head3 add_

=item Definition:

    string:error message = FBAMODEL->add_functional_role_mapping({roles => [string]:role names,roletypes => [string]:global/local,reactions => [string]:reaction IDs, user => string, password => string});

=item Description:
	
	Creates a new functional role mapping in the database.

=cut

sub add_functional_role_mapping {
    my ($self,$args) = @_;
    $args = $self->process_arguments($args);
    #Checking for administrative privelages
    if ($self->figmodel()->admin() != 1) {
    	return "Cannot use this function without Model SEED administrator privelages";	
    }
    #Checking that the necessary input has been provided
    if (!defined($args->{roles}) || !defined($args->{roletypes}) || !defined($args->{reactions})) {
    	return "FBAMODEL:add_functional_role_mapping:insufficient input provided";
    }
    #Creating mapping
   	
   
   
    return undef;
    if (!defined()) {
    	return "No original role name provided";	
    }
    my $roleObj = $self->figmodel()->database()->get_object("role",{name => $args->{originalRoleName}});
    if (!defined($roleObj)) {
    	my $searchName = $self->figmodel()->convert_to_search_role($args->{originalRoleName});
    	$roleObj = $self->figmodel()->database()->get_object("role",{searchname => $searchName});
    }
    if (!defined($roleObj)) {
    	return "Specified original role was not found";	
    }
    my $additionalNames;
    
    if (defined($args->{newRoleNames}) && @{$args->{newRoleNames}} > 0) {
    	for (my $i=0; $i < @{$additionalNames}; $i++) {
    		#Checking that the new role doesn't already exist
    		my $newSearchName = $self->figmodel()->convert_to_search_role($additionalNames->[$i]);
    		if (!defined($self->figmodel()->database()->get_object("role",{searchname => $newSearchName}))) {
    			#Creating the new roles
    			my $newRoleID = $self->figmodel()->database()->check_out_new_id("role");
    			my $newRole = $self->figmodel()->database()->create_object("role",{id => $newRoleID,name => $additionalNames->[$i],searchname => $newSearchName});
    			#Replicating the mappings with the new role
    			$self->figmodel()->replicate_role_mappings($roleObj->id(),$newRoleID);
    		}
    	}
    }
    if (!defined($args->{keepOriginal}) || $args->{keepOriginal} == 0) {
    	$self->figmodel()->delete_role_and_mappings($roleObj->id());
    }
    return undef;
}

=head3 pegs_of_function

=item Definition:

    {string:role name=>[string]:peg ID} = FBAMODEL->pegs_of_function({roles => [string]:role names});

=item Description:
	
	Returns a hash of the pegs associated with each input functional role.

=cut

sub pegs_of_function {
	my ($self,$args) = @_;
    $args = $self->process_arguments($args);
 	my $result;
 	for (my $i=0; $i < @{$args->{roles}}; $i++) {
 		my @pegs = $self->figmodel()->fig()->prots_for_role($args->{roles}->[$i]);
 		push(@{$result->{$args->{roles}[$i]}},@pegs);
 	}
 	return $result;
}

=head3 fba_submit_gene_activity_analysis
Definition:
	$result = FBAMODEL->fba_submit_gene_activity_analysis($arguments);
	$arguments = {"user"       => string,					(optional for analysis of private models)
				  "password"   => string, 					(optional for analysis of private models)
				  "model"	   => string,					(mandatory id of model to be analyzed)
				  "media"	   => string,					(mandatory id of media for growth simulation)
				  "geneCalls"	   => {string => double}}	(mandatory hash of gene IDs mapped to gene calls: negative for off, zero for unknown, positive for on)
	}
	
	$results = {"jobID" => string}		(ID used to check on job status and retrieve results)                            
Description: 
=cut
sub fba_submit_gene_activity_analysis {
	my ($self,$args) = @_;
	$args = $self->process_arguments($args,["model","geneCalls"],{user => undef,password => undef,media => "Complete"});
	if (defined($args->{error})) {return {error => $args->{error}};}
	my $mdl = $self->figmodel()->get_model($args->{model});
	if (!defined($mdl)) {
		return {error => "Input model ".$args->{model}." not found or inaccessible in the database"};	
	}
	return $mdl->fbaSubmitGeneActivityAnalysis($args);
}

=head3 fba_retreive_gene_activity_analysis
Definition:
	$result = FBAMODEL->fba_retreive_gene_activity_analysis($arguments);
	$arguments = {"jobid" => string}	(mandatory ID of the job you wish to retrieve the status or results from)
	
	$results = {"status" => string,					(always returned string indicating status of the job as: running, crashed, finished)
				"biomass" => double,				(predicted growth only returned when job is finished)
				"flux => {string => double},			(hash of model entities mapped to corresponding fluxes only returned when job is finished)
				"geneActivity => {string => string}}	(hash of gene IDs mapped to activity only returned when the job is finished)
Description: 
=cut
sub fba_retreive_gene_activity_analysis {
	my ($self,$args) = @_;
	$args = $self->process_arguments($args,["jobid"]);
	if (defined($args->{error})) {return {error => $args->{error}};}
	my $fbaObj = ModelSEED::FIGMODEL::FIGMODELfba->new({figmodel => $self->figmodel()});
	return $fbaObj->returnFBAJobResults($args);
}

=head3 test
Definition:
	FBAMODEL->test();                   
Description:
	This function is designed to test every function of the FBAMODEL server.
	This function be successfully run prior to any new code release to ensure no functionality has been lost.
	An error message will be printed for any function that fails.
=cut
sub test {
	my ($self) = @_;
	delete $self->figmodel()->{_user_acount};
	my $output = $self->get_reaction_id_list({id => ["Seed441768.4.16242"]});
	if (defined($output) && defined($output->{"Seed441768.4.16242"}->[10])) {
		print STDERR "FBAMODEL:get_reaction_id_list:private model protection test failed!\n";
	}
	$output = $self->get_reaction_id_list({id => ["Seed441768.4.16242"],user => "reviewer",password => "natbtech"});
	if (!defined($output) || !defined($output->{"Seed441768.4.16242"}->[10])) {
		print STDERR "FBAMODEL:get_reaction_id_list:private model access test failed!\n";
	}
	$output = $self->get_reaction_id_list({id => ["ALL","Seed83333.1"]});
	if (!defined($output) || !defined($output->{"ALL"}->[10]) || !defined($output->{"Seed83333.1"}->[10])) {
		print STDERR "FBAMODEL:get_reaction_id_list:test failed!\n";
	}
	$output = $self->get_reaction_data({id => $output->{"Seed83333.1"},model => ["Seed83333.1"]});
	if (!defined($output) || !defined($output->{"rxn00781"}) || !defined($output->{"rxn00781"}->{EQUATION}->[0]) || !defined($output->{"rxn00781"}->{"Seed83333.1"}->{"ASSOCIATED PEG"}->[0])) {
		print STDERR "FBAMODEL:get_reaction_data:test failed!\n";
	}
	$output = $self->get_biomass_reaction_data({model => ["Seed83333.1"]});
	if (!defined($output) || !defined($output->{"Seed83333.1"}) || !defined($output->{"Seed83333.1"}->{EQUATION}->[0])) {
		print STDERR "FBAMODEL:get_biomass_reaction_data:test failed!\n";
	}
	$output = $self->get_compound_id_list({id => ["ALL","Seed83333.1"]});
	if (!defined($output) || !defined($output->{"ALL"}->[10]) || !defined($output->{"Seed83333.1"}->[10])) {
		print STDERR "FBAMODEL:get_compound_id_list:test failed!\n";
	}
	$output = $self->get_compound_data({id => $output->{"Seed83333.1"},model => ["Seed83333.1"]});
	if (!defined($output) || !defined($output->{"cpd00002"}) || !defined($output->{"cpd00002"}->{FORMULA}->[0])) {
		print STDERR "FBAMODEL:get_compound_data:test failed!\n";
	}
	$output = $self->get_media_id_list();
	if (!defined($output) || !defined($output->[10])) {
		print STDERR "FBAMODEL:get_media_id_list:test failed!\n";
	}
	$output = $self->get_media_data({id => $output});
	if (!defined($output) || !defined($output->{"Carbon-D-Glucose"}->{COMPOUNDS}->[0])) {
		print STDERR "FBAMODEL:get_media_data:test failed!\n";
	}
	$output = $self->get_model_id_list();
	if (!defined($output) || !defined($output->[10])) {
		print STDERR "FBAMODEL:get_model_id_list:test failed!\n";
	}
	$output = $self->get_model_data({"id"   => ["Seed83333.1"]});
	if (!defined($output) || !defined($output->{"Seed83333.1"}->{Name})) {
		print STDERR "FBAMODEL:get_model_data:test failed!\n";
	}
	$output = $self->get_model_reaction_data({"id"   => "Seed83333.1"});
	if (!defined($output) || !defined($output->{"data"}->[10]->{DATABASE}->[0])) {
		print STDERR "FBAMODEL:get_model_reaction_data:test failed!\n";
	}
	$output = $self->classify_model_entities({parameters => [{"id" => "Seed83333.1",media => "Complete",archiveResults => 0}]});
	if (!defined($output) || !defined($output->[0]->{classes}->[0])) {
		print STDERR "FBAMODEL:classify_model_entities:test failed!\n";
	}	
	$output = $self->simulate_all_single_gene_knockout({parameters => [{"id" => "Seed83333.1",media => "Complete"}]});
	if (!defined($output) || !defined($output->[0]->{"essential genes"}->[0])) {
		print STDERR "FBAMODEL:simulate_all_single_gene_knockout:test failed!\n";
	}
	$output = $self->simulate_model_growth({parameters => [{"id" => "Seed83333.1",media => "Complete"}]});
	if (!defined($output) || !defined($output->[0]->{"fluxes"}->[0])) {
		print STDERR "FBAMODEL:simulate_model_growth:test failed!\n";
	}
	$output = $self->get_model_reaction_classification_table({"model" => ["Seed83333.1"]});
	if (!defined($output) || !defined($output->{"Seed83333.1"}->[0]->{class}->[0])) {
		print STDERR "FBAMODEL:get_model_reaction_classification_table:test failed!\n";
	}
	$output = $self->get_role_to_complex();
	if (!defined($output) || !defined($output->[0]->{"Functional Role"})) {
		print STDERR "FBAMODEL:get_role_to_complex:test failed!\n";
	}
	$output = $self->get_complex_to_reaction();
	if (!defined($output) || !defined($output->[0]->{"Reaction Id"})) {
		print STDERR "FBAMODEL:get_complex_to_reaction:test failed!\n";
	}
	$output = $self->get_model_essentiality_data({model => ["Seed83333.1"]});
	if (!defined($output) || !defined($output->{"Seed83333.1"}->{Complete}->{essential}->[0])) {
		print STDERR "FBAMODEL:get_model_essentiality_data:test failed!\n";
	}
	$output = $self->get_experimental_essentiality_data({model => ["83333.1"]});
	if (!defined($output) || !defined($output->{"83333.1"}->{ArgonneLBMedia}->{essential}->[0])) {
		print STDERR "FBAMODEL:get_experimental_essentiality_data:test failed!\n";
	}
	$output = $self->fba_calculate_minimal_media({model => "Seed83333.1",numFormulations => 2});
	if (!defined($output) || !defined($output->{essential}->[0])) {
		print STDERR "FBAMODEL:fba_calculate_minimal_media:test failed!\n";
	}
	$output = $self->pegs_of_function({roles => ["Phosphomannomutase (EC 5.4.2.8)"]});
	if (!defined($output) || !defined($output->{"Phosphomannomutase (EC 5.4.2.8)"}->[0])) {
		print STDERR "FBAMODEL:pegs_of_function:test failed!\n";
	}
	my $geneCalls;
	my $fileData = $self->figmodel()->database()->load_single_column_file($self->figmodel()->config("test function data")->[0]."GeneActivityAnalysis.dat");
	for (my $i=1; $i < @{$fileData}; $i++) {
		my @array = split(/\t/,$fileData->[$i]);
		if (@array >= 2) {
			$geneCalls->{$array[0]} = $array[1];
		}
	}
	$output = $self->fba_submit_gene_activity_analysis({model => "Seed158878.1",media => "Complete",queue => "test",geneCalls => $geneCalls});
	if (!defined($output) || !defined($output->{jobid})) {
		print STDERR "FBAMODEL:fba_submit_gene_activity_analysis:test failed!\n";
	}
	$self->figmodel()->runTestJob($output->{jobid});
	$output = $self->fba_retreive_gene_activity_analysis({jobid => $output->{jobid}});
	if (!defined($output) || !defined($output->{On_On}->[10])) {
		print STDERR "FBAMODEL:fba_retreive_gene_activity_analysis:test failed!\n";
	}
}

1;
