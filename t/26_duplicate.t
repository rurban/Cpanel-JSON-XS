use strict;
use Test::More tests => 17;
use Cpanel::JSON::XS;

my $json = Cpanel::JSON::XS->new;

# disallow dupkeys
ok (!eval { $json->decode ('{"a":"b","a":"c"}') }); # y_object_duplicated_key.json
ok (!eval { $json->decode ('{"a":"b","a":"b"}') }); # y_object_duplicated_key_and_value.json

# relaxed allows dupkeys
$json->relaxed;
# y_object_duplicated_key.json
is (encode_json ($json->decode ('{"a":"b","a":"c"}')), '{"a":"c"}', 'relaxed');
# y_object_duplicated_key_and_value.json
is (encode_json ($json->decode ('{"a":"b","a":"b"}')), '{"a":"b"}', 'relaxed');

# turning off relaxed disallows dupkeys
$json->relaxed(0);
$json->allow_dupkeys; # but turn it on
is (encode_json ($json->decode ('{"a":"b","a":"c"}')), '{"a":"c"}', 'allow_dupkeys');
is (encode_json ($json->decode ('{"a":"b","a":"b"}')), '{"a":"b"}', 'allow_dupkeys');

# disallow dupkeys explicitly
$json->allow_dupkeys(0);
eval { $json->decode ('{"a":"b","a":"c"}') };
like ($@, qr/^Duplicate keys not allowed/, 'allow_dupkeys(0)');

# disallow dupkeys explicitly with relaxed
$json->relaxed;
$json->allow_dupkeys(0);
eval { $json->decode ('{"a":"b","a":"c"}') }; # the XS slow path
like ($@, qr/^Duplicate keys not allowed/, 'relaxed and allow_dupkeys(0)');

# allow dupkeys
$json->allow_dupkeys;
$json->relaxed(0); # tuning off relaxed needs to turn off dupkeys
eval { $json->decode ('{"a":"b","a":"c"}') };
like ($@, qr/^Duplicate keys not allowed/, 'relaxed(0)');

# a private extension (GH #193)
$json->allow_dupkeys(0);
$json->dupkeys_as_arrayref; # should turn on dupkeys
is (encode_json ($json->decode ('{"a":"b","a":"c"}')), '{"a":["b","c"]}',
    'dupkeys_as_arrayref');
is (encode_json ($json->decode ('{"a":["b"],"a":"c"}')), '{"a":[["b"],"c"]}',
    'dupkeys_as_arrayref to []');
is (encode_json ($json->decode ('{"a":["b","c"],"a":["c"]}')), '{"a":[["b","c"],["c"]]}',
    'dupkeys_as_arrayref to [[]]');

# fast path: short ASCII keys
is_deeply ($json->decode ('{"a":1,"a":2,"b":3,"b":4}'),
           { a => [1, 2], b => [3, 4] },
           'dupkeys_as_arrayref: two distinct duplicated keys, fast path');

# slow path: keys longer than 24 bytes force _decode_str
{
  my $k1 = 'a' x 30;
  my $k2 = 'b' x 30;
  my $in = qq({"$k1":1,"$k1":2,"$k2":3,"$k2":4});
  is_deeply ($json->decode ($in),
             { $k1 => [1, 2], $k2 => [3, 4] },
             'dupkeys_as_arrayref: two distinct duplicated keys, slow path');
}

# three distinct duplicated keys - confirms fix past the first transition
is_deeply ($json->decode ('{"a":1,"a":2,"b":3,"b":4,"c":5,"c":6}'),
           { a => [1, 2], b => [3, 4], c => [5, 6] },
           'dupkeys_as_arrayref: three distinct duplicated keys');

# triple duplicate of a second key - further dups should append, not re-wrap
is_deeply ($json->decode ('{"a":1,"a":2,"b":3,"b":4,"b":5}'),
           { a => [1, 2], b => [3, 4, 5] },
           'dupkeys_as_arrayref: triple dup of second key');

# pre-existing arrayref values combine correctly across multiple keys
is_deeply ($json->decode ('{"a":["x"],"a":"y","b":["p"],"b":"q"}'),
           { a => [['x'], 'y'], b => [['p'], 'q'] },
           'dupkeys_as_arrayref: existing array values, two distinct keys');
