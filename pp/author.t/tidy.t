#!/usr/bin/perl
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
use Carp;
use Perl::Critic;
use Test::Perl::Critic;
use Test::More;

# Test that the module passes perlcritic
BEGIN {
    $OUTPUT_AUTOFLUSH = 1;
}

open my $critic_list, '<', 'author.t/critic.list';
my @test_files = <$critic_list>;
close $critic_list;
chomp @test_files;

my $rcfile = File::Spec->catfile( 'author.t', 'perlcriticrc' );
Test::Perl::Critic->import(
    -verbose         => '%l:%c %p %r',
    -profile         => $rcfile,
    '-single-policy' => 'CodeLayout::RequireTidyCode',
);
Test::Perl::Critic::all_critic_ok(@test_files);
