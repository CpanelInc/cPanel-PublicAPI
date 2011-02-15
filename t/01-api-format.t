#!/usr/bin/perl

use strict;
use warnings;

use Test::More;                      # last test to print

use lib 'lib';
use cPanel::PublicAPI::Test ();

my $pubapi = cPanel::PublicAPI::Test->new( 
    'ip'        => '127.0.0.1', 
    'usessl'    => 1,
    'user'      => 'someuser',
    'pass'      => 'somepass',
    'error_log' => 'test_log'
);

# test WHM
$cPanel::PublicAPI::Test::test_config = {
    'service' => 'whostmgr',
    'uri'   => '/json-api/loadavg',
    'method' => 'POST',
    'call'  => 'whm_api-noform',
    'return_format' => 'json',
};
my $res = $pubapi->whm_api('loadavg');
is( ref $res, 'HASH', 'Returned format ok for ' . $cPanel::PublicAPI::Test::test_config->{'call'} );

$cPanel::PublicAPI::Test::test_config->{'test_formdata'} = 'hash';
$cPanel::PublicAPI::Test::test_config->{'formdata'} = { 'key' => 'value' };
$cPanel::PublicAPI::Test::test_config->{'call'} = 'whm_api-refform';
$res = $pubapi->whm_api('loadavg', $cPanel::PublicAPI::Test::test_config->{'formdata'} );
is( ref $res, 'HASH', 'Returned format ok for ' . $cPanel::PublicAPI::Test::test_config->{'call'} );

$cPanel::PublicAPI::Test::test_config->{'test_formdata'} = 'string';
$cPanel::PublicAPI::Test::test_config->{'formdata'} = 'one&two';
$cPanel::PublicAPI::Test::test_config->{'call'} = 'whm_api-stringform';
$res = $pubapi->whm_api('loadavg', $cPanel::PublicAPI::Test::test_config->{'formdata'} );
is( ref $res, 'HASH', 'Returned format ok for ' . $cPanel::PublicAPI::Test::test_config->{'call'} );

delete $cPanel::PublicAPI::Test::test_config->{'formdata'};
delete $cPanel::PublicAPI::Test::test_config->{'test_formdata'};
$cPanel::PublicAPI::Test::test_config->{'return_format'} = 'json';
$res = $pubapi->whm_api('loadavg', undef, 'json' );
is( $res, '{"something":"somethinglese"}', 'raw JSON data returned raw correctly from whm_api' );

$cPanel::PublicAPI::Test::test_config->{'test_format'} = 'xml';
$cPanel::PublicAPI::Test::test_config->{'return_format'} = 'xml';
$cPanel::PublicAPI::Test::test_config->{'uri'} = '/xml-api/loadavg';
$res = $pubapi->whm_api('loadavg', undef, 'xml' );
is( $res, '<node><something>somethingelse</something></node>', 'raw XML data returned raw correctly from whm_api' );

# test API1 
$cPanel::PublicAPI::Test::test_config = {
    'service' => 'cpanel',
    'uri'   => '/json-api/cpanel',
    'method' => 'GET',
    'call'  => 'api1-noargs',
    'return_format' => 'json',
    'test_formdata' => 'hash',
    
};

# Without arguments
$cPanel::PublicAPI::Test::test_config->{'formdata'} = {
    'cpanel_jsonapi_module' => 'Test',
    'cpanel_jsonapi_func' => 'test',
    'cpanel_jsonapi_apiversion' => 1,
};

my $call_config = {
    'module' => 'Test',
    'func'  => 'test',
};

$res = $pubapi->cpanel_api1_request('cpanel', $call_config );
is( ref $res, 'HASH', 'Returned format ok for ' . $cPanel::PublicAPI::Test::test_config->{'call'} );

# with arguments
$cPanel::PublicAPI::Test::test_config->{'call'} = 'api1-args';
$cPanel::PublicAPI::Test::test_config->{'formdata'}->{'arg-0'} = 'one';
$cPanel::PublicAPI::Test::test_config->{'formdata'}->{'arg-1'} = 'two';
$res = $pubapi->cpanel_api1_request('cpanel', $call_config, [ 'one', 'two' ] );
is( ref $res, 'HASH', 'Returned format ok for ' . $cPanel::PublicAPI::Test::test_config->{'call'} );

# WHM

# with arguments
$cPanel::PublicAPI::Test::test_config->{'call'} = 'whm-api1-args';
$cPanel::PublicAPI::Test::test_config->{'formdata'}->{'cpanel_jsonapi_user'} = 'someuser';
$cPanel::PublicAPI::Test::test_config->{'service'} = 'whostmgr';
$call_config->{'user'} = 'someuser';
$res = $pubapi->cpanel_api1_request('whostmgr', $call_config, [ 'one', 'two' ] );
is( ref $res, 'HASH', 'Returned format ok for ' . $cPanel::PublicAPI::Test::test_config->{'call'} );

# without arguments
$cPanel::PublicAPI::Test::test_config->{'call'} = 'whm-api1-noargs';
delete $cPanel::PublicAPI::Test::test_config->{'formdata'}->{'arg-1'};
delete $cPanel::PublicAPI::Test::test_config->{'formdata'}->{'arg-0'};
$res = $pubapi->cpanel_api1_request('whostmgr', $call_config );
is( ref $res, 'HASH', 'Returned format ok for ' . $cPanel::PublicAPI::Test::test_config->{'call'} );

