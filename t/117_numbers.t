use strict;
use Cpanel::JSON::XS;
use Test::More;
plan tests => 9;

# TODO: detect STRINGIFY_INFNAN somehow. add it to the API?
is encode_json([9**9**9]), '[null]';          #inf
is encode_json([-sin(9**9**9)]), '[null]';    #nan
is encode_json([-9**9**9]), '[null]';         #-inf
is encode_json([sin(9**9**9)]), '[null]';     #-nan
is encode_json([9**9**9/9**9**9]), '[null]';  #-nan

my $num = 3;
my $str = "$num";
is encode_json({test => [$num, $str]}), '{"test":[3,"3"]}';

$num = 3.21;
$str = "$num";
is encode_json({test => [$num, $str]}), '{"test":[3.21,"3.21"]}';

$str = '0 but true';
$num = 1 + $str;
is encode_json({test => [$num, $str]}), '{"test":[1,"0 but true"]}';

$str = 'bar';
{ no warnings "numeric"; $num = 23 + $str }
is encode_json({test => [$num, $str]}), '{"test":[23,"bar"]}';
