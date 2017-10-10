#!/usr/bin/env perl

use Test::More;
plan skip_all => 'Release tests not required for installation'
  if not $ENV{RELEASE_TESTING};

eval { require Test::CheckChanges };
plan skip_all => 'Test::CheckChanges required for this test' if $@;
Test::CheckChanges::ok_changes();
