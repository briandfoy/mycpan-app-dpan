use ExtUtils::MakeMaker;

require 5.006;

eval "use Test::Manifest 1.21";

WriteMakefile(
	'NAME'	       => 'MyCPAN::App::DPAN',
	'ABSTRACT'     => 'Create a custom, private DarkPAN repository',
	'VERSION_FROM' => 'lib/DPAN.pm',
	'LICENSE'      => 'perl',
	'AUTHOR'       => 'brian d foy <bdfoy@cpan.org>',
	
	'PREREQ_PM'    => { 
		'MyCPAN::Indexer'      => '1.19',
		'CPAN::PackageDetails' => '0.18',
		},
	
	'PM'           => {
		'lib/Indexer.pm'  => '$(INST_LIBDIR)/DPAN/Indexer.pm',
		'lib/DPAN.pm'     => '$(INST_LIBDIR)/DPAN.pm',
		},

	'EXE_FILES'    => [ 'script/dpan' ],

	clean  => { FILES    => q|MyCPAN-*| },

	);
