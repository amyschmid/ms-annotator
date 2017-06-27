package CrossSeedLinks;

use strict;
use FIGjs;

sub script {qq(<SCRIPT Language="JavaScript" Type="text/javascript" Src="./Html/css/FIG.js"></SCRIPT>)}

#
#    $multilink = multilink( $cgi, $fid, \@seeds, \%opts )
#    $multilink = multilink( $cgi, $fid,          \%opts )
#
#    @seeds = ( [ $name, $base_url ], ... )
#
sub multilink
{
    my $opts = ref($_[-1]) eq 'HASH' ? pop : {};

    my ( $cgi, $fid, $seeds ) = @_;
    return $fid unless $cgi && $fid;

    my $link = onelink( $cgi, $fid );

    if ( ! ( $seeds && ref($seeds) eq 'ARRAY' && @$seeds ) )
    {
        eval { require FIG_Config; $seeds = $FIG_Config::seeds; }
    }

    if ( $seeds && ref( $seeds ) eq 'ARRAY' && @$seeds )
    {
        my $names = join '<BR />', map { $_->[0] } @$seeds;

        my $links = join '<BR />', 'Link to:',
                                    map { onelink( $cgi, $fid, $_, $opts ) }
                                    @$seeds;

        # my $tip = FIGjs::mouseover( $title, $text, $menu, $parent, $hc, $bc );
        my $tip = FIGjs::mouseover( 'Available SEEDs', $names, $links, '', '#CC6622', '#FFCC88' );

        $link .= qq( <SPAN $tip Style="background-color: #FFCC88;">&nbsp;&#x2638;&nbsp;</SPAN>);
    }

    $link;
}


#
#  $link = onelink( $cgi, $fid, $host, \%opts )
#  $link = onelink( $cgi, $fid,        \%opts )
#
sub onelink
{
    my $opts = ref($_[-1]) eq 'HASH' ? pop : {};

    my ( $cgi, $fid, $host ) = @_;

    $fid =~ /^fig\|\d+\.\d+\.([^.]+)\.\d+$/
        or return $fid;
    my $prot = $1 eq 'peg';

    my ( $name, $base ) = ref($host||'') eq 'ARRAY' ? @$host
                                                    : ( $fid, '.' );

    my $seed = $opts->{seed};

    my @params = ( '' );

    my $user = $cgi->param('user');
    push @params, "user=$user" if $user;

    my $params = join( '&', @params );

    my $url = ! $seed ? "$base/seedviewer.cgi?page=Annotation&feature=$fid" . $params
            :   $prot ? "$base/protein.cgi?prot=$fid"                       . $params
            :           "$base/feature.cgi?feature=$fid"                    . $params;

    my $tag = qq(A HRef="$url");
    $tag   .= qq( Class="$opts->{class}")     if $opts->{class};
    $tag   .= qq( Style="$opts->{style}")     if $opts->{style};
    $tag   .= qq( Target="$opts->{target}")   if $opts->{target};
    $tag   .= qq( OnClick="$opts->{onclick}") if $opts->{onclick};

    qq(<$tag>$name</A>);
}


sub html_esc { local $_ = shift || ''; s/\&/&amp;/g; s/>/&gt;/g; s/</&lt;/g; $_ }


1;
