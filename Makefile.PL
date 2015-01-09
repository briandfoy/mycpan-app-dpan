require 5.008;
use strict;
use warnings;

use File::Spec::Functions qw(catfile);

my $module    = 'MyCPAN::App::DPAN';
my $github    = 'https://github.com/briandfoy/mycpan-app-dpan';
my $main_file = catfile( 'lib', split /::/, "$module.pm" );

my %WriteMakefile = (
	'NAME'          => $module,
	'ABSTRACT_FROM' => $main_file,
	'VERSION_FROM'  => $main_file,
	'LICENSE'       => 'perl',
	'AUTHOR'        => 'brian d foy <bdfoy@cpan.org>',

	'EXE_FILES'    => [ qw(script/dpan) ],

	'CONFIGURE_REQUIRES' => {
		'ExtUtils::MakeMaker'   => '6.64',
		'File::Spec::Functions' => '0',
		},

	'BUILD_REQUIRES' => {
		},

	'TEST_REQUIRES' => {
		'Test::More' => '0.94',
		},

	'PREREQ_PM'     => {
		'CPAN::Checksums'      => '0',
		'CPAN::PackageDetails' => '0.24',
		'IPC::Cmd'             => '0',
		'IPC::System::Simple'  => '0',
		'Log::Log4perl'        => '0',
		'MyCPAN::Indexer'      => '1.28_04',
		'LWP::Simple'          => '0',
		'Test::Output'         => '0.13',
		'version'              => '0',
		},

	'META_MERGE' => {
		'meta-spec' => { version => 2 },
		resources => {
			repository => {
				type => 'git',
				url  => "$github.git",
				web  => $github,
				},
			bugtraker => {
				web    => "$github/issues",
				},
			homepage => $github,
			},
		},

	clean  => { FILES => q|MyCPAN-* test-corpus/modules test-corpus/indexer_reports| },
	);

sub arguments { \%WriteMakefile }

do_it() unless caller;
sub do_it {
	require File::Spec;
	my $MM ='ExtUtils::MakeMaker';
	my $MM_version =
		eval{ "$MM " . $WriteMakefile{'CONFIGURE_REQUIRES'}{'ExtUtils::MakeMaker'} }
			||
		"$MM 6.64";
	eval "use $MM_version; 1" or die "Could not load $MM_version: $@";
	eval "use Test::Manifest 1.21" 
		if -e File::Spec->catfile( qw(t test_manifest) );
	WriteMakefile( %WriteMakefile );
	}


no warnings;
__PACKAGE__;
