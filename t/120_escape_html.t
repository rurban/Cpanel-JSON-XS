use Test::More tests => 1;
use Cpanel::JSON::XS;
use warnings;
#########################

my $json = Cpanel::JSON::XS->new->allow_nonref;

my $hash = { "<script>" => "\"&\"" };

is($json->encode($hash), '{"\u003cscript\u003e":"\"\u0026\""}');
