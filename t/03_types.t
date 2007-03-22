BEGIN { $| = 1; print "1..14\n"; }

use utf8;
use JSON::XS;

our $test;
sub ok($) {
   print $_[0] ? "" : "not ", "ok ", ++$test, "\n";
}

use PApp::Util;
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
