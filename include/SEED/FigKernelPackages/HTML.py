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

#
# Simple binding of the HTML.pm module to python.
#
# This necessitated adding   
#
#  shift if UNIVERSAL::isa($_[0],__PACKAGE__);
#
# to the HTML.pm routines.
#
# Simple use:
#
# from FigKernelPackages import HTML
# h = HTML.HTML()
# print h.compute_html_header()
#
# One *should* be able to do the following cooler thing, but because
# the CallPerl module doesn't currently translate blessed refs as 
# method call arguments, it doesn't work.
# 
# 
# from FigKernelPackages import HTML
# import CallPerl
# 
# h = HTML.HTML()
# 
# CallPerl.use("CGI")
# c = CallPerl.new_object("CGI", "new")
# 
# h.show_page(c, ["firstline", "sec line"])
#

import FIG
import FIG_Config
import time
import os
import os.path
import re

def compute_html_header(additional_insert = '', user = ''):

    html_hdr_file = "./Html/html.hdr"

    if not os.path.isfile(html_hdr_file):
	html_hdr_file = os.path.join(FIG_Config.fig, "CGI/Html/html.hdr")

    html_hdr = open(html_hdr_file).readlines()

    html_hdr.append("<br><a href=\"%sindex.cgi?user=%s\">FIG search</a>\n" % (FIG_Config.cgi_base, user) );

    ver = open(os.path.join(FIG_Config.fig_disk, "CURRENT_RELEASE")).readline().strip()

    m = re.search(r'cvs\.(\d+)', ver)
    if m is not None:
        ver += " (%s)" % (time.ctime(int(m.group(1))))

    host = FIG.get_local_hostname()
    insert_stuff = "SEED version <b>%s</b> on %s" % (ver, host)
    if additional_insert != "":
        insert_stuff += "<br>" + additional_insert;

    out_hdr = []
    for line in html_hdr:
        line = re.sub(r'(href|img\s+src)="/FIG/', r'\1="%s' % (FIG_Config.cgi_base), line)
        if line == "<!-- HEADER_INSERT -->\n":
            line = insert_stuff
        out_hdr.append(line)

    return out_hdr
