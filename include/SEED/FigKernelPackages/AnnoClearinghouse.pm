#
# Annotation clearinghouse client code.
#
# The contrib dir is where the expert annotations are stored; it is separate
# from the main clearinghouse data directory since the clearinghouse data
# will be replaced on a regular basis.
#

package AnnoClearinghouse;

use FIG;
use FIG_Config;
use Data::Dumper;
use strict;
use DB_File;
use File::Copy;
use DirHandle;
use IO::File; 
use Digest::MD5;
 
use POSIX;

# my $arch = `arch`;
my $arch = "i686";
chomp $arch;


#
# Construct from directory containing an anno clearinghouse.
#
sub new
{
    my($class, $dir, $contrib_dir , $readonly , $dbh) = @_;

    my $pegsyn_to = "$dir/peg.synonyms.index.t";
    my $pegsyn_from = "$dir/peg.synonyms.index.f";
    my $assign_idx = "$dir/anno.btree";
    my $org_idx = "$dir/org.btree";
    my $orgname_idx = "$dir/orgname.btree";
    my $alias_idx = "$dir/alias.btree";
    my $singleton_idx = "$dir/singleton.index";
    my $nr_len = "$dir/nr-len.btree";
  

    
    # init the contrib dir if not already done
    #
    my $contrib_idx;
    my $contrib_idx_exp;
    my $contrib_idx_links;
    
    print STDERR "Reading contrib dir $contrib_dir\n";

    if ($contrib_dir)
    {
	&FIG::verify_dir($contrib_dir);
	print STDERR "Dir checked\n";
	$contrib_idx = "$contrib_dir/contrib.btree";
	if (! -f $contrib_idx)
	{
	    my %x;
	    my $t = tie %x, 'DB_File', $contrib_idx, O_RDWR | O_CREAT, 0666, $DB_BTREE;
	    $t or die "cannot create $contrib_idx: $!";
	    untie $t;
	}
	$contrib_idx_exp = "$contrib_dir/contrib.exp.btree";
	if (! -f $contrib_idx_exp)
	{
	    my %x;
	    my $t = tie %x, 'DB_File', $contrib_idx_exp, O_RDWR | O_CREAT, 0666, $DB_BTREE;
	    $t or die "cannot create $contrib_idx_exp: $!";
	    untie $t;
	}
	$contrib_idx_links = "$contrib_dir/contrib.links.btree";
	if (! -f $contrib_idx_links)
	{
	    my %x;
	    my $t = tie %x, 'DB_File', $contrib_idx_links, O_RDWR | O_CREAT, 0666, $DB_BTREE;
	    $t or die "cannot create $contrib_idx_links: $!";
	    untie $t;
	}
    }

    # print STDERR "DIR: $dir , $pegsyn_from\n";

    my $self = {
		dir => $dir,
		contrib_dir => $contrib_dir,
		index_dir   => "$dir/to_index",
		ps_to       => tie_index($pegsyn_to),
		ps_from     => tie_index($pegsyn_from),
		assign      => tie_index($assign_idx),
		org         => tie_index($org_idx),
		orgname     => tie_index($orgname_idx),
		alias       => tie_index($alias_idx, undef, 1),
		singleton   => tie_index($singleton_idx),
		dbh        => $dbh || undef ,
	
    };
    if ($contrib_idx)
    {
      if ($readonly){
	$self->{contrib} = tie_index($contrib_idx);
	$self->{contrib_exp} = tie_index($contrib_idx_exp);
	$self->{contrib_links} = tie_index($contrib_idx_links);
      }
      else{
	$self->{contrib} = tie_index($contrib_idx, O_RDWR);
	$self->{contrib_exp} = tie_index($contrib_idx_exp, O_RDWR);
	$self->{contrib_links} = tie_index($contrib_idx_links, O_RDWR);
      }
    }

    return bless $self, $class;
}

