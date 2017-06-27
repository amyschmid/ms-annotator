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
# Python interface to the clearing house. Just querying for now.
#

import xmlrpclib

DefaultURL = "http://pubseed.theseed.org/legacy_clearinghouse/api.cgi"
#DefaultURL = "http://www.mcs.anl.gov/~olson/SEED/api.cgi"
SSDefaultURL = "http://www.mcs.anl.gov/~olson/SEED/ss_hier.cgi"

class Clearinghouse:

    def __init__(self, url = None):

        if url is None:
            url = DefaultURL

        self.proxy = xmlrpclib.ServerProxy(url)

    def get_subsystems(self):
       """
       Retrieve the list of subsystems we have.

       Return a list of tuples (id, name, seed_id).
       """
       return self.proxy.get_subsystems()

    def get_subsystem(self, sub_id):
        """
        Return the information about this subsystem. Return is a list
        (name, version, date, curator, pedigree, seed_id).
        """
        
        return self.proxy.get_subsystem(sub_id)

    def get_subsystem_roles(self, sub_id):
        """
        Return the roles in this subsystem as a list of pairs (abbrev, name).
        """
        return self.proxy.get_subsystem_roles(sub_id)

    def get_subsystem_genomes(self, sub_id):
        """
        Return the roles in this subsystem as a list of pairs (abbrev, name).
        """
        
        return self.proxy.get_subsystem_genomes(sub_id)

    def get_subsystem_package_url(self, sub_id):
        """
        Return the download URL for the given subsystem.
        """

        return self.proxy.get_subsystem_package_url(sub_id)

    def get_full_subsystems(self, with_roles, with_genomes, with_pedigree):
        """
        Return all information about all subsystems.
        
        Return is a list [id, name, version, date, curator, pedigree, seed_id, url, [roles], [genomes]].
        """

        return self.proxy.get_full_subsystems(with_roles, with_genomes, with_pedigree)


    def get_seed_info(self, seed_id):
        """
        Return the registration information for the given seed ID.

        Return value is a list (display_name, url, last_active)
        """

        return self.proxy.get_seed_info(seed_id)

    def delete_subsystem(self, subsystem_id):
	""" Given this subsystem_id, make an entry in the subsystems-deleted table for each version of this subsystem with the same name and from the same seed
	"""
	return self.proxy.delete_subsystem(subsystem_id)


class SSHierarchy:

    def __init__(self, url = None):

        if url is None:
            url = SSDefaultURL

        self.proxy = xmlrpclib.ServerProxy(url)

    def read_category(self, cat):
       return self.proxy.read_category(cat)

    def cat_add_subsystem(self, cat, name):
       return self.proxy.cat_add_subsystem(cat, name)

    def cat_remove_subsystem(self, cat, name):
       return self.proxy.cat_remove_subsystem(cat, name)

    def cat_create(self, parent, name):
       return self.proxy.cat_create(parent, name)

    def all_subsystems(self):
       return self.proxy.all_subsystems()

    def all_categories(self):
       return self.proxy.all_categories()

