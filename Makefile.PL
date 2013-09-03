use ExtUtils::MakeMaker;

require 5.006;

eval "use Test::Manifest 1.21";

WriteMakefile(
	'NAME'	       => 'MyCPAN::App::DPAN',
	'ABSTRACT'     => 'Create a custom, private DarkPAN repository that looks just like a real CPAN',
	'VERSION_FROM' => 'lib/MyCPAN/App/DPAN.pm',
	'LICENSE'      => 'perl',
	'AUTHOR'       => 'brian d foy <bdfoy@cpan.org>',

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
				url  => 'https://github.com/briandfoy/mycpan--app--dpan',
				web  => 'https://github.com/briandfoy/mycpan--app--dpan',
				}
			}
		},

	clean  => { FILES    => q|MyCPAN-* test-corpus/modules test-corpus/indexer_reports| },

	);
