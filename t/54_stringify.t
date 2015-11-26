#!perl
use strict;
use warnings;
use Test::More;
BEGIN {
  eval "require Time::Piece;";
  if ($@) {
    plan skip_all => "Time::Piece required";
    exit 0;
  }
}
use Time::Piece;
plan $] < 5.008 ? (skip_all => "5.6 no AMG yet") : (tests => 5);
use Cpanel::JSON::XS;

my $time = localtime;
my $json = Cpanel::JSON::XS->new->convert_blessed;

if ($Cpanel::JSON::XS::VERSION lt '3.0202') {
  diag 'simulate convert_blessed via TO_JSON';
  eval 'sub Foo::TO_JSON { "Foo <". shift->[0] . ">" }';
  eval 'sub main::TO_JSON { "main=REF(". $$_[0] . ")" }';
  eval 'sub Time::Piece::TO_JSON { "$time" }';
}

package Foo;
use overload '""' => sub { "Foo <". shift->[0] . ">"};

package main;

my $object = bless ["foo"], 'Foo';
my $enc = $json->encode( { obj => $object } );

is( $enc, '{"obj":"Foo <foo>"}', "mg object stringified" )
  or diag($enc);

$enc = $json->encode( { time => $time } );
isa_ok($time, "Time::Piece");

# my $dec = $json->decode($enc);
is( $enc, qq({"time":"$time"}), 'mg Time::Piece object was stringified' );

$object = bless [], 'main';
$json->allow_blessed;
$enc = $json->encode( \$object );
# fails in 5.6
like( $enc, qr/main=ARRAY\(0x[A-Fa-f0-9]+\)/, "nomg blessed array stringified" )
  or diag($enc);

$enc = $json->encode( \\$object );
like( $enc, qr/REF\(0x[A-Fa-f0-9]+\)/, "nomg ref stringified" )
  or diag($enc);
