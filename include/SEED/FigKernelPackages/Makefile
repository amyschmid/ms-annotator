#
#
#


PERL = $(shell sed -ne 's/^RTPERL=\(.*\)/\1/p' $(RTROOT)/config/RTConfig)
RUNTIME_BINDIR = $(shell $(PERL) -MConfig -e 'print "$$Config{bin}\n"')

PERLPACKAGES := $(wildcard *.pm)
PYPACKAGES := $(wildcard *.py)

TEST_FILES = $(wildcard tests/*.t)

lib: lib_perl lib_py # html_doc

lib_perl:	$(foreach var, $(PERLPACKAGES), $(libdir)/$(PKGNAME)/$(var))
lib_py:	$(foreach var, $(PYPACKAGES), $(libdir)/$(PKGNAME)/$(var))

html_doc:

bin:

schematools:
stDeclFiles:
stGeneratedFiles:

compile_typespec:
	/vol/kbase/deployment/bin/compile_typespec \
		--psgi seed.psgi \
		SEED.spec .
	mv seed.psgi ../FigWebServices/.

test:
	$(PERL) "-MExtUtils::Command::MM" "-e" "test_harness($(TEST_VERBOSE))" $(TEST_FILES)

clean:

html_doc_dir:
	if [ ! -d $(cgidir)/Html/pod_docs  ] ; then mkdir $(cgidir)/Html/pod_docs; fi

$(libdir)/$(PKGNAME)/%.pm: $(TOPDIR)/$(PKGNAME)/%.pm
	cp  $< $@

$(libdir)/$(PKGNAME)/%.py: $(TOPDIR)/$(PKGNAME)/%.py
	cp  $< $@

#
# We have a config problem at the moment.  I do not want to depend
# upon explicit calls to other packages, as done here nor do I want
# to assume that package was built first.  For now, we live with this.

#$(workdir)/FIG_Config.pm:
#	cd $(workdir); $(TOPDIR)/FigCommon/configure-env $(RTARCH) $(TOPDIR)

$(libdir)/$(PKGNAME)/%.pm: $(workdir)/%.pm
	cp  $< $@
$(libdir)/$(PKGNAME)/%.py: $(workdir)/%.py
	cp  $< $@

