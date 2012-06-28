use Test::More tests => 9;
use utf8;
use Cpanel::JSON::XS;

ok (Cpanel::JSON::XS->new->allow_nonref (1)->utf8 (1)->encode ("ü") eq "\"\xc3\xbc\"");
ok (Cpanel::JSON::XS->new->allow_nonref (1)->encode ("ü") eq "\"ü\"");

SKIP: {
skip "5.6", 7 if $] < 5.008;

ok (Cpanel::JSON::XS->new->allow_nonref (1)->ascii (1)->utf8 (1)->encode (chr 0x8000) eq '"\u8000"');
ok (Cpanel::JSON::XS->new->allow_nonref (1)->ascii (1)->utf8 (1)->pretty (1)->encode (chr 0x10402) eq "\"\\ud801\\udc02\"\n");

eval { Cpanel::JSON::XS->new->allow_nonref (1)->utf8 (1)->decode ('"ü"') };
ok $@ =~ /malformed UTF-8/;

ok (Cpanel::JSON::XS->new->allow_nonref (1)->decode ('"ü"') eq "ü");
ok (Cpanel::JSON::XS->new->allow_nonref (1)->decode ('"\u00fc"') eq "ü");
ok (Cpanel::JSON::XS->new->allow_nonref (1)->decode ('"\ud801\udc02' . "\x{10204}\"") eq "\x{10402}\x{10204}");
ok (Cpanel::JSON::XS->new->allow_nonref (1)->decode ('"\"\n\\\\\r\t\f\b"') eq "\"\012\\\015\011\014\010");
}
