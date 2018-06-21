#!perl -w
# note that does not catch the leaking XS context cxt->sv_json #19
# even valgrind does not catch it

use strict;
use constant HAS_LEAKTRACE => eval{ require Test::LeakTrace };
use Test::More HAS_LEAKTRACE ? (tests => 1) : (skip_all => 'require Test::LeakTrace');
use Test::LeakTrace;

use Cpanel::JSON::XS;

leaks_cmp_ok{
  my $js = Cpanel::JSON::XS->new->convert_blessed->allow_tags->allow_nonref;
  $js->decode('"\ud801\udc02' . "\x{10204}\"");
  $js->decode('"\"\n\\\\\r\t\f\b"');
  $js->ascii->utf8->encode(chr 0x8000);

  sub Temp::TO_JSON { 7 }
  $js->encode ( bless { k => 1 }, Temp:: );

  sub Temp1::FREEZE { (3,1,2) }
  $js->encode ( bless { k => 1 }, Temp1:: );

} '<', 1;
