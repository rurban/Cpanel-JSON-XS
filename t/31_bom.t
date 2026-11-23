# Detect BOM and possibly convert to UTF-8 and set UTF8 flag.
#
# https://tools.ietf.org/html/rfc7159#section-8.1
# JSON text SHALL be encoded in UTF-8, UTF-16, or UTF-32.
use Test::More ($] >= 5.008) ? (tests => 9 + 6 + 1) : (skip_all => "needs 5.8");;
use Config;
use Cpanel::JSON::XS;
use Encode; # Currently required for <5.20
use charnames qw(:short);
use utf8;

my $json = Cpanel::JSON::XS->new->utf8;

# parser need to succeed, result should be valid
sub y_pass {
  my ($str, $name) = @_;
  my $result = $json->decode($str);
  my $expected = ["é"];
  is_deeply($result, $expected, "bom $name");
}

my @bom =
  (
   ["\xef\xbb\xbf[\"\303\251\"]",                       'UTF-8'],
   ["\xfe\xff\000\133\000\042\000\351\000\042\000\135", 'UTF16-LE'],
   ["\xff\xfe\133\000\042\000\351\000\042\000\135\000", 'UTF16-BE'],
   ["\xff\xfe\000\000\133\000\000\000\042\000\000\000\351\000\000\000\042\000\000\000\135\000\000\000",   'UTF32-LE'],
   ["\000\000\xfe\xff\000\000\000\133\000\000\000\042\000\000\000\351\000\000\000\042\000\000\000\135",   'UTF32-BE'],
  );

for my $bom (@bom) {
  y_pass(@$bom);
}

# [GH #125] BOM in the middle corrupts state, sets utf8 flag
my $j = Cpanel::JSON::XS->new;

ok(my $as_json = eval {
    $j->encode({ example => "data with non-ASCII characters",
                 unicode => "\N{greek:Sigma}" })
}, 'can encode a basic structure');
ok(eval { $j->decode($as_json) }, 'can decode again');
ok(eval { $j->decode("\x{feff}" . $as_json) }, 'can decode with BOM');
ok(eval { $j->decode($as_json) }, 'can decode original');

# Tests by Paul Johnson:

# Assert the caller's input SV is preserved bit-for-bit across a decode
# call whose filter callback throws, for each of the three croak-reachable
# callback sites (filter_json_object, filter_json_single_key_object, and
# allow_tags + THAW), with a leading UTF-8 BOM on the input.

my $bom = "\xef\xbb\xbf";

sub assert_preserved {
  my ($name, $payload, $setup) = @_;
  my $original = $bom . $payload;
  my $s        = $bom . $payload;
  my $j        = Cpanel::JSON::XS->new;
  $setup->($j);
  eval { $j->decode ($s) };
  ok ($@, "$name: callback threw");
  # The BOM-decode path legitimately sets SvUTF8 on the caller's SV.
  # We care about the underlying byte sequence (no SvPVX shift), not
  # the flag, so clear SvUTF8 on a copy and compare raw bytes.
  my $copy = $s;
  Encode::_utf8_off ($copy);
  is ($copy, $original, "$name: SV bytes preserved across throw");
}

assert_preserved (
  "filter_json_object",
  '{}',
  sub { $_[0]->filter_json_object (sub { die "boom\n" }) },
);

assert_preserved (
  "filter_json_single_key_object",
  '{"k":1}',
  sub { $_[0]->filter_json_single_key_object (k => sub { die "boom\n" }) },
);

{
  package BomFilterCorruption::Thaw;
  sub THAW { die "boom\n" }
}
assert_preserved (
  "allow_tags THAW",
  '("BomFilterCorruption::Thaw")[]',
  sub { $_[0]->allow_tags (1) },
);

# a BOM decode leaks nothing
SKIP: {
  skip "RSS is not meaningful under a sanitizer", 1 if $Config{ccflags} =~ /-fsanitize/;
  skip "RSS is read from /proc/self/status on Linux only", 1 unless $^O eq 'linux';
  open my $f, '<', '/proc/self/status' or skip "no /proc/self/status", 1;
  my $rss = sub { seek $f, 0, 0; while (<$f>) { return $1 if /^VmRSS:\s+(\d+)/ } };
  defined $rss->() or skip "no VmRSS in /proc/self/status", 1;
  my $dec = Cpanel::JSON::XS->new;
  my $bom = "\xfe\xff\0[\0001\0]";
  for (1 .. 20_000) { $dec->decode($bom) }
  my $r0 = $rss->();
  for (1 .. 200_000) { $dec->decode($bom) }
  cmp_ok( $rss->() - $r0, '<', 4000, 'UTF-16 BOM decode: no leak' );
}
