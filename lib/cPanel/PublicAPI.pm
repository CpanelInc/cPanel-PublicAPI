package cPanel::PublicAPI;

# Copyright (c) 2015, cPanel, Inc.
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

our $VERSION = 1.4;

use strict;
use Socket           ();
use Carp             ();
use MIME::Base64     ();
use IO::Socket::INET ();

my ( $whm_sock, $whm_sock_host, $loaded_ssl );
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

sub new {
    my ( $class, %OPTS ) = @_;

    my $self = {};
    bless( $self, $class );

    $self->{'debug'}   = $OPTS{'debug'}   || 0;
    $self->{'timeout'} = $OPTS{'timeout'} || 300;

    if ( exists $OPTS{'usessl'} ) {
        $self->{'usessl'} = $OPTS{'usessl'};
    }
    else {
        $self->{'usessl'} = 1;
    }
    if ( exists $OPTS{'ssl_verify_mode'} ) {
        $self->{'ssl_verify_mode'} = $OPTS{'ssl_verify_mode'};
    }
    else {
        $self->{'ssl_verify_mode'} = 1;
    }
    if ( exists $OPTS{'keepalive'} ) {
        $self->{'keepalive'} = int $OPTS{'keepalive'};
    }
    else {
        $self->{'keepalive'} = 0;
    }

    if ( exists $OPTS{'ip'} ) {
        $self->{'ip'} = $OPTS{'ip'};
    }
    elsif ( exists $OPTS{'host'} ) {
        $self->{'host'} = $OPTS{'host'};
    }
    else {
        $self->{'ip'} = '127.0.0.1';
    }

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

    if ( ( !exists( $OPTS{'pass'} ) || $OPTS{'pass'} eq '' ) && ( !exists $OPTS{'accesshash'} || $OPTS{'accesshash'} eq '' ) ) {
        my $homedir = exists $INC{'Cpanel/PwCache.pm'} ? ( Cpanel::PwCache::getpwuid($>) )[7] : ( getpwuid($>) )[7];
        $self->debug("Attempting to detect correct authentication credentials") if $self->{'debug'};

        if ( -e $homedir . '/.accesshash' ) {
            local $/;
            if ( open( my $hash_fh, '<', $homedir . '/.accesshash' ) ) {
                $self->{'accesshash'} = readline($hash_fh);
                $self->{'accesshash'} =~ s/[\r\n]+//g;
                close($hash_fh);
                $self->debug("Got access hash from $homedir/.accesshash") if $self->{'debug'};
            }
            else {
                $self->debug("Failed to fetch access hash from $homedir/.accesshash") if $self->{'debug'};
            }
        }
        elsif ( exists $ENV{'REMOTE_PASSWORD'} && $ENV{'REMOTE_PASSWORD'} && $ENV{'REMOTE_PASSWORD'} ne '__HIDDEN__' && exists $ENV{'SERVER_SOFTWARE'} && $ENV{'SERVER_SOFTWARE'} =~ /^cpsrvd/ ) {
            $self->debug("Got user password from the REMOTE_PASSWORD environment variables.") if $self->{'debug'};
            $OPTS{'pass'} = $ENV{'REMOTE_PASSWORD'};
        }

        else {
            Carp::confess('pass or access hash is a required parameter');
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
}

sub accesshash {
    my $self = shift;
    $self->{'accesshash'} = shift;
    delete $self->{'pass'};
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
    if ( $self->{'error'} ) {
        die $self->{'error'};
    }
    if ( defined $format && ( $format eq 'json' || $format eq 'xml' ) ) {
        return $$data;
    }
    else {
        my $parsed_data;
        eval { $parsed_data = $CFG{'serializer_can_deref'} ? $CFG{'api_serializer_obj'}->($data) : $CFG{'api_serializer_obj'}->($$data); };
        if ( !ref $parsed_data ) {
            $self->error("There was an issue with parsing the following response from cPanel or WHM: [data=[$$data]]");
            die $self->{'error'};
        }
        if (
            ( exists $parsed_data->{'error'} && $parsed_data->{'error'} =~ /Unknown App Requested/ ) ||    # xml-api v0 version
            ( exists $parsed_data->{'metadata'}->{'reason'} && $parsed_data->{'metadata'}->{'reason'} =~ /Unknown app requested/ )
          ) {                                                                                              # xml-api v1 version
            $self->error("cPanel::PublicAPI::whm_api was called with the invalid API call of: $call.");
            return;
        }
        return $parsed_data;
    }
}

sub api_request {
    my ( $self, $service, $uri, $method, $formdata, $headers ) = @_;

    $self->{'error'} = 0;

    $formdata ||= '';
    $method   ||= 'GET';
    $headers  ||= '';

    $self->debug("api_request: ( $self, $service, $uri, $method, $formdata, $headers )") if $self->{'debug'};

    $self->_init() if !exists $CFG{'init'};

    $self->{'error'} = undef;
    my $timeout = $self->{'timeout'} || 300;

    my $authstr;
    if ( exists $self->{'accesshash'} ) {
        $self->{'accesshash'} =~ s/[\r\n]//g;
        $authstr = 'WHM ' . $self->{'user'} . ':' . $self->{'accesshash'};
    }
    elsif ( exists $self->{'pass'} ) {
        $authstr = 'Basic ' . MIME::Base64::encode_base64( $self->{'user'} . ':' . $self->{'pass'} );
        $authstr =~ s/[\r\n]//g;
    }
    else {
        die 'No user name or password set, cannot execute query.';
    }

    my $orig_alarm = 0;
    my $page;
    my $port;

    if ( $self->{'usessl'} ) {
        if ( !$loaded_ssl ) {
            eval { require IO::Socket::SSL; };
            if ($@) {
                die "Failed to load IO::Socket::SSL: $@.";
            }
            Net::SSLeay::load_error_strings();
            Net::SSLeay::OpenSSL_add_ssl_algorithms();
            Net::SSLeay::ERR_load_crypto_strings();
            Net::SSLeay::randomize();
            IO::Socket::SSL->import('inet4');    # see case 16674
            $loaded_ssl = 1;
        }
        IO::Socket::SSL->import('inet4');        # see case 16674
        $port = $service =~ /^\d+$/ ? $service : $PORT_DB{$service}{'ssl'};
    }
    else {
        $port = $service =~ /^\d+$/ ? $service : $PORT_DB{$service}{'plaintext'};
    }

    $self->debug("Found port for service $service to be $port (usessl=$self->{'usessl'})") if $self->{'debug'};

    eval {
        if ( !$self->{'user'} ) {
            $self->error("You must specify a user to login as.");
            die $self->{'error'};                #exit eval
        }
        my $remote_server = $self->{'ip'}   || $self->{'host'};
        my $server_name   = $self->{'host'} || $self->{'ip'};
        if ( !$remote_server ) {
            $self->error("You must set a host to connect to. (missing 'host' and 'ip' parameter)");
            die $self->{'error'};                #exit eval
        }
        $server_name =~ s/\s*//g;
        my $keepalive         = $self->{'keepalive'} ? 1 : 0;
        my $connection_string = $remote_server . ':' . $port;
        my $attempts          = 0;
        my $hassigpipe;
        my $finished_request = 0;
        my $ssl_verify_mode  = $self->{'ssl_verify_mode'};

        local $SIG{'ALRM'} = sub {
            $self->error('Connection Timed Out');
            die $self->{'error'};
        };
        local $SIG{'PIPE'} = sub { $hassigpipe = 1; };
        $orig_alarm = alarm($timeout);
        my @connection_args = ( PeerHost => $remote_server, PeerPort => $port, SSL_verify_mode => $ssl_verify_mode );
        while ( ++$attempts < 3 ) {
            $hassigpipe = 0;
            if ( !ref $whm_sock || !$whm_sock_host || $whm_sock_host ne $connection_string ) {
                close($whm_sock) if ref $whm_sock;
                $whm_sock =
                  $self->{'usessl'}
                  ? IO::Socket::SSL->new(@connection_args)
                  : IO::Socket::INET->new($connection_string);
                if ( !$whm_sock ) {
                    undef $whm_sock;
                    $self->error("Could not connect to $connection_string: $!");
                    die $self->{'error'};    #exit eval
                }
                else {
                    $whm_sock_host = $connection_string;
                }
            }
            my $connection_type = ( $keepalive ? 'Keep-Alive' : 'Close' );

            $headers = $self->format_http_headers($headers) if ref $headers;
            if ( $method eq 'POST' || $method eq 'PUT' ) {
                $formdata = $self->format_http_query($formdata) if ref $formdata;
                print {$whm_sock} "$method $uri HTTP/1.1\r\nHost: $server_name\r\nConnection: $connection_type\r\n" . 'Content-Length: ' . length($formdata) . "\r\n" . "User-Agent: " . 'cPanel::PublicAPI (perl) ' . $VERSION . "\r\n" . "Authorization: $authstr\r\n$headers\r\n" . $formdata;
                $self->debug( ( "$method $uri HTTP/1.1\r\nHost: $server_name\r\nConnection: $connection_type\r\n" . 'Content-Length: ' . length($formdata) . "\r\n" . "User-Agent: " . 'cPanel::PublicAPI (perl) ' . $VERSION . "\r\n" . "Authorization: $authstr\r\n$headers\r\n" . $formdata ) ) if $self->{'debug'};
            }
            else {
                print {$whm_sock} "$method "
                  . ( $uri . '?' . ( ref $formdata ? join( '&', map { $CFG{'uri_encoder_func'}->($_) . '=' . $CFG{'uri_encoder_func'}->( $formdata->{$_} ) } keys %{$formdata} ) : $formdata ) )
                  . " HTTP/1.1\r\nHost: $server_name\r\nConnection: $connection_type\r\n"
                  . "User-Agent: "
                  . 'cPanel::PublicAPI (perl) '
                  . $VERSION . "\r\n"
                  . "Authorization: $authstr\r\n$headers\r\n";

                $self->debug( "$method " . ( $uri . '?' . ( ref $formdata ? join( '&', map { $CFG{'uri_encoder_func'}->($_) . '=' . $CFG{'uri_encoder_func'}->( $formdata->{$_} ) } keys %{$formdata} ) : $formdata ) ) . " HTTP/1.1\r\nHost: $server_name\r\nConnection: $connection_type\r\n" . "User-Agent: " . 'cPanel::PublicAPI (perl) ' . $VERSION . "\r\n" . "Authorization: $authstr\r\n$headers\r\n" )
                  if $self->{'debug'};

            }

            if ($hassigpipe) { undef $whm_sock_host; next; }    # http spec says to reconnect

            my $inheaders   = 1;
            my $httpheader  = readline($whm_sock);
            my $http_status = $httpheader;

            $self->debug("HTTP STATUS[$http_status]") if $self->{'debug'};

            if ( $hassigpipe || !$httpheader ) { undef $whm_sock_host; next; }    # http spec says to reconnect

            my %HEADERS;
            {
                local $/ = ( $httpheader =~ tr/\r// ) ? "\r\n\r\n" : "\n\n";
                %HEADERS = map { ( lc $_->[0], substr( $_->[1], 0, 8190 ) ) }     # lc the header and truncate the value to 8190 bytes
                  map { [ ( split( /:\s*/, $_, 2 ) )[ 0, 1 ] ] }                  # split header into name, value - and place into an arrayref for the next map to alter
                  split( /\r?\n/, readline($whm_sock) );                          # split each header
            }
            if ( $self->{'debug'} ) {
                foreach my $header ( keys %HEADERS ) {
                    $self->debug("HEADER[$header]=[$HEADERS{$header}]");
                }
            }
            {
                if ( exists $HEADERS{'transfer-encoding'} && $HEADERS{'transfer-encoding'} =~ /chunked/i ) {
                    $self->debug("READ TYPE=chunked") if $self->{'debug'};
                    local $/ = "\r\n";
                    my ( $size_to_read, $read_size, $read_buffer, $bytes_read );
                  CHUNKED_READ:
                    while (1) {
                        chomp( $read_size = readline($whm_sock) );
                        $size_to_read = hex($read_size) + 2;

                        #if ( $self->{'debug'} ) {
                        #    $self->debug("CHUNKED read_size=$read_size")               ;
                        #    $self->debug("REQUESTING_READ size_to_read=$size_to_read") ;
                        #}
                        while ($size_to_read) {
                            if ( !defined($read_size) || !( $bytes_read = read( $whm_sock, $read_buffer, $size_to_read ) ) ) {

                                #$self->debug("FINSIHED READING CHUNKED DATA [$bytes_read]") if $self->{'debug'};
                                last CHUNKED_READ;
                            }
                            $size_to_read -= $bytes_read;

                            #$self->debug("BYTES READ = [$bytes_read] (remaining in chunk $size_to_read)") if $self->{'debug'};
                            $page .=
                                $size_to_read == 0 ? substr( $read_buffer, 0, -2 )
                              : $size_to_read == 1 ? substr( $read_buffer, 0, -1 )
                              :                      $read_buffer;
                        }
                        last if hex($read_size) == 0;
                    }
                    $keepalive = 0 if exists $HEADERS{'connection'} && $HEADERS{'connection'} =~ /close/i;
                }
                elsif ( defined $HEADERS{'content-length'} ) {
                    $self->debug("READ TYPE=content-length") if $self->{'debug'};
                    my $bytes_to_read = int $HEADERS{'content-length'};
                    my $bytes_read = $bytes_to_read ? read( $whm_sock, $page, $bytes_to_read ) : 0;
                    if ( ( $bytes_to_read -= $bytes_read ) > 0 ) {
                        while ( $bytes_read = read( $whm_sock, $page, $bytes_to_read, length $page ) ) {
                            last if !$bytes_read || !( $bytes_to_read -= $bytes_read );
                        }
                    }
                    $self->debug("READ TYPE=content-length: Failed to read response from server.  The connection was dropped with $bytes_to_read bytes left: $!\n") if $self->{'debug'} && $bytes_to_read;
                    $keepalive = 0 if exists $HEADERS{'connection'} && $HEADERS{'connection'} =~ /close/i;
                }
                else {
                    $self->debug("READ TYPE=close") if $self->{'debug'};
                    $keepalive = 0;
                    local $/;
                    $page = readline($whm_sock);    # read until we close ths socket
                }
            }

            if ( $http_status !~ m/^HTTP\/1\.(0|1) 2/ ) {
                $keepalive = 0;
                $self->error("Server Error from $remote_server: $http_status");
            }

            if ( !$keepalive ) {
                close($whm_sock);
                undef $whm_sock_host;
            }

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
    if ( defined $format && ( $format eq 'json' || $format eq 'xml' ) ) {
        return $$data;
    }
    else {
        my $parsed_data;
        eval { $parsed_data = $CFG{'serializer_can_deref'} ? $CFG{'api_serializer_obj'}->($data) : $CFG{'api_serializer_obj'}->($$data); };
        if ( !ref $parsed_data ) {
            $self->error("There was an issue with parsing the following response from cPanel or WHM:\n$$data");
            die $self->{'error'};
        }
        if ( exists $parsed_data->{'event'}->{'reason'} && $parsed_data->{'event'}->{'reason'} =~ /failed: Undefined subroutine/ ) {
            $self->error( "cPanel::PublicAPI::cpanel_api1_request was called with the invalid API1 call of: " . $parsed_data->{'module'} . '::' . $parsed_data->{'func'} );
            return;
        }
        return $parsed_data;
    }
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

    if ( defined $format && ( $format eq 'json' || $format eq 'xml' ) ) {
        return $$data;
    }
    else {
        my $parsed_data;
        eval { $parsed_data = $CFG{'serializer_can_deref'} ? $CFG{'api_serializer_obj'}->($data) : $CFG{'api_serializer_obj'}->($$data); };
        if ( !ref $parsed_data ) {
            $self->error("There was an issue with parsing the following response from cPanel or WHM:\n$$data");
            die $self->{'error'};
        }
        if ( exists $parsed_data->{'cpanelresult'}->{'error'} && $parsed_data->{'cpanelresult'}->{'error'} =~ /Could not find function/ ) {    # xml-api v1 version
            $self->error( "cPanel::PublicAPI::cpanel_api2_request was called with the invalid API2 call of: " . $parsed_data->{'cpanelresult'}->{'module'} . '::' . $parsed_data->{'cpanelresult'}->{'func'} );
            return;
        }
        return $parsed_data;
    }
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

        #module, key (cpanel api uri), deserializer function, deserializer understands references
        [ 'JSON::Syck', 'json', \&JSON::Syck::Load,      0 ],
        [ 'JSON',       'json', \&JSON::decode_json,     0 ],
        [ 'JSON::XS',   'json', \&JSON::XS::decode_json, 0 ],
        [ 'JSON::PP',   'json', \&JSON::PP::decode_json, 0 ],
      ) {
        my $serializer_module = $serializer->[0];
        my $serializer_key    = $serializer->[1];
        $CFG{'api_serializer_obj'}   = $serializer->[2];
        $CFG{'serializer_can_deref'} = $serializer->[3];
        eval " require $serializer_module; ";
        if ( !$@ ) {
            $self->debug("loaded serializer: $serializer_module") if $self && ref $self && $self->{'debug'};
            $CFG{'serializer'}        = $CFG{'parser_key'}    = $serializer_key;
            $CFG{'serializer_module'} = $CFG{'parser_module'} = $serializer_module;
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
        [ 'Cpanel/CPAN/URI/Escape.pm', \&Cpanel::CPAN::URI::Escape::uri_escape ],
        [ 'URI/Escape.pm',             \&URI::Escape::uri_escape ],
      ) {
        my $module   = $encoder->[0];
        my $function = $encoder->[1];
        eval { require $module; };

        if ( !$@ ) {
            $self->debug("loaded encoder: $module") if $self && ref $self && $self->{'debug'};
            $CFG{'uri_encoder_func'} = $function;
            last;
        }
        else {
            $self->debug("failed to load encoder: $module") if $self && ref $self && $self->{'debug'};
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
