package cPanel::PublicAPI;

# Copyright 2019 cPanel, L.L.C.
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

our $VERSION = '2.8';

use strict;
use Carp            ();
use MIME::Base64    ();
use HTTP::Tiny      ();
use HTTP::CookieJar ();

our %CFG;

my %PORT_DB = (
    'whostmgr' => {
        'ssl'       => 2087,
        'plaintext' => 2086,
    },
    'cpanel' => {
        'ssl'       => 2083,
        'plaintext' => 2082,
    },
    'webmail' => {
        'ssl'       => 2096,
        'plaintext' => 2095,
    },
);

sub _create_http_tiny {
    return HTTP::Tiny->new(@_);
}

sub new {
    my ( $class, %OPTS ) = @_;

    my $self = {};
    bless( $self, $class );

    $self->{'debug'}   = $OPTS{'debug'}   || 0;
    $self->{'timeout'} = $OPTS{'timeout'} || 300;
    $self->{'usessl'} = exists $OPTS{'usessl'} ? $OPTS{'usessl'} : 1;

    if ( exists $OPTS{'ip'} ) {
        $self->{'ip'} = $OPTS{'ip'};
    }
    elsif ( exists $OPTS{'host'} ) {
        $self->{'host'} = $OPTS{'host'};
    }
    else {
        $self->{'ip'} = '127.0.0.1';
    }

    my $ua_creator = $OPTS{'http_tiny_creator'} || \&_create_http_tiny;

    $self->{'ua'} = $ua_creator->(
        agent      => "cPanel::PublicAPI/$VERSION ",
        verify_SSL => ( exists $OPTS{'ssl_verify_mode'} ? $OPTS{'ssl_verify_mode'} : 1 ),
        keep_alive => ( exists $OPTS{'keepalive'} ? int $OPTS{'keepalive'} : 0 ),
        timeout    => $self->{'timeout'},
    );

    if ( exists $OPTS{'error_log'} && $OPTS{'error_log'} ne 'STDERR' ) {
        if ( !open( $self->{'error_fh'}, '>>', $OPTS{'error_log'} ) ) {
            print STDERR "Unable to open $OPTS{'error_log'} for writing, defaulting to STDERR for error logging: $@\n";
            $self->{'error_fh'} = \*STDERR;
        }
    }
    else {
        $self->{'error_fh'} = \*STDERR;
    }

    if ( $OPTS{'user'} ) {
        $self->{'user'} = $OPTS{'user'};
        $self->debug("Using user param from object creation") if $self->{'debug'};
    }
    else {
        $self->{'user'} = exists $INC{'Cpanel/PwCache.pm'} ? ( Cpanel::PwCache::getpwuid($>) )[0] : ( getpwuid($>) )[0];
        $self->debug("Setting user based on current uid ($>)") if $self->{'debug'};
    }

    if ( exists $OPTS{'api_token'} && exists $OPTS{'accesshash'} ) {
        $self->error('You cannot specify both an accesshash and an API token');
        die $self->{'error'};
    }

    # Allow the user to specify an api_token instead of an accesshash.
    # Though, it will just act as a synonym.
    $OPTS{'accesshash'} = $OPTS{'api_token'} if $OPTS{'api_token'};

    if ( ( !exists( $OPTS{'pass'} ) || $OPTS{'pass'} eq '' ) && ( !exists $OPTS{'accesshash'} || $OPTS{'accesshash'} eq '' ) ) {
        my $homedir = exists $INC{'Cpanel/PwCache.pm'} ? ( Cpanel::PwCache::getpwuid($>) )[7] : ( getpwuid($>) )[7];
        $self->debug("Attempting to detect correct authentication credentials") if $self->{'debug'};

        if ( -e $homedir . '/.accesshash' ) {
            local $/;
            if ( open( my $hash_fh, '<', $homedir . '/.accesshash' ) ) {
                $self->{'accesshash'} = readline($hash_fh);
                $self->{'accesshash'} =~ s/[\r\n]+//g;
                close($hash_fh);
                $self->debug("Got accesshash from $homedir/.accesshash") if $self->{'debug'};
            }
            else {
                $self->debug("Failed to fetch accesshash from $homedir/.accesshash") if $self->{'debug'};
            }
        }
        elsif ( exists $ENV{'REMOTE_PASSWORD'} && $ENV{'REMOTE_PASSWORD'} && $ENV{'REMOTE_PASSWORD'} ne '__HIDDEN__' && exists $ENV{'SERVER_SOFTWARE'} && $ENV{'SERVER_SOFTWARE'} =~ /^cpsrvd/ ) {
            $self->debug("Got user password from the REMOTE_PASSWORD environment variables.") if $self->{'debug'};
            $self->{'pass'} = $ENV{'REMOTE_PASSWORD'};
        }
        else {
            Carp::confess('pass, accesshash, or api_token is a required parameter');
        }
    }
    elsif ( $OPTS{'pass'} ) {
        $self->{'pass'} = $OPTS{'pass'};
        $self->debug("Using pass param from object creation") if $self->{'debug'};
    }
    else {
        $OPTS{'accesshash'} =~ s/[\r\n]//;
        $self->{'accesshash'} = $OPTS{'accesshash'};
        $self->debug("Using accesshash param from object creation") if $self->{'debug'};
    }

    $self->_update_operating_mode();

    return $self;
}

