package GenomeMetaDatabase;

use strict;
use warnings;

use Time::Piece;
use FreezeThaw qw( freeze thaw );

use JobMetaDBHandle;
use JobDBHandle;

sub new {
    my ($class, $job) = @_;
    
    my $error;

    my $job_db;
    if (ref($job)) {
	$job_db = $job->_master;
    } else {
	($job_db, $error) = JobDBHandle->new();
	if ($error) {
	    die "Error connecting to JobDB: $error\n";
	}
	my $jobnum = $job;
	$job = $job_db->Job->init( { id => $jobnum } );
	unless (ref($job)) {
	    die "Could not find Job $jobnum in the database\n";
	}
    }
    
    my $meta_db;
    ($meta_db, $error) = JobMetaDBHandle->new();
    if ($error) {
	die "Error connecting to MetaDB: $error\n";
    }
    
    my $self = { 'job' => $job,
		 'meta_db' => $meta_db,
		 'job_db' => $job_db,
		 'readonly' => 0 };
    
    bless($self, $class);
    
    return $self;
}

sub create_new {
    return "DEPRECATED use of function create_new in GenomeMetaDatabase";
}

sub readonly {
    my ($self) = @_;

    return $self->{readonly};
}

sub set_metadata {
    my($self, $name, $val) = @_;

    my $entry = $self->{meta_db}->JobMD->init( { job => $self->{job},
						 tag => $name } );
    if ($entry) {
	$entry->value => $self->serialize_value($val);
    } else {
	$self->{meta_db}->JobMD->create( { job => $self->{job},
					   tag => $name,
					   value => $self->serialize_value($val) } );
    }
    $self->add_log_entry($name, $val);
}

sub get_metadata {
    my($self, $name) = @_;

    my $entry = $self->{meta_db}->JobMD->init( { job => $self->{job},
						 tag => $name } );

    my $val = $entry->{value};
    if (defined($val)) {
	$val = $self->deserialize_value($val);
    }
    return $val;
}

sub get_metadata_keys {
    my($self) = @_;

    my $allentries = $self->{meta_db}->JobMD->get_objects( { job => $self->{job} } );
    my $ak = {};
    foreach (@$allentries) {
	$ak->{$_} = 1;
    }
    my @all_keys = keys(%$ak);
    
    return @all_keys;
}

sub add_log_entry {
    my($self, $type, $data) = @_;

    $self->{meta_db}->Log->create( { 'job' => $self->{job},
				     'type' => $type,
				     'time' => time,
				     'entry' => $self->serialize_value($data) } );
}

sub get_log {
    my($self) = @_;

    my $out = [];
    my $log = $self->{meta_db}->Log->get_objects( { job => $self->{job} } );
    foreach my $entry (@$log) {
	my $ndate = Time::Piece->strptime($entry->{time}, '%Y-%m-%d %H:%M:%S' )->epoch;	
	push(@$out, [ 'log_entry', $entry->{type}, $ndate, $entry->{entry} ]);
    }

    return $out;
}

sub serialize_value {
    my($self, $val) = @_;

    if (ref($val)) {
	$val = freeze($val);
    }

    return $val;
}

sub deserialize_value {
    my($self, $val) = @_;

    if ($val =~ /^FrT;/) {
	my @result = thaw($val);
	$val = $result[0];
    }

    return $val;
}

sub convert_xml_to_db {
    my ($self) = @_;
    
    use GenomeMeta;
    my $key = ($self->{job}->metagenome) ? 'metagenome_'.$self->{job}->id : $self->{job}->genome_id;
    my $xml = GenomeMeta->new($key, $self->{job}->directory.'/meta.xml');

    my @keys = $xml->get_metadata_keys;
    foreach my $k (@keys) {
	$self->set_metadata($k, $xml->get_metadata($k));
    }
    
    return 1;
}

sub convert_log {
    my ($self) = @_;

    use GenomeMeta;
    my $key = ($self->{job}->metagenome) ? 'metagenome_'.$self->{job}->id : $self->{job}->genome_id;
    my $xml = GenomeMeta->new($key, $self->{job}->directory.'/meta.xml');

    my $log = $xml->get_log();
    my $dbh = $self->{meta_db}->backend->dbh;
    my $sth = $dbh->prepare("INSERT INTO Log (job,_job_db,type,time,entry) VALUES (?,?,?,?,?)");
    my ($job_id, $db_id) = $self->{meta_db}->translate_ref_to_ids($self->{job});
    foreach my $entry (@$log) {
        $sth->execute( $job_id, $db_id, $entry->[1], $entry->[2], $entry->[3] );
    }
    $dbh->commit();
    
    return 1;
}

1;
