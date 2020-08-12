use Test::More tests => 4;
use Cpanel::JSON::XS;
use Tie::Hash;
use Tie::Array;

my $js = Cpanel::JSON::XS->new;

tie my %h, 'Tie::StdHash';
%h = (a => 1);
is ($js->encode (\%h), '{"a":1}');

$h{d} = 4;
$h{c} = 3;
$h{b} = 2;
# sort the keys with canonical (GH #167)
is ($js->canonical->encode (\%h), '{"a":1,"b":2,"c":3,"d":4}');

tie my @a, 'Tie::StdArray';
@a = (1, 2);
is ($js->encode (\@a), '[1,2]');

push @a, 0;
is ($js->canonical->encode (\@a), '[1,2,0]');
