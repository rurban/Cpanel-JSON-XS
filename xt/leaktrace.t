#!perl -w
# note that does not catch the leaking XS context cxt->sv_json #19
# even valgrind does not catch it

use strict;
use constant HAS_LEAKTRACE => eval{ require Test::LeakTrace };
use Test::More HAS_LEAKTRACE ? (tests => 4) : (skip_all => 'require Test::LeakTrace');
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

# leak on allow_nonref croak, GH 206
leaks_cmp_ok{
    eval { decode_json('"asdf"') };
    #print $@;
}  '<', 1;

# illegal unicode croak
leaks_cmp_ok{
    eval { decode_json("{\"\x{c2}\x{c2}\"}") };
    #print $@;
}  '<', 1;

# wrong type croak
leaks_cmp_ok{
    use Cpanel::JSON::XS::Type;
    my $js = Cpanel::JSON::XS->new->canonical->require_types;
    eval { $js->encode([0], JSON_TYPE_FLOAT) };
    #print $@;
}  '<', 1;
