#
# decode on Perl 5.005, 5.6, 5.8 or later
#
use strict;
use Test::More tests => 6;

use Cpanel::JSON::XS;

BEGIN {
    use lib qw(t);
    use _unicode_handling;
}

no utf8;

my $json = Cpanel::JSON::XS->new->allow_nonref;

SKIP: {
  skip "5.6", 1 if $] < 5.008;
  is($json->decode(q|"ü"|),                   "ü"); # utf8
}
is($json->decode(q|"\u00fc"|),           "\xfc"); # latin1
is($json->decode(q|"\u00c3\u00bc"|), "\xc3\xbc"); # utf8

my $str = 'あ'; # Japanese 'a' in utf8

is($json->decode(q|"\u00e3\u0081\u0082"|), $str);

utf8::decode($str) if $] > 5.007; # usually UTF-8 flagged on, but no-op for 5.005.

is($json->decode(q|"\u3042"|), $str);


my $utf8 = $json->decode(q|"\ud808\udf45"|); # chr 12345

utf8::encode($utf8) if $] > 5.007; # UTf-8 flaged off

is($utf8, "\xf0\x92\x8d\x85");

