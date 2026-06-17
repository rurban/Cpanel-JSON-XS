# copied over from JSON::PC and modified to use Cpanel::JSON::XS
# extended with RFC 8785 surrogate ordering tests (GH #248)

use Test::More;
use strict;
BEGIN { plan tests => 6 };
use Cpanel::JSON::XS;
use utf8;
#########################

my ($js,$obj);
my $pc = Cpanel::JSON::XS->new->canonical(1)->ascii;

$obj = {a=>1, b=>2, c=>3, d=>4, e=>5, f=>6, g=>7, h=>8, i=>9};

$js = $pc->encode($obj);
is($js, q|{"a":1,"b":2,"c":3,"d":4,"e":5,"f":6,"g":7,"h":8,"i":9}|,
   'ASCII keys sorted ascending');

# RFC 8785: non-BMP char sorts before BMP char with codepoint >= 0xD800
# U+1F600 -> UTF-16: D83D DE00 (high surrogate 0xD83D)
# U+FB33  -> UTF-16: FB33
# 0xD83D < 0xFB33, so emoji sorts before dalet
is($pc->encode({ "\x{1F600}" => 1, "\x{FB33}" => 2 }),
   q|{"\ud83d\ude00":1,"\ufb33":2}|,
   'RFC 8785: non-BMP (emoji) before BMP dalet');

# BMP char below surrogate range sorts before non-BMP
# U+D7FF (last valid char before surrogates) < D83D (non-BMP high surrogate)
is($pc->encode({ "\x{1F600}" => 1, "\x{D7FF}" => 2 }),
   q|{"\ud7ff":2,"\ud83d\ude00":1}|,
   'RFC 8785: BMP below 0xD800 sorts before non-BMP');

# BMP char above surrogate range sorts after non-BMP
# D83D (non-BMP high surrogate) < E000 (first valid char after surrogates)
is($pc->encode({ "\x{1F600}" => 1, "\x{E000}" => 2 }),
   q|{"\ud83d\ude00":1,"\ue000":2}|,
   'RFC 8785: non-BMP sorts before BMP >= 0xE000');

# Two non-BMP chars: sorted by their surrogate pairs
# U+1F600 -> D83D DE00, U+1F601 -> D83D DE01, U+1F602 -> D83D DE02
is($pc->encode({ "\x{1F602}" => 3, "\x{1F600}" => 1, "\x{1F601}" => 2 }),
   q|{"\ud83d\ude00":1,"\ud83d\ude01":2,"\ud83d\ude02":3}|,
   'RFC 8785: two non-BMP chars sorted by surrogate pair');

# Mixed ASCII below 0x80 and non-BMP
# ASCII (0x61=97=a, 0x7A=122=z) < D83D (non-BMP high surrogate)
is($pc->encode({ "\x{1F600}" => 1, "z" => 2, "a" => 3 }),
   q|{"a":3,"z":2,"\ud83d\ude00":1}|,
   'RFC 8785: ASCII sorts before non-BMP');

