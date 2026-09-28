use strict;
use warnings;

use Cpanel::JSON::XS;
use Cpanel::JSON::XS::Type;

use Test::More tests => 26;

# --- check_type: scalar leaves, short names, JSON_TYPE_* constants ---

is_deeply([ check_type("hi", 'Str') ], [], 'Str matches string');
is_deeply([ check_type(5, 'Str') ], [ '$: expected Str, got Int' ], 'Str rejects int');
is_deeply([ check_type(5, JSON_TYPE_INT) ], [], 'JSON_TYPE_INT matches int constant form');
is_deeply([ check_type(undef, 'Int') ], [ '$: expected Int, got null' ], 'non-nullable Int rejects undef');
is_deeply([ check_type(undef, 'Int?') ], [], "'Int?' accepts undef");
is_deeply([ check_type(undef, 'Null') ], [], "'Null' accepts undef");
is_deeply([ check_type(3, 'Null') ], [ '$: expected null, got Int' ], "'Null' rejects a defined value");
is_deeply([ check_type([1,2,3], 'Any') ], [], "'Any' accepts anything, including refs' subtree" );
is_deeply([ check_type(undef, 'Any') ], [], "'Any' accepts undef too");

# --- arrays ---

is_deeply([ check_type([1,2,3], json_type_arrayof('Int')) ], [], 'arrayof(Int) ok');
is_deeply(
  [ check_type([1,"x",3], json_type_arrayof('Int')) ],
  [ '$->[1]: expected Int, got Str' ],
  'arrayof(Int) reports the bad element with its index'
);
is_deeply([ check_type([1,"a"], [ 'Int', 'Str' ]) ], [], 'fixed-shape array ok');
is_deeply(
  [ check_type([1,"a",3], [ 'Int', 'Str' ]) ],
  [ '$: expected array of length 2, got 3' ],
  'fixed-shape array length mismatch'
);
is_deeply([ check_type("x", json_type_arrayof('Int')) ], [ '$: expected array, got scalar' ], 'arrayof rejects non-array');

# --- hashes: closed schema vs open hashof ---

is_deeply(
  [ check_type({ id => 1, name => "joe" }, { id => 'Int', name => 'Str' }) ],
  [],
  'closed hash schema ok'
);
is_deeply(
  [ check_type({ id => 1 }, { id => 'Int', name => 'Str' }) ],
  [ q{$: missing required key 'name'} ],
  'closed hash schema reports missing required key'
);
is_deeply(
  [ check_type({ id => 1, extra => 1 }, { id => 'Int' }) ],
  [ q{$: unexpected key 'extra'} ],
  'closed hash schema reports unexpected key'
);
is_deeply(
  [ check_type({ id => 1, nick => undef }, { id => 'Int', nick => json_type_optional('Str') }) ],
  [],
  'json_type_optional key may be entirely absent, or present as null'
);
is_deeply(
  [ check_type({ id => 1 }, { id => 'Int', nick => json_type_optional('Str') }) ],
  [],
  'json_type_optional key absence is fine'
);
is_deeply(
  [ check_type({ a => "x", b => "y" }, json_type_hashof('Str')) ],
  [],
  'json_type_hashof stays open (any keys), homogeneous value type'
);
is_deeply(
  [ check_type({ a => "x", b => 2 }, json_type_hashof('Str')) ],
  [ q{$->{b}: expected Str, got Int} ],
  'json_type_hashof still enforces the value type, but keeps keys open'
);

# --- anyof ---

is_deeply(
  [ check_type(5, json_type_anyof('Int', json_type_arrayof('Int'))) ],
  [],
  'anyof: scalar alternative matches'
);
is_deeply(
  [ check_type([1,2], json_type_anyof('Int', json_type_arrayof('Int'))) ],
  [],
  'anyof: array alternative matches'
);

# --- decode_and_validate: end to end, using decode()'s own type introspection ---

my $json = Cpanel::JSON::XS->new;
my $schema = { id => JSON_TYPE_INT, name => 'Str', tags => json_type_arrayof('Str') };

my $data = $json->decode_and_validate('{"id":1,"name":"joe","tags":["a","b"]}', $schema);
is_deeply($data, { id => 1, name => 'joe', tags => [ 'a', 'b' ] }, 'decode_and_validate returns decoded data on success');

eval { $json->decode_and_validate('{"id":"1","name":"joe","tags":["a","b"]}', $schema) };
like($@, qr/expected Int, got Str/, 'decode_and_validate croaks with the mismatch, using the exact decoded type');

# a numeric-looking string decoded via JSON is still a JSON string: decode()'s
# own type introspection (not perl's scalar-flag heuristics) must catch this.
eval { $json->decode_and_validate('{"id":1,"name":"joe","tags":["a",2]}', $schema) };
like($@, qr/expected Str, got Int/, 'decode_and_validate catches a wrong element type inside arrayof');
