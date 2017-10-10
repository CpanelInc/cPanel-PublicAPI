#!/usr/bin/env perl

use Test::More;
plan skip_all => 'Release tests not required for installation'
  if not $ENV{RELEASE_TESTING};

eval { require Test::CPAN::Changes };
plan skip_all => 'Test::CPAN::Changes required for this test' if $@;
Test::CPAN::Changes::changes_ok();
