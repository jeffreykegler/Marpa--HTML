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

package Marpa::PP::Build_Me;

use 5.010;
use strict;
use warnings;

@Marpa::PP::Build_Me::ISA = ('Module::Build');

use Config;
use File::Copy;
use IPC::Cmd;
use Module::Build;
use Fatal qw(open close);
use English qw( -no_match_vars );
use Time::Piece;

use Marpa::PP::Config;

my @marpa_pp_use      = qw( Scalar::Util List::Util Carp Data::Dumper );
my @marpa_pp_perl_use = qw( Scalar::Util Carp Data::Dumper PPI Marpa::PP );

my $preamble = <<'END_OF_STRING';
# This file is written by Build.PL
# It is not intended to be modified directly
END_OF_STRING

sub installed_contents {
    my ( $self, $package ) = @_;
    my $marpa_pp_version = $self->dist_version();
    my $text             = $preamble;
    $text .= "package $package;\n";
    {
        ## no critic (ValuesAndExpressions::RequireInterpolationOfMetachars)
        $text .= q{use vars qw($VERSION $STRING_VERSION)} . qq{;\n};
        $text .= q{$VERSION = '} . $marpa_pp_version . qq{';\n};
        $text .= q{$STRING_VERSION = $VERSION} . qq{;\n};
        $text .= q{$VERSION = eval $VERSION} . qq{;\n};
    }
    $text .= "1;\n";
    return $text;
} ## end sub installed_contents

sub version_contents {
    my ( $self, $package, @use_packages ) = @_;

    my $marpa_pp_version = $self->dist_version();
    my $text             = $preamble;
    $text .= "package $package;\n";
    {
        ## no critic (ValuesAndExpressions::RequireInterpolationOfMetachars)
        $text .= q{use vars qw($TIMESTAMP)} . qq{;\n};
        $text .= q{$TIMESTAMP='} . localtime()->datetime . qq{';\n};
    }
    PACKAGE: for my $package (@use_packages) {
        my $version =
              $package eq 'Marpa::PP'
            ? $marpa_pp_version
            : $Marpa::PP::VERSION_FOR_CONFIG{$package};
        die "No version defined for $package" if not defined $version;
        $text .= "use $package $version ();\n";
    } ## end for my $package (@use_packages)
    $text .= "1;\n";
    return $text;
} ## end sub version_contents

sub write_file {
    my ( $self, $contents, @name_components ) = @_;
    my $base_dir  = $self->base_dir();
    my $file_name = pop @name_components;
    my $dir_name  = File::Spec->catdir( $base_dir, @name_components );
    -d $dir_name or mkdir $dir_name;
    my $path_name = File::Spec->catfile( $dir_name, $file_name );
    open my $fh, q{>}, $path_name;
    print {$fh} $contents or die "print: $ERRNO";
    close $fh;
    return 1;
} ## end sub write_file

sub ACTION_manifest {
    die qq{Automatic generation of the MANIFEST file is disabled\n}
        . qq{The Marpa::PP MANIFEST file is handwritten\n};
}

sub ACTION_licensecheck {
    require config::Marpa::PP::License;
    my @manifest = do {
        open my $fh, q{<}, 'MANIFEST';
        local $RS = undef;
        my $text = <$fh>;
        close $fh;
        $text =~ s/[#] [^\n]* $//gxms;
        grep { defined and not / \A \s* \z /xms }
            split /\n/xms,
            $text;
    };
    my @license_problems = Marpa::PP::License::license_problems(@manifest);
    if (@license_problems) {
        print {*STDERR} join q{}, @license_problems or die "print: $ERRNO";
        die q{Fatal error due to license language issues};
    }
    return 1;
} ## end sub ACTION_licensecheck

sub ACTION_distcheck {
    my $self = shift;
    $self->ACTION_licensecheck();
    return $self->SUPER::ACTION_distcheck;
}

sub ACTION_dist {
    my $self = shift;
    open my $fh, q{<}, 'Changes';
    my $changes = do { local $RS = undef; <$fh>; };
    close $fh;
    my $marpa_pp_version = $self->dist_version();
    die qq{"$marpa_pp_version" not in Changes file}
        if 0 > index $changes, $marpa_pp_version;
    return $self->SUPER::ACTION_dist;
} ## end sub ACTION_dist

sub write_installed_pm {
    my ( $self, @components ) = @_;
    my $filename = 'Installed';
    my $contents =
        installed_contents( $self, join q{::}, @components, $filename );
    $filename .= q{.pm};
    $self->write_file( $contents, @components, $filename );
    return 0;
} ## end sub write_installed_pm

sub ACTION_code {
    my $self = shift;
    say {*STDERR} 'Writing version files' or die "say: $ERRNO";
    write_installed_pm( $self, qw(lib Marpa PP ) );
    write_installed_pm( $self, qw(pperl Marpa PP Perl ) );
    my $perl_version_pm =
        version_contents( $self, 'Marpa::PP::Perl', @marpa_pp_perl_use );
    my $version_pm = version_contents( $self, 'Marpa::PP', @marpa_pp_use );
    $self->write_file( $version_pm,      qw(lib Marpa PP Version.pm) );
    $self->write_file( $perl_version_pm, qw(pperl Marpa PP Perl Version.pm) );
    return $self->SUPER::ACTION_code;
} ## end sub ACTION_code

1;
