use strict;
use warnings;
use ExtUtils::MakeMaker;

die "OS unsupported\n" if $^O eq 'MSWin32'; # Requires getpwuid to be implemented.

WriteMakefile(
    NAME          => 'cPanel::PublicAPI',
    AUTHOR        => q{cPanel, Inc. <integration@cpanel.net>},
    VERSION_FROM  => 'lib/cPanel/PublicAPI.pm',
    ABSTRACT_FROM => 'lib/cPanel/PublicAPI.pod',
    ( $ExtUtils::MakeMaker::VERSION >= 6.3002
        ? ( 'LICENSE' => 'bsd' )
        : () ),
    PL_FILES  => {},
    PREREQ_PM => {
        'Test::More'       => 0,
        'Test::Exception'  => 0,
        'JSON::XS'         => 2.0,
        'URI::Escape'      => 3,
        'IO::Socket::INET' => 1.31,
        'IO::Socket::SSL'  => 1.988,    # Versions below this do not handle close calls properly
        'HTTP::Tiny'       => 0.042,
        'HTTP::CookieJar'  => 0,
    },
    META_MERGE => {
        resources => {
            repository => 'https://github.com/CpanelInc/cPanel-PublicAPI',
        },
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'cPanel-PublicAPI-*' },
);
