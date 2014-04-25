#!perl -w
use strict;
use constant HAS_LEAKTRACE => eval{ require Test::LeakTrace };
use Test::More HAS_LEAKTRACE ? (tests => 1) : (skip_all => 'require Test::LeakTrace');
use Test::LeakTrace;

use Cpanel::JSON::XS;

leaks_cmp_ok{
    my $js = Cpanel::JSON::XS->new();
    $js->allow_nonref->decode('"\ud801\udc02' . "\x{10204}\"");
    $js->allow_nonref->decode('"\"\n\\\\\r\t\f\b"');
    $js->allow_nonref->ascii->utf8->encode(chr 0x8000);
} '<', 1;
