package cPanel::PublicAPI::WHM;

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

use cPanel::PublicAPI ();

our $VERSION = 1.0;

package cPanel::PublicAPI;

sub simple_get_whmreq {
    my ( $self, $uri, $argref, $argnameref, $opts ) = @_;

    $self->_init() if !exists $cPanel::PublicAPI::CFG{'init'};

    $self->debug("simple_get_whmreq: ( $self, $uri, $argref, $argnameref, $opts )\n") if $self->{'debug'};

    my $count = 0;
    if ( !$opts || !ref $opts ) { $opts = []; }
    if ( ref $argnameref ) {
        foreach my $arg ( @{$argnameref} ) {
            push @{$opts}, $cPanel::PublicAPI::CFG{'uri_encoder_func'}->($arg) . '=' . ( $cPanel::PublicAPI::CFG{'uri_encoder_func'}->( $argref->[$count] ) || '' );
            $count++;
        }
    }
    my $page_ref = $self->whmreq( $uri . '?' . join( '&', @{$opts} ) );
    if ( $self->{'error'} ) { return ''; }
    return $page_ref;
}

sub simple_post_whmreq {
    my ( $self, $uri, $argref, $argnameref, $opts ) = @_;

    $self->_init() if !exists $cPanel::PublicAPI::CFG{'init'};

    $self->debug("simple_post_whmreq: ( $self, $uri, $argref, $argnameref, $opts )") if $self->{'debug'};

    my $count = 0;
    if ( !$opts || !ref $opts ) { $opts = []; }
    if ( ref $argnameref ) {
        foreach my $arg ( @{$argnameref} ) {
            push @{$opts}, $cPanel::PublicAPI::CFG{'uri_encoder_func'}->($arg) . '=' . $cPanel::PublicAPI::CFG{'uri_encoder_func'}->( $argref->[$count] );
            $count++;
        }
    }
    my $page_ref = $self->whmreq( $uri, 'POST', join( '&', @{$opts} ) );
    if ( $self->{'error'} ) { return ''; }
    return $page_ref;
}

sub whmreq {
    my $self     = shift;
    my $uri      = shift;
    my $method   = shift || 'GET';
    my $formdata = shift;
    if ( $method eq 'GET' && $uri =~ /\?/ ) {
        ( $uri, $formdata ) = split( /\?/, $uri );
    }

    $self->debug("whmreq: ( $self, $uri, $method, $formdata )\n") if $self->{'debug'};

    my ( $status, $statusmsg, $data ) = $self->api_request( 'whostmgr', $uri, $method, $formdata );
    return wantarray ? split( /\r?\n/, $$data ) : $$data;
}

sub api1 {    #Cpanel::Accounting compat
    my $self   = shift;
    my $user   = shift;
    my $module = shift;
    my $func   = shift;
    return $self->cpanel_api1_request( 'whostmgr', { 'user' => $user, 'module' => $module, 'func' => $func }, \@_, 'xml' );
}

sub api2 {    #Cpanel::Accounting compat
    my $self   = shift;
    my $user   = shift;
    my $module = shift;
    my $func   = shift;
    return $self->cpanel_api2_request( 'whostmgr', { 'user' => $user, 'module' => $module, 'func' => $func }, {@_}, 'xml' );
}

1;