sub set_debug {
    my $self = shift;
    $self->{'debug'} = int shift;
}

sub user {
    my $self = shift;
    $self->{'user'} = shift;
}

sub pass {
    my $self = shift;
    $self->{'pass'} = shift;
    delete $self->{'accesshash'};
    $self->_update_operating_mode();
}

sub accesshash {
    my $self = shift;
    $self->{'accesshash'} = shift;
    delete $self->{'pass'};
    $self->_update_operating_mode();
}

sub api_token {
    return shift->accesshash(@_);
}

sub whm_api {
    my ( $self, $call, $formdata, $format ) = @_;
    $self->_init_serializer() if !exists $cPanel::PublicAPI::CFG{'serializer'};
    if ( !defined $call || $call eq '' ) {
        $self->error("A call was not defined when called cPanel::PublicAPI::whm_api_request()");
    }
    if ( defined $format && $format ne 'xml' && $format ne 'json' && $format ne 'ref' ) {
        $self->error("cPanel::PublicAPI::whm_api_request() was called with an invalid data format, the only valid format are 'json', 'ref' or 'xml'");
    }

    $formdata ||= {};
    if ( ref $formdata ) {
        $formdata = { 'api.version' => 1, %$formdata };
    }
    elsif ( $formdata !~ /(^|&)api\.version=/ ) {
        $formdata = "api.version=1&$formdata";
    }

    my $query_format;
    if ( defined $format ) {
        $query_format = $format;
    }
    else {
        $query_format = $CFG{'serializer'};
    }

    my $uri = "/$query_format-api/$call";

    my ( $status, $statusmsg, $data ) = $self->api_request( 'whostmgr', $uri, 'POST', $formdata );
    return $self->_parse_returndata(
        {
            'caller' => 'whm_api',
            'data'   => $data,
            'format' => $format,
            'call'   => $call
        }
    );
}

