package PubApiTest;

use cPanel::PublicAPI;

@PubApiTest::ISA= qw( cPanel::PublicAPI );

use strict;
use warnings;
use Test::More;

# This is used to specify what a specific call be using
our $test_config = {};

# Used to test the actual input to api_request
sub api_request {
    my ( $self, $service, $uri, $method, $formdata ) = @_;

    if ( defined $test_config->{'badcall'} ) {
        my $badcall_return;
        if ( $test_config->{'badcall'} eq 'whmapi' ) {
            $badcall_return = '{"error":"Unknown App Requested: asdf"}';
        }
        elsif ( $test_config->{'badcall'} eq 'cpanelapi2') {
            $badcall_return = '{"cpanelresult":{"apiversion":2,"error":"Could not find function \'test\' in module \'Test\'","func":"test","module":"Test"}}';
        }
        elsif ( $test_config->{'badcall'} eq 'cpanelapi1') {
            $badcall_return = '{"apiversion":"1","type":"event","module":"Test","func":"test","source":"module","data":{"result":""},"event":{"reason":"Test::test() failed: Undefined subroutine &Cpanel::Test::Test_test called at (eval 21) line 1.\n","result":0}}';
        }
        return 0, 'failed', \$badcall_return;
    }
    
    is( $service, $test_config->{'service'}, 'Service is correct for ' . $test_config->{'call'} );
    is( $uri, $test_config->{'uri'}, 'URI is correct for ' . $test_config->{'call'} );
    is( $method, $test_config->{'method'}, 'Method is correct for ' . $test_config->{'call'} );
    if ( exists $test_config->{'test_formdata'} && $test_config->{'test_formdata'} eq 'hash' ) {
        is_deeply( $formdata, $test_config->{'formdata'}, 'Formdata is correct for ' . $test_config->{'call'} );
    }
    elsif ( exists $test_config->{'test_formdata'} && $test_config->{'test_formdata'} eq 'string') {
        is( $formdata, $test_config->{'formdata'}, 'Fromdata is correct for ' . $test_config->{'call'} );
    }
    
    my $return_format = 'string';
    if ( $uri =~ /\/json-api\// ) {
        $return_format = 'json';
    }
    elsif ( $uri =~ /\/xml-api\//) {
        $return_format = 'xml';
    }
    is ( $return_format, $test_config->{'return_format'}, 'Serialization format correct for '  . $test_config->{'call'} );

    my $return;
    if ( $return_format eq 'json' ) {
        $return = '{"something":"somethinglese"}';
    }
    elsif( $return_format eq 'xml' ) {
        $return = '<node><something>somethingelse</something></node>';
    }
    else {
        $return = 'some data goes here';
    }
    return '1', 'ok', \$return;
}

1;
