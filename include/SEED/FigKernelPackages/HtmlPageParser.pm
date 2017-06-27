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


# package main;

# use Data::Dumper;
# use strict;

# my $p = HtmlSplitter->new();
# my $ret = $p->parse_file(shift || die);
# print "Done parsing: $ret\n";

# $p->{head} =~ s/\r\n/\n/gm;
# $p->{head} =~ s/\r/\n/gm;

# $p->{body} =~ s/\r\n/\n/gm;
# $p->{body} =~ s/\r/\n/gm;

# #print "HEAD: $p->{head}\n";
# #print "BODY: $p->{body}\n";

# my @maps = @{$p->{map_names}};

# print "maps: @maps\n";
# for my $map (@maps)
# {
#     print "$map:\n";
#     print $p->{map}->{$map}, "\n";
    
# }

package HtmlPageParser;

use strict;
use Data::Dumper;
use HTML::Parser ();

use base 'HTML::Parser';

sub new
{
    my($class) = @_;

    my $self = $class->SUPER::new(api_version => 3,
				  start_h => ["start_handler", "self,tagname,text,attr"],
				  end_h => ["end_handler", "self,tagname,text,attr"],
				  text_h => ["text_handler", "self,tagname,text"],
				  default_h => ["default_handler", "self,text"]);

    $self->{state} = 'start';
    return bless($self, $class);
}

sub start_handler
{
    my($self, $tag, $txt, $attr) = @_;

#    print "Start tag=$tag txt=$txt state=" . $self->state . "\n";

    if ($tag eq 'map')
    {
	my $name = $attr->{name};
	$self->{in_map} = $name;
	push(@{$self->{map_names}}, $name);
    }
    elsif ($tag eq 'img')
    {
	my $src = $attr->{src};
    }

    if (my $map = $self->{in_map})
    {
	$self->{map}->{$map} .= $txt;
    }

    #
    # If we're gathering information from the <HEAD> block, just accumulate text.
    #
    if ($self->state eq 'head')
    {
	$self->{head} .= $txt;
    }
    elsif ($self->state eq 'body')
    {
	$self->{body} .= $txt;
    }
    #
    # Otherwise, if we see a <head>, start gathering
    #
    elsif ($tag eq 'head')
    {
	$self->state('head');
    }
    elsif ($tag eq 'body')
    {
	$self->state('body');
    }
}

sub end_handler
{
    my($self, $tag, $txt, $attr) = @_;

    if (my $map = $self->{in_map})
    {
	$self->{map}->{$map} .= $txt;
    }

    if ($tag eq 'map')
    {
	delete $self->{in_map};
    }


    #
    # If we've finished the head, switch out of head state.
    #
    if ($tag eq 'head')
    {
	$self->state('none');
    }
    elsif ($tag eq 'body')
    {
	$self->state('none');
    }
    elsif ($self->state eq 'head')
    {
	$self->{head} .= $txt;
    }
    elsif ($self->state eq 'body')
    {
	$self->{body} .= $txt;
    }

}

sub text_handler
{
    my($self, $tag, $txt) = @_;

#    print "txt tag=$tag txt='$txt'\n";

    if (my $map = $self->{in_map})
    {
	$self->{map}->{$map} .= $txt;
    }

    if ($self->state eq 'head')
    {
	$self->{head} .= $txt;
    }
    elsif ($self->state eq 'body')
    {
	$self->{body} .= $txt;
    }

}
sub default_handler
{
    my($self, $tag, $txt) = @_;

#    print "def tag=$tag txt='$txt'\n";

    if (my $map = $self->{in_map})
    {
	$self->{map}->{$map} .= $txt;
    }
    
    if ($self->state eq 'head')
    {
	$self->{head} .= $txt;
    }
    elsif ($self->state eq 'body')
    {
	$self->{body} .= $txt;
    }
}

sub state
{
    my($self, $s) = @_;
    
    if (defined($s))
    {
#	cluck "set state to $s";
	my $old = $self->{state};
	$self->{state} = $s;
	return $old;
    }
    else
    {
	return $self->{state};
    }
}

1;
