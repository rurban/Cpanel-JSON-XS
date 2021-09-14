use strict;
use Config;
use Test::More;
use Cpanel::JSON::XS ();

BEGIN {
  plan skip_all => 'no threads' if !$Config{usethreads};
}

use threads;
use threads::shared;

BEGIN {
  if (eval {threads::shared->VERSION('1.21')}) {
    plan tests => 8;
  }
  else {
    plan skip_all => 'no shared_clone';
  }
}

my $json1 = shared_clone({'enabled' => Cpanel::JSON::XS::true});
is( Cpanel::JSON::XS::encode_json( $json1 ), '{"enabled":true}', "Cpanel::JSON::XS shared true");
my $json2 = shared_clone({'disabled' => Cpanel::JSON::XS::false});
is( Cpanel::JSON::XS::encode_json( $json2 ), '{"disabled":false}', "Cpanel::JSON::XS shared false");

SKIP: {
  eval "require JSON::XS;";
  skip "JSON::XS required for testing interop", 4 if $@;
  
  my $json3 = shared_clone({'enabled' => JSON::XS::true()});
  is( JSON::XS::encode_json( $json3 ), '{"enabled":true}', "JSON::XS shared true");
  my $json4 = shared_clone({'disabled' => JSON::XS::false()});
  is( JSON::XS::encode_json( $json4 ), '{"disabled":false}', "JSON::XS shared false");

  # Using the Types::Serialiser booleans
  my $json3a = shared_clone({'enabled' => Cpanel::JSON::XS::true});
  is( Cpanel::JSON::XS::encode_json( $json3a ), '{"enabled":true}', "Types::Serialiser shared true");
  my $json4a = shared_clone({'disabled' => Cpanel::JSON::XS::false});
  is( Cpanel::JSON::XS::encode_json( $json4a ), '{"disabled":false}', "Types::Serialiser shared false");
}

SKIP: {
  eval "require JSON::PP && require JSON::PP::Boolean;";
  skip "JSON::PP required for testing interop", 2 if $@;
  
 TODO: {
   local $TODO = "JSON::PP::Boolean $JSON::PP::VERSION looks broken, upgrade"
     if $JSON::PP::VERSION > 2.2740001 and $JSON::PP::VERSION < 4.0; # return null in both cases
   # 4.02 ok
   # 2.97001_04 broken
   # 2.94_01 broken
   # 2.27400_02 broken
   # 2.27400_01 ok
   # 2.27300 ok

   my $json5 = shared_clone({'enabled' => $JSON::PP::true});
   is( JSON::PP::encode_json( $json5 ), '{"enabled":true}', "JSON::PP shared true");
   my $json6 = shared_clone({'disabled' => $JSON::PP::false});
   is( JSON::PP::encode_json( $json6 ), '{"disabled":false}', "JSON::PP shared false");
  }
}
