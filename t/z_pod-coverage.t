# -*- perl -*-
use strict;
use warnings;
use Test::More;

plan skip_all => 'done_testing requires Test::More 0.88' if Test::More->VERSION < 0.88;
plan skip_all => 'This test is only run for the module author'
    unless -d '.git' || $ENV{AUTHOR_TESTING};

eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage"
    if $@;

for (all_modules()) {
  pod_coverage_ok($_, { trustme => [qr/^JSON_TYPE_.*_(?:NULL|CLASS)$/] }) unless /XXX/;
}

done_testing();
