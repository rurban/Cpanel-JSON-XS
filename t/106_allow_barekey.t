
use Test::More tests => 9;
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

# GH #244: truncated bare-key input must not cause a one-byte OOB heap read.
# The fast-scan loop previously ran p past dec->end before checking for ':'.
{
  my $coder = Cpanel::JSON::XS->new->allow_barekey(1);
  my $err;

  # bare key with no ':' or value — truncated at key end
  eval { $coder->decode('{a') };
  $err = $@;
  ok($err, 'truncated bare key {a errors');
  like($err, qr/expected|truncated|':'/i, 'truncated bare key: sensible error');

  # bare key followed by truncated value
  eval { $coder->decode('{ab:') };
  $err = $@;
  ok($err, 'truncated bare key {ab: errors');
}

