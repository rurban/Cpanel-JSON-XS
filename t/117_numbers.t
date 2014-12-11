use Test::More;
use strict;
BEGIN { plan tests => 5 }
BEGIN { $ENV{PERL_JSON_BACKEND} = 0; }
use Cpanel::JSON::XS;

is encode_json([9**9**9]), '[inf]';
is encode_json([-sin(9**9**9)]), '[nan]';

my $num = 3;
my $str = "$num";
TODO: {
  local $TODO = 'fix number detection heuristics (JSON-PP PR #10)';
  is encode_json({test => [$num, $str]}), '{"test":[3,"3"]}';
  $num = 3.21;
  $str = "$num";
  is encode_json({test => [$num, $str]}), '{"test":[3.21,"3.21"]}';
}
$str = '0 but true';
$num = 1 + $str;
is encode_json({test => [$num, $str]}), '{"test":[1,"0 but true"]}';
