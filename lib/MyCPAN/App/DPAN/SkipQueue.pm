require v5.14;

package MyCPAN::App::DPAN::SkipQueue;
use strict;
use warnings;

use base qw(MyCPAN::Indexer::Queue);
use vars qw($logger);
our $VERSION = '1.282';

use File::Basename;
use File::Find;
use File::Find::Closures qw( find_by_regex );
use File::Path qw(mkpath);
use File::Spec::Functions qw( catfile rel2abs );
use Log::Log4perl;

BEGIN {
	$logger = Log::Log4perl->get_logger( 'Queue' );
	}

=encoding utf8

=head1 NAME

MyCPAN::App::DPAN::Queue - Find distributions to index, possibly skipping some

=head1 SYNOPSIS

Use this from your C<dpan> configuration file by specifying it as the
queue class:

	queue_class  MyCPAN::App::DPAN::SkipQueue
	skip_perl    1

	# not yet implemented
	skip_name   Foo::Bar Bar::Baz
	skip_regex  Foo::.*

=head1 DESCRIPTION

This class returns a list of Perl distributions for the BackPAN
indexer to process.

=head2 Methods

=over 4

=item get_queue

This extends the C<get_queue> method from  C<MyCPAN::Indexer::Queue>
to filter the list of files it returns.

C<get_queue> sets the key C<queue> in C<$Notes> hash reference. It
finds all of the tarballs or zip archives in under the directories
named in C<dpan_dir> and C<merge_dirs> in the configuration.

It specifically skips files that end in C<.txt.gz> or C<.data.gz>
since PAUSE creates those meta files near the actual module
installations.

If the C<organize_dists> configuration value is true, it also copies
any distributions it finds into a PAUSE-like structure using the
value of the C<pause_id> configuration to create the path.

If C<skip_perl> is true, it filters out any distributions matching
C<\bperl->.

=cut

sub _get_file_list
	{
	my( $self, @dirs ) = @_;

	my $files = $self->SUPER::_get_file_list( @dirs );

	$logger->debug( "There are " . @$files . " files in the queue" );

	for( my $i = $#$files; $i >= 0; $i-- )
		{
		splice @$files, $i, 1, ()
			if $self->_basename_matches_skip( $files->[$i] );
		}

	$logger->debug( "After filtering, there are " .
		@$files . " files in the queue" );
	return $files;
	}

sub _basename_matches_skip
	{
	my( $self, $distname ) = @_;

	my $skip_perl = $self->get_coordinator->get_config->get( 'skip_perl' ) || 0;
	my @skip_regexes = grep { defined }
		$self->get_coordinator->get_config->get( 'skip_dists_regexes' );

	my @compiled_regexes = map {
		$logger->debug( "Trying to compile regex [$_]" );
		my $compiled = eval { qr/$_/ };
		$logger->fatal( "Could not compile regex [$_] from skip_dists_regexes: $@" )
			unless ref $compiled eq ref qr//;
		} @skip_regexes;

	push @skip_regexes, qr/^(?:strawberry-)?perl-/ if $skip_perl;

	$logger->debug( "skip_perl is [$skip_perl]" );
	$logger->debug( "skip_dists_regexes is [@skip_regexes]" );

	my $basename = basename( $distname );
	foreach my $regex ( @skip_regexes )
		{
		if( $basename =~ m/$regex/ )
			{
			$logger->debug( "Dist $basename matches $regex" );
			return $regex;
			}
		}

	return 0;
	}

=back

=head1 SEE ALSO

MyCPAN::Indexer::Queue

=head1 SOURCE AVAILABILITY

This code is in Github:

	https://github.com/briandfoy/mycpan-app-dpan.git

=head1 AUTHOR

brian d foy, C<< <briandfoy@pobox.com> >>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010-2025, brian d foy <briandfoy@pobox.com>. All rights reserved.

You may redistribute this under the terms of the Artistic License 2.0.

=cut
