use strict;
use Cpanel::JSON::XS;
use Test::More;
plan tests => 5;

is encode_json([9**9**9]), '[null]';
is encode_json([-sin(9**9**9)]), '[null]';

my $num = 3;
my $str = "$num";
is encode_json({test => [$num, $str]}), '{"test":[3,"3"]}';

$num = 3.21;
$str = "$num";
is encode_json({test => [$num, $str]}), '{"test":[3.21,"3.21"]}';

$str = '0 but true';
$num = 1 + $str;
is encode_json({test => [$num, $str]}), '{"test":[1,"0 but true"]}';
