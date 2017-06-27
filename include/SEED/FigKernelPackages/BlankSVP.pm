package BlankSVP;

use strict;
use HTML;
use Data::Dumper;

sub run
{
    my($fig, $cgi, $sapObject, $user, $url, $hidden_form_var) = @_;

    my @html = ();

    my $feature = $cgi->param("fid");

    my $func = $fig->function_of($feature);
    push(@html, "The function of $feature is $func");

    my $title = "Function for $feature";

    my $html_txt = join("", @html);
    return($html_txt, $title);
}

1;
