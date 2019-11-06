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

check_cpanel_version(79) or plan skip_all => 'This test requires cPanel version 80 or higher';

my ($created_token, $token_name, $created_account);

my $random_username;

do {
    $random_username = 'papi' . substr( rand, 2, 8 ) . 'test';
} while -e "/var/cpanel/users/$random_username";

END {
    if ($created_token) {
        diag "Deleting temporary root WHM API token “$token_name” …";
        system('/usr/local/cpanel/bin/whmapi1', 'api_token_revoke', "token_name=$token_name");
    }

    if ($created_account) {
        diag "Deleting temporary cPanel account “$random_username” …";
        system('/usr/local/cpanel/scripts/removeacct', '--force', $random_username);
    }
}

my @getpwuid = getpwuid($>);
my $homedir  = $getpwuid[7];
my $user     = $getpwuid[0];

if ( !-d '/usr/local/cpanel' ) {
    plan skip_all => 'This test requires that cPanel and WHM are installed on a server';
}

$token_name = 'papitest' . substr( rand, 2 );

diag "Creating temporary root WHM API token “$token_name” …";
my $out = `/usr/local/cpanel/bin/whmapi1 --output=json api_token_create token_name=$token_name`;
die if $?;

# Avoid the need for a formal JSON parser.
$out =~ m<"token":"(.+?)"> or die "No API token in output!\n$out";

$created_token = $1;

my $pubapi = cPanel::PublicAPI->new( usessl => 0, user => 'root', api_token => $created_token );

plan tests => 6;

my $password = generate_password();

diag "Creating temporary reseller “$random_username” …";

my $res      = $pubapi->whm_api(
    'createacct',
    {
        'username' => $random_username,
        'password' => $password,
        'domain'   => "$random_username.tld",
        'reseller' => 1,
    }
);
like( $res->{'metadata'}->{'reason'}, qr/Account Creation Ok/, 'Test account created' );

$created_account = 1;

_test_api_token_as_reseller( $random_username, $password );

_test_cpanel_api_token( $random_username, $password );

diag "Deleting temporary reseller “$random_username” …";

$res = $pubapi->whm_api(
    'removeacct',
    {
        'user' => $random_username,
    }
);
like( $res->{'metadata'}->{'reason'}, qr/\Q$random_username\E/, 'Test Account Removed' );

$created_account = 0;

#----------------------------------------------------------------------

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

sub _test_cpanel_api_token {
    my ( $username, $password ) = @_;

    # Unfortunately, for now we can’t actually create the token via this module.
    my $out = `/usr/local/cpanel/bin/uapi --output=json --user=$username Tokens create_full_access name=fulltoken`;

    $out =~ m<"token":"(.+?)"> or die "No API token in response: ($out)";
    my $token = $1;

    # Create the API Token
    my $api = cPanel::PublicAPI->new( 'user' => $username, api_token => $token, usessl => 0 );
    my $res = $api->cpanel_api2_request( 'cpanel', { module => 'Email', func => 'listpops' } );
    ok( $res->{'cpanelresult'}{'event'}{'result'}, 'Successfully called API2 Email::listpops with token' );
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

