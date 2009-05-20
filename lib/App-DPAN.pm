package MyCPAN::App::DPAN;
use strict;
use warnings;

use base qw( MyCPAN::App::Indexer::DPAN );
use vars qw($VERSION);

use Carp;
use Cwd qw(cwd);
use File::Temp qw(tempdir);
use File::Spec::Functions qw(catfile);
use Log::Log4perl;

$VERSION = '1.21';

BEGIN {
my $cwd = cwd();

my $report_dir = catfile( $cwd, 'indexer_reports' );

my %Defaults = (
	indexer_class         => 'MyCPAN::App::Indexer::DPAN',
	reporter_class        => 'MyCPAN::App::Indexer::DPAN',
	parallel_jobs         => 1,
	organize_dists        => 0,
	pause_id              => 'DPAN',
	);

sub default
	{
	exists $Defaults{ $_[1] }
		?
	$Defaults{ $_[1] }
		:
	$_[0]->SUPER::default( $_[1] );
	}

my $logger = Log::Log4perl->get_logger( 'backpan_indexer' );
}

1;
