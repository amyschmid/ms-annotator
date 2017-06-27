package GeneImpl;

sub new {
    #$proteinCollection is a ref to an array
    my ($class, $id, $name, $proteinCollection) = @_;
    $self = { id => $id,
	      name => $name,
	      proteinCollection => $proteinCollection
	      };
    return bless($self, $class);
}

package OrganismImpl;

sub new {
    my ($class, $id, $ncbi, $s_name, $c_name,$org_collection) = @_;
    $self = { id => $id,
	      ncbiTaxonomyID => $ncbi,
              scientificName => $s_name,
	      commonName => $c_name,
	      organismCollection => $org_collection
	    };
    return bless($self, $class);
}

package ProteinImpl;

sub new {
    my ($class, $id, $uniprotkbPrimaryAccession, $uniprotkbEntryName ) = @_;
    $self = {
	componentNameCollection  => undef,
	databaseCrossReferenceCollection  => undef,
	domainNameCollection  => undef,
	featureCollection  => undef,
	geneCollection  => undef,
	id  => $id,
	keywordCollection  => undef,
	organelleCollection  => undef,
	organismCollection  => undef,
	proteinNameCollection  => undef,
	proteinSequence  => undef,
	proteinType  => undef,
	uniprotkbAccessionCollection  => undef,
	uniprotkbEntryName  => $uniprotkbEntryName,
	uniprotkbPrimaryAccession  => $uniprotkbPrimaryAccession
	};
    return bless($self, $class);
}

package ProteinNameImpl;

sub new {
    #$proteinCollection is a ref to an array
    my ($class, $id, $proteinCollection, $value) = @_;
    $self = { id => $id,
	      proteinCollection => $proteinCollection,
	      value => $value
	      };
    return bless($self, $class);
}


##
# queryObjectRequest does not do what we want because of rpc encoding
# i think.  just here for historical record
##

package queryObjectRequest;

sub new {
    my ($class, $orgTargetObjectName, $orgCriteriaObj) = @_;
    $self = { orgTargetObjectName => $orgTargetObjectName,
	      OrgCriteriaObject => $orgCriteriaObj
	      };
    return bless($self, $class);
}



1;
