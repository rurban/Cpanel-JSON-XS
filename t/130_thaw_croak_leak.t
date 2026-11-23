use strict;
use Test::More tests => 4;

use Cpanel::JSON::XS;

my $freed = 0;
sub Marker::DESTROY { $freed++ }
sub Rejects::THAW { die "rejected\n" }

my $json = Cpanel::JSON::XS->new->allow_tags
  ->filter_json_single_key_object(m => sub { bless {}, 'Marker' });
eval { $json->decode('("Rejects")[{"m":1}]') };
is( $freed, 1, "Properly freed" );

# THAW dies inside an array/object: the enclosing containers are freed
sub Ok::THAW { my ($class, $fmt, @v) = @_; bless [@v], $class }
sub Ok::DESTROY { $freed++ }
$json = Cpanel::JSON::XS->new->allow_tags;
for my $text ('[("Ok")[],("Rejects")[]]', '{"k":("Ok")[],"t":("Rejects")[]}',
              '[[("Ok")[]],("Rejects")[]]') {
  $freed = 0;
  eval { $json->decode($text) };
  is( $freed, 1, "enclosing containers freed: $text" );
}
