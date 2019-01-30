use Test::More tests => 2;
use Cpanel::JSON::XS;
use warnings;
#########################

my $json = Cpanel::JSON::XS->new->allow_nonref;

my $hash = { "<script>" => "\"&\"" };

is($json->encode($hash), '{"\u003cscript\u003e":"\"\u0026\""}');

my $json_unescaped = Cpanel::JSON::XS->new->allow_nonref->dont_escape_html;

is($json_unescaped->encode($hash), '{"<script>":"\"&\""}');
