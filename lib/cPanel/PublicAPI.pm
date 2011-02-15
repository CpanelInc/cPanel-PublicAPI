package cPanel::PublicAPI;

# Copyright (c) 2011, cPanel, Inc.
# All rights reserved.
# http://cpanel.net
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#    * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the  nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL  BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

our $VERSION = 1.0;

use strict;
use Socket       ();
use Carp         ();
use MIME::Base64 ();

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
    bless($self, $class);

    $self->{'debug'}   ||= $OPTS{'debug'}   || 0;
    $self->{'timeout'} ||= $OPTS{'timeout'} || 300;

    if ( exists $OPTS{'usessl'} ) {
        $self->{'usessl'} = $OPTS{'usessl'};
    }
    else {
        $self->{'usessl'} = 1;
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
        $self->debug("Using user param from object creation\n") if $self->{'debug'};
    }
    else {
        $self->{'user'} = exists $INC{'cPanel/PwCache.pm'} ? ( cPanel::PwCache::getpwuid($>) )[0] : ( getpwuid($>) )[0];
        $self->debug("Setting user based on current uid ($>)\n") if $self->{'debug'};
    }

    if ( ( !exists( $OPTS{'pass'} ) || $OPTS{'pass'} eq '' ) && ( !exists $OPTS{'accesshash'} || $OPTS{'accesshash'} eq '' ) ) {
        my $homedir = exists $INC{'cPanel/PwCache.pm'} ? ( cPanel::PwCache::getpwuid($>) )[7] : ( getpwuid($>) )[7];
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
    my $query_format;
    if ( defined $format ) {
        $query_format = $format;
    }
    else {
        $query_format = $CFG{'serializer'};
    }

    my $uri = "/$query_format-api/$call";

    my ( $status, $statusmsg, $data ) = $self->api_request( 'whostmgr', $uri, 'POST', $formdata );

    if ( defined $format && ( $format eq 'json' || $format eq 'xml' ) ) {
        return $$data;
    }
    else {
        my $parsed_data;
        eval { $parsed_data = $CFG{'serializer_can_deref'} ? $CFG{'api_serializer_obj'}->($data) : $CFG{'api_serializer_obj'}->($$data); };
        if ( !ref $parsed_data ) {
            $self->error("There was an issue with parsing the following response from cPanel or WHM:\n$$data");
            die;
        }
        if (
            ( exists $parsed_data->{'error'} && $parsed_data->{'error'} =~ /Unknown App Requested/ ) ||                              # xml-api v0 version
            ( exists $parsed_data->{'metadata'}->{'reason'} && $parsed_data->{'metadata'}->{'reason'} =~ /Unknown app requested/ )
          ) {                                                                                                                        # xml-api v1 version
            $self->error("cPanel::PublicAPI::whm_api was called with the invalid API call of: $call.");
            return;
        }
        return $parsed_data;
    }
}

