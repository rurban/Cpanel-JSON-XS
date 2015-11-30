#!/usr/bin/perl -w
use strict;
use Test::More;
BEGIN {
  eval 'require JSON;'
    or plan skip_all => 'JSON required for cross testing';
}
plan tests => 48;
use JSON ();
use Cpanel::JSON::XS ();

my $pp = JSON->new;
my $json = Cpanel::JSON::XS->new;

eval q| $json->encode( [ sub {} ] ) |;
ok( $@ =~ /encountered CODE/, $@ );

eval q|  $json->encode( [ \-1 ] ) |;
ok( $@ =~ /cannot encode reference to scalar/, $@ );

eval q|  $json->encode( [ \undef ] ) |;
ok( $@ =~ /cannot encode reference to scalar/, $@ );

eval q|  $json->encode( [ \{} ] ) |;
ok( $@ =~ /cannot encode reference to scalar/, $@ );

# 46
eval q| $json->encode( {false => \""} ) |;
ok( $@ =~ /cannot encode reference to scalar/, $@ );
eval q| $json->encode( {false => \!!""} ) |;
ok( $@ =~ /cannot encode reference to scalar/, $@ );
eval q| $pp->encode( {false => \""} ) |;
ok( $@ =~ /cannot encode reference to scalar/, $@ );
eval q| $pp->encode( {false => \!!""} ) |;
ok( $@ =~ /cannot encode reference to scalar/, $@ );

$json->allow_unknown;
$pp->allow_unknown;

is( $json->encode( [ sub {} ] ), '[null]' );
is( $json->encode( [ \-1 ] ),    '[null]' );
is( $json->encode( [ \undef ] ), '[null]' );
is( $json->encode( [ \{} ] ),    '[null]' );

# 46
is( $pp->encode( {null => \"some"} ),   '{"null":null}',   'pp unknown' );
is( $pp->encode( {null => \""} ),       '{"null":null}',   'pp unknown' );
# valid special yes/no values even without nonref
my $e = $pp->encode( {true => !!1} ); # pp is a bit inconsistent
ok( ($e eq '{"true":"1"}') || ($e eq '{"true":1}'),    'pp sv_yes' );
is( $pp->encode( {false => !!0} ),      '{"false":""}',    'pp sv_no' );
is( $pp->encode( {false => !!""} ),     '{"false":""}',    'pp sv_no' );
is( $pp->encode( {true => \!!1} ),      '{"true":true}',   'pp \sv_yes');
is( $pp->encode( {false => \!!0} ),     '{"false":null}',  'pp \sv_no' );
is( $pp->encode( {false => \!!""} ),    '{"false":null}',  'pp \sv_no' );

is( $json->encode( {null => \"some"} ), '{"null":null}',   'js unknown' );
is( $json->encode( {null => \""} ),     '{"null":null}',   'js unknown' );
is( $json->encode( {true => !!1} ),     '{"true":1}',      'js sv_yes' );
is( $json->encode( {false => !!0} ),    '{"false":""}',    'js sv_no' );
is( $json->encode( {false => !!""} ),   '{"false":""}',    'js sv_no' );
is( $json->encode( {true => \!!1} ),    '{"true":true}',   'js \sv_yes' );
is( $json->encode( {false => \!!0} ),   '{"false":null}',  'js \sv_no' );
is( $json->encode( {false => \!!""} ),  '{"false":null}',  'js \sv_no' );

SKIP: {

  skip "this test is for Perl 5.8 or later", 4 if $] < 5.008;

$pp->allow_unknown(0);
$json->allow_unknown(0);

my $fh;
open( $fh, '>hoge.txt' ) or die $!;
END { unlink('hoge.txt'); }

eval q| $pp->encode( [ $fh ] ) |; # upstream changed due to this JSON::XS bug
ok( $@ =~ /(encountered GLOB|cannot encode reference to scalar)/, "pp ".$@ );
eval q| $json->encode( [ $fh ] ) |;
ok( $@ =~ /encountered GLOB/, "js ".$@ );

$pp->allow_unknown(1);
$json->allow_unknown(1);

is( $pp->encode  ( [ $fh ] ),    '[null]' );
is( $json->encode( [ $fh ] ),    '[null]' );

close $fh;

} # skip 5.6

# 46
$json->allow_unknown->allow_blessed;
$pp->allow_unknown->allow_blessed;
is( $json->encode( {false => \"some"} ), '{"false":null}' );
is( $json->encode( {false => \""} ),     '{"false":null}' );
is( $pp->encode  ( {false => \!!""} ),   '{"false":null}' );
is( $json->encode( {false => \!!""} ),   '{"false":null}' );

$json->allow_unknown->allow_blessed->convert_blessed;
$pp->allow_unknown->allow_blessed->convert_blessed;
$e = $pp->encode(  {false => \"some"} ); # again pp is a bit inconsistent
ok( ($e eq '{"false":null}') || ($e eq '{"false":some}'), 'pp stringref' );
is( $pp->encode  ( {false => \""} ),     '{"false":null}' );
is( $pp->encode  ( {false => \!!""} ),   '{"false":null}' );
TODO: {
  local $TODO = 'invalid JSON #46' if $Cpanel::JSON::XS::VERSION lt '3.0205';
  is( $json->encode( {false => \"some"} ), '{"false":"some"}' );
  is( $json->encode( {false => \""} ),     '{"false":null}' );
  is( $json->encode( {false => \!!""} ),   '{"false":null}' );
}


$json->allow_unknown->allow_blessed(0)->convert_blessed;
$pp->allow_unknown->allow_blessed(0)->convert_blessed;
is( $pp->encode  ( {false => \"some"} ), '{"false":null}' );
is( $pp->encode  ( {false => \""} ),     '{"false":null}' );
is( $pp->encode  ( {false => \!!""} ),   '{"false":null}' );
is( $json->encode( {false => \"some"} ), '{"false":null}' );
is( $json->encode( {false => \""} ),     '{"false":null}' );
is( $json->encode( {false => \!!""} ),   '{"false":null}' );

