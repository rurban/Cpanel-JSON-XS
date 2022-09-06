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

my $decoder = $JSON_NS->new()->allow_nonref->utf8( Cpanel::JSON::XS::UTF8_BYTES );

my $encoder = $JSON_NS->new()->ascii()->allow_nonref;

for my $char ( @chars_to_test ) {
    my $json_str = $encoder->encode($char);

    my $decoded = $decoder->decode( $json_str );

    my $utf8_char = $char;
    utf8::encode($utf8_char);

    is( $decoded, $utf8_char, "decode($json_str)" );

    # --------------------------------------------------
    my $utf8_ff = "\xff$utf8_char\xff";
    substr( $json_str, 1, 0, "\xff" );
    substr( $json_str, -1, 0, "\xff" );
    my $decoded_ff = $decoder->decode( $json_str );

    is($decoded_ff, $utf8_ff, "... and preserves 0xff octets");
}

done_testing;
