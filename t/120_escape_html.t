use Test::More tests => 4;
use Cpanel::JSON::XS;
use warnings;
#########################

my $json = Cpanel::JSON::XS->new->allow_nonref;

my $hash = { "<script>" => "\"&\"" };

is($json->encode($hash), '{"\u003cscript\u003e":"\"\u0026\""}');

my $json_unescaped = Cpanel::JSON::XS->new->allow_nonref->dont_escape_html;

is($json_unescaped->encode($hash), '{"<script>":"\"&\""}');

skip "5.6", 2 if $] < 5.008;
my $extra_hash = { "\x{2028}" => "\x{2029}" };
is($json->encode($extra_hash), '{"\u2028":"\u2029"}');
is($json_unescaped->encode($extra_hash), "{\"\x{2028}\":\"\x{2029}\"}");
