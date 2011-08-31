# 2010, Google Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following disclaimer
# in the documentation and/or other materials provided with the
# distribution.
# * Neither the name of Google Inc. nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# Alternatively, this software may be distributed under the terms of the
# GNU General Public License ("GPL") version 2 as published by the Free
# Software Foundation.

PACKAGE_NAME	= flashmap
VERSION_MAJOR	= 0
VERSION_MINOR	= 3

AR		= $(CROSS_COMPILE)ar
CC		= $(CROSS_COMPILE)gcc
LD		= $(CROSS_COMPILE)ld
MAKE		= make
RM		= rm -f

INSTALL		= install
INSTALL_DATA	:= $(INSTALL) -m 644
INSTALL_DIR	:= $(INSTALL) -m 755 -d
INSTALL_PROGRAM	:= $(INSTALL) -m 755

prefix		= /usr/local
sbindir		= $(prefix)/sbin
libdir		= $(prefix)/lib
includedir	= $(prefix)/include

DEFS		= -DVERSION_MAJOR=$(VERSION_MAJOR)\
                  -DVERSION_MINOR=$(VERSION_MINOR)
CFLAGS		+= -O2 -Wall -Werror -Wno-unused-parameter -Ilib/ $(DEFS)
CFLAGS_GCOV	:= -fprofile-arcs -ftest-coverage -lgcov
LINKOPTS	=

PROGRAMS	= fmap_decode fmap_encode fmap_csum libfmap_example
TEST_PROGRAM	= fmap_test
SHARED_OBJ	= libfmap.so
SHARED_OBJ_FILE	= libfmap-$(VERSION_MAJOR).$(VERSION_MINOR).so
LIB		= lib
GENHTML_OUTPUT	?= html

SVNVERSION := $(shell LC_ALL=C svnversion -cn . 2>/dev/null | sed -e "s/.*://" -e "s/\([0-9]*\).*/\1/" | grep "[0-9]" || LC_ALL=C svn info . 2>/dev/null | awk '/^Revision:/ {print $$2 }' | grep "[0-9]" || LC_ALL=C git svn info . 2>/dev/null | awk '/^Revision:/ {print $$2 }' | grep "[0-9]" || echo unknown)

RELEASENAME := $(PACKAGE_NAME)-$(VERSION_MAJOR).$(VERSION_MINOR)-r$(SVNVERSION)

export CFLAGS

all: $(PROGRAMS) $(SHARED_OBJ)

help:
	@echo "flashmap build targets:"
	@echo "help         - print this help screen"
	@echo "all          - build utilities and shared library"
	@echo "test         - build and run unit tests, generate coverage statistics"
	@echo "install      - install utilities, headers, and shared library"
	@echo "uninstall    - opposite of install"
	@echo ""


$(LIB)/libfmap.a:
	@$(MAKE) -C $(LIB)
	ar rcs $@ $(LIB)/*.o

$(SHARED_OBJ): $(LIB)/libfmap.a
	$(CC) -fpic -shared -Wl,-soname,$@ -o $(SHARED_OBJ_FILE) -Wl,-whole-archive $^ -Wl,-no-whole-archive

$(PROGRAMS): $(LIB)/libfmap.a
	$(CC) $(CFLAGS) $(LINKOPTS) -I. -o $@ $@.c $^

# Add shared object filename to gcc command in case it's not installed already
$(LIBFMAP_EXAMPLE): $(SHARED_OBJ)
	$(CC) $(CFLAGS) $(LINKOPTS) -o $@ $@.c $(SHARED_OBJ_FILE)

$(TEST_PROGRAM): $(LIB)/libfmap.a
	$(CC) $(CFLAGS) $(LINKOPTS) -I. -o $@ $@.c $^

test: CFLAGS += $(CFLAGS_GCOV)
test: $(TEST_PROGRAM)
	lcov --directory . --zerocounters
	@echo "Running $(TEST_PROGRAM)"
	./$(TEST_PROGRAM)
	lcov --directory . --capture \
	--output-file $(TEST_PROGRAM).info --test-name $(TEST_PROGRAM)
	genhtml -o $(GENHTML_OUTPUT)/ $(TEST_PROGRAM).info
	@echo "Unit test coverage statistics are at $(GENHTML_OUTPUT)/index.html"

test_only: $(TEST_PROGRAM)
	@echo "Running $(TEST_PROGRAM)"
	./$(TEST_PROGRAM)

PHONY += export
export:
	@rm -rf $(EXPORTDIR)/$(RELEASENAME)
	@svn export -r BASE . $(EXPORTDIR)/$(RELEASENAME)
	@sed "s/^SVNVERSION.*/SVNVERSION := $(SVNVERSION)/" Makefile >$(EXPORTDIR)/$(RELEASENAME)/Makefile
	@LC_ALL=C svn log >$(EXPORTDIR)/$(RELEASENAME)/ChangeLog
	@echo Exported $(EXPORTDIR)/$(RELEASENAME)/

