use Test::More;

my @classes = qw(
	MyCPAN::App::DPAN
	MyCPAN::App::DPAN::Reporter::AsYAML
	MyCPAN::App::DPAN::Reporter::Minimal
	MyCPAN::App::DPAN::Indexer
	MyCPAN::App::DPAN::CPANUtils
	);

foreach my $class ( @classes ) {
	use_ok $class or BAIL_OUT( "$class did not compile: $@" );
	}

done_testing();
