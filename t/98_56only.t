use Test::More $] < 5.008 ? (tests => 3) : (skip_all => "5.6 only");
use Cpanel::JSON::XS;

my $json = Cpanel::JSON::XS->new;

{
    my $formref = {
        'cpanel_apiversion' => 1,
        'utf8'       => 'אאאאאאאխ"',
        'func'       => 'phpmyadminlink',
        'module'     => 'Cgi'
    };

    ok( from_json( to_json($formref) ),
	"Cpanel::JSON::XS :: round trip untied utf8 with int" );
}

$js  = q|[-12.34]|;
$obj = $json->decode($js);
is($obj->[0], -12.34, 'digit -12.34');
$js = $json->encode($obj);
is($js,'[-12.34]', 'digit -12.34');
