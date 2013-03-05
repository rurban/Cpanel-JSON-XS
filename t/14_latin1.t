use JSON::XS;
use Test::More $] < 5.008 ? (skip_all => "5.6") : (tests => 4);

my $xs = JSON::XS->new->latin1->allow_nonref;

ok $xs->encode ("\x{12}\x{89}       ") eq "\"\\u0012\x{89}       \"";
ok $xs->encode ("\x{12}\x{89}\x{abc}") eq "\"\\u0012\x{89}\\u0abc\"";

ok $xs->decode ("\"\\u0012\x{89}\""       ) eq "\x{12}\x{89}";
ok $xs->decode ("\"\\u0012\x{89}\\u0abc\"") eq "\x{12}\x{89}\x{abc}";