#
# Read an annotations file, validing that
#
#   each line is tab-delimited pair (we accept more than two columns, tho)
#   each identifier already exists in our database
#
# Write the cleaned annotations to $out_clean, original copy to $out_orig.
#
sub clean_user_annotations
{
    my($self, $user, $fh, $out_orig, $out_clean) = @_;

    my $block;

    read($fh, $block, 1024) or die "Read failed: $!";
    open(OUT, ">$out_orig") or die "Cannot write $out_orig: $!";
    print OUT $block;

    my $badstr;
    if ($block =~ /^\{\\rtf/)
    {
	$badstr= "File is RTF.";
    }
    elsif ($block =~ /^(\376\067\0\043)|(\320\317\021\340\241\261\032\341)|(\333\245-\0\0\0)/)
    {
	$badstr = "File is a MS Office document.";
    }

    #
    # Try to guess line endings based on NL / CR counts.
    #

    my $nlcount = ($block =~ tr/\n//);
    my $crcount = ($block =~ tr/\r//);

    my $sep;
    if ($nlcount > 0 and $crcount == 0)
    {
	$sep = "\n";
    }
    elsif ($crcount > 0 and $nlcount == 0)
    {
	$sep = "\r";
    }
    elsif ($nlcount == 0 and $crcount == 0)
    {
	warn "Document is probably binary, no NL or CR in first block.";
	#
	# Try to read as normal doc in case there's just a really really long annotation.
	#
	$sep = "\n";
    }
    else
    {
	#
	# We have a mix of separators, treat as NL sep. We strip CR in any case.
	#
	$sep = "\n";
    }

    #
    # Write the file to the backup filename. Die afterwards if we hit badness above.
    # (we archive all the files for later forensics).
    #

    while (read($fh, $block, 4096))
    {
	print OUT $block;
    }
    close($fh);
    close(OUT);

    if ($badstr ne '')
    {
	die $badstr;
    }

    #
    # Now scan our backup copy and parse.
    #

    open(IN, "<$out_orig");
    open(OUT, ">$out_clean");

    local $/ = $sep;

    my $bad = [];
    my $line;
    while (<IN>)
    {
	$line++;
	chomp;
	s/\r//g;

	next if /^\s*$/;

	#
	# Allow some whitespace slop before the start of the line, and around the tab.
	#
	if (/^\s{0,10}(\S+)\s*\t\s*([^\t]*)/)
	{
	    my($id, $func) = ($1, $2);
	    $func =~ s/\s*$//;

	    # map old to new id prefix

	    if (my ($pref,$nid) = $id =~/(tigrcmr)\|([^\s]+)/){
	      $id = "cmr|$nid";
	    }
	    # print STDERR "ID $id\n";
	    # remove quotation marks around assertion (common excel export issue)
	    if ($func =~ /^\"(.+)\"/) {
	      $func = $1;
	    }

	    # check if 3rd column has a link
	    my $link ='';
	    if (/^\s{0,10}\S+\s*\t\s*[^\t]+\s*\t\s*(http\:\/\/\S+)/) {
	      $link = $1;
	    }

	    #
 	    # Look up the possibly-multiple mappings for this identifier.
	    #

	    my @ids;

	    # prefix for uniprot ids can change from tr to sp
	    if (my ($pref,$nid) = $id =~/(tr)\|([^\s]+)/){
		@ids = $self->lookup_principal_id("tr|".$nid);
		@ids = $self->lookup_principal_id("sp|".$nid)  unless (scalar @ids);
	    }
	    else{
		@ids = $self->lookup_principal_id($id);
	    }

	    if (@ids == 0)
	    {
		push(@$bad, [$id, $line, "cannot map ($user)"]);
	    }
	    elsif (@ids == 1)
	    {
		my($mid, $prin_id) = @{$ids[0]};
		print OUT "$mid\t$func\t$prin_id\t$link\n";
	    }
	    else
	    {
		push(@$bad, [$id, $line, "multiple ids mapped: " . join(" ", map { $_->[0] } @ids)]);
	    }
	}
	else
	{
	    push(@$bad, [undef, $line, "cannot parse line"]);
	}
    }

    close(IN);
    close(OUT);
#    if (@$bad)
#    {
#	unlink($out_clean);
#	die "Error looking up ids:\n\t" . join("\t\n", @bad) . ", aborting";
#    }
    return $bad;
}

sub import_user_annotations{
  
  my($self, $user, $file, $badlist) = @_;
  
  
  # take filehandle or filename
  unless (ref $file) {
    $file = IO::File->new("<$file") or
      die "Cannot open anno file $file: $!";
  }
  
  my $user_dir = "$self->{contrib_dir}/$user";
  &FIG::verify_dir($user_dir);
  
  #
  # Clean up annotations, checking for bad inputfiles.
  #
  
  my $save_orig = "$user_dir/anno.orig." . time;
  my $save_clean = "$user_dir/anno.clean." . time;
  
  
  my $bad_ids = $self->clean_user_annotations($user, $file, $save_orig, $save_clean);
  
  if (ref($badlist) eq 'ARRAY') {
    @$badlist = @$bad_ids;
  }

  if (1){
    print STDERR "Bad IDs ($user):\n";
    foreach my $line (@$bad_ids){
      print STDERR join "\t" , @$line , "\n";
    }
  }
  
  #
  # Scan and index cleaned annotations.
  #

  open(IN, "<$save_clean") or die "Cannot open $save_clean: $!";
  
  my $count = 0;
  my $contrib_hash = $self->{contrib};
  my $contrib_hash_exp = $self->{contrib_exp};
  my $contrib_links = $self->{contrib_links};

  
  
  while (my $line = <IN>) {
    
    chomp $line;
    my($id, $anno, $pid, $link) = split(/\t/ , $line);
       
    print STDERR "MSG: ($id, $anno, $pid, $link) \n";

    my $md5 = $self->md5_of_peg($id);
    print STDERR "MSG: MD5=$md5\n";
    
    if ($anno ne '') {
      
      #	    $contrib_hash->{$pid, $id, $user} = $anno;
      #	    $contrib_links->{$id, $user} = $link;
      
      # write to DB here
      # check for md5 sum, if non exists , get sequence and compute it
      
      if ($md5){
	
	$self->add_user_annotation( $id , $anno , $md5 , $user , $link || '');
	
      }
      else{
	print STDERR "Error: Can not compute md5 for $id!\n";
      }
	  
      print STDERR "MSG: Expand block for $id\n";
      # expand to all block ids
      #	    foreach my $entry (@{$self->lookup_id($id)}) {
      #		my ($equiv_id, $len) = @$entry;
      #		$contrib_hash_exp->{$equiv_id, $user} = $anno;
      #	    }
      
    }
    else {
      
      my $md5 = $self->md5_of_peg($id);
      if ($md5){
	$self->add_user_annotation( $id , $anno , $md5 , $user , $link || '');
      }
      else{
	print STDERR "Error: Can not compute md5 for $id!\n";
      }
      
	    
      
      
      #	    my $error = delete $contrib_hash->{$pid, $id, $user};
	    
      #	    print STDERR "ERROR\t$pid\t$id\t$user\t$error\n" unless($error);
      #	    delete $contrib_links->{$id, $user};
      
      # expand to all block ids
      #	    foreach my $entry (@{$self->lookup_id($id)}) {
      #		my ($equiv_id, $len) = @$entry;
      #		delete $contrib_hash_exp->{$equiv_id, $user};
      # }
	    
    }
    
    $count++;
  }
  close(IN);
  
  # explicit sync
  #   my $t = tied %{$self->{contrib}};
  #   $t->sync;
  #   my $texp = tied %{$self->{contrib_exp}};
  #   $texp->sync;
  
  return $count;
}


#
# Retrieve user annotations for a single sequence id. This method retrieves the 
# annotations from contrib.btree using pid,id as key. Returns (user, annotation).
# 

sub get_user_annotations
{
    my($self, $id) = @_;


    my $results;
    my $dbh = $self->{dbh};
    
    my $table = "Assertion";
    $table = "ACH_Assertion" if ($dbh->table_exists('ACH_Assertion') );

    my $statement = "SELECT * FROM $table WHERE id='$id' AND function!='' ";
    my $results = $dbh->SQL($statement);
    return @$results;

    # old 
    my $pid = $self->lookup_principal_id($id);
    my $key = $pid;
    my $val;

    my $t = tied %{$self->{contrib}};
    my $rc = $t->seq($key, $val, R_CURSOR);

    my @out;
    while ($rc == 0)
    {
	my($pid, $xid, $user) = split(/$;/, $key);	
	last if ($xid ne $id);
	if($xid eq $id) {
	  push(@out, [$user, $val]);
	}
	$rc = $t->seq($key, $val, R_NEXT);
    }
    return @out;
}


#
# Retrieve a user annotations for a block of ids specified by it principal
# id. This method queries the contrib.btree using pid as key and will return
# tuples (id, user, annotation).
# 

sub get_user_annotations_by_pid
{
    my($self, $pid) = @_;

    my @r = $self->get_annotations_by_pid($pid);

    my $results;
    my $dbh = $self->{dbh};
    my $table = "Assertion";
    $table = "ACH_Assertion" if ($dbh->table_exists('ACH_Assertion') );

    my %sequences;
    foreach my $e (@r) {	
      my ($id, $source, $func, $org, $len) = @$e;
      my $seq = $self->get_sequence( $id );

      $sequences{$seq} = 1;
    }

    foreach my $seq (keys %sequences){
      my $md5 = Digest::MD5::md5_hex( uc $seq );
      
      my $statement = "SELECT id , expert , function FROM $table WHERE md5='$md5' and function!=''";
     # print STDERR $statement , "\n";
      my $res = $dbh->SQL($statement);
      
      push @$results , @$res;
    }
    
    return @$results if (ref $results);

    # old


    my $key = $pid;
    my $val;

    my $t = tied %{$self->{contrib}};
    my $rc = $t->seq($key, $val, R_CURSOR);

    my @out;

    print STDERR "MSG: RC=$rc \$_=$_ Key=$key Val=$val\n";
    while ($rc == 0)
    {
	my($xpid, $xid, $user) = split(/$;/, $key);	
	last if ($xpid ne $pid);

	push(@out, [$xid, $user, $val]);
	$rc = $t->seq($key, $val, R_NEXT);
    }
    return @out;
}


#
# Retrieve the annotation link for the combination of user and single sequence id. 
# Returns the link or undef.
# 

sub get_user_annotation_link
{
    my($self, $user, $id) = @_;

    my $key = $id;
    my $val;

    my $t = tied %{$self->{contrib_links}};
    my $rc = $t->seq($key, $val, R_CURSOR);

    while ($rc == 0)
    {
	my($xid, $xuser) = split(/$;/, $key);	
	last if ($xid ne $id);
	if ($xuser eq $user) {
	  return $val;
	}
	$rc = $t->seq($key, $val, R_NEXT);
    }
    return undef;
}


#
# Retrieves user annotations made to a single sequence id or to any sequence in 
# the same block. This method retrieves the annotations from contrib.exp.btree using 
# using id as key. Returns (user, annotation).
# 

sub get_any_user_annotations
{
    my($self, $id) = @_;

    my $key = $id;
    my $val;

    my $t = tied %{$self->{contrib_exp}};
    my $rc = $t->seq($key, $val, R_CURSOR);

    my @out;
    while ($rc == 0)
    {
	my($xid, $user) = split(/$;/, $key);	
	last if ($xid ne $id);
	push(@out, [$user, $val]);
	$rc = $t->seq($key, $val, R_NEXT);
    }
    return @out;
}

#
# Retrieves all expert annotations made to a any fig id or to any sequence in 
# the same block. This method retrieves the annotations from contrib.exp.btree . 
# Returns (fig_id , user, annotation).
# 

sub get_any_expert_annotation_for_fig_ids
{
    my ($self, $id) = @_;

#    my $key = $id; 
    my $key;
    my $val;

    my @out; 
    my $t = tied %{$self->{contrib_exp}};
    my $rc = $t->seq($key, $val, R_CURSOR);


    while (my ($k, $v) = each  %{$self->{contrib_exp}} ) { 
      my ($xid, $user) = split(/$;/, $k);
      next unless ($xid =~ /fig/);
      #print "$k -> $v\n" ;

     
      #print "$xid , $user , $val \n";
      push @out , [ $xid , $user , $v];
     
      }

  
    return @out;
}


#
# Remove all annotations from a given user.
#
# We unfortunately haven't keep the right index to do this intelligently, but there's not
# that much data and we needn't do it often. 
#
sub purge_user_annotations 
{
    my($self, $user) = @_;

    my $key = '';
    my $val;

    # delete from contrib.btree
    my $t = tied %{$self->{contrib}};
    my $rc = $t->seq($key, $val, R_CURSOR);

    my $n = 0;
    while ($rc == 0)
    {
	my($xpid, $xid, $xuser) = split(/$;/, $key);

	if ($xuser eq $user)
	{
	    $t->del($key);
	    $n++;
	}

	$rc = $t->seq($key, $val, R_NEXT);
    }

    # delete from contrib.exp.btree
    my $texp = tied %{$self->{contrib_exp}};
    my $rc = $texp->seq($key, $val, R_CURSOR);

    while ($rc == 0)
    {
	my($xid, $xuser) = split(/$;/, $key);

	if ($xuser eq $user)
	{
	    $texp->del($key);
	    $n++;
	}

	$rc = $texp->seq($key, $val, R_NEXT);
    }

    return $n;
}

sub get_all_user_annotations{
  my($self, $user) = @_;
  
  my $results;
  my $dbh = $self->{dbh};
  
  unless ($user){
    print STDERR "Error: No User!\n";
    return 0;
  }
  
  my $table = "Assertion";
  $table = "ACH_Assertion" if ($dbh->table_exists('ACH_Assertion') );
  
  my $statement = "SELECT * FROM $table WHERE expert='$user' and function!=''";
  my $results = $dbh->SQL($statement);
  
  return $results if (ref $results);
  
  # old stuff clean up
  my $key = '';
  my $val;
  
  my $t = tied %{$self->{contrib}};
  my $rc = $t->seq($key, $val, R_CURSOR);

    my @out;

    while ($rc == 0)
    {
	my($pid, $xid, $xuser) = split(/$;/, $key);

	if ($xuser eq $user)
	{
	    push(@out, [$xid, $val]);
	}

	$rc = $t->seq($key, $val, R_NEXT);
    }

    return @out;
}

sub get_all_distinct_user_annotations
{
    my($self, $user) = @_;

    my $key = '';
    my $val;

    my $t = tied %{$self->{contrib}};
    my $rc = $t->seq($key, $val, R_CURSOR);

    my @out;

    while ($rc == 0)
    {
	my($pid, $xid, $xuser) = split(/$;/, $key);

	if ($xuser eq $user)
	{
	    push(@out, [$xid, $val]);
	}
# 	if ( $xuser =~/PIR/ ){
# 	  print STDERR "A".$user."A".$xuser."A" , "\n";
# 	  exit;
# 	}

	$rc = $t->seq($key, $val, R_NEXT);
    }

    return @out;
}

#
# Return the total number of user contributed annotations
#
sub count_contrib_annotations {
  if ($_[0]->{contrib}) {
    return scalar(keys(%{$_[0]->{contrib}}));
  }
  else {
    return 0;
  }
}

#
# Return the number of unique annotations contributed by users
#
sub count_contrib_unique_annotations {
  if ($_[0]->{contrib}) {
    my $unique = {};
    foreach my $k (keys(%{$_[0]->{contrib}})) {
      $unique->{ $_[0]->{contrib}->{$k} } = 1;
    }
    return scalar(keys(%$unique));
  }
  else {
    return 0;
  }
}
  
#
# Dump all user contributed annotations as 3 column table 
# [ id, user, annotation ]
# if $text is provided and true, it will return a text dump
# if $resolve_logins is provided and true, it will try to translate logins to full names
#
sub dump_contrib_annotations {
  my($self, $text, $resolve_logins) = @_;


  my $results;
  my $dbh = $self->{dbh};
  
  my $table = "Assertion";
  $table = "ACH_Assertion" if ($dbh->table_exists('ACH_Assertion') );

  my $statement = "SELECT * FROM $table WHERE function!=''";
  my $results = $dbh->SQL($statement);

  # try to get a connection to user database if logins have to be resolved
  my $dbm;
  if ($resolve_logins) {
    require DBMaster;
    eval { $dbm = DBMaster->new(-database => 'WebAppBackend' ,
				-backend  => 'MySQL',
				-host     => 'bio-app-authdb.mcs.anl.gov' ,
				-user     => 'mgrast',); };
    if ($@) {
      warn ">>> Connect to user database failed: $@";
    }
  }


#####     
  my @out;
  my $users = {};
  foreach my $row (@$results) {
    
    my($id, $func, $md5 , $xuser , $url) = @$row;

    
    if (!exists($users->{$xuser})) {
      $users->{$xuser} = $xuser;
      
      # if there's a user database connection, try to resolve logins
      if ($dbm) {
	my $user = $dbm->User->init({ login => $xuser });
	if (ref $user) {
	  $users->{$xuser} = $user->firstname.' '.$user->lastname;
	}
	else {
	  warn ">>> Cannot resolve user login '$xuser'.";
	}
      }
    }

  
    push(@out, [$md5, $id, $func , $users->{$xuser} , $url]);
    
  
  }
  
  @out = sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } @out;

  if ($text) {
    my $dump = '';
    foreach (@out) {
      $dump .= join("\t", @$_)."\n";
    }
    return $dump;
  }
  return @out;
}


#
# Retrieves all annotations for a principal id and returns tuples
# (id, source, annotation, length, organism)
# 

sub get_annotations_by_pid {
  my($self, $pid) = @_;
  
  my $block = $self->expand_block($pid);
  
  my @out;
  
  foreach my $entry (@$block) {
    my ($mid, $len) = @$entry;
    my ($fn, $what) = $self->get_assignment($mid);
    my $org = $self->get_org($mid) || '';
    $len = '' unless(defined $len);

    push @out, [ $mid, $what, $fn, $org, $len ];
    
  }
  
  return @out;
}



sub tie_index
{
    my($file, $flags, $empty_ok) = @_;

    my $h = {};
    my $tie = tie %$h, 'DB_File', $file, defined($flags) ? $flags :  O_RDONLY, 0666, $DB_BTREE;

    $tie or $empty_ok or die("cannot tie $file: $!");
    return $h;
}

sub get_assignment
{
    my($self, $id) = @_;

    my $v = $self->{assign}->{$id};
    return unless $v;

    my($what, $fn) = split(/$;/, $v);
    if (wantarray)
    {
	return ($fn, $what);
    }
    else
    {
	return $fn;
    }
}


sub get_org
{
    my($self, $id) = @_;

    my $onum = $self->{org}->{$id};
    return $self->{orgname}->{$onum};
}

#
# Get the sequence for an ID, using fastacmd and the formatted database.
#
sub get_sequence
{
    my($self, $id) = @_;

    my $prin_id = $self->lookup_principal_id($id);

    if ($prin_id)
    {
	#
	# Need to lookup the block of data we're in to find our sequence length.
	#

	my $block = $self->expand_block($prin_id);
	my @me = grep { $_->[0] eq $id } @$block;

	my $my_len = $me[0]->[1];

	my $seq = $self->lookup_raw_seq($prin_id, 0);
	return substr($seq, -$my_len);
    }
    else
    {
	my $seq = $self->lookup_raw_seq($id, 0);
	return $seq;
    }
}

sub lookup_raw_seq
{
    my($self, $id, $line_len) = @_;

    $line_len = 60 unless $line_len =~ /^\d+$/;

    my $nr = "$self->{dir}/$arch/nr";
    if (! -f "$nr")
    {
	warn "MSG: Didn't find $nr\n";
	$nr = "$self->{dir}/nr";
    }
    my $mid = $self->munge_id_for_formatdb($id);

    open(P, "$FIG_Config::ext_bin/fastacmd  -d $nr -p T -s '$mid' -l $line_len |");
    $_ = <P>;
    # discard ID line

    my @out = <P>;
    if (!close(P))
    {
	my $rc = $?;
	if (WIFEXITED($rc))
	{
	    my $code = WEXITSTATUS($rc);

	    if ($code == 2)
	    {
		warn "fastacmd did not find database $nr\n";
		warn "fastacmd  -d $nr -p T -s '$mid' -l $line_len |\n";
	    }
	    elsif ($code == 3)
	    {
		warn "Search for $mid in $nr failed\n";
	    }
	    else
	    {
		warn "fastacmd failed with status $code\n";
	    }
	}
	elsif (WIFSIGNALED($rc))
	{
	    my $sig = WTERMSIG($rc);
	    warn "fastacmd died from signal $sig\n";
	}
	else
	{
	    warn "fastacmd died with return code $rc\n";
	}
	return;
    }
    #
    # $line_len == 0 implies we want the raw data, unformatted. So chomp any newlines.
    #
    if ($line_len == 0)
    {
	chomp(@out);
    }
    if (wantarray)
    {
	return @out;
    }
    else
    {
	return join("", @out);
    }
}


sub munge_id_for_formatdb
{
    my($self, $id) = @_;
    
    if ($id =~ /^gi/)
    {
    }
    elsif ($id =~ /^ref|sp|gb/)
    {
	$id = "$id|";
    }
    elsif ($id =~ /\|/)
    {
	$id = "gnl|$id";
    }
    else
    {
	$id = "lcl|$id";
    }
    return $id;
}


sub lookup_id
{
    my($self, $id) = @_;

    #
    # Find principal syn for the id.
    #
    my $pid = $self->lookup_principal_id($id);

    return $self->expand_block($pid);
}

#
# Look up an id for this suffix. There may be multiple.
#
sub lookup_id_from_suffix
{
    my($self, $suffix) = @_;

    my $t = tied %{$self->{alias}};

    my $key = $suffix;
    my $value;
    my @ret;
    for (my $status = $t->seq($key, $value, R_CURSOR); $status == 0 and $key eq $suffix;
	 $status = $t->seq($key, $value, R_NEXT))
    {
	push(@ret, $value) if $value ne $suffix;
    }
    return @ret;
}


#
# Look up an id for this prefix. There may be multiple.
#
sub lookup_id_from_prefix
{
    my($self, $prefix) = @_;

    my $t = tied %{$self->{ps_from}};

    my $key = $prefix;
    $prefix =~ s /\|/\\\|/;
    my $value;
    my @ret;
    for (my $status = $t->seq($key, $value, R_CURSOR); $status == 0 and $key =~/^$prefix/;
	 $status = $t->seq($key, $value, R_NEXT))
    {
     
	push(@ret, [$value , $key , $prefix] );
    }
    return @ret;
}

#
# Get all synonyms for a given prefix. There may be multiple.
# Returns an array. Each entry in the array is of the form
# LENGHT_XXX:XXX_ID:LENGHT_SYN:SYN_ID:PRIMARY_ID:PREFIX
#
sub get_synonyms_for_prefix
{
    my($self, $prefix) = @_;

    my $t = tied %{$self->{ps_from}};

    my $key = $prefix;
    $prefix =~ s /\|/\\\|/;
    print STDERR $key,"\t","$prefix\n";
    my $value;
    my @ret;
    for (my $status = $t->seq($key, $value, R_CURSOR); $status == 0 and $key =~/^$prefix/;
	 $status = $t->seq($key, $value, R_NEXT))
    {
      my ($length , $xxx) = split ":" , $value ;
      foreach my $sid ( @{ $self->expand_block($xxx) } ){
	push(@ret, $value.":".$sid->[1].":".$sid->[0].":".$key.":".$prefix);
      }
    }
    return @ret;
}

sub lookup_principal_id
{
    my($self, $id) = @_;

    #
    # Find principal syn for the id.
    #
    my $ent = $self->{ps_from}->{$id};

    if (!$ent)
    {
	if ($self->{org}->{$id})
	{
	    return wantarray ? ([$id, $id]) : $id;
	}
	else
	{
	    #
	    # Try an alias lookup
	    #
	    my @a = $self->lookup_id_from_suffix($id);
	    if (@a == 0)
	    {
		return;
	    }
	    elsif (wantarray)
	    {
		return map { [$_, scalar $self->lookup_principal_id($_) ]} @a;
	    }
	    elsif (@a == 1)
	    {
		return $self->lookup_principal_id($a[0]);
	    }
	    else
	    {
		#
		# See if the aliases resolve to different principal ids. If they
		# do, bail. If not, return a representative.
		#
		my @all = map { [$_, scalar $self->lookup_principal_id($_) ]} @a;
		my %targets = map { $_->[1] } @all;
		if (%targets == 1)
		{
		    return $all[0]->[1];
		}
		else
		{
		    die "multiple aliases for $id: @a";
		}
	    }
	}
    }
    my($len, $pid) = split(/:/, $ent, 2);

    return wantarray ? ([$id, $pid]) : $pid;
}

sub expand_block
{
    my($self, $prin_id) = @_;

    my $ent = $self->{ps_to}->{$prin_id};

    if (!$ent)
    {
	my $len = $self->{nr_len}->{$prin_id};
	return [[$prin_id, $len]];
    }

    my($to_len, $from) = split(/:/, $ent, 2);
    my @from = map { [ split(/,/, $_) ] } split(/;/,$from);

    return \@from;
}

sub search
{
    my($self, $str, $limit) = @_;

    $str =~ s/\|/\\|/g;

    my @args;

    if ($limit =~ /^\d+$/)
    {
	push(@args, "-L", $limit);
    }

    push(@args, "-w", "-y", "-i", $str);

    
    
    my $src = "-H $self->{index_dir}";
#    $src = "-C";

#    open(G, "$FIG_Config::ext_bin/glimpse $limit_arg -w -y $src -i '$str'|") or die "glimpse failed: $!\n";

    #
    # First try glimpse server.
    #

    open(G, "-|", "$FIG_Config::ext_bin/glimpse", "-C", @args) or die "Glimpse failed: $!\n";

    my(@res) = $self->handle_glimpse_output(\*G);

    if (!close(G))
    {
	my $rc = $?;

	if (WIFEXITED($rc))
	{
	    my $code = WEXITSTATUS($rc);
	    if ($code == 2)
	    {
		#
		# We probably couldn't get to the glimpse server. Rerun with file-based index.
		#
		
		warn "glimpseserver failed\n";
		open(G, "-|", "$FIG_Config::ext_bin/glimpse", "-H", $self->{index_dir}, @args) or die "Glimpse failed: $!\n";
		
		@res = $self->handle_glimpse_output(\*G);
		
		if (!close(G))
		{
		    my $rc = $?;
		    if (WIFEXITED($rc) && WEXITSTATUS($rc) == 1)
		    {
			# no results
			return @res;
		    }
		    else
		    {
			die "Error running glimpse -H $self->{index_dir} @args: rc=$?";
		    }
		}
	    }
	    elsif ($code == 1)
	    {
		# no results.
		return @res;
	    }
	    else
	    {
		die "Error running glimpse -C @args: exitcode=$code";
	    }
	}
	else
	{
	    die "Error running glimpse -C @args: rc=$rc";
	}
    }

    return @res;

}

sub handle_glimpse_output
{
    my($self, $fh) = @_;

    # output looks like
    # /scratch/nr/KEGG/assigned_functions: kegg|mmc:Mmcs_4982	histidinol-phosphate aminotransferase

    my @res;
    while (<$fh>)
    {
	chomp;
	if (m,([^/]+)/assigned_functions:\s+(\S+)\s+(.*),)
	{
	    push(@res, [$2, $1, $3]);
	}
	elsif (m,seed\.assigned_functions:\s+(\S+)\s+(.*),)
	{
	    push(@res, [$1, 'SEED', $2]);
	}
    }
    return @res;
}

sub get_experts{
  my($self) = @_;
  
  my $key = '';
  my $val;
  
  my $t = tied %{$self->{contrib}};
  my $rc = $t->seq($key, $val, R_CURSOR);
  
  # try to get a connection to user database if logins have to be resolved
  my $dbm;

  require DBMaster;
  eval { $dbm = DBMaster->new(-database => 'WebAppBackend',
			      -backend  => 'MySQL',
			      -host     => 'bio-app-authdb.mcs.anl.gov' ,
			      -user     => 'mgrast',); };
  if ($@) {
    warn ">>> Connect to user database failed: $@";
  }
  
  
  
  my $users = {};
  while ($rc == 0) {
    
    my($pid, $xid, $xuser) = split(/$;/, $key);
    
    if (!exists($users->{$xuser})) {
      $users->{$xuser} = $xuser;
      
      # if there's a user database connection, try to resolve logins
      if ($dbm) {
	my $user = $dbm->User->init({ login => $xuser });
	if (ref $user) {
	  $users->{$xuser} = $user->firstname.' '.$user->lastname;
	}
	else {
	  warn ">>> Cannot resolve user login '$xuser'.";
	}
      }
    }
    $rc = $t->seq($key, $val, R_NEXT);
  }

  return $users;
}

# alter id prefixes for expert ids, to be consistend with the nr

sub alter_id_prefix{ 
  my($self, $user, $file, $timestamp , $prefix_mapping) = @_;
  
  my $count = 0;
  
  # take filehandle or filename

  print STDERR "Reading $file from $user. Timestamp is $timestamp.\n";
  unless (ref $file) {
    $file = IO::File->new("<$file") or
      die "Cannot open anno file $file: $!";
  }
  
 
  
  my $user_dir = "$self->{contrib_dir}/$user";
  &FIG::verify_dir($user_dir);
  
  #
  # 
  #
  
  my $save_corr = "$user_dir/anno.corrected_prefix";
  my $save_orig = "$user_dir/anno.orig.unchanged." . $timestamp;
  
  #open (CORR, ">$save_orig") or die "Can't open $save_orig!\n";
  
  while ( my $line = <$file> ){
    
    my @prefixes = $line =~ m/(\w+)\|[^\s]/gc;
    
    if (scalar @prefixes){
      #print $line , "";
      #print join " " , @prefixes , "\n";
      
      foreach my $prefix (@prefixes){
	
	my $new_prefix = $prefix_mapping->{ $prefix };
	next unless $new_prefix;
	
	$line =~ s/$prefix\|/$new_prefix\|/gc;
	
      }
    }
    
    #print $line , "\n";
    $count++;
    }
 
  return $count;
}
  
 


sub get_source_list{
  my ($self) = @_;

  my $dir = $self->{ dir }."/NR";
  my @sources;

  my $dh = DirHandle->new( $dir );
  while (defined($_ = $dh->read())) {
    next unless (-d "$dir/$_" and /^[^\.]+$/);
    push @sources , $_ ;
  }
  return \@sources
}

sub dump_source_data{
  my ($self , $source , $organism) = @_;

  print STDERR "Sources : " , join " " , @{ $self->get_source_list } , "\n";

  my $dir = $self->{ dir } ."/NR/$source/";

  
  # read all ids and functions

  open ( FUNC , "$dir/assigned_functions") or die "Can't open $dir/assigned_functions!\n";

  my %id2func;

  while (my $line = <FUNC>){
    chomp $line;
    my ($id, $func) = split "\t" , $line;
    $id2func{ $id }{ func } = $func ;
  }

  # read ids and organism mapping and map to function
 
  open ( ORG , "$dir/org.table") or die "Can't open $dir/org.table!\n";

  

  while (my $line = <ORG>){
    chomp $line;
    my ($id, $org) = split "\t" , $line;
     $id2func{ $id }{ org } = $org ;
  }

  return \%id2func
}


#
# returns a predefined set of mappings. 
# Old/unsupported prefixes are mapped 
# to current/supported prefixes.
# return { old_prefix => "new_prefix" } 
#

sub get_prefix_mapping{
  my ($self) = @_;

  my $mapping = {
		 
		};

   
  return $mapping
}

#
# search clearinghouse nr and return all
# id prefixes with source info
#

sub get_prefixes_from_nr{
  my ($self) = @_;
  my %prefixes;
  
  my $sources = $self->get_source_list;
  
  foreach my $source (@$sources){
    print STDERR "Reading $source\n";
    
    my $dir = $self->{ dir } ."/NR/$source/";
    
    # read all ids and functions and strip prefixes
    
    open ( FUNC , "$dir/assigned_functions") or die "Can't open $dir/assigned_functions!\n";
    
    
    
    while (my $line = <FUNC>){
      
      my ($id, $func) = split "\t" , $line;
      my ($prefix) = $id =~ /([^\|]+)/;
      # print STDERR "$prefix\t$id\n";
      $prefixes{ $prefix }{$source} = 1;
    }
  
  }
  return \%prefixes
}

#
# query expert annotations and return id prefixes used by experts
#

sub get_prefixes_from_expert_ids{
  my ($self) = @_;

  my %prefixes;
  my $files;

  my $contrib_dir = $self->{contrib_dir};

  my $dh = DirHandle->new( $contrib_dir );
  while (defined($_ = $dh->read())) {
    
    next unless (-d "$contrib_dir/$_" and /^[^\.]+$/);
    
    my $user = $_;
    my $path = "$contrib_dir/$_";
    
    my $idh  = DirHandle->new($path);
    while (defined($_ = $idh->read())) {
      
      next unless (/^anno\.\d+$/ or /^anno\.orig\.\d+/);
      push @$files, [ $user, "$path/$_" ];
      
    }
  }
  
  
  foreach my $f (@$files) {
    
    my ($user, $file) = @$f;
    print STDERR "Reading $file from $user\n";
    open (FILE , "$file" ) or die "Can't open $file\n";
    
    while ( my $line = <FILE>){
 
      my @ids = $line =~ /([^\s]+\|[^\s]+)/gc;
     
      foreach my $id ( @ids ){
	my ($prefix) = $id =~ /([^\|]+\|)/;
	$prefixes{ $prefix }{ $user } = 1;
      }
    }
    close FILE;
    
  }
  return \%prefixes
}


##### DB stuff #########

### add_user_annotation ########

sub add_user_annotation{
  my ($self , $id , $annotation , $md5 , $expert , $link) = @_;

  my $results;
  my $dbh = $self->{dbh};
  
  $annotation=~s/`/\\`/gc;
  $annotation=~s/'/\\'/gc;
  
  unless ($expert){
    print STDERR "Error: No Expert, can not add user assertions!\n";
    return 0;
  }

  # check for existing entry and update or create new one
  if ($annotation){
     my $table = "Assertion";
     $table = "ACH_Assertion" if ($dbh->table_exists('ACH_Assertion') );

     my $statement = "SELECT * FROM $table WHERE id='$id' AND md5='$md5' AND expert='$expert'";
     my $results = $dbh->SQL($statement);
     
     if (ref $results and scalar @$results){
       $results = $dbh->SQL("UPDATE $table SET function=? , url='$link' where id='$id' and md5='$md5' and expert='$expert'"  , 0 , $annotation);
     }
     else{
       $results = $dbh->SQL("INSERT INTO $table (id ,function , md5 ,expert , url ) VALUES ('$id' , ? , '$md5' , '$expert' , '$link')" , 0 , $annotation);
     }
     
     $self->add2correspondences($md5,$expert,$annotation)
  }
  # if empty annotation then delete entry
  else{
    my $table = "Assertion";
    $table = "ACH_Assertion" if ($dbh->table_exists('ACH_Assertion') );
    
    my $statement = "DELETE FROM $table WHERE id='$id' AND md5='$md5' AND expert='$expert'";
    my $results = $dbh->SQL($statement);
    
    return $results;
  }

 

  return ;
}

sub add2correspondences{
  my ($self , $md5 , $exp, $func) = @_;
  my $dbh = $self->db_handle;
  my $conflict = 0;
  

  print STDERR "MSG: Adding correspondences.\n";
  my $statement = "SELECT expert, function FROM ACH_Assertion WHERE md5='$md5' and expert!='$exp' and function!='' ";
  my $results = $dbh->SQL($statement);

  if  (ref $results and scalar @$results){
      print STDERR "MSG: more than one expert assertion for block\n";
    foreach my $assertion (@$results){
      if ($func ne $assertion->[1]){
	my @diffs = sort ( $func , $assertion->[1] );


	my $statement = "SELECT * FROM ACH_Correspondence WHERE function1=? and function2=?";
	print STDERR $statement ,"\n";
	
	my $results = $dbh->SQL($statement , 0 , $diffs[0] , $diffs[1] );

	unless (ref $results and scalar @$results){
	  $results = $dbh->SQL("INSERT INTO ACH_Correspondence (function1 , function2, status ) VALUES ( ? , ? , '')" , 0 , $diffs[0] , $diffs[1] );
	  $conflict = 1;
	}
       }
    }
  }

  
  return $conflict;
}


sub get_diffs_for_user {
  my ($self , $user) = @_;

  
  return unless ($user);
  my $dbh  = $self->db_handle;
  


 
  
  my $diffs;
  
  if ($user){
    
    my $statement = "select ACH_Correspondence.function1, ACH_Correspondence.function2, ACH_Correspondence.status from ACH_Correspondence, ACH_Assertion where ( ACH_Correspondence.function1=ACH_Assertion.function or ACH_Correspondence.function2=ACH_Assertion.function ) and ACH_Assertion.expert='".$user."' and ACH_Correspondence.status=''";
    
    $diffs = $dbh->SQL($statement); 
  }
  
  foreach my $tuple (@$diffs) {
      if ($tuple->[2] eq "s") {  $tuple->[2] = "same" }
      elsif ($tuple->[2] eq "d") { $tuple->[2] = "different" }
      elsif ($tuple->[2] eq "i") { $tuple->[2] = "ignore" } 
      elsif ($tuple->[2] eq "") { $tuple->[2] = "unhandled" } 
  }
  
  return $diffs;
}

sub md5_of_peg {
    my( $self, $peg ) = @_;
    
    # print STDERR $peg , "\n";

    return undef if ! $peg;

    #  Try to find it in the DBMS

    my $dbh = $self->db_handle;
    my $response;
    print STDERR "No db_handle\n" unless ($dbh);
#    print  STDERR "Table : " , $dbh->table_exists('ACH_ID2Group') , "\n";
#    print STDERR "Check done\n";

    if ( $dbh and $dbh->table_exists('ACH_ID2Group') ){
	print STDERR "table found \n";
      $response = $dbh->SQL( "SELECT md5 FROM ACH_ID2Group WHERE id = '$peg' group by md5" ); 
      if ($response and scalar @$response > 1){
	print STDERR "Error: Different checksums for same ID, exit.";
      }
      
    }
    elsif ( $dbh->table_exists(' protein_sequence_MD5') ) {
	print STDERR "Check table protein_sequence_MD5 \n";
      $response = $dbh->SQL( "SELECT md5 FROM protein_sequence_MD5 WHERE id = '$peg'" );
    }
    print STDERR "Response $response\n";
    return $response->[0]->[0] if ($response && @$response==1);

    #  Try to make it from the translation

    print STDERR "MSG: getting sequence for $peg \n";

    my $sequence = $self->get_sequence( $peg );
    print STDERR "No Sequence for $peg\n" unless($sequence);
    return undef unless ($sequence );

    #  Got a sequence, find the md5, save it in the DBMS, and return it

    my $md5 = Digest::MD5::md5_hex( uc $sequence );
    if ($dbh->table_exists('ACH_Sequence2MD5') ){
      $dbh->SQL( "INSERT INTO ACH_Sequence2MD5 ( sequence, md5 ) VALUES ( '$sequence', '$md5' )" );
    }
    else{
      $dbh->SQL( "INSERT INTO protein_sequence_MD5 ( id, md5 ) VALUES ( '$peg', '$md5' )" );
    }
    
    return $md5;
}

# translates an ID into another
# input is an ID and a type (e.g. gi)
# if type is empty returns all IDs
# returns a list of IDs of this type and the organisms 

sub get_corresponding_ids{
  my ( $self , $id , $type) = @_;
  my @results;
  
  my $pid = $self->lookup_principal_id($id);
  my @r = $self->get_annotations_by_pid($pid);
  
  foreach my $e (@r) {	
    my ($id, $source, $func, $org, $len) = @$e;
    
    
    if($type){

      # unify upper and lower cases
      lc($source);
      lc($type);
      my ($prefix) = $id =~ /(\w+)\|/;

      if ( $type eq $source or $type eq $prefix){
	my @pair;
	push @pair , $id , $org ;
	push @results , \@pair ;
      }
    }

    else{
      my @pair;
      push @pair , $id , $org ;
      push @results , \@pair ;
    }
    
  }
  return @results;
}

sub get_organism_name{
  my ($self , $id) = @_;

  my @results = $self-> get_corresponding_ids( $id );

  foreach my $r ( @results){
    return $r->[1] if ($r->[0] =~/$id/);
  }
}

sub db_handle{
  my ($self) = @_;
  return $self->{dbh}
}

1;
