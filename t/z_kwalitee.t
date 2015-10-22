# -*- perl -*-
use strict;
use warnings;
use Test::More;
use Config;

plan skip_all => 'requires Test::More 0.88' if Test::More->VERSION < 0.88;

BEGIN {
  plan skip_all => 'This test is only run for the module author'
    unless -d '.git' || $ENV{AUTHOR_TESTING};
  plan skip_all => 'Test::Kwalitee fails with clang -faddress-sanitizer'
    if $Config{ccflags} =~ /-faddress-sanitizer/;

  # Missing XS dependencies are usually not caught by EUMM
  # And they are usually only XS-loaded by the importer, not require.
  for (qw( Text::CSV_XS Module::CPANTS::Kwalitee::Distros List::MoreUtils Test::Kwalitee )) {
    eval { eval "require $_;"; $_->import unless $_ eq 'Test::Kwalitee'; };
    plan skip_all => "$_ needed for testing kwalitee"
      if $@;
  }
}

Test::Kwalitee->import( tests => [ qw( -use_strict ) ] );
