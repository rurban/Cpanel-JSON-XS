use strict;
use warnings;

use Cpanel::JSON::XS;

use Test::More tests => 8;

my $sjson = Cpanel::JSON::XS->new->canonical->require_types->type_all_string->allow_nonref;

is($sjson->encode(0), '"0"');
is($sjson->encode("0"), '"0"');
is($sjson->encode(0.5), '"0.5"');
is($sjson->encode("0.5"), '"0.5"');
is($sjson->encode([ 1, "2", { key1 => 3.5 }, [ "string", -10 ] ]), '["1","2",{"key1":"3.5"},["string","-10"]]');
is($sjson->encode([ Cpanel::JSON::XS::false, Cpanel::JSON::XS::true ]), '["false","true"]');
is($sjson->encode([ 1 < 0, 1 > 0 ]), '["","1"]');
is($sjson->encode(undef), 'null');
