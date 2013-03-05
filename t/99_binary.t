use Test::More $] < 5.008 ? (skip_all => "5.6") : (tests => 24576);
use JSON::XS;

sub test($) {
   my $js;

   $js = JSON::XS->new->allow_nonref(0)->utf8->ascii->shrink->encode ([$_[0]]);
   ok ($_[0] eq ((decode_json $js)->[0]), 0);
   $js = JSON::XS->new->allow_nonref(0)->utf8->ascii->encode ([$_[0]]);
   ok ($_[0] eq (JSON::XS->new->utf8->shrink->decode($js))->[0], 1);

   $js = JSON::XS->new->allow_nonref(0)->utf8->shrink->encode ([$_[0]]);
   ok ($_[0] eq ((decode_json $js)->[0]), 2);
   $js = JSON::XS->new->allow_nonref(1)->utf8->encode ([$_[0]]);
   ok ($_[0] eq (JSON::XS->new->utf8->shrink->decode($js))->[0], 3);

   $js = JSON::XS->new->allow_nonref(1)->ascii->encode ([$_[0]]);
   ok ($_[0] eq JSON::XS->new->decode ($js)->[0], 4);
   $js = JSON::XS->new->allow_nonref(0)->ascii->encode ([$_[0]]);
   ok ($_[0] eq JSON::XS->new->shrink->decode ($js)->[0], 5);

   $js = JSON::XS->new->allow_nonref(1)->shrink->encode ([$_[0]]);
   ok ($_[0] eq JSON::XS->new->decode ($js)->[0], 6);
   $js = JSON::XS->new->allow_nonref(0)->encode ([$_[0]]);
   ok ($_[0] eq JSON::XS->new->shrink->decode ($js)->[0], 7);
}

srand 0; # doesn't help too much, but its at least more deterministic

for (1..768) {
   test join "", map chr ($_ & 255), 0..$_;
   test join "", map chr rand 255, 0..$_;
   test join "", map chr ($_ * 97 & ~0x4000), 0..$_;
   test join "", map chr (rand (2**20) & ~0x800), 0..$_;
}
