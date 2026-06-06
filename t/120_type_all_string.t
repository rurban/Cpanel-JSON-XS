use strict;
use warnings;

use Cpanel::JSON::XS;

use Test::More tests => 12;

my $sjson = Cpanel::JSON::XS->new->canonical->require_types->type_all_string;

is($sjson->encode(0), '"0"');
is($sjson->encode("0"), '"0"');
is($sjson->encode(0.5), '"0.5"');
is($sjson->encode("0.5"), '"0.5"');
is($sjson->encode([ 1, "2", { key1 => 3.5 }, [ "string", -10 ] ]), '["1","2",{"key1":"3.5"},["string","-10"]]');
is($sjson->encode([ Cpanel::JSON::XS::false, Cpanel::JSON::XS::true ]), '["false","true"]');
is($sjson->encode([ 1 < 0, 1 > 0 ]), '["","1"]');
is($sjson->encode(undef), 'null');

# GH #175: type_all_string must not interfere with allow_blessed/convert_blessed
{
  package TO_JSON_Obj;
  sub new { bless { x => 1 }, shift }
  sub TO_JSON { return { from_to_json => 1 } }
}
my $obj = bless {}, "SomeClass";
my $toj = TO_JSON_Obj->new;

# allow_blessed + type_all_string: blessed -> null (unquoted)
my $ab = Cpanel::JSON::XS->new->canonical->allow_blessed->type_all_string;
is($ab->encode({ num => 42, obj => $obj }), '{"num":"42","obj":null}',
   'allow_blessed + type_all_string: blessed becomes null');

# allow_blessed + convert_blessed + type_all_string (OP scenario)
my $both = Cpanel::JSON::XS->new->canonical->allow_blessed->convert_blessed->type_all_string;
is($both->encode({ num => 42, obj => $obj }), '{"num":"42","obj":null}',
   'allow_blessed + convert_blessed + type_all_string');

# convert_blessed + type_all_string with TO_JSON: TO_JSON result is stringified
my $conv = Cpanel::JSON::XS->new->canonical->convert_blessed->type_all_string;
is($conv->encode({ num => 42, obj => $toj }), '{"num":"42","obj":{"from_to_json":"1"}}',
   'convert_blessed + type_all_string: TO_JSON values get stringified');

# numbers still stringified with allow_blessed + type_all_string
is($ab->encode([ 1, Cpanel::JSON::XS::true, Cpanel::JSON::XS::false, 0.5 ]), '["1","true","false","0.5"]',
   'numbers and booleans still stringified with allow_blessed');
