use strict;
use Test::More tests => 16;
use Cpanel::JSON::XS ();

my $booltrue  = q({"is_true":true});
my $boolfalse = q({"is_false":false});
my $yesno     = [ !0, !1 ]; # native yes, no. YAML::XS compatible
my $truefalse = "[true,false]";
my $cjson = Cpanel::JSON::XS->new;

# from JSON::MaybeXS
my $data = $cjson->decode('{"foo": true, "bar": false, "baz": 1}');
ok($cjson->is_bool($data->{foo}), 'true decodes to a bool')
  or diag 'true is: ', explain $data->{foo};
ok($cjson->is_bool($data->{bar}), 'false decodes to a bool')
  or diag 'false is: ', explain $data->{bar};
ok(!$cjson->is_bool($data->{baz}), 'int does not decode to a bool')
  or diag 'int is: ', explain $data->{baz};

my $js = $cjson->decode( $booltrue );
is( $cjson->encode( $js ), $booltrue);
ok( $js->{is_true} == 1 );
ok( Cpanel::JSON::XS::is_bool($js->{is_true}) );

$js = $cjson->decode( $boolfalse );
is( $cjson->encode( $js ), $boolfalse );
ok( $js->{is_false} == 0 );
ok( Cpanel::JSON::XS::is_bool($js->{is_false}) );

is( $cjson->encode( [\1,\0] ), $truefalse  );
is( $cjson->encode( [ Cpanel::JSON::XS::true,  Cpanel::JSON::XS::false] ),
    $truefalse );

TODO: {
  local $TODO = 'GH #39';
  is( $cjson->encode( $yesno ), $truefalse, "map yes/no to [true,false]");
  $js = $cjson->decode( $truefalse );
}
ok ($js->[0] == !0, "decode true to !0");
ok ($js->[1] == !1, "decode false to !1");
ok( Cpanel::JSON::XS::is_bool($js->[0]) );
ok( Cpanel::JSON::XS::is_bool($js->[1]) );
