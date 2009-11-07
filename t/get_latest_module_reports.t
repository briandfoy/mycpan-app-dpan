#!/usr/bin/perl
use strict;
use warnings;

use Test::More 'no_plan';

use File::Spec::Functions qw(catfile);

my $class  = 'MyCPAN::App::DPAN::Reporter::Minimal';
my $method = 'get_latest_module_reports';

# turn off Log4perl
BEGIN { $INC{'Log/Log4perl.pm'} = 1; package Log::Log4perl; sub AUTOLOAD { __PACKAGE__ }; }

use_ok( $class );
can_ok( $class, $method );

{
no strict 'refs';
no warnings 'redefine';
*{"${class}::_get_report_names_by_dist_names"} =
	sub { return $Mock::Reports_names_hashref };
	
*{"${class}::_get_all_reports"} =
	sub { return $Mock::Reports_arrayref };

*{"${class}::get_success_report_dir"} =
	sub { 'foo' };
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Situations

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# The reports match the dists, no extras
{
$Mock::Reports_names_hashref = {
	'Foo-Bar-1.23.txt' => 'Foo-Bar-1.23.tar.gz',
	'Bar-4.673.txt'    => 'Bar-4.673.tar.gz',
	'Baz-8.673.txt'    => 'Baz-8.673.tar.gz',
	};
$Mock::Reports_arrayref      = [qw(
	Foo-Bar-1.23.txt
	Bar-4.673.txt
	Baz-8.673.txt
	)];
my $expected = [ sort qw(
	foo/Bar-4.673.txt
	foo/Baz-8.673.txt	
	foo/Foo-Bar-1.23.txt
	)];
	
my $actual = [ sort $class->$method() ];

is_deeply( $actual, $expected, 'No extras' );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Some reports are old
{
$Mock::Reports_names_hashref = {
	'Foo-Bar-1.23.txt' => 'Foo-Bar-1.23.tar.gz',
	'Bar-4.673.txt'    => 'Bar-4.673.tar.gz',
	'Baz-8.673.txt'    => 'Baz-8.673.tar.gz',
	};
$Mock::Reports_arrayref      = [qw(
	Foo-Bar-1.22.txt
	Foo-Bar-1.23.txt
	Bar-4.672.txt
	Bar-4.673.txt
	Baz-8.671.txt
	Baz-8.672.txt
	Baz-8.673.txt
	)];

my $expected = [ sort qw(
	foo/Bar-4.673.txt
	foo/Baz-8.673.txt	
	foo/Foo-Bar-1.23.txt
	)];
	
my $actual = [ sort $class->$method() ];

is_deeply( $actual, $expected, 'Some old reports' );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Some reports are newer without matching dists
{
$Mock::Reports_names_hashref = {
	'Fob-Bar-1.23.txt' => 'Fob-Bar-1.23.tar.gz',
	'Bar-4.673.txt'    => 'Bar-4.673.tar.gz',
	'Baz-8.673.txt'    => 'Baz-8.673.tar.gz',
	};
$Mock::Reports_arrayref      = [qw(
	Fob-Bar-1.21.txt
	Fob-Bar-1.23.txt
	Fob-Bar-1.24.txt
	Bar-4.673.txt
	Baz-8.673.txt
	Bar-4.674.txt
	Quux-999.txt
	)];

my $expected = [ sort qw(
	foo/Bar-4.673.txt
	foo/Baz-8.673.txt	
	foo/Fob-Bar-1.23.txt
	)];
	
my $actual = [ sort $class->$method() ];

is_deeply( $actual, $expected, 'Some newer reports' );
}

# Some reports don't have matching dists
{
$Mock::Reports_names_hashref = {
	'Baz-8.673.txt'    => 'Baz-8.673.tar.gz',
	};
$Mock::Reports_arrayref      = [qw(
	Foo-Bar-1.21.txt
	Foo-Bar-1.23.txt
	Foo-Bar-1.24.txt
	Bar-4.673.txt
	Baz-8.673.txt
	)];

my $expected = [ sort qw(
	foo/Baz-8.673.txt	
	)];

my $actual = [ sort $class->$method() ];

is_deeply( $actual, $expected, 'Some extra reports' );
}
