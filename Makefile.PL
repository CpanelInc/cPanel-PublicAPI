use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'cPanel::PublicAPI',
    AUTHOR              => q{Matt Dees <matt@cpanel.net>},
    VERSION_FROM        => 'lib/cPanel/PublicAPI.pm',
    ABSTRACT_FROM       => 'lib/cPanel/PublicAPI.pod',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'JSON::XS'  => 2.0,
        'URI::Escape' => 3,
        'Net::SSLeay' => 1.36,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'cPanel-PublicAPI-*' },
);
