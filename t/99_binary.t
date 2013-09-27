use Test::More tests => 30720;
use Cpanel::JSON::XS;

sub test($) {
   my $js;

   $js = Cpanel::JSON::XS->new->utf8->ascii->shrink->encode ([$_[0]]);
   is ($_[0], ((decode_json $js)->[0]), "allow_nonref(0)->utf8->ascii->shrink->encode");
   $js = Cpanel::JSON::XS->new->utf8->ascii->encode ([$_[0]]);
   is ($_[0], (Cpanel::JSON::XS->new->utf8->shrink->decode($js))->[0], "allow_nonref(0)->utf8->shrink->decode");

   $js = Cpanel::JSON::XS->new->utf8->shrink->encode ([$_[0]]);
   is ($_[0], ((decode_json $js)->[0]), "allow_nonref(0)->utf8->shrink->encode");
   $js = Cpanel::JSON::XS->new->allow_nonref->utf8->encode ([$_[0]]);
   is ($_[0], (Cpanel::JSON::XS->new->utf8->shrink->decode($js))->[0], "allow_nonref(1)->utf8->encode");

   $js = Cpanel::JSON::XS->new->allow_nonref->ascii->encode ([$_[0]]);
   is ($_[0], Cpanel::JSON::XS->new->decode ($js)->[0], "allow_nonref(1)->ascii->encode");
   $js = Cpanel::JSON::XS->new->ascii->encode ([$_[0]]);
   is ($_[0], (Cpanel::JSON::XS->new->shrink->decode ($js))->[0], "allow_nonref(0)->ascii->encode");

 SKIP: {
     skip "skipped shrink 5.6", 1 if $] < 5.008;
     $js = Cpanel::JSON::XS->new->allow_nonref->shrink->encode ([$_[0]]);
     is ($_[0], Cpanel::JSON::XS->new->decode ($js)->[0], "allow_nonref(1)->shrink->encode");
   }
   $js = Cpanel::JSON::XS->new->encode ([$_[0]]);
   is ($_[0], Cpanel::JSON::XS->new->shrink->decode ($js)->[0], "allow_nonref(0)->encode");
}

sub test_bin($) {
  my $js = Cpanel::JSON::XS->new->binary->allow_nonref->encode($_[0]);
  my $dec = Cpanel::JSON::XS->new->binary->allow_nonref->decode($js);
  is ($js, Cpanel::JSON::XS->new->binary->allow_nonref->encode($dec), "binary->allow_nonref(1)->encode");

  $js = Cpanel::JSON::XS->new->binary->encode([$_[0]]);
  $dec = Cpanel::JSON::XS->new->binary->decode($js)->[0];
  is ($js, Cpanel::JSON::XS->new->binary->encode([$dec]), "binary->allow_nonref(0)->encode");
}

srand 0; # doesn't help too much, but its at least more deterministic

for (1..768) {
   test join "", map chr ($_ & 255), 0..$_;
   test_bin join "", map chr ($_ & 255), 0..$_;

   SKIP: {
     skip "skipped uf8 w/o binary: 5.6", 24 if $] < 5.008;
     test join "", map chr rand 255, 0..$_;
     test join "", map chr ($_ * 97 & ~0x4000), 0..$_;
     test join "", map chr (rand (2**20) & ~0x800), 0..$_;
   }

   test_bin join "", map chr rand 255, 0..$_;

   SKIP: {
     skip "skipped uf8 w binary: 5.6", 4 if $] < 5.008;
     test_bin join "", map chr ($_ * 97 & ~0x4000), 0..$_;
     test_bin join "", map chr (rand (2**20) & ~0x800), 0..$_;
   }
}
