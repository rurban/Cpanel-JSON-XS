use strict;
use Config;
use Test::More tests => 3;

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

# a dying callback frees the enclosing containers (no leak); the error propagates
eval { Cpanel::JSON::XS->new->filter_json_object(sub { die "cb\n" })->decode('[[{"a":1}]]') };
is( $@, "cb\n", "dying filter callback propagates" );

# a dying filter callback frees the keys of the enclosing objects
SKIP: {
  skip "RSS is not meaningful under a sanitizer", 1 if $Config{ccflags} =~ /-fsanitize/;
  skip "RSS is read from /proc/self/status on Linux only", 1 unless $^O eq 'linux';
  open my $f, '<', '/proc/self/status' or skip "no /proc/self/status", 1;
  my $rss = sub { seek $f, 0, 0; while (<$f>) { return $1 if /^VmRSS:\s+(\d+)/ } };
  defined $rss->() or skip "no VmRSS in /proc/self/status", 1;
  my $dec = Cpanel::JSON::XS->new->allow_singlequote
    ->filter_json_object(sub { die "obj_cb\n" });
  my $text = '{"a":{"b":{"c":{}}}}';
  for (1 .. 20_000) { eval { $dec->decode($text) } }
  my $r0 = $rss->();
  for (1 .. 200_000) { eval { $dec->decode($text) } }
  cmp_ok( $rss->() - $r0, '<', 4000, 'filter_json_object die: no key leak' );
}
