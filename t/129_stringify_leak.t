use strict;
use Config;
use Test::More tests => 5;
use Encode ();

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


# encode_str croaks on malformed UTF-8: nothing may leak.
# A truncated sequence with the UTF8 flag forced on is malformed on every perl.
sub malformed {
  my $s = "\xe2\x98\xba\x20\xe2\x98";
  Encode::_utf8_on($s);
  return $s;
}
{
  package Bad;
  use overload '""' => sub { main::malformed() }, fallback => 1;
  sub DESTROY { $freed++ }
}
$freed = 0;
eval { Cpanel::JSON::XS->new->convert_blessed->encode([ bless {}, 'Bad' ]) };
ok( $@, 'croaks on malformed UTF-8' );
is( $freed, 1, 'overloaded object freed after croak' );

SKIP: {
  skip "RSS is not meaningful under a sanitizer", 1 if $Config{ccflags} =~ /-fsanitize/;
  skip "RSS is read from /proc/self/status on Linux only", 1 unless $^O eq 'linux';
  open my $f, '<', '/proc/self/status' or skip "no /proc/self/status", 1;
  my $rss = sub { seek $f, 0, 0; while (<$f>) { return $1 if /^VmRSS:\s+(\d+)/ } };
  defined $rss->() or skip "no VmRSS in /proc/self/status", 1;
  my $enc = Cpanel::JSON::XS->new->allow_stringify;
  my $one = sub {
    my $s = malformed();
    eval { $enc->encode([\$s]) };
  };
  for (1 .. 20_000) { $one->() }
  my $r0 = $rss->();
  for (1 .. 200_000) { $one->() }
  cmp_ok( $rss->() - $r0, '<', 4000, 'allow_stringify croak: no string copy leak' );
}
