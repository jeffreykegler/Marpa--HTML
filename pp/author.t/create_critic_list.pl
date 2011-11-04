#!perl
# Copyright 2011 Jeffrey Kegler
# This file is part of Marpa::PP.  Marpa::PP is free software: you can
# redistribute it and/or modify it under the terms of the GNU Lesser
# General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Marpa::PP is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser
# General Public License along with Marpa::PP.  If not, see
# http://www.gnu.org/licenses/.

use 5.010;
use strict;
use warnings;
use English qw( -no_match_vars );
use Fatal qw( open close );

my %exclude = map { ( $_, 1 ) } qw(
    Makefile.PL
);

open my $manifest, '<', '../MANIFEST'
    or die "open of ../MANIFEST failed: $ERRNO";

my @test_files = ();
FILE: while ( my $file = <$manifest> ) {
    chomp $file;
    $file =~ s/\s*[#].*\z//xms;
    next FILE if $exclude{$file};
    my ($ext) = $file =~ / [.] ([^.]+) \z /xms;
    given ( lc $ext ) {
        when (undef) {
            break
        }
        when ('pl') { say $file or die "Cannot say: $ERRNO" }
        when ('pm') { say $file or die "Cannot say: $ERRNO" }
        when ('t')  { say $file or die "Cannot say: $ERRNO" }
    } ## end given
} ## end while ( my $file = <$manifest> )

close $manifest;
