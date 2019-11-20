use strict;
use warnings;

use Cpanel::JSON::XS;

use Test::More tests => 5;

my $sjson = Cpanel::JSON::XS->new->canonical->require_types->type_all_string->allow_nonref;

is($sjson->encode(0), '"0"');
is($sjson->encode("0"), '"0"');
is($sjson->encode(0.5), '"0.5"');
is($sjson->encode("0.5"), '"0.5"');
is($sjson->encode([ 1, "2", { key1 => 3.5 }, [ "string", -10 ] ]), '["1","2",{"key1":"3.5"},["string","-10"]]');
