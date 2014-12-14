use strict;
use Cpanel::JSON::XS;
use Test::More;
plan tests => 19;

is encode_json([9**9**9]),         '[null]', "inf -> null";
is encode_json([-sin(9**9**9)]),   '[null]', "nan -> null";
is encode_json([-9**9**9]),        '[null]', "-inf -> null";
is encode_json([sin(9**9**9)]),    '[null]', "-nan -> null";
is encode_json([9**9**9/9**9**9]), '[null]', "-nan -> null";

my $json = Cpanel::JSON::XS->new->stringify_infnan;
my ($inf, $nan) = ($^O eq 'MSWin32') ? ('1.#INF','1.#QNAN') : ('inf','nan');
is $json->encode([9**9**9]),  "[\"$inf\"]",  "inf -> \"inf\"";
is $json->encode([-sin(9**9**9)]),
  $^O eq 'MSWin32' ? "[\"-1.#IND\"]" : "[\"$nan\"]",  "nan -> \"nan\"";
is $json->encode([-9**9**9]), "[\"-$inf\"]", "-inf -> \"-inf\"";
TODO: {
  local $TODO = 'cygwin has no -nan' if $^O eq 'cygwin';
  is $json->encode([sin(9**9**9)]),
    $^O eq 'MSWin32' ? "[\"$nan\"]" : "[\"-$nan\"]", "-nan -> \"-nan\"";
  is $json->encode([9**9**9/9**9**9]),
    $^O eq 'MSWin32' ? "[\"-1.#IND\"]" : "[\"-$nan\"]", "-nan -> \"-nan\"";
}

$json = Cpanel::JSON::XS->new->stringify_infnan(2);
is $json->encode([9**9**9]),         "[$inf]",  "inf";
is $json->encode([-sin(9**9**9)]),
  $^O eq 'MSWin32' ? "[-1.#IND]" : "[$nan]",  "nan";
is $json->encode([-9**9**9]),        "[-$inf]", "-inf";
TODO: {
  local $TODO = 'cygwin has no -nan' if $^O eq 'cygwin';
  is $json->encode([sin(9**9**9)]),
    $^O eq 'MSWin32' ? "[$nan]" : "[-$nan]", "-nan";
  is $json->encode([9**9**9/9**9**9]),
    $^O eq 'MSWin32' ? "[-1.#IND]" : "[-$nan]", "-nan";
}

my $num = 3;
my $str = "$num";
is encode_json({test => [$num, $str]}), '{"test":[3,"3"]}', 'int dualvar';

$num = 3.21;
$str = "$num";
is encode_json({test => [$num, $str]}), '{"test":[3.21,"3.21"]}', 'numeric dualvar';

$str = '0 but true';
$num = 1 + $str;
is encode_json({test => [$num, $str]}), '{"test":[1,"0 but true"]}', 'int/string dualvar';

$str = 'bar';
{ no warnings "numeric"; $num = 23 + $str }
is encode_json({test => [$num, $str]}), '{"test":[23,"bar"]}', , 'int/string dualvar';
