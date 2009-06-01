package MyCPAN::App::DPAN::Reporter::Minimal;
use strict;
use warnings;

use vars qw($VERSION $logger);
$VERSION = '1.23';

use Carp;
use File::Basename;
use File::Spec::Functions qw(catfile);
use Log::Log4perl;

BEGIN {
	$logger = Log::Log4perl->get_logger( 'Reporter' );
	}

=head1 NAME

MyCPAN::App::DPAN::Reporter::Minimal - Save the minimum information that dpan needs

=head1 SYNOPSIS

Use this in the dpan config by specifying it as the reporter class:

	# in backpan_indexer.config
	reporter_class  MyCPAN::App::DPAN::Reporter::Minimal

=head1 DESCRIPTION

This class takes the result of examining a distribution and saves only the information
that dpan needs to create the PAUSE index files. It's a very small text file
with virtually no processing overhead compared to YAML.

=head2 Methods

=over 4

=item get_reporter( $Notes )

C<get_reporter> sets the C<reporter> key in the C<$Notes> hash reference. The
value is a code reference that takes the information collected about a distribution
and dumps it as a YAML file.

See L<MyCPAN::Indexer::Tutorial> for details about what C<get_reporter> expects
and should do.

=cut

sub get_reporter
	{
	#TRACE( sub { get_caller_info } );

	my( $class, $Notes ) = @_;

	$Notes->{reporter} = sub {
		my( $Notes, $info ) = @_;

		unless( defined $info )
			{
			$logger->error( "info is undefined!" );
			return;
			}

		my $dist = $info->dist_info( 'dist_file' );
		$logger->error( "Info doesn't have dist_name! WTF?" ) unless $dist;

		no warnings 'uninitialized';
		( my $basename = basename( $dist ) ) =~ s/\.(tgz|tar\.gz|zip)$//;

		my $out_dir_key  = $info->run_info( 'completed' ) ? 'success' : 'error';

		$out_dir_key = 'error' if grep { $info->run_info($_) }
			qw(error fatal_error);

		my $out_path = catfile(
			$Notes->{config}->get( "${out_dir_key}_report_subdir" ),
			"$basename.txt"
			);

		open my($fh), ">", $out_path or $logger->fatal( "Could not open $out_path: $!" );
		print $fh "# Primary package [TAB] version [newline]\n";
		foreach my $module ( @{ $info->{dist_info}{module_info} || [] } )
			{
			next 
			my $version = $module->{version_info}{value};
			$version = $version->numify if eval { $version->can('numify') };

			print $fh join "\t",
				$module->{primary_package},
				$version,
				$module->{dist_file};
				
			print $fh "\n";
			}
		close $fh;

		$logger->error( "$basename.yml is missing!" ) unless -e $out_path;

		1;
		};

	1;
	}

=item final_words( $Notes )

C<get_reporter> sets the C<reporter> key in the C<$Notes> hash reference. The
value is a code reference that takes the information collected about a distribution
and counts the modules used in the test files.

See L<MyCPAN::Indexer::Tutorial> for details about what C<get_reporter> expects
and should do.

=cut

sub final_words
	{
	# This is where I want to write 02packages and CHECKSUMS
	my( $class, $Notes ) = @_;

	$logger->trace( "Final words from the DPAN Reporter" );

	my $report_dir = $Notes->{config}->success_report_subdir;
	$logger->debug( "Report dir is $report_dir" );

	opendir my($dh), $report_dir or
		$logger->fatal( "Could not open directory [$report_dir]: $!");

	my %dirs_needing_checksums;

	require CPAN::PackageDetails;
	my $package_details = CPAN::PackageDetails->new;

	$logger->info( "Creating index files" );

	$class->_init_skip_package_from_config( $Notes );
	
	require version;
	FILE: foreach my $file ( readdir( $dh ) )
		{
		next unless $file =~ /\.txt\z/;
		$logger->debug( "Processing output file $file" );
		
		open my($fh), '<', $file or do {
			$logger->error( "Could not open file: $!" );
			next FILE;
			};
		
		MODULE: foreach my $module ( <$fh>  )
			{
			chomp;
			my( $package, $version, $dist_file ) = split /\t/;
			
			next MODULE unless -e $dist_file; # && $dist_file =~ m/^\Q$backpan_dir/;
			my $dist_dir = dirname( $dist_file );
			$dirs_needing_checksums{ $dist_dir }++;
			

			( my $version_variable = $module->{version_info}{identifier} || '' )
				=~ s/(?:\:\:)?VERSION$//;
			$logger->debug( "Package from version variable is $version_variable" );

			PACKAGE: foreach my $package ( @$packages )
				{
				if( $version_variable && $version_variable ne $package )
					{
					$logger->debug( "Skipping package [$package] since version variable [$version_variable] is in a different package" );
					next;
					}

				# broken crap that works on Unix and Windows to make cpanp
				# happy. It assumes that authors/id/ is in front of the path
				# in 02paackages
				( my $path = $dist_file ) =~ s/.*authors.id.//g;

				$path =~ s|\\+|/|g; # no windows paths.

				if( $class->skip_package( $package ) )
					{
					$logger->debug( "Skipping $package: excluded by config" );
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

	$class->_create_index_files( $Notes, $package_details, [ keys %dirs_needing_checksums ] );
	
	1;
	}

sub _create_index_files
	{
	my( $class, $Notes, $package_details, $dirs_needing_checksums ) = @_;
	
	my $index_dir = do {
		my $d = $Notes->{config}->backpan_dir;
		
		# there might be more than one if we pull from multiple sources
		# so make the index in the first one.
		my $abs = rel2abs( ref $d ? $d->[0] : $d );
		$abs =~ s/authors.id.*//;
		catfile( $abs, 'modules' );
		};
	
	mkpath( $index_dir ) unless -d $index_dir;

	my $packages_file = catfile( $index_dir, '02packages.details.txt.gz' );

	$logger->info( "Writing 02packages.details.txt.gz" );	
	$package_details->write_file( $packages_file );

	$logger->info( "Writing 03modlist.txt.gz" );	
	$class->create_modlist( $index_dir );

	$logger->info( "Creating CHECKSUMS files" );	
	$class->create_checksums( $dirs_needing_checksums );
	
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
	my( $self, $Notes ) = @_;
	
	%skip_packages =
		map { $_, 1 }
		grep { defined }
		split /\s+/,
		$Notes->{config}->ignore_packages || '';
	
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

=head1 TO DO

=head1 SOURCE AVAILABILITY

This code is in Github:

	git://github.com/briandfoy/mycpan-indexer.git

=head1 AUTHOR

brian d foy, C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2008-2009, brian d foy, All Rights Reserved.

You may redistribute this under the same terms as Perl itself.

=cut

1;
