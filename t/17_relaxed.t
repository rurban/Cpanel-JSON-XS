use Test::More $] < 5.008 ? (skip_all => "5.6") : (tests => 9);
use utf8;
use Cpanel::JSON::XS;

my $json = Cpanel::JSON::XS->new->relaxed;

ok ('[1,2,3]' eq encode_json $json->decode (' [1,2, 3]'));
ok ('[1,2,4]' eq encode_json $json->decode ('[1,2, 4 , ]'));
ok (!eval { $json->decode ('[1,2, 3,4,,]') });
ok (!eval { $json->decode ('[,1]') });

ok ('{"1":2}' eq encode_json $json->decode (' {"1":2}'));
ok ('{"1":2}' eq encode_json $json->decode ('{"1":2,}'));
ok (!eval { $json->decode ('{,}') });

ok ('[1,2]' eq encode_json $json->decode ("[1#,2\n ,2,#  ]  \n\t]"));

ok ('["Hello\tWorld"]' eq encode_json $json->decode ("[\"Hello\tWorld\"]"));
