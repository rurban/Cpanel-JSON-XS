BEGIN { $| = 1; print "1..7\n"; }

use JSON::XS;

our $test;
sub ok($;$) {
   print $_[0] ? "" : "not ", "ok ", ++$test, "\n";
}

my $js = JSON::XS->new;

ok (ref $js->decode (("[" x 4096) . ("]" x 4096)));
ok (ref $js->decode (("{\"\":" x 4095) . "[]" . ("}" x 4095)));
ok (ref $js->max_depth (32)->decode (("[" x 32) . ("]" x 32)));

ok ($js->max_depth(1)->encode ([]));
ok (!eval { $js->encode ([[]]), 1 });

ok ($js->max_depth(2)->encode ([{}]));
ok (!eval { $js->encode ([[{}]]), 1 });

