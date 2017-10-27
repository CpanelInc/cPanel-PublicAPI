package cPanel::PublicAPI::WHM::CachedVersion;

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

use cPanel::PublicAPI::WHM::Legacy ();

our $basedir  = '/var/cpanel/accounting';
our $cachedir = '/var/cpanel/accounting/cache';
our $cachettl = 3600;                             #one hour

sub check_dirs {
    foreach my $dir ( $basedir, $cachedir ) {
        if ( !-e $dir ) {
            mkdir( $dir, 0700 );
        }
    }
}

sub cached_version {
    my $self = shift;
    my $ttl = shift || $cachettl;
    my $version;

    $self->check_dirs();

    my $file = ( $self->{'ip'} || $self->{'host'} );

    if ( !$file ) {
        return;
    }

    $file =~ s/\///g;
    my $fullfile = $cachedir . '/' . $file;
    my $now      = time();
    my $mtime    = ( stat($fullfile) )[9];

    if ( $mtime && ( $mtime + $ttl ) > $now && $mtime < $now ) {
        if ( open( my $cache_fh, '<', $fullfile ) ) {
            my $fileversion = readline($cache_fh);
            if ( $fileversion =~ /^(\d+\.\d+\.\d+)/ ) {
                $version = $1;
            }
            close($cache_fh);
        }
    }

    if ($version) { return $version; }

    $version = $self->version();

    if ($version) {
        if ( open( my $cache_fh, '>', $fullfile ) ) {
            print {$cache_fh} $version;
            close($cache_fh);
        }
    }

    return $version;
}

1;
