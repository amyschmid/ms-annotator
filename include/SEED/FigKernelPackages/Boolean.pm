package Boolean;
use strict;
use Data::Dumper;

#####################
# There are two basic services
# 
#  my ($error,$compiled_rules) = &Boolean::compile_rules($roles,$definitions,$rules);
# 
# takes three strings as input.  Each string is a set of lines.
# 
#       $roles has lines containing the abbreviation and corresponding role.
#       $definitions are simple macros 
#       $rules contain variant codes and boolean expressions
# 
# These are compiled into a set of internal variables that support
# evaluation of the rules in the context of a set of identified
# roles.  The evaluation of the rule is achieved by
# 
#  my ($vc,$debug) = &Boolean::find_vc($compiled_rules,$roles_present);
# 
# The $vc will be set to the value specified in the first rule that succeeds.
# Otherwise it will be '-1'.
# 
# Here is an example of how it is intended to be used:
# 
# use Boolean;
# use strict;
# use Data::Dumper;
# 
# my $roles = '
# HutH Histidine ammonia-lyase (EC 4.3.1.3)
# HutU Urocanate hydratase (EC 4.2.1.49)
# HutI Imidazolonepropionase (EC 3.5.2.7)
# GluF Glutamate formiminotransferase (EC 2.1.2.5)
# HutG Formiminoglutamase (EC 3.5.3.8)
# NfoD N-formylglutamate deformylase (EC 3.5.1.68)
# NfoD2 N-formylglutamate deformylase (EC 3.5.1.68) [alternative form]
# ForI Formiminoglutamic iminohydrolase (EC 3.5.3.13)
# ForC Formiminotetrahydrofolate cyclodeaminase (EC 4.3.1.4)
# HutR1 Histidine utilization repressor
# HutR2 Hut operon positive regulatory protein
# HutT1 Histidine transport protein (permease)
# Hypo1 Conserved hypothetical protein (perhaps related to histidine degradation)
# ';
# 
# my $definitions = '
# *NfoD means NfoD or NfoD2
# *Alt3 means *NfoD and ForI
# *Req means HutH and HutU and HutI
# ';
# 
# my $rules = '
# 1.111 means *Req and GluF and HutG and *Alt3
# 1.101 means *Req and GluF and *Alt3
# 1.011 means *Req and HutG and *Alt3
# 1.001 means *Req and *Alt3
# 1.010 means *Req and HutG
# 1.100 means *Req and GluF
# missing means 3 of {HutH,HutU,HutI,1 of {GluF,HutG,*Alt3}}
# 0 means 2 of {HutH,HutU,HutI,1 of {GluF,HutG,*Alt3}}
# ';
# 
# my $roles_present = [
# 		     'Histidine ammonia-lyase (EC 4.3.1.3)',
#                      'Urocanate hydratase (EC 4.2.1.49)',
# 		     'Imidazolonepropionase (EC 3.5.2.7)',
# 		     'Glutamate formiminotransferase (EC 2.1.2.5)',
# 		     'N-formylglutamate deformylase (EC 3.5.1.68)',
# 		     'Formiminoglutamic iminohydrolase (EC 3.5.3.13)',
# 		     'Formiminoglutamase (EC 3.5.3.8)'
# 		     ];
# 
# my ($err,$parsed_rules) = &Boolean::compile_rules($roles,$definitions,$rules);
# 
# if ($err)
# {
#     print "ERROR: $err\n";
# }
# else
# {
#     my $vc = &Boolean::find_vc($parsed_rules,$roles_present);
#     print "vc = $vc\n";
# }
# 
# 
# find_vc supports an additional argument, which if it is "true" produces
# a record of the logical expressions that were evaluate and what they evaluated
# to.  This can produce quite a bit of output, but it is useful to figure out
# which rule (for example) is malformed.
# 
############################################

sub compile_rules {
    my($roles,$definitions,$rules) = @_;

    my $error = '';
    my $comment = '';
    my $encoding = [[],0];   # Encoding is a 2-tuple [Memory,NxtAvail]
    my $abbrev_to_loc = {};
    my $rulesP;

    my %roles_to_abbrev;
    foreach $_ (split(/\n/,$roles))
    {
	if ($_ =~ /^(\S+)\s+(\S.*\S)\s*$/)
	{
	    my($abbrev,$role) = ($1,$2);
	    $roles_to_abbrev{$role} = $abbrev;
	    my $loc = &add_to_encoding($encoding,['role',$role]);
	    $abbrev_to_loc->{$abbrev} = $loc;
	    if ($ENV{'debug'})
	    {
		print STDERR "added abbrev: $abbrev, loc=$loc\n";
	    }
	}
    }
    my @roles = keys(%roles_to_abbrev);
    if (keys(%roles_to_abbrev) < 1)
    {
	$error .= "Roles are invalid<BR>";
    }
    else 
    {
	my ( $puterror, $rc ) = &parse_definitions($encoding,$abbrev_to_loc,$definitions);
	$error .= $puterror;
	if ( ! $rc || $puterror ne '' ) 
	{
	    $error .= "<br>Definitions are invalid";
	}
	else 
	{
	    if ($ENV{'debug'})
	    {
		print STDERR &Dumper(['encoded',$encoding]);
	    }
	    ($_, $rulesP ) = &parse_rules($encoding,$abbrev_to_loc,$rules);
	    $error .= $_;
	    if ( @$rulesP < 1 || $_ ne '' ) 
	    {
		$error .= "<br>There are invalid rules, please go back and fix this!";
	    }
	    else
	    {
		if ($ENV{'debug'})
		{
		    print STDERR &Dumper(['rules',$rulesP]);
		}
	    }

	}
    }
    return ($error,($error ? undef : [$encoding,$abbrev_to_loc,$rulesP]));
}
      
