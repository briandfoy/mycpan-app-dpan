#!perl
use strict;
use warnings;

use Test::More tests => 6;

use File::Path qw(rmtree);
use File::Spec::Functions;

my $dir = 'test-corpus';
SKIP: {
	skip "Test corpus is not present. Skipping tests.", 10 unless -d $dir;
	
	chdir $dir;
	my $report_dir = 'indexer_reports';
	rmtree $report_dir;
	ok( ! -d $report_dir, "$report_dir is gone" );

	my $modules_dir = 'modules';
	rmtree $modules_dir;
	ok( ! -d $modules_dir, "$modules_dir is gone" );
	
	system( '../blib/script/dpan' );
	
	ok( -d $report_dir, "$report_dir is there now" );

	ok( -d $modules_dir, "$modules_dir is gone" );

	my $package_file = catfile( $modules_dir, '02packages.details.txt.gz' );
 	ok( -e $package_file, "$package_file is there" );
	
	my $modlist_file = catfile( $modules_dir, '03modlist.data.gz' );
 	ok( -e $modlist_file, "$modlist_file is there" );
 
	};
