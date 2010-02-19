package MyCPAN::App::DPAN::SVNPostFlight;
use strict;
use warnings;
use vars qw( $logger );

use Data::Dumper;
use IPC::Cmd;
use IPC::Run qw();
use IPC::System::Simple qw(capturex systemx);
use Log::Log4perl;
use XML::Simple;

BEGIN {
$logger = Log::Log4perl->get_logger( 'PostFlight' );
}

BEGIN {
my $svn = IPC::Cmd::can_run( 'svn' );
$logger->debug( "svn commmand is [$svn]" );

sub svn { $svn }

sub dry_run { $_[0]->{postflight_dry_run} }

sub run_svn
	{
	my( $self, @commands ) = @_;
	
	if( $self->dry_run )
		{
		print "dry run: $svn @commands\n";
		}
	else
		{
		return capturex( $self->svn, @commands );
		}
	}
	
}

sub run
	{
	my( $class, $application ) = @_;

	my $config = $application->get_coordinator->get_config;
	
	my $self = bless 
		{ 
		postflight_dry_run => $config->get( 'postflight_dry_run' ),
		}, $class;
		
	my $commands = $self->_get_commands;
	
	$self->_handle_commands( $commands );
	
	$self->_report_repo_url;
	}	

BEGIN {
my %Commands = (
	'unversioned' => 'add',
	'deleted'     => 'rm',
	);
	
sub _get_commands
	{
	my( $self ) = @_;
	my $xml = $self->_get_svn_status_xml;
	
	my $ref = XMLin( $xml );

	my( @commands, @conflicts );
	foreach my $entry ( @{ $ref->{target}{entry} } )
		{
		my $status = $entry->{'wc-status'}{item};
		my $path   = $entry->{path};
		if( exists $Commands{ $status } )
			{
			push @commands, [ $Commands{ $status }, $path ];
			}
		if( $status eq 'conflicted' )
			{
			push @conflicts, $path;
			}
		}
	
	if( @conflicts )
		{
		my $list = join "\n\t", @conflicts;
		
		$logger->logdie( "I can't continue. There are conflicts in svn:\n\t$list\n" );
		return;
		}
		
	\@commands;
	}
}

sub _svn_update
	{
	my( $self ) = @_;
	my $output = capturex( $self->svn, 'update' );
	$logger->debug( "svn status output: $output" );
	$output;		
	}

sub _get_svn_status_xml
	{
	my( $self ) = @_;
	# don't use run_svn because we have to still run for dry run
	my $status = capturex( $self->svn, 'status', '--xml' ); 
	$logger->debug( "svn status output: $status" );
	$status;
	}

sub _handle_commands
	{
	my( $self, $commands ) = @_;

	my $svn = $self->svn;
	
	$self->_svn_update;
	
	foreach my $command ( @$commands )
		{
		$logger->debug( "$svn @$command" );
		$self->run_svn( @$command );
		}

	my @commit_command = (  $svn, 'commit', '-m', 'DPAN PostFlight commit' );
	
	my( $in, $output ) = ( '' );
	
	IPC::Run::run( \@commit_command, \$in, \$output, \$output ) 
		or do {
			$logger->debug( "svn commit output: $output" );
			$logger->logdie( "Could not commit to svn!" );
			return;
			};

	return 1;
	}

sub _report_repo_url
	{
	my( $self ) = @_;
	
	my $xml = capturex( $self->svn, 'info', '--xml' );
	$logger->debug( "svn info output: $xml" );
	
	my $ref  = XMLin( $xml );
	my $repo = $ref->{entry}{url};	
	print "To use this DPAN, point your CPAN tool to:\n\n\t$repo\n\n";
	}

1;
