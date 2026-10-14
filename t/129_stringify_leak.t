use strict;
use Test::More tests => 2;

use Cpanel::JSON::XS;

my $freed = 0;
package Str;
use overload '""' => sub { 'str' }, fallback => 1;
sub DESTROY { $freed++ }

package main;
Cpanel::JSON::XS->new->convert_blessed->encode([ bless {}, 'Str' ]);
is( $freed, 1, 'hash object' );
{ my $s = 'x'; Cpanel::JSON::XS->new->convert_blessed->encode([ bless \$s, 'Str' ]) }
is( $freed, 2, 'scalar object' );
