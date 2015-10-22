use strict;
use Test::More tests => 5;
use Cpanel::JSON::XS ();

my $booltrue  = q({"is_true":true});
my $boolfalse = q({"is_false":false});
my $boolpl    = [ !0, !1 ];
my $cjson = Cpanel::JSON::XS->new;

my $js = $cjson->decode( $booltrue );
is( $cjson->encode( $js ), $booltrue);
is( $js->{is_true}, 1 );

$js = $cjson->decode( $boolfalse );
is( $cjson->encode( $js ), $boolfalse );
is( $js->{is_false}, 0 );

TODO: {
  local $TODO = 'GH #39';
  is( $cjson->encode( $boolpl ), '[true,false]');
}
