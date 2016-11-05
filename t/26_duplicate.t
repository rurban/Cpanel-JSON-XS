use Test::More tests => 4;
use Cpanel::JSON::XS;

my $json = Cpanel::JSON::XS->new;

is (encode_json $json->decode ('{"a":"b","a":"c"}'), '{"a":"c"}'); # t/test_parsing/y_object_duplicated_key.json
is (encode_json $json->decode ('{"a":"b","a":"b"}'), '{"a":"b"}'); # t/test_parsing/y_object_duplicated_key_and_value.json

$json->disallow_dupkeys;
ok (!eval { $json->decode ('{"a":"b","a":"c"}') }); # t/test_parsing/y_object_duplicated_key.json
ok (!eval { $json->decode ('{"a":"b","a":"b"}') }); # t/test_parsing/y_object_duplicated_key_and_value.json
