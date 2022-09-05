use Test::More;
use utf8;
use Cpanel::JSON::XS;
use warnings;

my $JSON_NS = 'Cpanel::JSON::XS';

my @chars_to_test = (
    "\xe9",         # e acute
    "\x{100}",      # A with macron
    "\x{201c}",     # left double quote
    "\x{1f600}",    # smiley
);

my @chars_to_test_utf8 = map {
    my $v = $_;
    utf8::encode($v);
    $v;
} @chars_to_test;

my @chars_to_test_escaped_json = map {
    $JSON_NS->new()->ascii()->allow_nonref->encode($_)
} @chars_to_test;

my $decoder = $JSON_NS->new()->allow_nonref->utf8( Cpanel::JSON::XS::UTF8_BYTES );

for my $i ( 0 .. $#chars_to_test ) {
    my $json_str = $chars_to_test_escaped_json[$i];

    my $decoded = $decoder->decode( $json_str );

    is( $decoded, $chars_to_test_utf8[$i], "decode($json_str)" );
}

done_testing;
