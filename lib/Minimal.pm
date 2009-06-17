package MyCPAN::App::DPAN::Reporter::Minimal;
use strict;
use warnings;

use base qw(MyCPAN::Indexer::Reporter::Base);
use vars qw($VERSION $logger);
$VERSION = '1.24';

use Carp;
use File::Basename;
use File::Path;
use File::Spec::Functions qw(catfile rel2abs);
use Log::Log4perl;

BEGIN {
	$logger = Log::Log4perl->get_logger( 'Reporter' );
	}

=head1 NAME

MyCPAN::App::DPAN::Reporter::Minimal - Save the minimum information that dpan needs

=head1 SYNOPSIS

Use this in the C<dpan> config by specifying it as the reporter class:

	# in dpan.config
	reporter_class  MyCPAN::App::DPAN::Reporter::Minimal

=head1 DESCRIPTION

This class takes the result of examining a distribution and saves only
the information that dpan needs to create the PAUSE index files. It's
a very small text file with virtually no processing overhead compared
to YAML.

=head2 Methods

=over 4

=item get_reporter

C<get_reporter> sets the C<reporter> key in the notes. The value is a
code reference that takes the information collected about a
distribution and dumps it as a YAML file.

See L<MyCPAN::Indexer::Tutorial> for details about what
C<get_reporter> expects and should do.

=cut

sub get_report_file_extension { 'txt' }

sub get_reporter
	{
	#TRACE( sub { get_caller_info } );

	my( $self ) = @_;

	my $reporter = sub {
		my( $info ) = @_;

		unless( defined $info )
			{
			$logger->error( "info is undefined!" );
			return;
			}

		my $out_path = $self->get_report_path( $info );

		open my($fh), ">", $out_path or $logger->fatal( "Could not open $out_path: $!" );
		print $fh "# Primary package [TAB] version [TAB] dist file [newline]\n";
		foreach my $module ( @{ $info->{dist_info}{module_info} || [] } )
			{
			# skip if we are ignoring those packages?
			my $version = $module->{version_info}{value} || 'undef';
			$version = $version->numify if eval { $version->can('numify') };

			$logger->warn( "No primary package for $module->{name}" )
				unless defined $module->{primary_package};

			$logger->warn( "No dist file for $module->{name}" )
				unless defined $info->{dist_info}{dist_file};
				
			print $fh join "\t",
				$module->{primary_package},
				$version,
				$info->{dist_info}{dist_file};
				
			print $fh "\n";
			}
		close $fh;

		$logger->error( "$out_path is missing!" ) unless -e $out_path;

		1;
		};
		
	$self->set_note( 'reporter', $reporter );
	}
	
=item final_words

Runs after all the reporting for all distributions has finished. This
creates a C<CPAN::PackageDetails> object and stores it as the C<package_details>
notes. It store the list of directories that need fresh F<CHECKSUMS> files
in the C<dirs_needing_checksums> note.

The checksums and index file creation are split across two steps so that
C<dpan> has a chance to do something between the analysis and their creation.

=cut

