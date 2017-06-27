package ContigMD5;

#
# Little class to normalize & compute contig MD5 checksums.
#
#
# We throw away > fasta identifier lines, as well as whitespace. It is
# incumbent on the user of this class to stop sending it data when the
# end of the sequence is reached.
#

use strict;
use Digest::MD5;

sub new
{
    my($class) = @_;

    my $self = {
	digest => new Digest::MD5->new(),
    };

    return bless $self, $class;
}

sub add
{
    my($self, $txt) = @_;

    $txt =~ s/^>[^\n]*\n//m;
    $txt =~ s/\s*//g;
    $self->{digest}->add(lc($txt));
}

sub checksum
{
    my($self) = @_;
    return $self->{digest}->clone()->hexdigest;
}
1;
