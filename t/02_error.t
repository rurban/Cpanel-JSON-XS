#BEGIN { $| = 1; print "1..31\n"; }
use Test::More tests => 32;

use utf8;
use Cpanel::JSON::XS;
no warnings;

#our $test;
#sub ok($) {
#   print $_[0] ? "" : "not ", "ok ", ++$test, "\n";
#}

eval { Cpanel::JSON::XS->new->encode ([\-1]) }; ok $@ =~ /cannot encode reference/;
eval { Cpanel::JSON::XS->new->encode ([\undef]) }; ok $@ =~ /cannot encode reference/;
eval { Cpanel::JSON::XS->new->encode ([\2]) }; ok $@ =~ /cannot encode reference/;
eval { Cpanel::JSON::XS->new->encode ([\{}]) }; ok $@ =~ /cannot encode reference/;
eval { Cpanel::JSON::XS->new->encode ([\[]]) }; ok $@ =~ /cannot encode reference/;
eval { Cpanel::JSON::XS->new->encode ([\\1]) }; ok $@ =~ /cannot encode reference/;

eval { $x = Cpanel::JSON::XS->new->ascii->decode ('croak') }; ok $@ =~ /malformed JSON/, $@;

SKIP: {
skip "5.6", 25 if $] < 5.008;

eval { Cpanel::JSON::XS->new->allow_nonref (1)->decode ('"\u1234\udc00"') }; ok $@ =~ /missing high /;
eval { Cpanel::JSON::XS->new->allow_nonref->decode ('"\ud800"') }; ok $@ =~ /missing low /;
eval { Cpanel::JSON::XS->new->allow_nonref (1)->decode ('"\ud800\u1234"') }; ok $@ =~ /surrogate pair /;

eval { Cpanel::JSON::XS->new->decode ('null') }; ok $@ =~ /allow_nonref/;
eval { Cpanel::JSON::XS->new->allow_nonref (1)->decode ('+0') }; ok $@ =~ /malformed/;
eval { Cpanel::JSON::XS->new->allow_nonref->decode ('.2') }; ok $@ =~ /malformed/;
eval { Cpanel::JSON::XS->new->allow_nonref (1)->decode ('bare') }; ok $@ =~ /malformed/;
eval { Cpanel::JSON::XS->new->allow_nonref->decode ('naughty') }; ok $@ =~ /null/;
eval { Cpanel::JSON::XS->new->allow_nonref (1)->decode ('01') }; ok $@ =~ /leading zero/;
eval { Cpanel::JSON::XS->new->allow_nonref->decode ('00') }; ok $@ =~ /leading zero/;
eval { Cpanel::JSON::XS->new->allow_nonref (1)->decode ('-0.') }; ok $@ =~ /decimal point/;
eval { Cpanel::JSON::XS->new->allow_nonref->decode ('-0e') }; ok $@ =~ /exp sign/;
eval { Cpanel::JSON::XS->new->allow_nonref (1)->decode ('-e+1') }; ok $@ =~ /initial minus/;
eval { Cpanel::JSON::XS->new->allow_nonref->decode ("\"\n\"") }; ok $@ =~ /invalid character/;
eval { Cpanel::JSON::XS->new->allow_nonref (1)->decode ("\"\x01\"") }; ok $@ =~ /invalid character/;
eval { Cpanel::JSON::XS->new->decode ('[5') }; ok $@ =~ /parsing array/;
eval { Cpanel::JSON::XS->new->decode ('{"5"') }; ok $@ =~ /':' expected/;
eval { Cpanel::JSON::XS->new->decode ('{"5":null') }; ok $@ =~ /parsing object/;

eval { Cpanel::JSON::XS->new->decode (undef) }; ok $@ =~ /malformed/;
eval { Cpanel::JSON::XS->new->decode (\5) }; ok !!$@; # Can't coerce readonly
eval { Cpanel::JSON::XS->new->decode ([]) }; ok $@ =~ /malformed/;
eval { Cpanel::JSON::XS->new->decode (\*STDERR) }; ok $@ =~ /malformed/;
eval { Cpanel::JSON::XS->new->decode (*STDERR) }; ok !!$@; # cannot coerce GLOB

eval { decode_json ("\"\xa0") }; ok $@ =~ /malformed.*character/;
eval { decode_json ("\"\xa0\"") }; ok $@ =~ /malformed.*character/;

}
