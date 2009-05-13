package MyCPAN::App::DPAN;
use strict;
use warnings;

use base qw( MyCPAN::App::BackPAN::Indexer );
use vars qw($VERSION);

use Cwd qw(cwd);
use File::Temp qw(tempdir);
use File::Spec::Functions qw(catfile);

$VERSION = '1.18';

BEGIN {
my $cwd = cwd();

my $report_dir = catfile( $cwd, 'indexer_reports' );
my $temp_dir   = File::Temp->new(
	DIR     => $cwd,
	CLEANUP => 1,
	);
	
my %Defaults = (
	report_dir            => $report_dir,
	temp_dir              => $temp_dir,
	'alarm'               => 15,
	copy_bad_dists        => 0,
	retry_errors          => 1,
	indexer_id            => 'Joe Example <joe@example.com>',
	system_id             => 'an unnamed machine',
	indexer_class         => 'MyCPAN::App::DPAN::Indexer',
	queue_class           => 'MyCPAN::Indexer::Queue',
	dispatcher_class      => 'MyCPAN::Indexer::Dispatch::Parallel',
	interface_class       => 'MyCPAN::Indexer::Interface::Text',
	worker_class          => 'MyCPAN::Indexer::Worker',
	reporter_class        => 'MyCPAN::App::DPAN::Indexer',
	parallel_jobs         => 1,
	);

sub default 
	{ 
	exists $Defaults{ $_[1] } 
		?
	$Defaults{ $_[1] } 
		:
	$_[0]->SUPER::default( $_[1] );
	}
}

sub run
	{
	my $class = shift;
	
	print "dpan $VERSION\n";

	$class->SUPER::run( @_ );
	}
1;
