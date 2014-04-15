use Test::More;
eval "use JSON::XS (); require JSON;";
if ($@) {
  plan skip_all => "JSON::XS and JSON required for testing interop";
  exit 0;
} else {
  plan tests => 2;
}

use Cpanel::JSON::XS ();

my $boolstring = q({"is_true":true});
my $xs_string;
{
    require JSON::XS;
    my $json = JSON::XS->new;
    $xs_string = $json->decode( $boolstring );
}
my $cjson = Cpanel::JSON::XS->new->allow_blessed;

is($cjson->encode( $xs_string ), $boolstring) or diag "\$JSON::XS::VERSION=$JSON::XS::VERSION";

{
    require JSON;
    local $ENV{PERL_JSON_BACKEND} = 0;
    my $json = JSON->new;
    $xs_string = $json->decode( $boolstring );
}

is($cjson->encode( $xs_string ), $boolstring) or diag "\$JSON::VERSION=$JSON::VERSION";

