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

# SSL tests
my $pubapi = check_api_access();

isa_ok( $pubapi, 'cPanel::PublicAPI' );

my $res = $pubapi->api_request( 'whostmgr', '/xml-api/loadavg', 'GET', {} );
like( $$res, qr/<loadavg>\s*<one>\d+\.\d+<\/one>\s*<five>\d+\.\d+<\/five>\s*<fifteen>\d+\.\d+<\/fifteen>\s*<\/loadavg>*/, 'whm get no params' );

# Create the test regex for reuse
my $createacct_regex = qr/<statusmsg>.*is a reserved username.*<\/statusmsg>/;

$res = $pubapi->api_request( 'whostmgr', '/xml-api/createacct', 'GET', { 'username' => 'test', 'domain' => 'test.com' } );
like( $$res, $createacct_regex, 'ssl whm get hash params' );

$res = $pubapi->api_request( 'whostmgr', '/xml-api/createacct', 'GET', 'username=test&domain=test.com' );
like( $$res, $createacct_regex, 'ssl whm get string params' );

$res = $pubapi->api_request( 'whostmgr', '/xml-api/createacct', 'POST', { 'username' => 'test', 'domain' => 'test.com' } );
like( $$res, $createacct_regex, 'ssl whm post hash params' );

$res = $pubapi->api_request( 'whostmgr', '/xml-api/createacct', 'POST', 'username=test&domain=test.com' );
like( $$res, $createacct_regex, 'ssl whm post string params' );

# Create account for cpanel & reseller testing

if ( !-e '/var/cpanel/users/papiunit' ) {
    my $password = generate_password();
    $res = $pubapi->api_request(
        'whostmgr',
        '/xml-api/createacct',
        'POST',
        {
            'username' => 'papiunit',
            'password' => $password,
            'domain'   => 'cpanel-public-api-test.acct',
        }
    );

    like( $$res, qr/Account Creation Ok/, 'Test account created' );

    # skip is not used here due to the other code contained within this block.
    if ( $$res =~ /Account Creation Ok/ ) {
        my $cp_pubapi = cPanel::PublicAPI->new(
            'user'            => 'papiunit',
            'pass'            => $password,
            'ssl_verify_mode' => 0,
        );
        isa_ok( $cp_pubapi, 'cPanel::PublicAPI' );
        is( $cp_pubapi->{'operating_mode'}, 'session', 'Session operating mode is set properly when user/pass is used' );
        ok( !defined $cp_pubapi->{'cookie_jars'}->{'cpanel'},     'no cookies have been established for the cpanel service before the first query is made' );
        ok( !defined $cp_pubapi->{'security_tokens'}->{'cpanel'}, 'no security_token has been set for the cpanel service before the first query is made' );
        $res = $cp_pubapi->api_request( 'cpanel', '/xml-api/cpanel', 'GET', 'cpanel_xmlapi_module=StatsBar&cpanel_xmlapi_func=stat&display=diskusage' );
        like( $$res, qr/<module>StatsBar<\/module>/, 'ssl cpanel get string params' );

        my $security_token = $cp_pubapi->{'security_tokens'}->{'cpanel'};
        ok( $security_token, 'security token for cpanel has been set upon first request' );
        $res = $cp_pubapi->api_request( 'cpanel', '/xml-api/cpanel', 'GET', { 'cpanel_xmlapi_module' => 'StatsBar', 'cpanel_xmlapi_func' => 'stat', 'display' => 'diskusage' } );
        like( $$res, qr/<module>StatsBar<\/module>/, 'ssl cpanel post hash params' );
        is( $cp_pubapi->{'security_tokens'}->{'cpanel'}, $security_token, 'security_token was not changed when the second cpanel request was made' );

        $res = $cp_pubapi->api_request( 'cpanel', '/xml-api/cpanel', 'POST', 'cpanel_xmlapi_module=StatsBar&cpanel_xmlapi_func=stat&display=diskusage' );
        like( $$res, qr/<module>StatsBar<\/module>/, 'ssl cpanel get string params' );

        $res = $cp_pubapi->api_request( 'cpanel', '/xml-api/cpanel', 'POST', { 'cpanel_xmlapi_module' => 'StatsBar', 'cpanel_xmlapi_func' => 'stat', 'display' => 'diskusage' } );
        like( $$res, qr/<module>StatsBar<\/module>/, 'ssl cpanel post hash params' );

        $res = $pubapi->api_request( 'whostmgr', '/xml-api/removeacct', 'GET', { 'user' => 'papiunit' } );
        like( $$res, qr/papiunit account removed/, 'Test Account Removed' );
    }
}

my $cp_conf = load_cpanel_config();

my $nonssl_tests = 0;
if ( !$cp_conf->{'requiressl'} && !$cp_conf->{'alwaysredirecttossl'} ) {
    $nonssl_tests = 1;
}

SKIP: {
    skip 'nonssl querying is not supported on this server', 5, unless $nonssl_tests;

    my $unsecure = cPanel::PublicAPI->new( 'usessl' => 0 ) if $nonssl_tests;
    isa_ok( $unsecure, 'cPanel::PublicAPI' );

    $res = $unsecure->api_request( 'whostmgr', '/xml-api/loadavg', 'GET' ) if $nonssl_tests;
    like( $$res, qr/<loadavg>\s*<one>\d+\.\d+<\/one>\s*<five>\d+\.\d+<\/five>\s*<fifteen>\d+\.\d+<\/fifteen>\s*<\/loadavg>*/, 'nossl whm get no params' );

    $res = $unsecure->api_request( 'whostmgr', '/xml-api/createacct', 'GET', { 'username' => 'test', 'domain' => 'test.com' } );
    like( $$res, $createacct_regex, 'nossl whm get hash params' ) if $nonssl_tests;

    $res = $unsecure->api_request( 'whostmgr', '/xml-api/createacct', 'GET', 'username=test&domain=test.com' );
    like( $$res, $createacct_regex, 'nossl whm get string params' ) if $nonssl_tests;

    $res = $unsecure->api_request( 'whostmgr', '/xml-api/createacct', 'POST', { 'username' => 'test', 'domain' => 'test.com' } );
    like( $$res, $createacct_regex, 'nossl whm post hash params' ) if $nonssl_tests;

    $res = $unsecure->api_request( 'whostmgr', '/xml-api/createacct', 'POST', 'username=test&domain=test.com' );
    like( $$res, $createacct_regex, 'nossl whm post string params' ) if $nonssl_tests;

}

done_testing();

# used for generating the password of a test account
sub generate_password {
    my @chars = ( 'A' .. 'Z', 'a' .. 'z', '0' .. '9' );
    my $pass = '';
    foreach ( 1 .. 32 ) {
        $pass .= $chars[ int rand @chars ];
    }
    return $pass;
}

sub load_cpanel_config {
    my %cpanel_config;
    open( my $config_fh, '<', '/var/cpanel/cpanel.config' ) || BAIL_OUT('Could not load /var/cpanel/cpanel.config');
    foreach my $line ( readline($config_fh) ) {
        next if $line !~ /=/;
        chomp $line;
        my ( $key, $value ) = split( /=/, $line, 2 );
        $cpanel_config{$key} = $value;
    }
    return \%cpanel_config;
}

sub check_api_access {
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
