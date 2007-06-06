BEGIN { $| = 1; print "1..67\n"; }

use utf8;
use JSON::XS;

our $test;
sub ok($) {
   print $_[0] ? "" : "not ", "ok ", ++$test, "\n";
}

ok (!defined JSON::XS->new->allow_nonref (1)->decode ('null'));
ok (JSON::XS->new->allow_nonref (1)->decode ('true') == 1);
ok (JSON::XS->new->allow_nonref (1)->decode ('false') == 0);

ok (JSON::XS->new->allow_nonref (1)->decode ('5') == 5);
ok (JSON::XS->new->allow_nonref (1)->decode ('-5') == -5);
ok (JSON::XS->new->allow_nonref (1)->decode ('5e1') == 50);
ok (JSON::XS->new->allow_nonref (1)->decode ('-333e+0') == -333);
ok (JSON::XS->new->allow_nonref (1)->decode ('2.5') == 2.5);

ok (JSON::XS->new->allow_nonref (1)->decode ('""') eq "");
ok ('[1,2,3,4]' eq to_json from_json ('[1,2, 3,4]'));
ok ('[{},[],[],{}]' eq to_json from_json ('[{},[], [ ] ,{ }]'));
ok ('[{"1":[5]}]' eq to_json [{1 => [5]}]);
ok ('{"1":2,"3":4}' eq JSON::XS->new->canonical (1)->encode (from_json '{ "1" : 2, "3" : 4 }'));
ok ('{"1":2,"3":1.2}' eq JSON::XS->new->canonical (1)->encode (from_json '{ "1" : 2, "3" : 1.2 }'));

ok ('[true]' eq to_json [JSON::XS::true]);
ok ('[false]' eq to_json [JSON::XS::false]);
ok ('[true]' eq to_json [\1]);
ok ('[false]' eq to_json [\0]);
ok ('[null]' eq to_json [undef]);

for $v (1, 2, 3, 5, -1, -2, -3, -4, 100, 1000, 10000, -999, -88, -7, 7, 88, 999, -1e5, 1e6, 1e7, 1e8) {
   ok ($v == ((from_json "[$v]")->[0]));
   ok ($v == ((from_json to_json [$v])->[0]));
}

ok (30123 == ((from_json to_json [30123])->[0]));
ok (32123 == ((from_json to_json [32123])->[0]));
ok (32456 == ((from_json to_json [32456])->[0]));
ok (32789 == ((from_json to_json [32789])->[0]));
ok (32767 == ((from_json to_json [32767])->[0]));
ok (32768 == ((from_json to_json [32768])->[0]));

