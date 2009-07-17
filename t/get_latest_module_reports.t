#!/usr/bin/perl
use strict;
use warnings;

use Test::More 'no_plan';

use File::Spec::Functions qw(catfile);

my $class      = 'MyCPAN::App::DPAN::Reporter::Minimal';
my $report_dir = catfile( qw(t indexer_reports success) );

BEGIN { $INC{'Log/Log4perl.pm'} = 1; package Log::Log4perl; sub AUTOLOAD { __PACKAGE__ }; }

use_ok( $class );

{
no strict 'refs';
no warnings 'redefine';
*{"${class}::get_success_report_dir"} = sub { $report_dir };
}

my $coordinator_class = 'MyCPAN::Indexer::Coordinator';
use_ok( $coordinator_class );
my $coordinator = $coordinator_class->new;
isa_ok( $coordinator, $coordinator_class );

use_ok( 'ConfigReader::Simple' );
my $config = ConfigReader::Simple->new;
$config->set( 'backpan_dir', 'foo' );
$coordinator->set_config( $config );

my $queue_class = 'QueueMock';
my $queue_mock = bless {}, $queue_class;
{
no strict 'refs';
no warnings 'redefine';
*{"${queue_class}::_get_file_list"} = sub { [ qw(a b c) ] };
*{"${queue_class}::get_queue"} = sub { qw(a b c) };
}
$coordinator->set_queue( $queue_mock );

my $mock = bless { _coordinator => $coordinator }, $class;
can_ok( $mock, 'set_coordinator' );
ok( $mock->set_coordinator( $coordinator ) );
ok( $coordinator->set_reporter( $mock ) );

can_ok( $mock, 'get_success_report_dir' );
can_ok( $mock, 'get_latest_module_reports' );

ok( -d $mock->get_success_report_dir, 'Report directory exists' );

TODO: {
local $TODO = "Need to add a coordinator object";
my @files = $mock->get_latest_module_reports;

is( scalar @files, 1, "There is only one report" );

is( $files[0], 
	catfile( $report_dir, 'Foo-Bar-0.02.txt' ), 
	'The report is the lastest one' 
	);
}