sub find_vc {
    my($compiled,$roles_present) = @_;
    my( $encoding,$abbrev_to_loc,$rules) = @$compiled;

    my $vcT = undef;
    my %roles_present = map { $_ => 1 } @$roles_present;
    my $debug = [];
    my $matched;
    for ( my $i = 0, $matched = undef; ( ! defined( $matched ) ) && ( $i < @$rules) ; $i++ ) 
    {
	$matched = &is_rule_true( $rules->[$i], \%roles_present,$debug );
    }
  
    return ((defined( $matched ) ? $matched : -1), join("",@$debug));
}

sub add_to_encoding {
    my($encoding,$val) = @_;

    my($mem,$nxt) = @$encoding;
    $mem->[$nxt] = $val;
    $encoding->[1]++;
    return $nxt;
}

sub parse_definitions {
  my ( $encoding, $abbrev_to_loc, $defI ) = @_;

  my $rc = 1;
  my $error = '';

  foreach my $def ( split(/\n/,$defI) ) 
  {
    $def =~ s/\t/ /g;
    if ( $def =~ /^(\S+)\s+(means )?(\S.*\S)/ ) 
    {
	my ( $abbrev, $bool ) = ( $1, $3 );
      
	my $loc = &parse_bool( $bool, $encoding, $abbrev_to_loc );
	if (defined($loc))
	{
	    $abbrev_to_loc->{$abbrev} = $loc;
	    if ($ENV{'debug'})
	    {
		print STDERR "added abbrev: $abbrev, loc=$loc\n";
	    }
	}
	else
	{
	    $error .= "<br>Invalid Definition: $def";
	    $rc = 0;
	}
    }
    elsif ( $def =~ /\S/ ) {
      $error .= "<br>Invalid Definition: $def";
      $rc = 0;
    }
  }
  return ( $error, $rc );
}

sub parse_rules {
    my ( $encoding, $abbrev_to_loc, $rulesI ) = @_;

    my @rulesI = (ref $rulesI) ? @$rulesI : split(/\n/,$rulesI);
    my $error = '';
    my @rules = ();
    foreach my $thisrule ( @rulesI ) 
    {
	my ( $boolexp, $variant_code, $loc );
	$thisrule =~ s/\t/ /g;
	if ( ( $thisrule =~ /^\s*(\S+)\s+(means )?(\S.*\S)\s*$/ ) &&
	     ( ( $variant_code, $boolexp ) = ( $1,$3 ) ) &&
	     defined( $loc = &parse_bool( $boolexp, $encoding, $abbrev_to_loc ) ) ) 
	{
	    push( @rules, [ $variant_code, [ $encoding->[0], $loc ] ] );
	}
	elsif ( $thisrule =~ /\S/ ) {
	    $error .= "<br>Invalid rule: $thisrule\n";
	}
    }
    return ( $error, \@rules );
}

