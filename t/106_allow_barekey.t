
use Test::More tests => 2;
use strict;
use Cpanel::JSON::XS;
#########################

my $json = Cpanel::JSON::XS->new->allow_nonref;

eval q| $json->decode('{foo:"bar"}') |;

ok($@); # in XS and PP, the error message differs.

$json->allow_barekey;

is($json->decode('{foo:"bar"}')->{foo}, 'bar');


