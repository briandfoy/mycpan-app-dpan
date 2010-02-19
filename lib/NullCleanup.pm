package MyCPAN::App::DPAN::NullCleanup;

sub run
	{
	my( $self, $application ) = @_;

	my $coordinator = $application->get_coordinator;
	my $config      = $coordinator->get_config;

	print "I'm the null cleanup class and I'm done before I start!\n";

	return 1;
	}

1;
