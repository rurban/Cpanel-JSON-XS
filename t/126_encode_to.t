#
# encode_to: streaming encode directly to a filehandle (GH #250)
#
use strict;
use warnings;
use Test::More tests => 11;
use Encode ();
use File::Temp qw(tempfile);

use Cpanel::JSON::XS;

sub slurp_raw {
    my ($file) = @_;
    open my $fh, "<:raw", $file or die "open $file: $!";
    local $/;
    return scalar <$fh>;
}

# basic round trip: encode_to produces the same bytes as encode()
{
    my $json = Cpanel::JSON::XS->new->canonical;
    my $data = { a => 1, b => [1, 2, 3], c => "hi\"there" };

    my ($fh, $file) = tempfile(UNLINK => 1);
    my $n = $json->encode_to($fh, $data);
    close $fh;

    my $content  = slurp_raw($file);
    my $expected = $json->encode($data);

    is($content, $expected, "encode_to bytes match encode()");
    is($n, length($content), "encode_to return value is bytes written");
}

# pretty printing streams correctly too
{
    my $json = Cpanel::JSON::XS->new->canonical->pretty;
    my $data = { x => [1, 2, { y => "z" }] };

    my ($fh, $file) = tempfile(UNLINK => 1);
    $json->encode_to($fh, $data);
    close $fh;

    is(slurp_raw($file), $json->encode($data), "pretty encode_to matches encode()");
}

# large payload spanning many internal 8k flush cycles must still be exact
{
    my $json = Cpanel::JSON::XS->new->canonical;
    my @big  = map { { id => $_, name => "item_$_" x 5, uni => "\x{263A}\x{20ac}" } } 1 .. 5000;

    my ($fh, $file) = tempfile(UNLINK => 1);
    my $n = $json->encode_to($fh, \@big);
    close $fh;

    my $content  = slurp_raw($file);
    my $expected = Encode::encode_utf8($json->encode(\@big));

    ok(length($content) > 8192 * 4, "payload is large enough to force multiple flushes");
    is($content, $expected, "large streamed payload matches encode() byte-for-byte");
    is($n, length($content), "return value counts all flushed bytes");
}

# explicit ->utf8 flag: encode_to writes the same octets as encode()
{
    my $json = Cpanel::JSON::XS->new->utf8;
    my $data = { snowman => "\x{2603}" };

    my ($fh, $file) = tempfile(UNLINK => 1);
    $json->encode_to($fh, $data);
    close $fh;

    is(slurp_raw($file), $json->encode($data), "utf8-flagged encode_to matches encode()");
}

# allow_nonref is enforced identically to encode()
{
    my $json = Cpanel::JSON::XS->new->allow_nonref(0);
    my ($fh, $file) = tempfile(UNLINK => 1);

    eval { $json->encode_to($fh, "bare scalar") };
    like($@, qr/hash- or arrayref expected/, "encode_to enforces allow_nonref like encode()");
    close $fh;
}

# writing to a dead filehandle is a hard error, not silent truncation
{
    my $json = Cpanel::JSON::XS->new;
    my ($fh, $file) = tempfile(UNLINK => 1);
    close $fh;

    eval { $json->encode_to($fh, { a => 1 }) };
    like($@, qr/error writing to filehandle/, "encode_to croaks on write failure");
}

# empty array streams correctly and the byte count is exact
{
    my $json = Cpanel::JSON::XS->new;
    my ($fh, $file) = tempfile(UNLINK => 1);
    my $n = $json->encode_to($fh, []);
    close $fh;
    is($n, 2, "encode_to([]) writes the 2 bytes '[]'");
    is(slurp_raw($file), "[]", "empty array streams correctly");
}