sub api_request {
    my ( $self, $service, $uri, $method, $formdata, $headers ) = @_;

    $formdata ||= '';
    $method   ||= 'GET';
    $headers  ||= {};

    $self->debug("api_request: ( $self, $service, $uri, $method, $formdata, $headers )") if $self->{'debug'};

    $self->_init() if !exists $CFG{'init'};

    undef $self->{'error'};
    my $timeout = $self->{'timeout'} || 300;

    my $orig_alarm = 0;
    my $page;

    my $port = $self->_determine_port_for_service($service);
    $self->debug("Found port for service $service to be $port (usessl=$self->{'usessl'})") if $self->{'debug'};

    eval {
        $self->{'remote_server'} = $self->{'ip'} || $self->{'host'};
        $self->_validate_connection_settings();
        if ( $self->{'operating_mode'} eq 'session' ) {
            $self->_establish_session($service) if !( $self->{'security_tokens'}->{$service} && $self->{'cookie_jars'}->{$service} );
            $self->{'ua'}->cookie_jar( $self->{'cookie_jars'}->{$service} );
        }

        my $remote_server    = $self->{'remote_server'};
        my $attempts         = 0;
        my $finished_request = 0;
        my $hassigpipe;

        local $SIG{'ALRM'} = sub {
            $self->error('Connection Timed Out');
            die $self->{'error'};
        };

        local $SIG{'PIPE'} = sub { $hassigpipe = 1; };
        $orig_alarm = alarm($timeout);

        $formdata = $self->format_http_query($formdata) if ref $formdata;

        my $scheme = $self->{'usessl'} ? "https" : "http";
        my $url = "$scheme://$remote_server:$port";
        if ( $self->{'operating_mode'} eq 'session' ) {
            my $security_token = $self->{'security_tokens'}->{$service};
            $url .= '/' . $self->{'security_tokens'}->{$service} . $uri;
        }
        else {
            $url .= $uri;
        }

        my $content;
        if ( $method eq 'POST' || $method eq 'PUT' ) {
            $content = $formdata;
        }
        else {
            $url .= "?$formdata";
        }
        $self->debug("URL: $url") if $self->{'debug'};

        if ( !ref $headers ) {
            my @lines = split /\r\n/, $headers;
            $headers = {};
            foreach my $line (@lines) {
                last unless length $line;
                my ( $key, $value ) = split /:\s*/, $line, 2;
                next unless length $key;
                $headers->{$key} ||= [];
                push @{ $headers->{$key} }, $value;
            }
        }

        if ($self->{'operating_mode'} eq 'accesshash') {
            my $token_app = ($service eq 'whostmgr') ? 'whm' : $service;

            $headers->{'Authorization'} = sprintf(
                '%s %s:%s',
                $token_app,
                $self->{'user'},
                $self->{'accesshash'},
            );
        }

        my $options = {
            headers => $headers,
        };
        $options->{'content'} = $content if defined $content;
        my $ua = $self->{'ua'};
        while ( ++$attempts < 3 ) {
            $hassigpipe = 0;
            my $response = $ua->request( $method, $url, $options );
            if ( $response->{'status'} == 599 ) {
                $self->error("Could not connect to $url: $response->{'content'}");
                die $self->{'error'};    #exit eval
            }

            if ($hassigpipe) { next; }    # http spec says to reconnect
            my %HEADERS;
            if ( $self->{'debug'} ) {
                %HEADERS = %{ $response->{'headers'} };
                foreach my $header ( keys %HEADERS ) {
                    $self->debug("HEADER[$header]=[$HEADERS{$header}]");
                }
                if ( exists $HEADERS{'transfer-encoding'} && $HEADERS{'transfer-encoding'} =~ /chunked/i ) {
                    $self->debug("READ TYPE=chunked");
                }
                elsif ( defined $HEADERS{'content-length'} ) {
                    $self->debug("READ TYPE=content-length");
                }
                else {
                    $self->debug("READ TYPE=close");
                }
            }

            if ( !$response->{'success'} ) {
                $self->error("Server Error from $remote_server: $response->{'status'} $response->{'reason'}");
            }

            $page = $response->{'content'};

            $finished_request = 1;
            last;
        }

        if ( !$finished_request && !$self->{'error'} ) {
            $self->error("The request could not be completed after the maximum attempts");
        }

    };
    if ( $self->{'debug'} && $@ ) {
        warn $@;
    }

    alarm($orig_alarm);    # Reset with parent's alarm value

    return ( $self->{'error'} ? 0 : 1, $self->{'error'}, \$page );
}

sub establish_tfa_session {
    my ( $self, $service, $tfa_token ) = @_;
    if ( $self->{'operating_mode'} ne 'session' ) {
        $self->error("2FA-authenticated sessions are not supported when using accesshash keys or API tokens");
        die $self->{'error'};
    }
    if ( !( $service && $tfa_token ) ) {
        $self->error("You must specify the service name, and the 2FA token in order to establish a 2FA-authenticated session");
        die $self->{'error'};
    }

    undef $self->{'cookie_jars'}->{$service};
    undef $self->{'security_tokens'}->{$service};
    return $self->_establish_session( $service, $tfa_token );
}

