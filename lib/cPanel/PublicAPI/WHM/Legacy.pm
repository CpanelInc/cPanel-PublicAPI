package cPanel::PublicAPI::Legacy;

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

use cPanel::PublicAPI::WHM ();

sub _modpkg {
    my $self  = shift;
    my $op    = shift;
    my $count = 0;
    my @OPTS  = ('nohtml=1');
    if ( $op eq 'edit' ) { push @OPTS, 'edit=yes'; }
    return $self->simple_get_whmreq( '/scripts/addpkg', \@_, [ 'name', 'hasshell', 'bwlimit', 'quota', 'ip', 'cgi', 'cpmod', 'maxftp', 'maxsql', 'maxpop', 'maxlst', 'maxsub', 'maxpark', 'maxaddon', 'featurelist', 'language' ], \@OPTS );
}

sub addpkg {
    my $self = shift;
    return $self->_modpkg( 'add', @_ );
}

sub editpkg {
    my $self = shift;
    return $self->_modpkg( 'edit', @_ );
}

sub killpkg {
    my $self = shift;
    return $self->simple_get_whmreq( '/scripts/killpkg', \@_, ['pkg'], ['nohtml=1'] );
}

sub suspend {
    my $self = shift;
    return $self->simple_get_whmreq( '/scripts/remote_suspend', \@_, ['user'] );
}

sub unsuspend {
    my $self = shift;
    return $self->simple_get_whmreq( '/scripts/remote_unsuspend', \@_, ['user'] );
}

sub killacct {
    my $self = shift;
    return $self->simple_get_whmreq( '/scripts/killacct', \@_, ['user'], ['nohtml=1'] );
}

sub showversion {
    my $self = shift;
    return $self->simple_get_whmreq( '/scripts2/showversion', \@_ );
}

sub version {
    my $self = shift;
    return $self->simple_get_whmreq( '/scripts2/showversion', \@_ );
}

sub showhostname {
    my $self = shift;
    return $self->simple_get_whmreq( '/scripts2/gethostname', \@_ );
}

sub createacct {
    my $self = shift;
    return $self->simple_get_whmreq( '/scripts/wwwacct', \@_, [ 'domain', 'username', 'password', 'plan', 'language' ], ['nohtml=1'] );
}

sub listpkgs {
    my $self = shift;
    my $req = $self->simple_get_whmreq( '/scripts/remote_listpkg', \@_ );
    my %PKGS;
    foreach ( split( /\n/, $req ) ) {
        my ( $pkg, $contents ) = split( /=/, $_ );
        my @CONTENTS = split( /\,/, $contents );
        $PKGS{$pkg} = \@CONTENTS;
    }
    return wantarray ? %PKGS : \%PKGS;
}

sub listaccts {
    my $self = shift;
    my $req = $self->simple_get_whmreq( '/scripts2/listaccts', \@_, [], ['nohtml=1&viewall=1'] );
    my %ACCTS;
    foreach ( split( /\n/, $req ) ) {
        next if $_ !~ /=/;
        my ( $acct, $contents ) = split( /=/, $_ );
        my @CONTENTS = split( /\,/, $contents );
        $ACCTS{$acct} = \@CONTENTS;
    }
    return wantarray ? %ACCTS : \%ACCTS;
}
1;
