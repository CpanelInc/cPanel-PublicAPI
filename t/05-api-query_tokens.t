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

use Test::More;    # last test to print

use cPanel::PublicAPI ();

my @getpwuid = getpwuid($>);
my $homedir  = $getpwuid[7];
my $user     = $getpwuid[0];

if ( !-d '/usr/local/cpanel' ) {
    plan skip_all => 'This test requires that cPanel and WHM are installed on a server';
}

if ( !-e $homedir . '/.accesshash' ) {
    plan skip_all => 'This test requires that an account hash is defined (see "Setup Remote Access Keys" in WHM)';
}

check_cpanel_version(63) or plan skip_all => 'This test requires cPanel version 64 or higher';

my $pubapi = cPanel::PublicAPI->new( 'ssl_verify_mode' => 0 );
if ( !-e '/var/cpanel/users/papiunit' ) {
    plan tests => 5;
    my $password = generate_password();
    my $res      = $pubapi->whm_api(
        'createacct',
        {
            'username' => 'papiunit',
            'password' => $password,
            'domain'   => 'cpanel-public-api-test.acct',
            'reseller' => 1,
        }
    );
    like( $res->{'metadata'}->{'reason'}, qr/Account Creation Ok/, 'Test account created' );

    _test_api_token_as_reseller( 'papiunit', $password );

    $res = $pubapi->whm_api(
        'removeacct',
        {
            'user' => 'papiunit',
        }
    );
    like( $res->{'metadata'}->{'reason'}, qr/papiunit account removed/, 'Test Account Removed' );
}
else {
    plan skip_all => 'Unable to create test account. It already exists';
}

sub _test_api_token_as_reseller {
    my ( $reseller, $password ) = @_;

    # Create the API Token
    my $reseller_api = cPanel::PublicAPI->new( 'user' => $reseller, 'pass' => $password, 'ssl_verify_mode' => 0 );
    my $res = $reseller_api->whm_api( 'api_token_create', { 'token_name' => 'my_token' } );
    ok( $res->{'metadata'}->{'result'}, 'Successfully called api_token_create API call as reseller' );
    my $plaintext_token = $res->{'data'}->{'token'};

    my $pub_api_with_token = cPanel::PublicAPI->new( 'user' => $reseller, 'api_token' => 'this is so wrong', 'ssl_verify_mode' => 0 );

    eval { $pub_api_with_token->whm_api('loadavg') };
    ok( $@, 'API call fails with wrong API token' );

    $pub_api_with_token->api_token($plaintext_token);
    $res = $pub_api_with_token->whm_api('loadavg');
    ok( defined $res->{'one'}, 'API call successfully made using the correct token' );
}

sub generate_password {
    my @chars = ( 'A' .. 'Z', 'a' .. 'z', '0' .. '9' );
    my $pass = '';
    foreach ( 1 .. 32 ) {
        $pass .= $chars[ int rand @chars ];
    }
    return $pass;
}

sub check_cpanel_version {
    my $min_version = shift;
    open( my $version_fh, '<', '/usr/local/cpanel/version' ) || return 0;
    my $version = do { local $/; <$version_fh> };
    chomp $version;
    my ( $maj, $min, $rev, $sup ) = split /[\._]/, $version;
    return 1 if $min >= $min_version;
    return 0;
}

