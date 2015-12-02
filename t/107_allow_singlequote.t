
use Test::More tests => 5;
use strict;
use Cpanel::JSON::XS;
#########################

my $json = Cpanel::JSON::XS->new;

eval q| $json->decode("{'foo':'bar'}") |;
ok($@, "error $@"); # in XS and PP, the error message differs.
# '"' expected, at character offset 1 (before "'foo':'bar'}")

$json->allow_singlequote;

is($json->decode(q|{'foo':"bar"}|)->{foo}, 'bar');
is($json->decode(q|{'foo':'bar'}|)->{foo}, 'bar');
is($json->allow_barekey->decode(q|{foo:'bar'}|)->{foo}, 'bar');

is($json->decode(q|{'foo baz':'bar'}|)->{"foo baz"}, 'bar');
