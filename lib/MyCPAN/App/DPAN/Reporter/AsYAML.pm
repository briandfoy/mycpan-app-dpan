require v5.14;

package MyCPAN::App::DPAN::Reporter::AsYAML;
use strict;
use warnings;

use subs qw(get_caller_info);
use vars qw($reporter_logger $collator_logger);

# don't change the inheritance order
# this should be done with roles, but we don't quite have that yet
# it's a problem with who's cleanup() get called
use base qw(MyCPAN::Indexer::Reporter::AsYAML);

use Cwd qw(cwd);
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use File::Spec::Functions qw(catfile rel2abs);

our $VERSION = '1.282';

=encoding utf8

=head1 NAME

MyCPAN::App::DPAN::Reporter::AsYAML - Record the indexing results as YAML

=head1 SYNOPSIS

Use this in the dpan config by specifying it as the reporter class and
the collator class:

	# in dpan.config
	reporter_class  MyCPAN::App::DPAN::Reporter::AsYAML
	collator_class  MyCPAN::App::DPAN::Reporter::AsYAML

=head1 DESCRIPTION

This module implements the reporter_class components to allow C<dpan>
to create a CPAN-like directory structure with its associated index
files. It runs through the indexing, saves the reports as YAML, and
prints a report at the end of the run.

=cut

use Carp qw(croak);
use Cwd  qw(cwd);

use Log::Log4perl;

BEGIN {
	$reporter_logger = Log::Log4perl->get_logger( 'Reporter' );
	$collator_logger = Log::Log4perl->get_logger( 'Collator' );
	}

# Override the exit from the parent class so we can embed a run
# inside a bigger application. Applications should override this
# on their own to do any final processing they want.
sub _exit { 1 }

=head2 Methods

=over 4

=item get_reporter

Inherited from MyCPAN::App::BackPAN::Indexer

=item get_collator

This Reporter class also implements its Collator since the two are
coupled by the report format. It's a wrapper around C<final_words>,
which previously did the same thing.

=cut

sub get_collator
	{
	#TRACE( sub { get_caller_info } );

	my( $self ) = @_;

	my $collator = sub { $_[0]->final_words( $_[1] ) };

	$self->set_note( 'collator', $collator );

	1;
	}

=item final_words

Creates the F<02packages.details.txt.gz> and F<CHECKSUMS> files once
C<dpan> has analysed every distribution.

=cut

sub final_words
	{
	# This is where I want to write 02packages and CHECKSUMS
	my( $self ) = @_;

	$collator_logger->trace( "Final words from the DPAN Reporter" );

	my $report_dir = $self->get_config->success_report_subdir;
	$collator_logger->debug( "Report dir is $report_dir" );

	opendir my($dh), $report_dir or
		$collator_logger->fatal( "Could not open directory [$report_dir]: $!");

	my %dirs_needing_checksums;

	require CPAN::PackageDetails;
	my $package_details = CPAN::PackageDetails->new;

	$collator_logger->info( "Creating index files" );

	$self->_init_skip_package_from_config;

	require version;
	foreach my $file ( readdir( $dh ) )
		{
		next unless $file =~ /\.yml\z/;
		$collator_logger->debug( "Processing output file $file" );
		my $yaml = eval { YAML::LoadFile( catfile( $report_dir, $file ) ) } or do {
			$collator_logger->error( "$file: $@" );
			next;
			};

		my $dist_file = $yaml->{dist_info}{dist_file};

		#print STDERR "Dist file is $dist_file\n";

		# some files may be left over from earlier runs, even though the
		# original distribution has disappeared. Only index distributions
		# that are still there
		# check that dist file is in one of these directories
		next unless -e $dist_file;

		my $dist_dir = dirname( $dist_file );

		$dirs_needing_checksums{ $dist_dir }++;

=pod

This is the big problem. Since we didn't really parse the source code, we
don't really know how to match up packages and VERSIONs. The best we can
do right now is assume that a $VERSION we found goes with the packages
we found.

Additionally, that package variable my have been in one package, but
been the version for another package. For example:

	package DBI;

	$DBI::PurePerl::VERSION = 1.23;

=cut

		foreach my $module ( @{ $yaml->{dist_info}{module_info} }  )
			{
			my $packages = $module->{packages};
			my $version  = $module->{version_info}{value};
			$version = $version->numify if eval { $version->can('numify') };

			( my $version_variable = $module->{version_info}{identifier} || '' )
				=~ s/(?:\:\:)?VERSION$//;
			$collator_logger->debug( "Package from version variable is $version_variable" );

			PACKAGE: foreach my $package ( @$packages )
				{
				if( $version_variable && $version_variable ne $package )
					{
					$collator_logger->debug( "Skipping package [$package] since version variable [$version_variable] is in a different package" );
					next;
					}

				# broken crap that works on Unix and Windows to make cpanp
				# happy. It assumes that authors/id/ is in front of the path
				# in 02paackages
				( my $path = $dist_file ) =~ s/.*authors.id.//g;

				$path =~ s|\\+|/|g; # no windows paths.

				if( $self->skip_package( $package ) )
					{
					$collator_logger->debug( "Skipping $package: excluded by config" );
					next PACKAGE;
					}

				$package_details->add_entry(
					'package name' => $package,
					version        => $version,
					path           => $path,
					);
				}
			}
		}

	$self->_create_index_files( $package_details, [ keys %dirs_needing_checksums ] );

	1;
	}