sub api_request {
    my ( $self, $service, $uri, $method, $formdata ) = @_;

    $self->{'error'} = 0;

    $method ||= 'GET';
    $self->debug("api_request: ( $self, $service, $uri, $method, $formdata )") if $self->{'debug'};

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
    }
    else {
        die 'No user name or password set, cannot execute query.';
    }

    my $orig_alarm = 0;
    my $page;
    my $port;

    if ( $self->{'usessl'} ) {
        eval { require Net::SSLeay; };
        if ($@) {
            die "Failed to load Net::SSLeay: $@.";
        }
        eval { local $SIG{'__DIE__'}; require cPanel::Rand; };
        if ( !$@ ) {
            $ENV{'RND_SEED'} = cPanel::Rand::getranddata(512);
            $Net::SSLeay::random_device = undef;
        }

        $port = $service =~ /^\d+$/ ? $service : $PORT_DB{$service}{'ssl'};
    }
    else {
        $port = $service =~ /^\d+$/ ? $service : $PORT_DB{$service}{'plaintext'};
    }

    $self->debug("Found port for service $service to be $port (usessl=$self->{'usessl'})") if $self->{'debug'};

    eval {
        local $SIG{'ALRM'} = sub {
            $self->error('Connection Timed Out');
            die $self->{'error'};
        };
        local $SIG{'PIPE'} = sub {
            $self->error('Connection is broken (broken pipe)');
            die $self->{'error'};
        };
        if ( !$self->{'user'} ) {
            $self->error("You must specify a user to login as.");
            die $self->{'error'};    #exit eval
        }
        if ( !$self->{'ip'} && !$self->{'host'} ) {
            $self->error("You must set a host to connect to.");
            die $self->{'error'};    #exit eval
        }
        my $host = $self->{'host'} || $self->{'ip'};

        $orig_alarm = alarm($timeout);
        if ( $self->{'usessl'} ) {
            my ( $result, %headers );
            if ( $method && $method eq 'POST' ) {
                $self->debug("Net::SSLeay::post_https(  $host, $port, $uri, ... )") if $self->{'debug'};
                ( $page, $result, %headers ) = Net::SSLeay::post_https(
                    $host, $port, $uri,
                    Net::SSLeay::make_headers(
                        'Authorization' => $authstr,
                        'Connection'    => 'close',
                        'User-Agent'    => 'cPanel::PublicAPI (perl) ' . $VERSION
                    ),
                    ( ref $formdata ? $self->format_http_query($formdata) : $formdata )
                );

                #FIXME: trap errors
            }
            else {
                $self->debug("Net::SSLeay::get_https( $host, $port, $uri, ... )") if $self->{'debug'};
                ( $page, $result, %headers ) = Net::SSLeay::get_https(
                    $host, $port,
                    $uri . '?' . ( ref $formdata ? $self->format_http_query($formdata) : $formdata ),
                    Net::SSLeay::make_headers(
                        'Authorization' => $authstr,
                        'Connection'    => 'close',
                        'User-Agent'    => 'cPanel::PublicAPI (perl) ' . $VERSION
                    ),
                );

                #FIXME: trap errors
            }
            if ( !defined($result) ) {
                $self->error("Connection to $host:2087 failed: $!.");
            }
            if ( $result !~ /OK/ ) {
                $self->error($result);
            }
        }
        else {
            my $proto = getprotobyname('tcp');
            socket( my $whm_sock, &Socket::AF_INET, &Socket::SOCK_STREAM, $proto );
            my $iaddr;
            if ( exists $self->{'host'} ) {
                $iaddr = gethostbyname( $self->{'host'} );
            }
            if ( !$iaddr && exists $self->{'ip'} ) {
                $iaddr = Socket::inet_aton( $self->{'ip'} );
            }
            if ( !$iaddr ) {
                $self->error("Unable to resolve $self->{'host'}");
                die;    # exit eval
            }
            my $sin = Socket::sockaddr_in( $port, $iaddr );

            connect( $whm_sock, $sin ) || do {
                $self->error("Unable to connect to  $host:$port\n");
                die;    # exit eval
            };

            if ( $method eq 'POST' ) {
                if ( ref $formdata ) {
                    $formdata = $self->format_http_query($formdata);
                }
                send $whm_sock, "POST $uri HTTP/1.0\r\nConnection: close\r\n" . 'Content-Length: ' . length($formdata) . "\r\n" . "User-Agent: " . 'cPanel::PublicAPI (perl) ' . $VERSION . "\r\n" . "Authorization: $authstr\r\n\r\n" . $formdata, 0;
                $self->debug( ( "POST $uri HTTP/1.0\r\nConnection: close\r\n" . 'Content-Length: ' . length($formdata) . "\r\n" . "User-Agent: " . 'cPanel::PublicAPI (perl) ' . $VERSION . "\r\n" . "Authorization: $authstr\r\n\r\n" . $formdata ) ) if $self->{'debug'};
            }
            else {
                send $whm_sock, "GET " . ( $uri . '?' . ( ref $formdata ? join( '&', map { $CFG{'uri_encoder_func'}->($_) . '=' . $CFG{'uri_encoder_func'}->( $formdata->{$_} ) } keys %{$formdata} ) : $formdata ) ) . " HTTP/1.0\r\n" . "Connection: close\r\n" . "User-Agent: " . 'cPanel::PublicAPI (perl) ' . $VERSION . "\r\n" . "Authorization: $authstr\r\n\r\n", 0;

                $self->debug( "GET " . ( $uri . '?' . ( ref $formdata ? join( '&', map { $CFG{'uri_encoder_func'}->($_) . '=' . $CFG{'uri_encoder_func'}->( $formdata->{$_} ) } keys %{$formdata} ) : $formdata ) ) . " HTTP/1.0\r\n" . "Connection: close\r\n" . "User-Agent: " . 'cPanel::PublicAPI (perl) ' . $VERSION . "\r\n" . "Authorization: $authstr\r\n\r\n" )
                  if $self->{'debug'};

            }

            my $inheaders  = 1;
            my $httpheader = readline($whm_sock);
            if ( $httpheader !~ m/OK/ ) {
                $self->error("Server Error from $host: ${httpheader}");
                die;    # exit eval
            }
            {
                local $/ = "\r\n\r\n";
                readline($whm_sock);
                local $/;
                $page = readline($whm_sock);    # read until we close ths socket
            }
            close $whm_sock;
        }
    };
    alarm($orig_alarm);                         # Reset with parent's alarm value

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
        $formdata->{ 'cpanel_' .  $query_format . 'api_' . $cfg_item } = $cfg->{$cfg_item};
    }
    $formdata->{ 'cpanel_' .  $query_format . 'api_apiversion' } = 1;

    my ( $status, $statusmsg, $data ) = $self->api_request( $service, '/' .  $query_format . '-api/cpanel', ( ( scalar keys %$formdata < 10 && _total_form_length( $formdata, 1024 ) < 1024 ) ? 'GET' : 'POST' ), $formdata );
    if ( defined $format && ( $format eq 'json' || $format eq 'xml' ) ) {
        return $$data;
    }
    else {
        my $parsed_data;
        eval { $parsed_data = $CFG{'serializer_can_deref'} ? $CFG{'api_serializer_obj'}->($data) : $CFG{'api_serializer_obj'}->($$data); };
        if ( !ref $parsed_data ) {
            $self->error("There was an issue with parsing the following response from cPanel or WHM:\n$$data");
            die;
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
            die;
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
        [ 'cPanel/CPAN/URI/Escape.pm', \&cPanel::CPAN::URI::Escape::uri_escape ],
        [ 'URI/Escape.pm',             \&URI::Escape::uri_escape ],
      ) {
        my $module   = $encoder->[0];
        my $function = $encoder->[1];
        eval { require $module; };

        if ( !$@ ) {
            $self->debug("loaded encoder: $module\n") if $self && ref $self && $self->{'debug'};
            $CFG{'uri_encoder_func'} = $function;
            last;
        }
        else {
            $self->debug("failed to load encoder: $module\n") if $self && ref $self && $self->{'debug'};
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

sub format_http_query {
    my ( $self, $formdata ) = @_;
    if ( ref $formdata ) {
        return join( '&', map { $CFG{'uri_encoder_func'}->($_) . '=' . $CFG{'uri_encoder_func'}->( $formdata->{$_} ) } keys %{$formdata} );
    }
    return $formdata;
}
