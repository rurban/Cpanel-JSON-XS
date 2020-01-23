use strict;
use warnings;

use Cpanel::JSON::XS;
use Devel::Peek;

# Devel::Peek::SvREFCNT(%hash) is supported since 5.19.3
use Test::More ($] < 5.019003) ? (skip_all => "5.19.3") : (tests => 1);

my $json = Cpanel::JSON::XS->new;

my $x = '{"some": "json"}';
$json->decode($x, my $types);
is(Devel::Peek::SvREFCNT(%{$types}), 1);

__END__
# Following code triggers memory leak when SvREFCNT is not 1
for (1..5000000) {
    my $var;
    $json->decode($x, $var);
}