sub _validate_connection_settings {
    my $self = shift;

    if ( !$self->{'user'} ) {
        $self->error("You must specify a user to login as.");
        die $self->{'error'};
    }

    if ( !$self->{'remote_server'} ) {
        $self->error("You must set a host to connect to. (missing 'host' and 'ip' parameter)");
        die $self->{'error'};
    }
}

sub _update_operating_mode {
    my $self = shift;

    if ( exists $self->{'accesshash'} ) {
        $self->{'accesshash'} =~ s/[\r\n]//g;
        $self->{'operating_mode'} = 'accesshash';
    }
    elsif ( exists $self->{'pass'} ) {
        $self->{'operating_mode'} = 'session';

        # This is called whenever the pass or accesshash is changed,
        # so we reset the cookie jars, and tokens on such changes
        $self->{'cookie_jars'}     = { map { $_ => undef } keys %PORT_DB };
        $self->{'security_tokens'} = { map { $_ => undef } keys %PORT_DB };
    }
    else {
        $self->error('You must specify an accesshash, API token, or password');
        die $self->{'error'};
    }
}

sub _establish_session {
    my ( $self, $service, $tfa_token ) = @_;

    return if $self->{'operating_mode'} ne 'session';
    return if $self->{'security_tokens'}->{$service} && $self->{'cookie_jars'}->{$service};

    $self->{'cookie_jars'}->{$service} = HTTP::CookieJar->new();
    $self->{'ua'}->cookie_jar( $self->{'cookie_jars'}->{$service} );

    my $port   = $self->_determine_port_for_service($service);
    my $scheme = $self->{'usessl'} ? "https" : "http";
    my $url    = "$scheme://$self->{'remote_server'}:$port/login";
    my $resp   = $self->{'ua'}->post_form(
        $url,
        {
            'user' => $self->{'user'},
            'pass' => $self->{'pass'},
            ( $tfa_token ? ( 'tfa_token' => $tfa_token ) : () ),
        },
    );

    if ( my $security_token = ( split /\//, $resp->{'headers'}->{'location'} )[1] ) {
        $self->{'security_tokens'}->{$service} = $security_token;
        $self->debug("Established $service session");
        return 1;
    }

    my $details = $resp->{'reason'};
    $details .= " ($resp->{'content'})" if $resp->{'status'} == 599;

    $self->error("Failed to establish session and parse security token: $resp->{'status'} $details");

    die $self->{'error'};
}

sub _determine_port_for_service {
    my ( $self, $service ) = @_;

    my $port;
    if ( $self->{'usessl'} ) {
        $port = $service =~ /^\d+$/ ? $service : $PORT_DB{$service}{'ssl'};
    }
    else {
        $port = $service =~ /^\d+$/ ? $service : $PORT_DB{$service}{'plaintext'};
    }
    return $port;
}

sub cpanel_api1_request {
    my ( $self, $service, $cfg, $formdata, $format ) = @_;

    my $query_format;
    if ( defined $format ) {
        $query_format = $format;
    }
    else {
        $query_format = $CFG{'serializer'};
    }

    $self->_init_serializer() if !exists $cPanel::PublicAPI::CFG{'serializer'};
    my $count = 0;
    if ( ref $formdata eq 'ARRAY' ) {
        $formdata = { map { ( 'arg-' . $count++ ) => $_ } @{$formdata} };
    }
    foreach my $cfg_item ( keys %{$cfg} ) {
        $formdata->{ 'cpanel_' . $query_format . 'api_' . $cfg_item } = $cfg->{$cfg_item};
    }
    $formdata->{ 'cpanel_' . $query_format . 'api_apiversion' } = 1;

    my ( $status, $statusmsg, $data ) = $self->api_request( $service, '/' . $query_format . '-api/cpanel', ( ( scalar keys %$formdata < 10 && _total_form_length( $formdata, 1024 ) < 1024 ) ? 'GET' : 'POST' ), $formdata );

    return $self->_parse_returndata(
        {
            'caller' => 'cpanel_api1',
            'data'   => $data,
            'format' => $format,
        }
    );
}

sub cpanel_api2_request {
    my ( $self, $service, $cfg, $formdata, $format ) = @_;
    $self->_init_serializer() if !exists $cPanel::PublicAPI::CFG{'serializer'};

    my $query_format;
    if ( defined $format ) {
        $query_format = $format;
    }
    else {
        $query_format = $CFG{'serializer'};
    }

    foreach my $cfg_item ( keys %{$cfg} ) {
        $formdata->{ 'cpanel_' . $query_format . 'api_' . $cfg_item } = $cfg->{$cfg_item};
    }
    $formdata->{ 'cpanel_' . $query_format . 'api_apiversion' } = 2;
    my ( $status, $statusmsg, $data ) = $self->api_request( $service, '/' . $query_format . '-api/cpanel', ( ( scalar keys %$formdata < 10 && _total_form_length( $formdata, 1024 ) < 1024 ) ? 'GET' : 'POST' ), $formdata );

    return $self->_parse_returndata(
        {
            'caller' => 'cpanel_api2',
            'data'   => $data,
            'format' => $format,
        }
    );
}

sub _parse_returndata {
    my ( $self, $opts_hr ) = @_;

    if ( $self->{'error'} ) {
        die $self->{'error'};
    }
    elsif ( ${ $opts_hr->{'data'} } =~ m/tfa_login_form/ ) {
        $self->error("Two-Factor Authentication enabled on the account. Establish a session with the security token, or disable 2FA on the account");
        die $self->{'error'};
    }

    if ( defined $opts_hr->{'format'} && ( $opts_hr->{'format'} eq 'json' || $opts_hr->{'format'} eq 'xml' ) ) {
        return ${ $opts_hr->{'data'} };
    }
    else {
        my $parsed_data;
        eval { $parsed_data = $CFG{'api_decode_func'}->( ${ $opts_hr->{'data'} } ); };
        if ( !ref $parsed_data ) {
            $self->error("There was an issue with parsing the following response from cPanel or WHM: [data=[${$opts_hr->{'data'}}]]");
            die $self->{'error'};
        }

        my $error_check_dt = {
            'whm_api'     => \&_check_whm_api_errors,
            'cpanel_api1' => \&_check_cpanel_api1_errors,
            'cpanel_api2' => \&_check_cpanel_api2_errors,
        };
        return $error_check_dt->{ $opts_hr->{'caller'} }->( $self, $opts_hr->{'call'}, $parsed_data );
    }
}

sub _check_whm_api_errors {
    my ( $self, $call, $parsed_data ) = @_;

    if (
        ( exists $parsed_data->{'error'} && $parsed_data->{'error'} =~ /Unknown App Requested/ ) ||    # xml-api v0 version
        ( exists $parsed_data->{'metadata'}->{'reason'} && $parsed_data->{'metadata'}->{'reason'} =~ /Unknown app\s+(?:\(.+\))?\s+requested/ )    # xml-api v1 version
      ) {
        $self->error("cPanel::PublicAPI::whm_api was called with the invalid API call of: $call.");
        return;
    }
    return $parsed_data;
}

sub _check_cpanel_api1_errors {
    my ( $self, undef, $parsed_data ) = @_;
    if (
        exists $parsed_data->{'event'}->{'reason'} && (
            $parsed_data->{'event'}->{'reason'} =~ /failed: Undefined subroutine/ ||                                                              # pre-11.44 error message
            $parsed_data->{'event'}->{'reason'} =~ m/failed: Can\'t use string/                                                                   # 11.44+ error message
        )
      ) {
        $self->error( "cPanel::PublicAPI::cpanel_api1_request was called with the invalid API1 call of: " . $parsed_data->{'module'} . '::' . $parsed_data->{'func'} );
        return;
    }
    return $parsed_data;
}

sub _check_cpanel_api2_errors {
    my ( $self, undef, $parsed_data ) = @_;

    if ( exists $parsed_data->{'cpanelresult'}->{'error'} && $parsed_data->{'cpanelresult'}->{'error'} =~ /Could not find function/ ) {           # xml-api v1 version
        $self->error( "cPanel::PublicAPI::cpanel_api2_request was called with the invalid API2 call of: " . $parsed_data->{'cpanelresult'}->{'module'} . '::' . $parsed_data->{'cpanelresult'}->{'func'} );
        return;
    }
    return $parsed_data;
}

sub _total_form_length {
    my $data = shift;
    my $max  = shift;
    my $size = 0;
    foreach my $key ( keys %{$data} ) {
        return 1024 if ( ( $size += ( length($key) + 2 + length( $data->{$key} ) ) ) >= 1024 );
    }
    return $size;
}

sub _init_serializer {
    return if exists $CFG{'serializer'};
    my $self = shift;    #not required
    foreach my $serializer (

        #module, key (cpanel api uri), deserializer function name
        [ 'JSON::Syck', 'json', 'Load'        ],
        [ 'JSON',       'json', 'decode_json' ],
        [ 'JSON::XS',   'json', 'decode_json' ],
        [ 'JSON::PP',   'json', 'decode_json' ],
      ) {
        my $serializer_module = $serializer->[0];
        my $serializer_key    = $serializer->[1];
        eval " require $serializer_module; ";
        if ( !$@ ) {
            $self->debug("loaded serializer: $serializer_module") if $self && ref $self && $self->{'debug'};
            $CFG{'serializer'}        = $CFG{'parser_key'}    = $serializer_key;
            $CFG{'serializer_module'} = $CFG{'parser_module'} = $serializer_module;
            $CFG{'api_decode_func'} = $serializer_module->can($serializer->[2]);

            last;
        }
        else {
            $self->debug("Failed to load serializer: $serializer_module: @_") if $self && ref $self && $self->{'debug'};
        }
    }
    if ($@) {
        Carp::confess("Unable to find a module capable of deserializing the api response.");
    }
}

sub _init {
    return if exists $CFG{'init'};
    my $self = shift;    #not required
    $CFG{'init'} = 1;

    # moved this over to a pattern to allow easy change of deps
    foreach my $encoder (
        [ 'Cpanel/Encoder/URI.pm', 'Cpanel::Encoder::URI', 'uri_encode_str' ],
        [ 'URI/Escape.pm',         'URI::Escape', 'uri_escape' ],
      ) {
        my $module_path   = $encoder->[0];
        my $module   = $encoder->[1];
        my $funcname = $encoder->[2];
        eval { require $module_path; };

        if ( !$@ ) {
            $self->debug("loaded encoder: $module_path") if $self && ref $self && $self->{'debug'};
            $CFG{'uri_encoder_func'} = $module->can($funcname);
            last;
        }
        else {
            $self->debug("failed to load encoder: $module_path") if $self && ref $self && $self->{'debug'};
        }
    }
    if ($@) {
        Carp::confess("Unable to find a module capable of encoding api requests.");
    }
}

sub error {
    my ( $self, $msg ) = @_;
    print { $self->{'error_fh'} } $msg . "\n";
    $self->{'error'} = $msg;
}

sub debug {
    my ( $self, $msg ) = @_;
    print { $self->{'error_fh'} } "debug: " . $msg . "\n";
}

sub format_http_headers {
    my ( $self, $headers ) = @_;
    if ( ref $headers ) {
        return '' if !scalar keys %{$headers};
        return join( "\r\n", map { $_ ? ( $_ . ': ' . $headers->{$_} ) : () } keys %{$headers} ) . "\r\n";
    }
    return $headers;
}

sub format_http_query {
    my ( $self, $formdata ) = @_;
    if ( ref $formdata ) {
        return join( '&', map { $CFG{'uri_encoder_func'}->($_) . '=' . $CFG{'uri_encoder_func'}->( $formdata->{$_} ) } sort keys %{$formdata} );
    }
    return $formdata;
}

