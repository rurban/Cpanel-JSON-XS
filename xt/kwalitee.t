# -*- perl -*-
use strict;
use warnings;
use Test::More;
use Config;

plan skip_all => 'requires Test::More 0.88' if Test::More->VERSION < 0.88;
plan skip_all => 'requires Perl 5.8.2' if $] < 5.008002;

plan skip_all => 'This test is only run for the module author'
  unless -d '.git' || $ENV{AUTHOR_TESTING} || $ENV{RELEASE_TESTING};

# Missing XS dependencies are usually not caught by EUMM
# And they are usually only XS-loaded by the importer, not require.
for (qw( Class::XSAccessor Text::CSV_XS List::MoreUtils )) {
  eval "use $_;";
  plan skip_all => "$_ required for Test::Kwalitee"
    if $@;
}
eval "require Test::Kwalitee;";
plan skip_all => "Test::Kwalitee required"
  if $@;

plan skip_all => 'Test::Kwalitee fails with clang -faddress-sanitizer'
  if $Config{ccflags} =~ /-faddress-sanitizer/;

Test::Kwalitee->import( tests => [ qw( -use_strict ) ] );
