#!/usr/bin/perl

use Test::More 'no_plan';

use File::Spec::Functions qw(catfile);

my $class      = 'MyCPAN::App::DPAN::Reporter::Minimal';
my $report_dir = catfile( qw(t indexer_reports success) );

BEGIN { $INC{'Log/Log4perl.pm'} = 1; package Log::Log4perl; sub AUTOLOAD { __PACKAGE__ }; }

use_ok( $class );

no warnings 'redefine';
*{"${class}::get_success_report_dir"} = sub { $report_dir };
		
my $mock = bless { }, $class;
can_ok( $mock, 'get_success_report_dir' );
can_ok( $mock, 'get_latest_module_reports' );

ok( -d $mock->get_success_report_dir, 'Report directory exists' );

my @files = $mock->get_latest_module_reports;

is( scalar @files, 1, "There are not files yet" );

is( $files[0], catfile( $report_dir, 'Foo-Bar-0.02.txt' ) );
