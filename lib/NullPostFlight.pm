package MyCPAN::App::DPAN::NullPostFlight;

sub run
	{
	my( $self, $application ) = @_;

	my $coordinator = $application->get_coordinator;
	my $config      = $coordinator->get_config;

	print "I'm the null postflight class and I'm done before I start!\n";

	return 1;
	}

1;
