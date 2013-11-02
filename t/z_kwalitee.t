# -*- perl -*-
use strict;
use warnings;

use Test::More;
use Config;

plan skip_all => 'This test is only run for the module author'
    unless -d '.git' || $ENV{IS_MAINTAINER};
plan skip_all => 'Test::Kwalitee fails with clang -faddress-sanitizer'
    if $Config{ccflags} =~ /-faddress-sanitizer/;

use File::Copy 'cp';
cp('MYMETA.yml','META.yml') if -e 'MYMETA.yml' and !-e 'META.yml';
eval {
  require Test::Kwalitee;
  Test::Kwalitee->import(
    tests => [ qw( -use_strict -has_test_pod -has_test_pod_coverage)]);
};
plan skip_all => "Test::Kwalitee needed for testing kwalitee"
    if $@;
