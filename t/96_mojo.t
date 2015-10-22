use Test::More;
BEGIN {
  eval "require Mojo::JSON;";
  if ($@) {
    plan skip_all => "Mojo::JSON required for testing interop";
    exit 0;
  } else {
    plan tests => 6;
  }
}

use Mojo::JSON ();
use Cpanel::JSON::XS ();

my $booltrue = q({"is_true":true});
my $boolfalse = q({"is_false":false});
#my $boolpl     = { is_false => \0, is_true => \1 };
my $js = Mojo::JSON::decode_json( $booltrue );
is( $js->{is_true}, 1 );

my $cjson = Cpanel::JSON::XS->new;
is($cjson->encode( $js ), $booltrue)
  or diag "\$Mojolicious::VERSION=$Mojolicious::VERSION,".
  " \$Cpanel::JSON::XS::VERSION=$Cpanel::JSON::XS::VERSION";

$js = Mojo::JSON::decode_json( $boolfalse );
is( $cjson->encode( $js ), $boolfalse );
is( $js->{is_false}, 0 );

# issue18: support Types::Serialiser without allow_blessed (if JSON-XS-3.x is loaded)
$js = $cjson->decode( $booltrue );
is( $cjson->encode( $js ), $booltrue ) or diag(ref $js->{is_true} );
$js = $cjson->decode( $boolfalse );
is( $cjson->encode( $js ), $boolfalse ) or diag(ref $js->{is_false} );
