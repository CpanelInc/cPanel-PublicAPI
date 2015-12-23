use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'cPanel::PublicAPI',
    AUTHOR              => q{cPanel, Inc. <integration@cpanel.net>},
    VERSION_FROM        => 'lib/cPanel/PublicAPI.pm',
    ABSTRACT_FROM       => 'lib/cPanel/PublicAPI.pod',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'Modified BSD')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'JSON::XS'  => 2.0,
        'URI::Escape' => 3,
        'IO::Socket::INET' => 1.31,
        'IO::Socket::SSL' => 1.33,
        'HTTP::Tiny' => 0.042,
        'HTTP::CookieJar' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'cPanel-PublicAPI-*' },
);
