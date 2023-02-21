
use Test::More tests => 6;
use strict;
use utf8;
use Cpanel::JSON::XS;
#########################

my $json = Cpanel::JSON::XS->new;

eval q| $json->decode('{foo:"bar"}') |;
ok($@); # in XS and PP, the error message differs.

$json->allow_barekey;
is($json->decode('{foo:"bar"}')->{foo}, 'bar');
is($json->decode('{ foo : "bar"}')->{foo}, 'bar', 'with space');
is($json->decode(qq({\tfoo\t:"bar"}))->{foo}, 'bar', 'with tab');

SKIP: {
  skip "5.6 has no is_utf8", 2 if $] < 5.008;
  my $r = $json->decode(qq({"füü": 1}));
  my @k = keys %$r;
  is(utf8::is_utf8($k[0]), 1, 'keep utf8 as string key');
  $r = $json->decode(qq({füü: 1}));
  @k = keys %$r;
  is(utf8::is_utf8($k[0]), 1, 'keep utf8 as bare key');
}

