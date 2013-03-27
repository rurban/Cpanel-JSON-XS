use Test::More $] < 5.008 ? (skip_all => "5.6") : (tests => 24576);
use Cpanel::JSON::XS;

sub test($) {
   my $js;

   $js = Cpanel::JSON::XS->new->allow_nonref(0)->utf8->ascii->shrink->encode ([$_[0]]);
   is ($_[0], ((decode_json $js)->[0]), "allow_nonref(0)->utf8->ascii->shrink->encode");
   $js = Cpanel::JSON::XS->new->allow_nonref(0)->utf8->ascii->encode ([$_[0]]);
   is ($_[0], (Cpanel::JSON::XS->new->utf8->shrink->decode($js))->[0], "utf8->shrink->decode");

   $js = Cpanel::JSON::XS->new->allow_nonref(0)->utf8->shrink->encode ([$_[0]]);
   is ($_[0], ((decode_json $js)->[0]), "allow_nonref(0)->utf8->shrink->encode");
   $js = Cpanel::JSON::XS->new->allow_nonref(1)->utf8->encode ([$_[0]]);
   is ($_[0], (Cpanel::JSON::XS->new->utf8->shrink->decode($js))->[0], "allow_nonref(1)->utf8->encode");

   $js = Cpanel::JSON::XS->new->allow_nonref(1)->ascii->encode ([$_[0]]);
   is ($_[0], Cpanel::JSON::XS->new->decode ($js)->[0], "allow_nonref(1)->ascii->encode");
   $js = Cpanel::JSON::XS->new->allow_nonref(0)->ascii->encode ([$_[0]]);
   is ($_[0], Cpanel::JSON::XS->new->shrink->decode ($js)->[0], "allow_nonref(0)->ascii->encode");

   $js = Cpanel::JSON::XS->new->allow_nonref(1)->shrink->encode ([$_[0]]);
   is ($_[0], Cpanel::JSON::XS->new->decode ($js)->[0], "decode");
   $js = Cpanel::JSON::XS->new->allow_nonref(0)->encode ([$_[0]]);
   is ($_[0], Cpanel::JSON::XS->new->shrink->decode ($js)->[0], "shrink->decode");
}

srand 0; # doesn't help too much, but its at least more deterministic

for (1..768) {
   test join "", map chr ($_ & 255), 0..$_;
   test join "", map chr rand 255, 0..$_;
   test join "", map chr ($_ * 97 & ~0x4000), 0..$_;
   test join "", map chr (rand (2**20) & ~0x800), 0..$_;
}
