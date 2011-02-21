#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use lib 'lib';
use cPanel::PublicAPI ();

my @getpwuid = getpwuid($>);
my $homedir  = $getpwuid[7];
my $user     = $getpwuid[0];

# test default settings
if ( !-e $homedir . '/.accesshash' ) {
    $ENV{'REMOTE_PASSWORD'} = 'b4r!' if !defined $ENV{'REMOTE_PASSWORD'};
}

check_options();
check_options( 'debug' => 1, 'error_log' => '/dev/null' );
check_options( 'timeout'   => 150 );
check_options( 'usessl'    => 0 );
check_options( 'ip'        => '4.2.2.2' );
check_options( 'host'      => 'zomg.cpanel.net' );
check_options( 'error_log' => 'error_log_test' );
check_options( 'user'      => 'bar' );
check_options( 'pass'      => 'f00!3Df@' );
my $accesshash = 'sdflkjl
sdafjkl
sdlfkjh';
check_options( 'accesshash' => $accesshash );

my $pubapi = cPanel::PublicAPI->new( 'error_log' => 'error_log_test' );

$pubapi->error('random string');
is( $pubapi->{'error'}, 'random string', 'Error variable is stored correctly' );

$pubapi->_init();
is( ref $cPanel::PublicAPI::CFG{'uri_encoder_func'}, 'CODE', 'URI Encoder Detected' );

$pubapi->_init_serializer();
is( ref $cPanel::PublicAPI::CFG{'api_serializer_obj'}, 'CODE', 'Serializer Module Detected' );
like( $cPanel::PublicAPI::CFG{'serializer_module'}, qr/^JSON/, 'Serializer Module is Named' );
is( $cPanel::PublicAPI::CFG{'serializer'},           'json', 'Serailizer format is correct' );
is( $cPanel::PublicAPI::CFG{'serializer_can_deref'}, 0,      'Serailizer reref option set' );

my $query_result = $pubapi->format_http_query( { 'one' => 'uno', 'two' => 'dos' } );
is( $query_result, 'one=uno&two=dos', 'format_http_query' );

$pubapi->set_debug(1);
is( $pubapi->{'debug'}, 1, 'set_debug accessor' );

$pubapi->user('someuser');
is( $pubapi->{'user'}, 'someuser', 'user accessor' );

$pubapi->{'accesshash'} = 'deleteme';
$pubapi->pass('somepass');
is( $pubapi->{'pass'}, 'somepass', 'pass accessor' );
ok( !exists $pubapi->{'accesshash'}, 'pass accessor deletes accesshash scalar' );

$pubapi->accesshash('onetwothreefour');
is( $pubapi->{'accesshash'}, 'onetwothreefour', 'accesshash accessor' );
ok( !exists $pubapi->{'pass'}, 'accesshash accessor deletes pass scalar' );

can_ok( $pubapi, 'new', 'set_debug', 'user', 'pass', 'accesshash', 'whm_api', 'api_request', 'cpanel_api1_request', 'cpanel_api2_request', '_total_form_length', '_init_serializer', '_init', 'error', 'debug', 'format_http_query' );

done_testing();

# This subroutine is intended to check the options sent to a publicAPI instance.
# The first parameter is the publicAPI instance, the rest should be hash key-pairs that allow you to
# override default settings
sub check_options {
    my %OPTS   = @_;
    my $pubapi = cPanel::PublicAPI->new(%OPTS);
    isa_ok( $pubapi, 'cPanel::PublicAPI' );
    if ( defined $OPTS{'debug'} ) {
        is( $pubapi->{'debug'}, $OPTS{'debug'}, 'debug constructor option' );
    }
    else {
        is( $pubapi->{'debug'}, '0', 'debug default' );
    }

    if ( defined $OPTS{'timeout'} ) {
        is( $pubapi->{'timeout'}, $OPTS{'timeout'}, 'timeout constructor option' );
    }
    else {
        is( $pubapi->{'timeout'}, 300, 'timeout default' );
    }

    if ( defined $OPTS{'usessl'} ) {
        is( $pubapi->{'usessl'}, $OPTS{'usessl'}, 'usessl constructor option' );
    }
    else {
        is( $pubapi->{'usessl'}, 1, 'usessl default' );
    }

    if ( defined $OPTS{'ip'} ) {
        is( $pubapi->{'ip'}, $OPTS{'ip'}, 'ip constructor option' );
    }
    elsif ( defined $OPTS{'host'} ) {
        is( $pubapi->{'host'}, $OPTS{'host'}, 'host constructor option' );
    }
    else {
        is( $pubapi->{'ip'}, '127.0.0.1', 'ip default' );
    }

    if ( defined $OPTS{'error_log'} ) {
        ok( $pubapi->{'error_fh'} ne \*STDERR, 'error_log is not STDERR' );
    }
    else {
        is( $pubapi->{'error_fh'}, \*STDERR, 'error_log is set to STDERR' );
    }

    if ( defined $OPTS{'user'} ) {
        is( $pubapi->{'user'}, $OPTS{'user'}, 'user constructor option' );
    }
    else {
        is( $pubapi->{'user'}, $user, 'user default' );
    }

    if ( defined $OPTS{'pass'} ) {
        is( $pubapi->{'pass'}, $OPTS{'pass'}, 'pass constructor option' );
    }
    elsif ( defined $OPTS{'accesshash'} ) {
        my $accesshash = $OPTS{'accesshash'};
        $accesshash =~ s/[\r\n]//;
        is( $pubapi->{'accesshash'}, $accesshash, 'accesshash constructor option' );
    }
    else {
        if ( -e $homedir . './accesshash' ) {
            my $accesshash = get_accesshash();
            is( $pubapi->{'accesshash'}, $accesshash, 'accesshash default' );
        }
        else {
            is( $pubapi->{'pass'}, $ENV{'REMOTE_PASS'}, 'password default' );
        }
    }
}

sub get_accesshash {
    my $accesshash;
    open( my $ah_fh, '<', $homedir . '/.accesshash' );
    foreach my $line ( readline($ah_fh) ) {
        $accesshash .= $line;
    }
    $accesshash =~ s/[\r\n]//;
    return $accesshash;
}
