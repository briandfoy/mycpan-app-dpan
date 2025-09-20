#!perl
use v5.14;
use warnings;

use Test::More;

# Nerf rename so we don't play with any files and we can fake it failing
our $Rename_return = 1;
BEGIN { *CORE::GLOBAL::rename = sub { $Rename_return }; }

subtest 'rename overload' => sub {
	is( rename( 'foo', 'bar' ), 1, 'rename overload returns true' );
	};

my $dpan = Mock::Minimal->new;
my $appender = Log::Log4perl->appender_by_name( 'String' );

subtest 'sanity' => sub {
	isa_ok( $dpan, 'Mock::Minimal' );
	can_ok( $dpan, 'create_index_files' );

	can_ok( 'Mock::Minimal', 'get_note' );
	isa_ok( $dpan->get_note( 'package_details' ), 'Mock::CPAN::PackageDetails' );
	};

subtest 'everything works' => sub {
	$appender->string('');
	$Rename_return = 1;
	my $package_details = $dpan->get_note( 'package_details' );
	$package_details->set_count( 137 );
	is( $package_details->count, 137, "package_details reports 137 entries" );
	$package_details->set_check_file_die_message( 0 );

	my $rc = eval { $dpan->create_index_files };
	is( $appender->string, '', 'There is no error message' );
	ok( $rc, "create_index files returns true for 137 entries, no errors" );
	};

subtest 'no entries' => sub {
	$appender->string('');
	$Rename_return = 1;
	my $package_details = $dpan->get_note( 'package_details' );
	$package_details->set_count( 0 );
	is( $package_details->count, 0, "package_details reports no entries" );
	$package_details->set_check_file_die_message( 0 );

	my $rc = eval { $dpan->create_index_files };
	like( $appender->string, qr/no entries/, 'Error message comes from no entries' );
	ok( ! $rc, "create_index files does not return true for zero entries" );
	};

subtest 'check_file fails' => sub {
	$appender->string('');
	$Rename_return = 1;
	my $croak = "Oops, I did it again!";
	my $package_details = $dpan->get_note( 'package_details' );
	$package_details->set_count( 137 );
	$package_details->set_check_file_die_message( $croak );
	my $rc = eval { $dpan->create_index_files };

	like( $appender->string, qr/has a problem/, 'Error message comes from check_file' );
	ok( ! $rc, "create_index files does not return true for check_file error" );
	};

subtest 'rename fails' => sub {
	$appender->string('');
	$Rename_return = 0;
	my $package_details = $dpan->get_note( 'package_details' );
	$package_details->set_count( 137 );
	$package_details->set_check_file_die_message( 0 );
	my $rc = eval { $dpan->create_index_files };

	like( $appender->string, qr/Could not rename/, 'Error message comes from failed rename' );
	ok( ! $rc, "create_index files does not return true for rename error" );
	};

done_testing();

BEGIN {
	use Log::Log4perl;

	Log::Log4perl->init( \ '
		log4perl.category.Collator        = FATAL, String

		log4perl.appender.String          = Log::Log4perl::Appender::String
		log4perl.appender.String.layout   = Log::Log4perl::Layout::PatternLayout
		log4perl.appender.String.layout.ConversionPattern = %m
	');
	}

BEGIN {
	package Mock::Minimal {
		use base qw( MyCPAN::App::DPAN::Reporter::Minimal );
		use File::Spec::Functions;
		use File::Path qw(make_path);

		sub new { bless {}, $_[0] };

		sub get_config  { $_[0] }
		sub dpan_dir {
			state $sub_path = catfile( qw(test-corpus authors id) );
			make_path $sub_path unless -d $sub_path;
			$sub_path;
			};
		sub i_ignore_errors_at_my_peril { 0 }

		sub get_note {
			Mock::CPAN::PackageDetails->new;
			}

		sub create_modlist   { 1 };
		sub create_checksums { 1 };
		sub update_whois     { 1 };
		}

	package Mock::CPAN::PackageDetails {
		use Carp qw(croak);

		our $Count = 0;
		our $Check_file_die_message = 0;

		sub new { bless {}, $_[0] }
		sub count { $Count }
		sub set_count { $Count = $_[1] }
		sub write_file { 1 }
		sub check_file { $Check_file_die_message ? croak $Check_file_die_message : 1 }
		sub set_check_file_die_message { $Check_file_die_message = $_[1] }
		}
}
