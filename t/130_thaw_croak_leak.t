use strict;
use Test::More tests => 1;

use Cpanel::JSON::XS;

my $freed = 0;
sub Marker::DESTROY { $freed++ }
sub Rejects::THAW { die "rejected\n" }

my $json = Cpanel::JSON::XS->new->allow_tags
  ->filter_json_single_key_object(m => sub { bless {}, 'Marker' });
eval { $json->decode('("Rejects")[{"m":1}]') };
is( $freed, 1, "Properly freed" );
