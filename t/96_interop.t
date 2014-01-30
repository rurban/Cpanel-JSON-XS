use Test::More;
eval "use JSON::XS ();";
if ($@) {
  plan skip_all => "JSON::XS required for testing interop";
} else {
  plan tests => 1;
}

use Cpanel::JSON::XS ();

my $boolstring = q({"is_true":true});
my $xs_string;
{
    use JSON::XS ();
    my $json = JSON::XS->new;
    $xs_string = $json->decode( $boolstring );
}
my $json = Cpanel::JSON::XS->new;

is($json->encode( $xs_string ), $boolstring);
