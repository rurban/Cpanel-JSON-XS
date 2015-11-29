
use strict;
my $has_bignum;
BEGIN {
  eval q| require Math::BigInt |;
  $has_bignum = $@ ? 0 : 1;
}
use Test::More $has_bignum ? (tests => 6) : (skip_all => "Can't load Math::BigInt");
use Cpanel::JSON::XS;

my $v = Math::BigInt->VERSION;
$v =~ s/_.+$// if $v;

my $fix =  !$v ? '+'
  : $v < 1.6 ? '+'
  : '';

my $json = new Cpanel::JSON::XS;

$json->allow_nonref->allow_bignum;
$json->convert_blessed->allow_blessed;

my $num  = $json->decode(q|100000000000000000000000000000000000000|);

isa_ok($num, 'Math::BigInt');
is("$num", $fix . '100000000000000000000000000000000000000');

TODO: {
  local $TODO = 'allow_bignum';
  is($json->encode($num), $fix . '100000000000000000000000000000000000000');
}
$num  = $json->decode(q|2.0000000000000000001|);
isa_ok($num, 'Math::BigFloat');

TODO: {
  local $TODO = 'allow_bignum';
  is("$num", '2.0000000000000000001');
  is($json->encode($num), '2.0000000000000000001');
}
