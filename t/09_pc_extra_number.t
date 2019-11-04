# copied over from JSON::PC and modified to use Cpanel::JSON::XS

use Test::More;
use strict;
BEGIN { plan tests => 8 };
use Cpanel::JSON::XS;
use utf8;

#########################
my ($js,$obj);
my $pc = new Cpanel::JSON::XS;

$js  = '{"foo":0}';
$obj = $pc->decode($js);
is($obj->{foo}, 0, "normal 0");

$js  = '{"foo":0.1}';
$obj = $pc->decode($js);
is($obj->{foo}, 0.1, "normal 0.1");


$js  = '{"foo":10}';
$obj = $pc->decode($js);
is($obj->{foo}, 10, "normal 10");

$js  = '{"foo":-10}';
$obj = $pc->decode($js);
is($obj->{foo}, -10, "normal -10");


$js  = '{"foo":0, "bar":0.1}';
$obj = $pc->decode($js);
is($obj->{foo},0,  "normal 0");
is($obj->{bar},0.1,"normal 0.1");

# GH 154
$obj = $pc->decode(q([0.3]));
TODO: {
  local $TODO = "strtold vs json_atof_scan1, GH #154" if $] < 5.021004;
  is($obj->[0] - 0.3, 0.0, "normal 0.3");
}
ok(abs($obj->[0] - 0.3) < 1e-16, "numeric epsilon <1E-16");

