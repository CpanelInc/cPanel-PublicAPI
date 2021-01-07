#!/usr/bin/perl

# Copyright 2017, cPanel, Inc.
# All rights reserved.
# http://cpanel.net
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# 3. Neither the name of the owner nor the names of its contributors may be
# used to endorse or promote products derived from this software without
# specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

use strict;
use warnings;

use Test::More;
use Test::Exception;

use cPanel::PublicAPI ();

my @getpwuid = getpwuid($>);
my $homedir  = $getpwuid[7];
my $user     = $getpwuid[0];

# test default settings
if ( !-e $homedir . '/.accesshash' ) {
    $ENV{'REMOTE_PASSWORD'} = 'b4r!' if !defined $ENV{'REMOTE_PASSWORD'};
    $ENV{'SERVER_SOFTWARE'} = 'cpsrvd fakeout';
}

check_options();
check_options( 'debug' => 1, 'error_log' => '/dev/null' );
check_options( 'timeout'   => 150 );
check_options( 'usessl'    => 0 );
check_options( 'ip'        => '4.2.2.2' );
check_options( 'host'      => 'zomg.cpanel.net' );
check_options( 'error_log' => '/dev/null' );
check_options( 'user'      => 'bar' );
check_options( 'pass'      => 'f00!3Df@' );
my $accesshash = 'sdflkjl
sdafjkl
sdlfkjh';
check_options( 'accesshash' => $accesshash );
check_options( 'api_token'  => 'sdfkjl' );
throws_ok {
    check_options( 'api_token' => 'sdfkjl', 'accesshash' => $accesshash );
}
qr/You cannot specify both an accesshash and an API token/, 'Dies when specifying both an accesshash and API token';

my $http_tiny_creator_called;

my $pubapi = cPanel::PublicAPI->new(
    'error_log' => '/dev/null',
        http_tiny_creator => sub {
            $http_tiny_creator_called = 1;

            return HTTP::Tiny->new(@_);
        },

);

ok( $http_tiny_creator_called, 'http_tiny_creator is called' );

$pubapi->error('random string');
is( $pubapi->{'error'}, 'random string', 'Error variable is stored correctly' );

$pubapi->_init();
is( ref $cPanel::PublicAPI::CFG{'uri_encoder_func'}, 'CODE', 'URI Encoder Detected' );

$pubapi->_init_serializer();
is( ref $cPanel::PublicAPI::CFG{'api_decode_func'}, 'CODE', 'Serializer parse function detected' );
like( $cPanel::PublicAPI::CFG{'serializer_module'}, qr/^JSON/, 'Serializer Module is Named' );
is( $cPanel::PublicAPI::CFG{'serializer'},           'json', 'Serailizer format is correct' );

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

$pubapi->api_token('fivesixseveneight');
is( $pubapi->{'accesshash'}, 'fivesixseveneight', 'api_token accessor' );
ok( !exists $pubapi->{'pass'}, 'api_token accessor deletes pass scalar' );

my $header_string = $pubapi->format_http_headers( { 'Authorization' => 'Basic cm9vdDpsMGx1cnNtNHJ0IQ==' } );
is( $header_string, "Authorization: Basic cm9vdDpsMGx1cnNtNHJ0IQ==\r\n", 'format_http_headers is ok' );

can_ok( $pubapi, 'new', 'set_debug', 'user', 'pass', 'accesshash', 'api_token', 'whm_api', 'api_request', 'cpanel_api1_request', 'cpanel_api2_request', '_total_form_length', '_init_serializer', '_init', 'error', 'debug', 'format_http_query' );

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
    elsif ( defined $OPTS{'api_token'} ) {
        is( $pubapi->{'accesshash'}, $OPTS{'api_token'}, 'api_token constructor option' );
    }
    elsif ( defined $OPTS{'accesshash'} ) {
        my $accesshash = $OPTS{'accesshash'};
        $accesshash =~ s/[\r\n]//g;
        is( $pubapi->{'accesshash'}, $accesshash, 'accesshash constructor option' );
    }
    else {
        if ( -e $homedir . './accesshash' ) {
            my $accesshash = get_accesshash();
            is( $pubapi->{'accesshash'}, $accesshash, 'accesshash default' );
        }
        else {
            is( $pubapi->{'pass'}, $ENV{'REMOTE_PASSWORD'}, 'password default' );
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