PHONY += tarball
# TAROPTIONS reduces information leakage from the packager's system.
# If other tar programs support command line arguments for setting uid/gid of
# stored files, they can be handled here as well.
TAROPTIONS = $(shell LC_ALL=C tar --version|grep -q GNU && echo "--owner=root --group=root")
tarball: export
	@tar cjf $(EXPORTDIR)/$(RELEASENAME).tar.bz2 -C $(EXPORTDIR)/ $(TAROPTIONS) $(RELEASENAME)/
	@rm -rf $(EXPORTDIR)/$(RELEASENAME)
	@echo Created $(EXPORTDIR)/$(RELEASENAME).tar.bz2

install: all
	$(INSTALL_DIR) $(DESTDIR)$(sbindir)
	$(INSTALL_DIR) $(DESTDIR)$(libdir)
	$(INSTALL_DIR) $(DESTDIR)$(includedir)
	$(INSTALL_PROGRAM) fmap_decode $(DESTDIR)$(sbindir)
	$(INSTALL_PROGRAM) fmap_encode $(DESTDIR)$(sbindir)
	$(INSTALL_PROGRAM) fmap_csum $(DESTDIR)$(sbindir)
	$(INSTALL_DATA) lib/fmap.h $(DESTDIR)$(includedir)
	$(INSTALL_DATA) lib/valstr.h $(DESTDIR)$(includedir)
	$(INSTALL_DATA) $(SHARED_OBJ_FILE) $(DESTDIR)$(libdir)
	@echo Installed shared library, please run ldconfig to set up symlinks.

uninstall:
	$(RM) $(DESTDIR)$(sbindir)/fmap_decode
	$(RM) $(DESTDIR)$(sbindir)/fmap_encode
	$(RM) $(DESTDIR)$(sbindir)/fmap_csum
	$(RM) $(DESTDIR)$(includedir)/fmap.h
	$(RM) $(DESTDIR)$(includedir)/valstr.h
	$(RM) $(DESTDIR)$(libdir)/$(SHARED_OBJ)
	$(RM) $(DESTDIR)$(libdir)/$(SHARED_OBJ_FILE)

.PHONY: clean
RCS_FIND_IGNORE := \( -name SCCS -o -name BitKeeper -o -name .svn -o -name CVS -o -name .pc -o -name .hg -o -name .git \) -prune -o

lcov-clean:
	@find . $(RCS_FIND_IGNORE) \
		\( -name '*.css' -o -name '*.gcda' -o -name '*.png' \
		-o -name '*.css' -o -name '*.info' -o -name '*.html' \
		-o -name '*.gcno' \) \
		-type f -print | xargs rm -f
	@rm -rf $(GENHTML_OUTPUT)/

clean: lcov-clean
	rm -f *.o *.a $(PROGRAMS) $(TEST_PROGRAM) $(LIBFMAP_EXAMPLE) $(SHARED_OBJ_FILE)
	@$(MAKE) -C $(LIB) clean

%.o: %.c
	$(CC) $(CFLAGS) -c $^ -I. -o $@