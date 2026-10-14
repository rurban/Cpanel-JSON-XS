use strict;
use Test::More tests => 1;

use Cpanel::JSON::XS;

my $called = 0;
sub Ghost::run { $called++ }

# the callback removes itself; the hash it returns may reuse the freed table
my $json = Cpanel::JSON::XS->new;
$json->filter_json_single_key_object(k => sub {
  $json->filter_json_single_key_object(k => undef);
  return { outer => $_[0] };
});
$json->decode('{"outer":{"k":"Ghost::run"}}');
is( $called, 0, "callback removed itself in filter" );
