#!perl -w
use strict;
use Cpanel::JSON::XS;

  my $js = Cpanel::JSON::XS->new->convert_blessed->allow_tags->allow_nonref;
  $js->decode('"\ud801\udc02' . "\x{10204}\"");
  $js->decode('"\"\n\\\\\r\t\f\b"');
  $js->ascii->utf8->encode(chr 0x8000);

  sub Temp::TO_JSON { 7 }
  $js->encode ( bless { k => 1 }, Temp:: );

  sub Temp1::FREEZE { (3,1,2) }
  $js->encode ( bless { k => 1 }, Temp1:: );

