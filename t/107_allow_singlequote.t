
use Test::More tests => 4;
use strict;
use Cpanel::JSON::XS;
#########################

my $json = Cpanel::JSON::XS->new->allow_nonref;

eval q| $json->decode("{'foo':'bar'}") |;

ok($@); # in XS and PP, the error message differs.

$json->allow_singlequote;

is($json->decode(q|{'foo':"bar"}|)->{foo}, 'bar');
is($json->decode(q|{'foo':'bar'}|)->{foo}, 'bar');
is($json->allow_barekey->decode(q|{foo:'bar'}|)->{foo}, 'bar');

