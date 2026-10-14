use strict;
use Config;
use Test::More;

BEGIN {
  plan skip_all => 'needs ithreads on perl 5.8.9+' if !$Config{useithreads} || $] < 5.008009;
}

use threads;
use Cpanel::JSON::XS;
plan tests => 2;

my $json = Cpanel::JSON::XS->new->filter_json_object(sub { 'filtered' });
is( threads->create(sub { $json->decode('{}') })->join, 'filtered', 'filter_json_object in threads' );
is( $json->decode('{}'), 'filtered', 'vs filter_json_object' );