sub _create_index_files
	{
	my( $self, $package_details, $dirs_needing_checksums ) = @_;

	my $index_dir = do {
		my $d = $self->get_config->dpan_dir;

		# there might be more than one if we pull from multiple sources
		# so make the index in the first one.
		my $abs = rel2abs( ref $d ? $d->[0] : $d );
		$abs =~ s/authors.id.*//;
		catfile( $abs, 'modules' );
		};

	mkpath( $index_dir ) unless -d $index_dir;

	my $packages_file = catfile( $index_dir, '02packages.details.txt.gz' );

	$reporter_logger->info( "Writing 02packages.details.txt.gz" );
	$package_details->write_file( $packages_file );

	$reporter_logger->info( "Writing 03modlist.txt.gz" );
	$self->create_modlist( $index_dir );

	$reporter_logger->info( "Creating CHECKSUMS files" );
	$self->create_checksums( $dirs_needing_checksums );

	1;
	}

=item guess_package_name

Given information about the module, make a guess about which package
is the primary one. This is

NOT YET IMPLEMENTED

=cut

sub guess_package_name
	{
	my( $self, $module_info ) = @_;


	}

=item get_package_version( MODULE_INFO, PACKAGE )

Get the $VERSION associated with PACKAGE. You probably want to use
C<guess_package_name> first to figure out which package is the
primary one that you should index.

NOT YET IMPLEMENTED

=cut

sub get_package_version
	{


	}

=item skip_package( PACKAGE )

Returns true if the indexer should ignore PACKAGE.

By default, this skips the Perl special packages specified by the
ignore_packages configuration. By default, ignore packages is:

	main
	MY
	MM
	DB
	bytes
	DynaLoader

To set a different list, configure ignore_packages with a space
separated list of packages to ignore:

	ignore_packages main Foo Bar::Baz Test

Note that this only ignores those exact packages. You can't configure
this with regex or wildcards (yet).

=cut

BEGIN {
my $initialized = 0;
my %skip_packages;

sub _skip_package_initialized { $initialized }

sub _init_skip_package_from_config
	{
	my( $self ) = @_;

	%skip_packages =
		map { $_, 1 }
		grep { defined }
		split /\s+/,
		$self->get_notes( 'config' )->ignore_packages || '';

	$initialized = 1;
	}

sub skip_package
	{
	my( $self, $package ) = @_;

	exists $skip_packages{ $package }
	}
}

=item create_package_details

Not yet implemented. Otehr code needs to be refactored and show up
here.

=cut

sub create_package_details
    {
    my( $self, $index_dir ) = @_;


    1;
    }

=item create_modlist

If a modules/03modlist.data.gz does not already exist, this creates a
placeholder which defines the CPAN::Modulelist package and the method
C<data> in that package. The C<data> method returns an empty hash
reference.

=cut

sub create_modlist
	{
	my( $self, $index_dir ) = @_;

	my $module_list_file = catfile( $index_dir, '03modlist.data.gz' );
	$reporter_logger->debug( "modules list file is [$module_list_file]");

	if( -e $module_list_file )
		{
		$reporter_logger->debug( "File [$module_list_file] already exists!" );
		return 1;
		}

	my $fh = IO::Compress::Gzip->new( $module_list_file );
	print $fh <<"HERE";
File:        03modlist.data
Description: This a placeholder for CPAN.pm
Modcount:    0
Written-By:  Id: $0
Date:        @{ [ scalar localtime ] }

package CPAN::Modulelist;

sub data { {} }

1;
HERE

	close $fh;
	}

=item create_checksums

Creates the CHECKSUMS file that goes in each author directory in CPAN.
This is mostly a wrapper around CPAN::Checksums since that already handles
updating an entire tree. We just do a little logging.

=cut

sub create_checksums
	{
	my( $self, $dirs ) = @_;

	require CPAN::Checksums;
	foreach my $dir ( @$dirs )
		{
		my $rc = eval{ CPAN::Checksums::updatedir( $dir ) };
			$reporter_logger->error( "Couldn't create CHECKSUMS for $dir: $@" ) if $@;
			$reporter_logger->info(
				do {
					  if(    $rc == 1 ) { "Valid CHECKSUMS file is already present" }
					  elsif( $rc == 2 ) { "Wrote new CHECKSUMS file in $dir" }
					  else              { "updatedir unexpectedly returned an error" }
				} );
		}
	}

=back

=head1 SOURCE AVAILABILITY

This code is in Github:

	https://github.com/briandfoy/mycpan-app-dpan.git

=head1 AUTHOR

brian d foy, C<< <briandfoy@pobox.com> >>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010-2025, brian d foy <briandfoy@pobox.com>. All rights reserved.

You may redistribute this under the terms of the Artistic License 2.0.

=cut
