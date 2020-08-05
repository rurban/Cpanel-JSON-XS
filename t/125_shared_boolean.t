use strict;
use Config;
use Test::More;
use Cpanel::JSON::XS ();

BEGIN {
  plan skip_all => 'no threads' if !$Config{usethreads};
  plan tests => 6;
}

use threads;
use threads::shared;

TODO: {
  local $TODO = 'threads::shared';
  my $json1 = shared_clone({'enabled' => Cpanel::JSON::XS::true});
  is( Cpanel::JSON::XS::encode_json( $json1 ), '{"enabled":true}', "Cpanel::JSON::XS shared true");
}
my $json2 = shared_clone({'disabled' => Cpanel::JSON::XS::false});
is( Cpanel::JSON::XS::encode_json( $json2 ), '{"disabled":false}', "Cpanel::JSON::XS shared false");

SKIP: {
  eval "require JSON::XS;";
  skip "JSON::XS required for testing interop", 2 if $@;
  
  my $json3 = shared_clone({'enabled' => JSON::XS::true()});
  is( JSON::XS::encode_json( $json3 ), '{"enabled":true}', "JSON::XS shared true");
  my $json4 = shared_clone({'disabled' => JSON::XS::false()});
  is( JSON::XS::encode_json( $json4 ), '{"disabled":false}', "JSON::XS shared false");
}

SKIP: {
  eval "require JSON::PP && require JSON::PP::Boolean;";
  skip "JSON::PP required for testing interop", 2 if $@;
  
  my $json5 = shared_clone({'enabled' => $JSON::PP::true});
  is( JSON::PP::encode_json( $json5 ), '{"enabled":true}', "JSON::PP shared true");
  my $json6 = shared_clone({'disabled' => $JSON::PP::false});
  is( JSON::PP::encode_json( $json6 ), '{"disabled":false}', "JSON::PP shared false");
}
