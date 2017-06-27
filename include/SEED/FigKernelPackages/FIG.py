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

import urlparse
import socket
import os
import popen2
import sys
import re
import xmlrpclib

import FIG_Config

import Clearinghouse

class NoSubsystemException(Exception):
    pass

def get_clearinghouse(url = None):
    return Clearinghouse.Clearinghouse(url)

def get_ss_hierarchy(url = None):
    return Clearinghouse.SSHierarchy(url)

#
# Subsystem helper code.
#

def get_subsystem(name):
    try:
        sub = Subsystem(name)
    except NoSubsystemException:
        sub = None

    return sub
        

def get_local_hostname():
    #
    # See if there is a FIGdisk/config/hostname file. If there
    # is, force the hostname to be that.
    #

    try:
        fh = open(os.path.join(FIG_Config.fig_disk, "config", "hostname"))
        host = fh.readline()
        return host.strip()
    except:
        pass

    #
    # First check to see if we our hostname is correct.
    #
    # Map it to an IP address, and try to bind to that ip.
    #

    hostname = socket.getfqdn()

    #
    # See if hostname is something.local., which is what
    # a Mac will return if it didn't get a name via some
    # other mechanism (DHCP or static config). We have to
    # check here because otherwise it will pass the fqdn and
    # local binding test.
    #

    if not re.search(r"\.local\.?$", hostname):

	#
	# First check that hostname is a fqdn, and that we can bind to it.
	#

	if hostname.find('.') >= 0:
	    if try_bind(hostname):
		return hostname
	
    #
    # Otherwise, do a hostname lookup and try to bind to the IP address.
    #
    
    try:
        ip = socket.gethostbyname(hostname)

    except socket.error:
        return get_hostname_by_adapter()

    if not try_bind(ip):

        return get_hostname_by_adapter()
    
    #
    # It worked. Reverse-map back to a hopefully fqdn.
    #

    try:
        rev = socket.gethostbyaddr(ip)

    except socket.error:

        #
        # Failed, return bare IP address.
        #

        return ip

    host = rev[0]
    #
    # Check to see if we have a FQDN.
    #
    if host.find(".") >= 0:
        return host
    else:
        return ip

def try_bind(host):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.bind((host, 0))
        return 1
    except socket.error:
        return 0

def get_hostname_by_adapter():
    #
    # Attempt to determine our local hostname based on the
    # network environment.
    #
    # This implementation reads the routing table for the default route.
    # We then look at the interface config for the interface that holds the default.
    #
    #
    # Linux routing table:
    # [olson@yips 0.0.0]$ netstat -rn
    #     Kernel IP routing table
    #     Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
    #     140.221.34.32   0.0.0.0         255.255.255.224 U         0 0          0 eth0
    #     169.254.0.0     0.0.0.0         255.255.0.0     U         0 0          0 eth0
    #     127.0.0.0       0.0.0.0         255.0.0.0       U         0 0          0 lo
    #     0.0.0.0         140.221.34.61   0.0.0.0         UG        0 0          0 eth0
    # 
    #     Mac routing table:
    # 
    #     bash-2.05a$ netstat -rn
    #     Routing tables
    # 
    #  Internet:
    #     Destination        Gateway            Flags    Refs      Use  Netif Expire
    #     default            140.221.11.253     UGSc       12      120    en0
    #     127.0.0.1          127.0.0.1          UH         16  8415486    lo0
    #     140.221.8/22       link#4             UCS        12        0    en0
    #     140.221.8.78       0:6:5b:f:51:c4     UHLW        0      183    en0    408
    #     140.221.8.191      0:3:93:84:ab:e8    UHLW        0       92    en0    622
    #     140.221.8.198      0:e0:98:8e:36:e2   UHLW        0        5    en0    691
    #     140.221.9.6        0:6:5b:f:51:d6     UHLW        1       63    en0   1197
    #     140.221.10.135     0:d0:59:34:26:34   UHLW        2     2134    en0   1199
    #     140.221.10.152     0:30:1b:b0:ec:dd   UHLW        1      137    en0   1122
    #     140.221.10.153     127.0.0.1          UHS         0        0    lo0
    #     140.221.11.37      0:9:6b:53:4e:4b    UHLW        1      624    en0   1136
    #     140.221.11.103     0:30:48:22:59:e6   UHLW        3      973    en0   1016
    #     140.221.11.224     0:a:95:6f:7:10     UHLW        1        1    en0    605
    #     140.221.11.237     0:1:30:b8:80:c0    UHLW        0        0    en0   1158
    #     140.221.11.250     0:1:30:3:1:0       UHLW        0        0    en0   1141
    #     140.221.11.253     0:d0:3:e:70:a      UHLW       13        0    en0   1199
    #     169.254            link#4             UCS         0        0    en0
    # 
    #     Internet6:
    #     Destination                       Gateway                       Flags      Netif Expire
    #                                                                     UH          lo0
    #     fe80::%lo0/64                                                   Uc          lo0
    #                                       link#1                        UHL         lo0
    #     fe80::%en0/64                     link#4                        UC          en0
    #     0:a:95:a8:26:68               UHL         lo0
    #     ff01::/32                                                       U           lo0
    #     ff02::%lo0/32                                                   UC          lo0
    #     ff02::%en0/32                     link#4                        UC          en0

    try:
        fh = os.popen("netstat -rn", "r")
    except:
	return "localhost"

    interface_name = None
    for l in fh:
        cols = l.strip().split()

        if len(cols) > 0 and (cols[0] == "default" or cols[0] == "0.0.0.0"):
            interface_name = cols[-1]
            break
        
    fh.close()
    
    # print "Default route on ", interface_name

    #
    # Find ifconfig.
    #

    ifconfig = None

    path = os.environ["PATH"].split(":")
    path.extend(["/sbin", "/usr/sbin"])
    for p in path: 
        i = os.path.join(p, "ifconfig")
        if os.access(i, os.X_OK):
            ifconfig = i
            break

    if ifconfig is None:
        print >> sys.stderr, "Ifconfig not found"
        return "localhost"

    # print >> sys.stderr, "found ifconfig ", ifconfig

    try:
        fh = os.popen(ifconfig+ " " + interface_name, "r")
    except:
	print >> sys.stderr, "Could not run ", ifconfig
	return "localhost"

    ip = None

    linux_re = re.compile("inet\s+addr:(\d+\.\d+\.\d+\.\d+)\s+")
    mac_re = re.compile("inet\s+(\d+\.\d+\.\d+\.\d+)\s+")

    for l in fh:
	#
	# Mac:
	#         inet 140.221.10.153 netmask 0xfffffc00 broadcast 140.221.11.255
	# Linux:
	#           inet addr:140.221.34.37  Bcast:140.221.34.63  Mask:255.255.255.224
	#

        l = l.strip()

        m = linux_re.search(l)
        if m:
	    #
	    # Linux hit.
	    #
            ip = m.group(1)
            break

        m = mac_re.search(l)

        if m:
	    #
	    # Mac hit.
	    #
	    ip = m.group(1)
            break
    fh.close()

    if ip is None:
        print >> sys.stderr, "Didn't find an IP"
        return "localhost"

    return ip