# Test JSON
$cPanel::PublicAPI::Test::test_config->{'call'} = 'whm-api1-rawjson';
$cPanel::PublicAPI::Test::test_config->{'return_format'} = 'json';
$res = $pubapi->cpanel_api1_request('whostmgr', $call_config, undef, 'json' );
is( $res, '{"something":"somethinglese"}', 'raw JSON data returned raw correctly from cpanel_api1_request' );

# Test XML
$cPanel::PublicAPI::Test::test_config->{'call'} = 'whm-api1-rawxml';
$cPanel::PublicAPI::Test::test_config->{'test_format'} = 'xml';
$cPanel::PublicAPI::Test::test_config->{'return_format'} = 'xml';
$cPanel::PublicAPI::Test::test_config->{'uri'} = '/xml-api/cpanel';

$cPanel::PublicAPI::Test::test_config->{'formdata'} = {
    'cpanel_xmlapi_user' => 'someuser',
    'cpanel_xmlapi_module' => 'Test',
    'cpanel_xmlapi_func' => 'test',
    'cpanel_xmlapi_apiversion' => '1',
};

$res = $pubapi->cpanel_api1_request('whostmgr', $call_config, [], 'xml' );
is( $res, '<node><something>somethingelse</something></node>', 'raw XML data returned raw correctly from cpanel_api1_request' );

# API2
$cPanel::PublicAPI::Test::test_config = {
    'service' => 'cpanel',
    'uri'   => '/json-api/cpanel',
    'method' => 'GET',
    'call'  => 'api2-noargs',
    'return_format' => 'json',
    'test_formdata' => 'hash',
};

$cPanel::PublicAPI::Test::test_config->{'formdata'} = {
    'cpanel_jsonapi_func' => 'test',
    'cpanel_jsonapi_module' => 'Api2Test',
    'cpanel_jsonapi_apiversion' => '2',
};

$call_config = {
    'module' => 'Api2Test',
    'func'  => 'test',
};
# without args
$res = $pubapi->cpanel_api2_request( 'cpanel', $call_config );
is( ref $res, 'HASH', 'Returned format ok for ' . $cPanel::PublicAPI::Test::test_config->{'call'} );

# with args
$cPanel::PublicAPI::Test::test_config->{'call'} = 'whm-api2-args';
my $args = {
    'testing' => 'one two three',
    'earth below' => 'us',
};

foreach my $key ( keys %{ $args } ) {
    $cPanel::PublicAPI::Test::test_config->{'formdata'}->{$key} =$args->{$key};
}

$res = $pubapi->cpanel_api2_request( 'cpanel', $call_config, $args );
is( ref $res, 'HASH', 'Returned format ok for ' . $cPanel::PublicAPI::Test::test_config->{'call'} );

# XML/JSON response tests
delete $cPanel::PublicAPI::Test::test_config->{'formdata'}->{'testing'};
delete $cPanel::PublicAPI::Test::test_config->{'formdata'}->{'earth below'};

$cPanel::PublicAPI::Test::test_config->{'call'} = 'api2-rawjson';
$res = $pubapi->cpanel_api2_request( 'cpanel', $call_config, undef, 'json' );
is( $res, '{"something":"somethinglese"}', 'raw JSON data returned raw correctly from cpanel_api2_request' );

#xml

$cPanel::PublicAPI::Test::test_config->{'call'} = 'api2-rawxml';
$cPanel::PublicAPI::Test::test_config->{'formdata'} = {
    'cpanel_xmlapi_module' => 'Api2Test',
    'cpanel_xmlapi_func' => 'test',
    'cpanel_xmlapi_apiversion' => '2'
};
$cPanel::PublicAPI::Test::test_config->{'format'} = 'xml';
$cPanel::PublicAPI::Test::test_config->{'return_format'} = 'xml';
$cPanel::PublicAPI::Test::test_config->{'uri'} = '/xml-api/cpanel';

$res = $pubapi->cpanel_api2_request( 'cpanel', $call_config, undef, 'xml' );
is( $res, '<node><something>somethingelse</something></node>', 'raw XML data returned raw correctly from cpanel_api2_request' );

# test call failure situations
$cPanel::PublicAPI::Test::test_config->{'badcall'} = 'whmapi';
$pubapi->whm_api('version');
like( $pubapi->{'error'}, qr/cPanel::PublicAPI::whm_api was called with the invalid API call of/, 'whm_api invalid call checking works' );

$cPanel::PublicAPI::Test::test_config->{'badcall'} = 'cpanelapi1';
$pubapi->cpanel_api1_request('cpanel', { 'module' => 'test', 'func' => 'test'} );
like( $pubapi->{'error'}, qr/cPanel::PublicAPI::cpanel_api1_request was called with the invalid API1 call of:/, 'cpanel_api1_request invalid call checking works' );

$cPanel::PublicAPI::Test::test_config->{'badcall'} = 'cpanelapi2';
$pubapi->cpanel_api2_request('cpanel', { 'module' => 'test', 'func' => 'test'} );
like( $pubapi->{'error'}, qr/cPanel::PublicAPI::cpanel_api2_request was called with the invalid API2 call of:/, 'cpanel_api1_request invalid call checking works' );

done_testing();