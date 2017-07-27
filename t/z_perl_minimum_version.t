# -*- perl -*-

# Test that our declared minimum Perl version matches our syntax
use strict;
BEGIN {
  $|  = 1;
  $^W = 1;
}

my @MODULES = (
  'Perl::MinimumVersion 1.20',
  'Test::MinimumVersion 0.101082',
);

# Don't run tests during end-user installs
use Test::More;
unless (-d '.git' || $ENV{AUTHOR_TESTING}) {
  plan( skip_all => "Author tests not required for installation" );
}

# Load the testing modules
foreach my $MODULE ( @MODULES ) {
  eval "use $MODULE";
  if ( $@ ) {
    plan( skip_all => "$MODULE not available for testing" );
    die "Failed to load required release-testing module $MODULE"
      if -d '.git' || $ENV{AUTHOR_TESTING};
  }
}

all_minimum_version_ok("5.008"); # but 5.6.2 is allowed dynamically

1;