sub final_words
	{
	# This is where I want to write 02packages and CHECKSUMS
	my( $self ) = @_;

	$logger->trace( "Final words from the DPAN Reporter" );

	my %dirs_needing_checksums;

	require CPAN::PackageDetails;
	my $package_details = CPAN::PackageDetails->new;

	$logger->info( "Creating index files" );

	$self->_init_skip_package_from_config;
	
	require version;
	FILE: foreach my $file ( $self->get_latest_module_reports )
		{
		$logger->debug( "Processing output file $file" );
		
		open my($fh), '<', $file or do {
			$logger->error( "Could not open [$file]: $!" );
			next FILE;
			};
		
		my @packages;
		PACKAGE: while( <$fh>  )
			{
			next PACKAGE if /^\s*#/;
			
			chomp;
			my( $package, $version, $dist_file ) = split /\t/;
			$version = undef if $version eq 'undef';
			
			next MODULE unless -e $dist_file; # && $dist_file =~ m/^\Q$backpan_dir/;
			my $dist_dir = dirname( $dist_file );
			$dirs_needing_checksums{ $dist_dir }++;

			# broken crap that works on Unix and Windows to make cpanp
			# happy. It assumes that authors/id/ is in front of the path
			# in 02paackages
			( my $path = $dist_file ) =~ s/.*authors.id.//g;

			$path =~ s|\\+|/|g; # no windows paths.

			if( $self->skip_package( $package ) )
				{
				$logger->debug( "Skipping $package: excluded by config" );
				next PACKAGE;
				}
			
			push @packages, [ $package, $version, $path ];
			}
		
		# Some distros declare the same package in multiple files. We
		# only want the one with the defined or highest version
		my %Seen;
		my @filtered_packages =
			grep { ! $Seen{$_->[0]}++ }
			sort {
				$a->[0] cmp $b->[0]
					||
				$b->[1] cmp $a->[1]  # yes, versions are strings
				}
			map { my $s = $_; $s->[1] = 'undef' unless defined $s->[1]; $s }
			@packages;

		foreach my $tuple ( @filtered_packages )
			{
			my( $package, $version, $path ) = @$tuple;
			
			eval { $package_details->add_entry(
				'package name' => $package,
				version        => $version,
				path           => $path,
				) } or warn "Could not add $package $version from $path! $@\n";
			}
		}

	$self->set_note( 'package_details', $package_details );
	$self->set_note( 'dirs_needing_checksums', [ keys %dirs_needing_checksums ] );
	
	1;
	}

sub get_latest_module_reports
	{
	my( $self, $directory ) = @_;
	
	my $report_dir = $self->get_success_report_dir;
	$logger->debug( "Report dir is $report_dir" );

	opendir my($dh), $report_dir or
		$logger->fatal( "Could not open directory [$report_dir]: $!");

	my %Seen = ();
	my @files = 
		map  { catfile( $report_dir, $_->[-1] ) }
		grep { ! $Seen{$_->[0]}++ } 
		map  { [ /^(.*)-(.*)\.txt\z/, $_ ] }
		reverse 
		sort 
		grep { /\.txt\z/ } 
		readdir( $dh );

	}
	
sub create_index_files
	{
	my( $self ) = @_;
	
	my $index_dir = do {
		my $d = $self->get_config->backpan_dir;
		
		# there might be more than one if we pull from multiple sources
		# so make the index in the first one.
		my $abs = rel2abs( ref $d ? $d->[0] : $d );
		$abs =~ s/authors.id.*//;
		catfile( $abs, 'modules' );
		};
	
	mkpath( $index_dir ) unless -d $index_dir; # XXX

	my $packages_file = catfile( $index_dir, '02packages.details.txt.gz' );

	my $package_details = $self->get_note( 'package_details' );
	
	$logger->info( "Writing 02packages.details.txt.gz" );	
	$package_details->write_file( $packages_file );

	$logger->info( "Writing 03modlist.txt.gz" );	
	$self->create_modlist( $index_dir );

	$logger->info( "Creating CHECKSUMS files" );	
	$self->create_checksums( $self->get_note( 'dirs_needing_checksums' ) );
	
	1;
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
		$self->get_config->ignore_packages || '';
	
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
	$logger->debug( "modules list file is [$module_list_file]");

	if( -e $module_list_file )
		{
		$logger->debug( "File [$module_list_file] already exists!" );
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
			$logger->error( "Couldn't create CHECKSUMS for $dir: $@" ) if $@;
			$logger->info(
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

	git://github.com/briandfoy/mycpan--app--dpan.git

=head1 AUTHOR

brian d foy, C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2009, brian d foy, All Rights Reserved.

You may redistribute this under the same terms as Perl itself.

=cut

1;
