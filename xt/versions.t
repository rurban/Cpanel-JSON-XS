# -*- perl -*-

# Test that every module in this distribution declares the same $VERSION:
# XS.pm, XS/Boolean.pm, XS/Type.pm and t/_unicode_handling.pm.

use strict;
BEGIN {
  $|  = 1;
  $^W = 1;
}

use Test::More;

# Don't run tests during end-user installs
unless (-d '.git' || $ENV{AUTHOR_TESTING}) {
  plan( skip_all => "Author tests not required for installation" );
}

use ExtUtils::MakeMaker ();

my @FILES = qw(XS.pm XS/Boolean.pm XS/Type.pm t/_unicode_handling.pm);

plan tests => scalar(@FILES) - 1;

my %version;
for my $file (@FILES) {
  my $v = eval { MM->parse_version($file) };
  die "could not find \$VERSION in $file: $@" unless defined $v && $v ne 'undef';
  $version{$file} = $v;
}

my $ref_file    = $FILES[0];
my $ref_version = $version{$ref_file};

for my $file (@FILES[1 .. $#FILES]) {
  is($version{$file}, $ref_version,
     "$file \$VERSION ($version{$file}) matches $ref_file (\$VERSION $ref_version)");
}
