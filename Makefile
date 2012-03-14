# Copyright 2011 Jeffrey Kegler
# This file is part of Marpa::XS.  Marpa::XS is free software: you can
# redistribute it and/or modify it under the terms of the GNU Lesser
# General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Marpa::XS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser
# General Public License along with Marpa::XS.  If not, see
# http://www.gnu.org/licenses/.

.PHONY: dummy html_full_test full_test install

dummy: 

full_test: html_full_test

html_full_test:
	cd html && perl Build.PL
	cd html && ./Build realclean
	cd html && perl Build.PL
	cd html && ./Build
	cd html && ./Build distmeta
	curdir=$(CURDIR); \
	echo PERL5LIB=$$curdir/noxs/lib:$$PERL5LIB; \
	cd html; \
	    PERL5LIB=$$curdir/noxs/lib:$$PERL5LIB prove t
	cd html && ./Build test
	cd html && ./Build distcheck
	cd html && ./Build dist
	
install:
	(cd html && perl Build.PL)
	(cd html && ./Build code)
