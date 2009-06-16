package MyCPAN::App::DPAN;
use strict;
use warnings;

use base qw(MyCPAN::App::BackPAN::Indexer);
use vars qw($VERSION);

use Cwd qw(cwd);
use File::Spec::Functions;
use Log::Log4perl;

$VERSION = '1.23_01';

BEGIN {

my $cwd = cwd();

my $report_dir = catfile( $cwd, 'indexer_reports' );

my %Defaults = (
	ignore_packages       => 'main MY MM DB bytes DynaLoader',
	indexer_class         => 'MyCPAN::App::DPAN::Indexer',
	dispatcher_class      => 'MyCPAN::Indexer::Dispatcher::Serial',
	organize_dists        => 0,
	parallel_jobs         => 1,
	pause_id              => 'DPAN',
	reporter_class        => 'MyCPAN::App::DPAN::Reporter::Minimal',
	backpan_dir           => [ $cwd ]
	);

sub default_keys
	{
	my %Seen;
	grep { ! $Seen{$_}++ } keys %Defaults, $_[0]->SUPER::default_keys;
	}
	
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

sub components
	{
	(
	[ qw( queue      MyCPAN::Indexer::Queue                get_queue      ) ],
	[ qw( dispatcher MyCPAN::Indexer::Dispatcher::Serial   get_dispatcher ) ],
	[ qw( reporter   MyCPAN::App::DPAN::Reporter::Minimal  get_reporter   ) ],
	[ qw( worker     MyCPAN::Indexer::Worker               get_task       ) ],
	[ qw( interface  MyCPAN::Indexer::Interface::Text      do_interface   ) ],
	[ qw( reporter   MyCPAN::App::DPAN::Reporter::Minimal  final_words    ) ],
	)
	}

1;

=head1 NAME

MyCPAN::App::DPAN - Create a CPAN-like structure out of some dists

=head1 SYNOPSIS

	use MyCPAN::App::DPAN;
	
	MyCPAN::App::DPAN->activate( @ARGV );
	
=head1 DESCRIPTION

This module ties together all the bits to let the C<dpan> do its work. It
overrides the defaults in C<MyCPAN::App::BackPAN::Indexer> to provide the
right components.

=cut

=head1 SOURCE AVAILABILITY

This code is in Github:

      git://github.com/briandfoy/mycpan-indexer.git
      git://github.com/briandfoy/mycpan--app--dpan.git

=head1 AUTHOR

brian d foy, C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2008-2009, brian d foy, All Rights Reserved.

You may redistribute this under the same terms as Perl itself.

=cut
