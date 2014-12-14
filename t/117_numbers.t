use strict;
use Cpanel::JSON::XS;
use Test::More;
plan tests => 9;

if (Cpanel::JSON::XS->get_stringify_infnan) {
  my ($inf, $nan) = ($^O eq 'MSWin32') ? ('1.#INF','1.#IND') : ('inf','nan');
  is encode_json([9**9**9]), "[\"$inf\"]";           #inf
  is encode_json([-sin(9**9**9)]), "[\"$nan\"]";     #nan
  is encode_json([-9**9**9]), "[\"-$inf\"]";         #-inf
  is encode_json([sin(9**9**9)]), "[\"-$nan\"]";     #-nan
  is encode_json([9**9**9/9**9**9]), "[\"-$nan\"]";  #-nan
} else {
  is encode_json([9**9**9]), '[null]';          #inf
  is encode_json([-sin(9**9**9)]), '[null]';    #nan
  is encode_json([-9**9**9]), '[null]';         #-inf
  is encode_json([sin(9**9**9)]), '[null]';     #-nan
  is encode_json([9**9**9/9**9**9]), '[null]';  #-nan
}

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