def top_link():

    #
    # Determine if this is a toplevel cgi or one in one of the subdirs (currently
    # just /p2p).
    #

    sname = os.getenv("SCRIPT_NAME")

    if sname is not None:
        parts = os.getenv("SCRIPT_NAME").split('/');

        if len(parts) > 2 and parts[-2] == 'FIG':
            top = '.'
        elif len(parts) > 3 and parts[-3] == 'FIG':
            top = '..'
        else:
            top = FIG_Config.cgi_base
    else:
        top = FIG_Config.cgi_base

            

    return top

def cgi_url():
    return top_link()
    # return plug_url(FIG_Config.cgi_url)

def temp_url():
    return plug_url(FIG_Config.temp_url)

def plug_url(url):

    name = get_local_hostname()

    if not name:
        return url

    p = urlparse.urlparse(url)
    
    p = list(p)

    p[1] = name

    new_url = urlparse.urlunparse(p)
    return new_url

def get_seed_id():
    #
    # Retrieve the seed identifer from FIGdisk/config/seed_id.
    #
    # If it's not there, create one, and make it readonly.
    #

    id_file = os.path.join(FIG_Config.fig_disk, "config", "seed_id")
    if not os.path.isfile(id_file):

        fh = os.popen("uuidgen", "r")
        
        newid = fh.readline()
        newid = newid.strip()

        fh.close()

        fh = open(id_file, "w")
        print >>fh, newid
        fh.close()

	os.chmod(id_file, 0444)

    fh = open(id_file)
    id = fh.readline()
    fh.close()
    id = id.strip()
    return id

#
# Define a FIG class; this is analagous to the FIG class used in FIG.pm
#
# It also lets us cache stuff, and use __call__ to map calls to
# an XMLRPC server for the perl stuff we don't implement locally.
#

class FIG:

    def __init__(self):
        self.xmlrpc_proxy = None
        self.xmlrpc_proc = None

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
        # Not accessible in globals. Return an XMLRPC calling proxy.
        #

        return XMLRPCCaller(self, name)

    def foo(self):
        print "FOO"


    def call_xmlrpc(self, name, args):

        try:
            if self.xmlrpc_proxy is None:
                self.start_xmlrpc_server()

        except Exception, e:
            print "Got exception ... ", e
            return

        proc = getattr(self.xmlrpc_proxy, name)
        retval = apply(proc, args)
        return retval

    def start_xmlrpc_server(self):
        server_path = os.path.join(FIG_Config.bin, "fig_xmlrpc_server")

        if not os.access(server_path, os.X_OK):
            raise Exception, "XMLRPC server path %s not found" % (server_path)

        
        proc = self.xmlrpc_proc = popen2.Popen3(server_path, 0)

        print "Server started ", proc.pid
        
        url = proc.fromchild.readline()
        url = url.strip()
        print "Read url ", url

        proc.fromchild.close()

        self.xmlrpc_proxy = xmlrpclib.ServerProxy(url)
    
class XMLRPCCaller:
    def __init__(self, fig, name):
        self.fig = fig
        self.name = name

    def __call__(self, *args):
        return self.fig.call_xmlrpc(self.name, args)

class Subsystem:
    def __init__(self, name):
        self.dir = os.path.join(FIG_Config.data, "Subsystems", name.replace(" ","_"))

        if not os.path.isdir(self.dir):
            raise NoSubsystemException("Subsystem %s not found" % (name))

    def get_version(self):
        try:
            fh = open(os.path.join(self.dir, "VERSION"))
            version = fh.readline().strip()
            try:
                local_version = int(version)
            except TypeError:
                local_version = -1
            fh.close()
        except:
            local_version = -1

        return local_version;

    def get_curator(self):
        curator = None
        try:
            fh = open(os.path.join(self.dir, "curation.log"))
            l = fh.readline().strip()
            fh.close()
            m = re.match(r"^\d+\t(\S+)\s+started", l)
            if m:
                curator = m.group(1)
        except:
            pass

        return curator

if __name__ == "__main__":

    print get_local_hostname()
    print cgi_url()
    print temp_url()

    print get_seed_id()
