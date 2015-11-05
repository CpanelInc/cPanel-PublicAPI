#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok('cPanel::PublicAPI') || print "Bail out!
";
}

diag("Testing cPanel::PublicAPI $cPanel::PublicAPI::VERSION, Perl $], $^X");
