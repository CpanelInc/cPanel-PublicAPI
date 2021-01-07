package cPanel::PublicAPI::API;

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

cPanel::PublicAPI::_init_serializer() if !exists $cPanel::PublicAPI::CFG{'serializer'};

sub api_listaccts {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/listaccts', \@_, [ 'search', 'searchtype' ] ) );
}

sub api_createacct {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/createacct', \@_, [ 'username', 'domain', 'password', 'plan' ] ) );
}

sub api_removeacct {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/removeacct', \@_, ['user'] ) );
}

sub api_showversion {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/version', \@_ ) );
}

sub api_version {
    goto &xmlapi_showversion;
}

sub api_applist {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/applist', \@_ ) );
}

sub api_generatessl {
    my $self = shift;
    return $self->serialize( $self->simple_post_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/generatessl', \@_, [ 'host', 'pass', 'country', 'state', 'city', 'co', 'cod', 'email', 'xemail' ] ) );
}

sub api_generatessl_noemail {
    my $self = shift;
    return $self->serialize( $self->simple_post_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/generatessl', \@_, [ 'host', 'pass', 'country', 'state', 'city', 'co', 'cod', 'email' ], ['noemail=1'] ) );
}

sub api_listcrts {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/listcrts', \@_ ) );
}

# Variable arguments
sub api_setresellerlimits {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/setresellerlimits', \@_ ) );
}

sub api_setresellerpackagelimit {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/setresellerpackagelimit', \@_, [ 'user', 'package', 'allowerd', 'number', 'no_limit' ] ) );
}

sub api_setresellermainip {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/setresellermainip', \@_, [ 'user', 'ip' ] ) );
}

sub api_setresellerips {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/setresellerips', \@_, [ 'user', 'delegate', 'ips' ] ) );
}

sub api_setresellernameservers {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/setresellernameservers', \@_, [ 'user', 'nameservers' ] ) );
}

sub api_suspendreseller {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/suspendreseller', \@_, [ 'user', 'reason', 'disallow' ] ) );
}

sub api_unsuspendreseller {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/unsuspendreseller', \@_, ['user'] ) );
}

# Variable arguments
sub api_addzonerecord {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/addzonerecord', \@_ ) );
}

# Variable arguments
sub api_editzonerecord {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/editzonerecord', \@_ ) );
}

sub api_removezonerecord {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/removezonerecord', \@_, [ 'domain', 'Line' ] ) );
}

sub api_getzonerecord {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/getzonerecord', \@_, [ 'domain', 'Line' ] ) );
}

sub api_servicestatus {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/servicestatus', \@_, ['service'] ) );
}

sub api_configureservice {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/configureservice', \@_, [ 'service', 'enabled', 'monitored' ] ) );
}

sub api_acctcounts {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/acctcounts', \@_, ['user'] ) );
}

sub api_domainuserdata {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/domainuserdata', \@_, ['domain'] ) );
}

sub api_editquota {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/editquota', \@_, [ 'user', 'quota' ] ) );
}

sub api_nvget {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/nvget', \@_, ['key'] ) );
}

# The underlying XMLAPI call allows setting multiple nvvars at once by appending
# labels to the end of the variable names... i.e. key1, value1
sub api_nvset {
    my $self = shift;
    return $self->serialize( $self->simple_post_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/nvset', \@_, [ 'key', 'value' ] ) );
}

sub api_myprivs {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/myprivs', \@_ ) );
}

sub api_listzones {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/listzones', \@_ ) );
}

sub api_sethostname {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/sethostname', \@_, ['hostname'] ) );
}

sub api_setresolvers {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/setresolvers', \@_, [ 'nameserver1', 'nameserver2', 'nameserver3' ] ) );
}

sub api_addip {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/addip', \@_, [ 'ip', 'netmask' ] ) );
}

sub api_delip {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/delip', \@_, [ 'ip', 'ethernetdev', 'skipifshutdown' ] ) );
}

sub api_listips {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/listips', \@_ ) );
}

sub api_dumpzone {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/dumpzone', \@_, ['domain'] ) );
}

sub api_listpkgs {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/listpkgs', \@_ ) );
}

sub api_limitbw {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/limitbw', \@_, [ 'user', 'bwlimit' ] ) );
}

sub api_showbw {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/showbw', \@_, [ 'month', 'year', 'showres', 'search', 'searchtype' ] ) );
}

sub api_killdns {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/killdns', \@_, ['domain'] ) );
}

sub api_adddns {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/adddns', \@_, [ 'domain', 'ip', 'trueowner' ] ) );
}

sub api_changepackage {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/changepackage', \@_, [ 'user', 'pkg' ] ) );
}

sub api_modifyacct {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/modifyacct', \@_, [ 'user', 'domain', 'HASCGI', 'CPTHEME', 'LANG', 'MAXPOP', 'MAXFTP', 'MAXLST', 'MAXSUB', 'MAXPARK', 'MAXADDON', 'MAXSQL', 'shell' ] ) );
}

sub api_suspendacct {
    my $self = shift;
    return $self->serialize( $self->simple_post_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/suspendacct', \@_, [ 'user', 'reason' ] ) );
}

sub api_unsuspendacct {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/unsuspendacct', \@_, ['user'] ) );
}

sub api_listsuspended {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/listsuspended', \@_ ) );
}

sub api_addpkg {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/addpkg', \@_, [ 'pkgname', 'quota', 'ip', 'cgi', 'cpmod', 'maxftp', 'maxsql', 'maxpop', 'maxlst', 'maxsub', 'maxpark', 'maxaddon', 'featurelist', 'hasshell', 'bwlimit' ] ) );
}

sub api_killpkg {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/killpkg', \@_, ['pkg'] ) );
}

sub api_editpkg {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/editpkg', \@_, [ 'pkgname', 'quota', 'ip', 'cgi', 'cpmod', 'maxftp', 'maxsql', 'maxpop', 'maxlst', 'maxsub', 'maxpark', 'maxaddon', 'featurelist', 'hasshell', 'bwlimit' ] ) );
}

sub api_setacls {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/setacls', \@_, [ 'reseller', 'acllist' ] ) );
}

sub api_terminatereseller {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/terminatereseller', \@_, [ 'reseller', 'verify' ] ) );
}

sub api_resellerstats {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/resellerstats', \@_, ['reseller'] ) );
}

sub api_setupreseller {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/setupreseller', \@_, [ 'user', 'makeowner' ] ) );
}

sub api_lookupnsip {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/lookupnsip', \@_, ['nameserver'] ) );
}

sub api_listresellers {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/listresellers', \@_ ) );
}

sub api_listacls {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/listacls', \@_ ) );
}

sub api_saveacllist {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/saveacllist', \@_, ['acllist'] ) );
}

sub api_unsetupreseller {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/unsetupreseller', \@_, ['user'] ) );
}

sub api_gethostname {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/gethostname', \@_ ) );
}

sub api_fetchsslinfo {
    my $self = shift;
    return $self->serialize( $self->simple_post_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/fetchsslinfo', \@_, [ 'domain', 'crtdata' ] ) );
}

sub api_installssl {
    my $self = shift;
    return $self->serialize( $self->simple_post_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/installssl', \@_, [ 'domain', 'user', 'cert', 'key', 'cab', 'ip' ] ) );
}

sub api_passwd {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/passwd', \@_, [ 'user', 'pass' ] ) );
}

sub api_getlanglist {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/getlanglist', \@_ ) );
}

sub api_reboot {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/reboot', \@_, ['force'] ) );
}

sub api_accountsummary_user {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/accountsummary', \@_, ['user'] ) );
}

sub api_accountsummary_domain {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/accountsummary', \@_, ['domain'] ) );
}

sub api_loadavg {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/loadavg', \@_ ) );
}

sub api_restartservice {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/restartservice', \@_, ['service'] ) );
}

sub api_setsiteip_user {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/setsiteip', \@_, [ 'user', 'ip' ] ) );
}

sub api_setsiteip_domain {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/setsiteip', \@_, [ 'domain', 'ip' ] ) );
}

sub api_initializemsgcenter {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/initializemsgcenter', \@_, [ 'title', 'id' ] ) );
}

sub api_createmsg {
    my $self = shift;

    # Need to perform magic to deal with the optional parameters.
    my @parm_names = ( 'title', 'updated', 'published', 'content', 'author.name', 'author.email', 'author.uri', 'contributor.name', 'contributor.email', 'contributor.uri', 'summary' );

    my $extra_count = scalar(@_) - scalar(@parm_names);
    my $cat_count = int( $extra_count / 3 + ( ( $extra_count % 3 ) && 1 ) );
    foreach my $i ( 1 .. $cat_count ) {
        push @parm_names, "category.$i.term", "category.$i.label", "category.$i.scheme";
    }

    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/createmsg', \@_, \@parm_names ) );
}

sub api_deletemsg {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/deletemsg', \@_, ['atom_id'] ) );
}

sub api_getmsgfeed {
    my $self = shift;
    return $self->serialize( $self->simple_get_whmreq( '/' . $cPanel::PublicAPI::CFG{'serializer'} . '-api/getmsgfeed', \@_, ['which'] ) );
}

sub serialize {
    my $self = shift;
    return $cPanel::PublicAPI::CFG{'api_decode_func'}->(@_);
}

1;
