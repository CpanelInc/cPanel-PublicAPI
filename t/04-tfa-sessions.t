#!/usr/bin/perl

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

check_cpanel_version() or plan skip_all => 'This test requires cPanel version 54 or higher';

eval { require MIME::Base32; require Digest::SHA; 1; } or do {
    plan skip_all => 'This test requires the MIME::Base32 and Digest::SHA modules';
};
unshift @INC, '/usr/local/cpanel';
require Cpanel::Security::Authn::TwoFactorAuth::Google;

my $pubapi = check_api_access_and_config();

if ( !-e '/var/cpanel/users/papiunit' ) {
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

    $res = $pubapi->whm_api(
        'setacls',
        {
            'reseller'        => 'papiunit',
            'acl-create-acct' => 1,
        }
    );
    ok( $res->{'metadata'}->{'result'}, 'Assigned create-acct ACL successfully' );

    _test_tfa_as_reseller( 'papiunit', $password );

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

done_testing();

sub _test_tfa_as_reseller {
    my ( $reseller, $password ) = @_;

    my $reseller_api = cPanel::PublicAPI->new( 'user' => $reseller, 'pass' => $password, 'ssl_verify_mode' => 0 );
    my $res = $reseller_api->whm_api( 'twofactorauth_generate_tfa_config', {} );
    ok( $res->{'metadata'}->{'result'}, 'Successfully called generate tfa config API call as reseller' );

    my $tfa_secret = $res->{'data'}->{'secret'};
    my $google_auth = Cpanel::Security::Authn::TwoFactorAuth::Google->new( { 'secret' => $tfa_secret, 'account_name' => '', 'issuer' => '' } );
    $res = $reseller_api->whm_api(
        'twofactorauth_set_tfa_config',
        {
            'secret'    => $tfa_secret,
            'tfa_token' => $google_auth->generate_code(),
        }
    );
    ok( $res->{'metadata'}->{'result'}, '2FA successfully configured for reseller' );

    eval { $reseller_api->whm_api('loadavg') };
    ok( $@, 'API calls fail without a 2FA session established' );

    $reseller_api->establish_tfa_session( 'whostmgr', $google_auth->generate_code() );
    $res = $reseller_api->whm_api('loadavg');
    ok( defined $res->{'one'}, 'API call successfully made after establishing 2FA session' );
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
    open( my $version_fh, '<', '/usr/local/cpanel/version' ) || return 0;
    my $version = do { local $/; <$version_fh> };
    chomp $version;
    my ( $maj, $min, $rev, $sup ) = split /[\._]/, $version;
    return 1 if $min >= 53;
    return 0;
}

sub check_api_access_and_config {

    open( my $config_fh, '<', '/var/cpanel/cpanel.config' ) || BAIL_OUT('Could not load /var/cpanel/cpanel.config');
    my $securitypolicy_enabled = 0;
    foreach my $line ( readline($config_fh) ) {
        next if $line !~ /=/;
        chomp $line;
        my ( $key, $value ) = split( /=/, $line, 2 );
        if ( $key eq 'SecurityPolicy::TwoFactorAuth' ) {
            $securitypolicy_enabled = 1 if $value;
            last;
        }
    }
    if ( !$securitypolicy_enabled ) {
        plan skip_all => '2FA security policy is disabled on the server';
    }

    my $pubapi = cPanel::PublicAPI->new( 'ssl_verify_mode' => 0 );
    my $res = eval { $pubapi->whm_api('applist') };
    if ($@) {
        plan skip_all => "Failed to verify API access as current user: $@";
    }

    if ( exists $res->{'data'}->{'app'} && ref $res->{'data'}->{'app'} eq 'ARRAY' ) {
        return $pubapi if grep { $_ eq 'createacct' } @{ $res->{'data'}->{'app'} };
    }

    plan skip_all => "Current user doesn't appear to have proper privileges";
}
