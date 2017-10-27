package cPanel::PublicAPI::DNS;

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

our $VERSION = '2.3';

package cPanel::PublicAPI;

use cPanel::PublicAPI::WHM   ();
use cPanel::PublicAPI::Utils ();

sub addtocluster {
    my $self = shift;
    my $page = $self->simple_post_whmreq( '/cgi/trustclustermaster.cgi', \@_, [ 'user', 'clustermaster', 'pass', 'version' ], ['recurse=0'] );
    if ( $page =~ /has been established/i ) {
        return 1;
    }
    return;
}

sub getzone_local {
    my $self = shift;
    return $self->simple_post_whmreq( '/scripts2/getzone_local', \@_, [ 'zone', 'dnsuniqid' ] );
}

sub getzones_local {
    my $self = shift;
    return $self->simple_post_whmreq( '/scripts2/getzones_local', \@_, [ 'zones', 'dnsuniqid' ] );
}

sub getallzones_local {
    my $self = shift;
    return $self->simple_post_whmreq( '/scripts2/getallzones_local', \@_, ['dnsuniqid'] );
}

sub cleandns_local {
    my $self = shift;
    return $self->simple_get_whmreq( '/scripts2/cleandns_local', \@_, ['dnsuniqid'] );
}

sub getips_local {
    my $self = shift;
    return cPanel::PublicAPI::Utils::get_string_with_collapsed_trailing_eols( split( /\n/, ( $self->simple_get_whmreq( '/scripts2/getips_local', \@_, ['dnsuniqid'] ) ) ) );
}

sub getpath_local {
    my $self = shift;
    return cPanel::PublicAPI::Utils::get_string_with_collapsed_trailing_eols( split( /\n/, ( $self->simple_get_whmreq( '/scripts2/getpath_local', \@_, ['dnsuniqid'] ) ) ) );
}

sub removezone_local {
    my $self = shift;
    return $self->simple_post_whmreq( '/scripts2/removezone_local', \@_, [ 'zone', 'dnsuniqid' ] );
}

sub removezones_local {
    my $self = shift;
    return $self->simple_post_whmreq( '/scripts2/removezones_local', \@_, [ 'zones', 'dnsuniqid' ] );
}

sub reloadzones_local {
    my $self = shift;
    return $self->simple_post_whmreq( '/scripts2/reloadzones_local', \@_, [ 'dnsuniqid', 'zone' ] );    # backcompat
}

sub reloadbind_local {
    my $self = shift;
    return $self->simple_post_whmreq( '/scripts2/reloadbind_local', \@_, [ 'dnsuniqid', 'zone' ] );     # backcompat
}

sub reconfigbind_local {
    my $self = shift;
    return $self->simple_post_whmreq( '/scripts2/reconfigbind_local', \@_, [ 'dnsuniqid', 'zone' ] );    # backcompat
}

sub quickzoneadd_local {
    my $self = shift;
    return $self->simple_post_whmreq( '/scripts2/quickzoneadd_local', \@_, [ 'zone', 'zonedata', 'dnsuniqid' ] );
}

sub savezone_local {
    my $self = shift;
    return $self->simple_post_whmreq( '/scripts2/savezone_local', \@_, [ 'zone', 'zonedata', 'dnsuniqid' ] );
}

sub synczones_local {
    my ( $self, $formdata, $dnsuniqid ) = @_;
    cPanel::PublicAPI::_init() if !exists $cPanel::PublicAPI::CFG{'init'};
    $formdata =~ s/\&$//g;    # formdata must come pre encoded.
    $formdata .= '&dnsuniqid=' . $cPanel::PublicAPI::CFG{'uri_encoder_func'}->($dnsuniqid);
    my $page = join( "\n", $self->whmreq( '/scripts2/synczones_local', 'POST', $formdata ) );
    return if $self->{'error'};
    return $page;
}

sub addzoneconf_local {
    my $self = shift;
    return $self->simple_get_whmreq( '/scripts2/addzoneconf_local', \@_, [ 'zone', 'dnsuniqid' ] );
}

sub getzonelist_local {
    my $self = shift;
    return split( /\n/, $self->simple_get_whmreq( '/scripts2/getzonelist_local', \@_, ['dnsuniqid'] ) );
}

sub zoneexists_local {
    my $self = shift;
    my $exists = cPanel::PublicAPI::Utils::remove_trailing_newline( $self->simple_post_whmreq( '/scripts2/zoneexists_local', \@_, [ 'zone', 'dnsuniqid' ] ) );
    $exists =~ s/[\r\n]//g;
    if ( $exists eq '1' ) {
        return 1;
    }
    return 0;
}
