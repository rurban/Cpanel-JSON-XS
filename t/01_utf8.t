BEGIN { $| = 1; print "1..21\n"; }

use Convert::Scalar ':utf8';

no bytes;

$y = "\xff\x90\x44";

utf8_encode $y;

print length($y)==5 ? "" : "not ", "ok 1\n";
print utf8_length($y)==3 ? "" : "not ", "ok 2\n";

utf8_upgrade $y;
print utf8_length($y)==5 ? "" : "not ", "ok 3\n";
print length($y)==5 ? "" : "not ", "ok 4\n";

print utf8_downgrade($y) ? "" : "not ", "ok 5\n";
print utf8_length($y)==3 ? "" : "not ", "ok 6\n";
print length($y)==5 ? "" : "not ", "ok 7\n";

$y = "\x{257}";
print !utf8_downgrade($y, 1) ? "" : "not ", "ok 8\n";
print !eval {
   utf8_downgrade($y, 0);
   1;
} ? "" : "not ", "ok 9\n";

$b = "1234\xc0";
{
   use utf8;
   $u = "\x{1234}";
}

print utf8($b) ? "not " : "", "ok 10\n";
print utf8($u) ? "" : "not ", "ok 11\n";
print utf8($b) ? "not " : "", "ok 12\n";
print utf8($u) ? "" : "not ", "ok 13\n";
utf8 $b,1;
utf8_off $u;
print utf8($b) ? "" : "not ", "ok 14\n";
print utf8($u) ? "not " : "", "ok 15\n";

if ($] < 5.007) {
   print "ok 16\n";
   print "ok 17\n";
} else {
   print utf8_valid $b ? "not " : "", "ok 16\n";
   print utf8_valid $u ? "" : "not ", "ok 17\n";
}

print utf8_on($u) eq $u ? "" : "not ", "ok 18\n";
print utf8($u) ? "" : "not ", "ok 19\n";
print utf8_off($u) eq $u ? "" : "not ", "ok 20\n";
print utf8($u) ? "not " : "", "ok 21\n";

