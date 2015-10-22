#!perl
use strict;
use warnings;
use Test::More $] < 5.008 ? (skip_all => "5.6") : (tests => 5);
use Cpanel::JSON::XS;
use Time::Piece;

my $time = localtime;
my $json = Cpanel::JSON::XS->new;
if ($json->can("stringify_blessed")) {
  $json->stringify_blessed(1);
  diag 'stringify_blessed is enabled';
} else {
  diag 'stringify_blessed is simulated with convert_blessed';
  $json->convert_blessed(1);
  eval 'sub Foo::TO_JSON { "Foo <". shift->[0] . ">" }';
  eval 'sub main::TO_JSON { "main=REF(". $$_[0] . ")" }';
  eval 'sub Time::Piece::TO_JSON { "$time" }';
}

package Foo;
use overload '""' => sub { "Foo <". shift->[0] . ">"};

package main;

my $object = bless ["foo"], 'Foo';
my $enc = $json->encode( { obj => $object } );

TODO: {
  local $TODO = 'Not yet ready';   
  is( $enc, '{"obj":"Foo <foo>"}', "mg object stringified" )
    or diag($enc);
}

$enc = $json->encode( { time => $time } );
isa_ok($time, "Time::Piece");

TODO: {
  local $TODO = 'Not yet ready';   
  # my $dec = $json->decode($enc);
  is( $enc, qq({"time":"$time"}), 'mg Time::Piece object was stringified' );
}

$object = bless [], 'main';
$enc = $json->encode( \$object );
like( $enc, qr/main=ARRAY\(0x[A-Fa-f0-9]+\)/, "nomg blessed array stringified" )
  or diag($enc);

$enc = $json->encode( \\$object );
like( $enc, qr/REF\(0x[A-Fa-f0-9]+\)/, "nomg ref stringified" )
  or diag($enc);