sub parse_bool {
    my ( $s, $encoding, $abbrev_to_loc ) = @_;

    foreach my $abbrev ( sort { length($b) <=> length($a) } keys( %$abbrev_to_loc ) ) {
      my $loc = $abbrev_to_loc->{$abbrev};
      my $abbrevQ = quotemeta $abbrev;
      while ($s =~ s/(^|[\s\{,(])($abbrevQ)($|[\s\},)])/$1<$loc>$3/) {}
    }
    my $got = 0;
    my $counter = 0;
    while ( $s !~ /^\s*<\d+>\s*$/ ) {
      $counter ++;
      # this last is just for preventing the process from running amok #
      last if ( $counter > 1000 );
	my $nxt = $encoding->[1];

	if ( $s =~ s/\(\s*(<\d+>)\s*\)/$1/ ) {
	  $got = 1;
	}
	elsif ( $s =~ s/not\s+<(\d+)>/<$nxt>/ ) {
	  &add_to_encoding( $encoding, [ "not", $1 ] );
	  $got = 1;
	}
	elsif ( $s =~ s/<(\d+)>\s+and\s+<(\d+)>/<$nxt>/ ) {
	  &add_to_encoding( $encoding, [ "and", $1, $2 ] );
	  $got = 1;
	}
	elsif ( $s =~ s/<(\d+)>\s+or\s+<(\d+)>/<$nxt>/ ) {
	  &add_to_encoding( $encoding, [ "or", $1, $2 ] );
	  $got = 1;
	}
	elsif ( $s =~ s/<(\d+)>\s+->\s+<(\d+)>/<$nxt>/ ) {
	  &add_to_encoding( $encoding, [ "->", $1, $2 ] );
	  $got = 1;
	}
	elsif ( $s =~ s/(\d+)\s+of\s+\{\s*(<\d+>(,\s*<\d+>)*)\s*\}/<$nxt>/ ) {
	  my $n = $1;
	  my $args = $2;
	  my @args = map { $_ =~ /<(\d+)>/; $1 } split( /,\s*/, $args );
	  &add_to_encoding( $encoding, [ "of", $n, [@args] ] );
	  $got = 1;
	}
	last if ( ! $got );
    }

    return ( $s =~ /^\s*<(\d+)>\s*$/) ? $1 : undef;
}

sub is_rule_true {
    my( $rule, $roles_present,$debug ) = @_;

    my ( $variant,$exp ) = @$rule;
    return &is_true_exp( $exp, $roles_present,$debug ) ? $variant : undef;
}

sub is_true_exp {
    my($bool,$roles_present,$debug) = @_;

    my $rc;
    my($nodes,$root) = @$bool;
    my $val = $nodes->[$root];
    if (! ref  $val) 
    { 
	return &is_true_exp([$nodes,$val],$roles_present,$debug);
    }
    else
    {
	my $op = $val->[0];
	if ($op eq 'role')
	{
	    my $x;
	    $rc =  ($roles_present->{$val->[1]}) ? 1 : 0;
	    if ($debug)
	    {
		if ($rc ) { push(@$debug,"$val->[1] is present\n") }
		else      { push(@$debug,"$val->[1] is not present\n") }
	    }
	}
	elsif ($op eq "of")
	{
	    my $truth_value;
	    my $count = 0;
	    foreach $truth_value (map { &is_true_exp([$nodes,$_],$roles_present,$debug) } @{$val->[2]})
	    {
		if ($truth_value) { $count++ }
	    }
	    if ($debug)
	    {
		my $bool1 = &printable_bool($bool);
		push(@$debug,"$bool1: ");
		if ($count >= $val->[1]) { push(@$debug,"$count of $val->[1], so it succeeds\n") }
		else                     { push(@$debug,"$count of $val->[1], so it fails\n") }
	    }
	    $rc =  $val->[1] <= $count;
	}
	elsif ($op eq "not")
	{
	    $rc = &is_true_exp([$nodes,$val->[1]],$roles_present,$debug) ? 0 : 1;
	    if ($debug)
	    {
		my $bool1 = &printable_bool($bool);
		push(@$debug,("$bool1: ", $rc ? " succeeds" : " fails","\n"));
	    }
	}
	else
	{
	    my $v1 = &is_true_exp([$nodes,$val->[1]],$roles_present,$debug);
	    my $v2 = &is_true_exp([$nodes,$val->[2]],$roles_present,$debug);

	    if    ($op eq "and") { $rc =  ($v1 && $v2) }
	    elsif ($op eq "or")  { $rc =  ($v1 || $v2) }
	    elsif ($op eq "->")  { $rc =  ((not $v1) || $v2) }
	    else 
	    {
		print STDERR &Dumper($val,$op);
		die "invalid expression";
	    }
	    if ($debug)
	    {
		my $bool1 = &printable_bool($bool);
		push(@$debug,("$bool1: ", $rc ? " succeeds" : " fails","\n"));
	    }
	}
    }
    return $rc;
}

sub print_bool {
    my($bool) = @_;

    my $s = &printable_bool($bool);
    print $s,"\n";
}

sub printable_bool {
    my($bool) = @_;

    my($nodes,$root) = @$bool;
    my $val = $nodes->[$root];

    if (! ref  $val) 
    { 
	return &printable_bool([$nodes,$val]);
    }
    else
    {
	my $op = $val->[0];

	if ($op eq 'role')
	{
	    return $val->[1];
	}
	elsif ($op eq "of")
	{
	    my @expanded_args = map { &printable_bool([$nodes,$_]) } @{$val->[2]};
	    my $args = join(',',@expanded_args);
	    return "$val->[1] of {$args}";
	}
	elsif ($op eq "not")
	{
	    return "($op " .  &printable_bool([$nodes,$val->[1]]) . ")";
	}
	else
	{
	    return "(" . &printable_bool([$nodes,$val->[1]]) . " $op " . &printable_bool([$nodes,$val->[2]]) . ")";
	}
    }
}

1;
