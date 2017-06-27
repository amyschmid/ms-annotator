package FFB3;

use base 'Exporter';

#
# Utility object for Figfam building (Rel3) code.
#

use strict;
use FIG;

use IPC::Run qw(start finish reap_nb run);
use base 'Class::Accessor';
use DB_File;
use POSIX ":sys_wait_h";

__PACKAGE__->mk_accessors(qw(build_dir fig fh chunksize n_written file_idx tmp_dir files pending sort_cmd));

sub new
{
    my($class, $build_dir, $fig) = @_;

    my $af_file = "$build_dir/assigned_functions.btree";
    my $hash = {};
    if (!tie %$hash, 'DB_File', $af_file, O_RDONLY, 0, $DB_BTREE)
    {
	warn "Could not tie $af_file: $!";
    }

    my $tr_file = "$build_dir/translation.btree";
    my $tr_hash = {};
    if (!tie %$tr_hash, 'DB_File', $tr_file, O_RDONLY, 0, $DB_BTREE)
    {
	warn "Could not tie $tr_file: $!";
    }

    my $self = {
	build_dir => $build_dir,
	assigned_functions => $hash,
	translations => $tr_hash,
	fig => $fig,
	fh => {},
	chunksize => 1_000_000,
	sort_cmd => ["sort", "-S", "100M"],
	n_written => {},
	file_idx => {},
	files => {},
	pending => [],
    };

    
    return bless $self, $class;
}

sub function_of
{
    my($self, $fid) = @_;
    return $self->{assigned_functions}->{$fid};
}

sub get_translation
{
    my($self, $fid) = @_;
    return $self->{translations}->{$fid};
}

sub function_of_filtered
{
    my($self, $fid) = @_;
    my $func = $self->{assigned_functions}->{$fid};

    $func =~ s/\s*$//;
    $func =~ s/^\s*//;
    $func =~ s/^FIG\d+ \(not subsystem-based\): //;
    $func =~ s/\s+\#[^\#].*//;

    return $func;
}

sub bundle_write
{
    my($self, $char, $str) = @_;

    my $ent = $self->fh->{$char};

    if ($self->n_written->{$char} >= $self->chunksize)
    {
	$self->bundle_close($char);
	undef $ent;
	$self->bundle_check();
	$self->n_written->{$char} = 0;
    }
    if (!$ent)
    {
	$ent = $self->bundle_open($char);
    }
    my $fh = $ent->{fh};
    print $fh $str;
    $self->n_written->{$char}++;
}

sub bundle_open
{
    my($self, $char) = @_;

    my $idx = $self->file_idx->{$char} + 0;
    my $file = sprintf($self->tmp_dir . "/bundle.$char.%05d", $idx);
    print "Write to $file\n";
    $self->file_idx->{$char} = $idx + 1;

    push @{$self->files->{$char}}, $file;

    my($rpipe, $wpipe);
    pipe($rpipe, $wpipe);

    my $pid = fork;
    if ($pid == 0)
    {
	open(STDIN, "<&", $rpipe) or die "Cannot dup stdin: $!";
	close($rpipe);
	close($wpipe);
	open(STDOUT, ">", $file) or die "Cannot write $file: $!";
	exec(@{$self->sort_cmd});
	die "exec failed: $!";
    }

    close($rpipe);
    my $ent = { fh => $wpipe, file => $file, pid => $pid };
    $self->fh->{$char} = $ent;
    return $ent;
}

sub bundle_close
{
    my($self, $char) = @_;
    my $ent = $self->fh->{$char};
    return unless $ent;
    $ent->{fh}->close;
    delete $self->fh->{$char};
    push @{$self->pending}, $ent;
}

sub bundle_check
{
    my($self) = @_;
    my @np;
    for my $ent (@{$self->pending})
    {
	my $r = waitpid($ent->{pid}, WNOHANG);
	if ($r)
	{
	    print "Wait $ent->{pid} returns $r err=$?\n";
	}
	else
	{
	    push(@np, $ent);
	}
    }
    @{$self->pending} = @np;
}
    
sub bundle_finish
{
    my($self, $out_dir) = @_;
    for my $char (keys %{$self->fh})
    {
	$self->bundle_close($char);
    }
    
    for my $ent (@{$self->pending})
    {
	print "Wait for $ent->{pid}\n";
	my $r = waitpid($ent->{pid}, 0);
	if ($r)
	{
	    print "Wait $ent->{pid} returns $r err=$?\n";
	}
    }

#    pareach [ keys %files ], sub {
#	my $char = shift;
    for my $char (keys %{$self->files})
    {
	my $out = "$out_dir/all.$char";

	my @files = @{$self->files->{$char}};
	my $r = run ["sort", "-m", @files], ">", $out;
	print "run for @files returns $r\n";
#	my $cmd = "ls -l @files; sort -m @files > $out";
#	my $rc = system($cmd);
#	print "rc=$rc: $cmd\n";
    }
}
    
1;
