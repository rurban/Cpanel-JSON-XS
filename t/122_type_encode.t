use strict;
use warnings;

use Cpanel::JSON::XS;
use Cpanel::JSON::XS::Type;

use Test::More tests => 24;

# GH #240: encode with type_spec must not modify the type_spec hash

my $cjson = Cpanel::JSON::XS->new->utf8->canonical;

# Basic: type_spec is unchanged after a single encode
{
    my $type_spec = { a => JSON_TYPE_STRING_OR_NULL, b => JSON_TYPE_INT };
    my $orig_a = $type_spec->{a};
    my $orig_b = $type_spec->{b};

    $cjson->encode({ a => "hello", b => 1 }, $type_spec);

    is($type_spec->{a}, $orig_a, 'type_spec->{a} unchanged after encode (non-null)');
    is($type_spec->{b}, $orig_b, 'type_spec->{b} unchanged after encode (non-null)');
}

# type_spec unchanged when value is null (undef)
{
    my $type_spec = { a => JSON_TYPE_STRING_OR_NULL, b => JSON_TYPE_INT_OR_NULL };
    my $orig_a = $type_spec->{a};
    my $orig_b = $type_spec->{b};

    $cjson->encode({ a => undef, b => undef }, $type_spec);

    is($type_spec->{a}, $orig_a, 'type_spec->{a} unchanged after encode (null value)');
    is($type_spec->{b}, $orig_b, 'type_spec->{b} unchanged after encode (null value)');
}

# Loop scenario: multiple encodes with the same type_spec (GH #240 core case)
{
    my $type_spec = { a => JSON_TYPE_STRING_OR_NULL, b => JSON_TYPE_INT };
    my $orig_a = $type_spec->{a};
    my $orig_b = $type_spec->{b};

    my @rows = (
        { a => "0.0",  b => 1 },
        { a => undef,  b => 2 },
        { a => "hello", b => 3 },
        { a => undef,  b => 4 },
        { a => "0.0",  b => 5 },
    );

    my @results;
    for my $row (@rows) {
        my $json = eval { $cjson->encode($row, $type_spec) };
        push @results, $json;
        is($type_spec->{a}, $orig_a, "type_spec->{a} unchanged after loop encode");
        is($type_spec->{b}, $orig_b, "type_spec->{b} unchanged after loop encode");
    }

    is($results[0], '{"a":"0.0","b":1}',   'loop encode result 1 correct');
    is($results[1], '{"a":null,"b":2}',    'loop encode result 2 correct (null)');
    is($results[2], '{"a":"hello","b":3}', 'loop encode result 3 correct');
    is($results[3], '{"a":null,"b":4}',    'loop encode result 4 correct (null)');
    is($results[4], '{"a":"0.0","b":5}',   'loop encode result 5 correct');
}

# type_spec loaded via raw integer values (as if decoded from a JSON config file)
{
    my $type_spec = Cpanel::JSON::XS->new->decode('{"a":260,"b":2}');
    is($type_spec->{a}, JSON_TYPE_STRING_OR_NULL, 'decoded type value matches JSON_TYPE_STRING_OR_NULL');
    is($type_spec->{b}, JSON_TYPE_INT,            'decoded type value matches JSON_TYPE_INT');

    my $result = $cjson->encode({ a => "test", b => 42 }, $type_spec);
    is($result, '{"a":"test","b":42}', 'encode with decoded-integer type_spec works');
    is($type_spec->{a}, JSON_TYPE_STRING_OR_NULL, 'type_spec unchanged after encode with decoded-integer types');
    is($type_spec->{b}, JSON_TYPE_INT,            'type_spec b unchanged after encode with decoded-integer types');
}
