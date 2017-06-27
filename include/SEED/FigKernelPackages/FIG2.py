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

import CallPerl

CallPerl.use("FIG")

import FIG_Config

import Clearinghouse

def get_clearinghouse(url = None):
    return Clearinghouse.Clearinghouse(url)

class FIG:

    def __init__(self):
        self.fig = CallPerl.new_object("FIG", "new")
        self.fig.set_hint('genus_species', 0)
        self.fig.set_hints(['get_subsystem',
                            'get_seed_id',
                            'get_local_hostname',
                            'temp_url',
                            'cgi_url',
                            ], 0)

    def __repr__(self):
        return "FIG instance %s" % ( self)

    def __str__(self):
        return "FIG instance %s" % (id(self))

    def __getattr__(self, name):
        g = globals()
        if g.has_key(name) and callable(g[name]):
            return g[name]

        if name.startswith("_"):
            return None
        
        #
        # Not accessible in globals. Return an invocation via the CallPelr interface.
        #

        return getattr(self.fig, name)

    def foo(self):
        print "FOO"


if __name__ == "__main__":

    f = FIG()
    print f.get_local_hostname()
    print f.cgi_url()
    print f.temp_url()

    print f.get_seed_id()
