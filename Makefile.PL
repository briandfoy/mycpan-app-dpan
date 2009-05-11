use ExtUtils::MakeMaker;

require 5.006;

eval "use Test::Manifest 1.21";

WriteMakefile(
	'NAME'	       => 'MyCPAN::App::DPAN',
	'ABSTRACT'     => 'Create a custom, private DarkPAN repository that looks just like a real CPAN',
	'VERSION_FROM' => 'lib/App-DPAN.pm',
	'LICENSE'      => 'perl',
	'AUTHOR'       => 'brian d foy <bdfoy@cpan.org>',
	
	'PREREQ_PM'    => { 
		'CPAN::Checksums'      => '0',
		'CPAN::PackageDetails' => '0.18',
		'Log::Log4perl'        => '0',
		'MyCPAN::Indexer'      => '1.18_03',
		'Test::Output'         => '0.13',
		'version'              => '0',
		'YAML'                 => '0',
		},
	
	'PM'           => {
		'lib/Indexer-DPAN.pm'     => '$(INST_LIBDIR)/Indexer/DPAN.pm',
		'lib/App-DPAN.pm'         => '$(INST_LIBDIR)/DPAN.pm',
		},

	'MAN3PODS'     => {},

	'EXE_FILES'    => [ qw(script/dpan) ],
	
	clean  => { FILES    => q|MyCPAN-*| },

	);
