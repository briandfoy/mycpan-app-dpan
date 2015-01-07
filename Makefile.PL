require 5.006;
use strict;
use warnings;


my $github    = 'https://github.com/briandfoy/';
my $main_file = 'lib/';

my %WriteMakefile = (
	'NAME'         => 'MyCPAN::App::DPAN',
	'ABSTRACT_FROM' => $main_file,
	'VERSION_FROM' => 'lib/MyCPAN/App/DPAN.pm',
	'LICENSE'      => 'perl',
	'AUTHOR'       => 'brian d foy <bdfoy@cpan.org>',

	'CONFIGURE_REQUIRES' => {
		'ExtUtils::MakeMaker' => '6.64',
		},

	'BUILD_REQUIRES' => {
		},

	'TEST_REQUIRES' => {
		'Test::More' => '0.94',
		},

	'PREREQ_PM'     => {
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
	'PREREQ_PM'    => { 
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

	'EXE_FILES'    => [ qw(script/dpan) ],

	META_MERGE => {
		'meta-spec' => { version => 2 },
		resources => {
			repository => {
				type => 'git',
				url  => 'git@github.com:briandfoy/mycpan--app--dpan.git',
				web  => 'https://github.com/briandfoy/mycpan--app--dpan',
				}
			}
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
			//
		"$MM 6.64";
	eval "use $MM_version" || die "Could not load $MM_version: $@";
	eval "use Test::Manifest 1.21" 
		if -e File::Spec->catfile( qw(t test_manifest) );
	WriteMakefile( %WriteMakefile );
	}


no warnings;
__PACKAGE__;
