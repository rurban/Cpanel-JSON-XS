use strict;
use constant HAVE_BOOLEANS => ($^V ge v5.36);
use Test::More tests => 63 + (HAVE_BOOLEANS ? 2 : 0);
use Cpanel::JSON::XS ();
use Config;

my $have_blessed;
BEGIN {
  if (eval { require Scalar::Util }) {
    Scalar::Util->import('blessed');
    $have_blessed = 1;
  }
}

my $booltrue  = q({"is_true":true});
my $boolfalse = q({"is_false":false});
my $truefalse = "[true,false]";
my $cjson = Cpanel::JSON::XS->new;
my $true  = Cpanel::JSON::XS::true;
my $false = Cpanel::JSON::XS::false;

my $nonref_cjson = Cpanel::JSON::XS->new;
my $unblessed_bool_cjson = Cpanel::JSON::XS->new->unblessed_bool;

# from JSON::MaybeXS
my $data = $cjson->decode('{"foo": true, "bar": false, "baz": 1}');
ok($cjson->is_bool($data->{foo}), 'true decodes to a bool')
  or diag 'true is: ', explain $data->{foo};
ok($cjson->is_bool($data->{bar}), 'false decodes to a bool')
  or diag 'false is: ', explain $data->{bar};
ok(!$cjson->is_bool($data->{baz}), 'int does not decode to a bool')
  or diag 'int is: ', explain $data->{baz};

my $js = $cjson->decode( $booltrue );
is( $cjson->encode( $js ), $booltrue);
ok( $js->{is_true} == $true );
ok( Cpanel::JSON::XS::is_bool($js->{is_true}) );

$js = $cjson->decode( $boolfalse );
is( $cjson->encode( $js ), $boolfalse );
ok( $js->{is_false} == $false );
ok( Cpanel::JSON::XS::is_bool($js->{is_false}) );

is( $cjson->encode( [\1,\0] ), $truefalse  );
is( $cjson->encode( [ $true, $false] ),
    $truefalse );

# GH #39
# perl block which returns sv_no or sv_yes
SKIP: {
  skip "Devel::Cover #92", 4 if $INC{'Devel/Cover.pm'};

  is( $nonref_cjson->encode( do{(my $a=0)==1} ), "false", "map do{(my \$a)=0)==1} to false");
  is( $nonref_cjson->encode( do{(my $a=0)==1} ), "false", "map do{(my \$a)=0)==1} to false");
  is( $nonref_cjson->encode( do{(my $a=1)==1} ), "true", "map do{(my \$a)=1)==1} to true");
  is( $nonref_cjson->encode( do{(my $a=1)==1} ), "true", "map do{(my \$a)=1)==1} to true");
}
# GH #39
# XS function UNIVERSAL::isa returns sv_no or sv_yes
is( $nonref_cjson->encode( UNIVERSAL::isa('0', '1') ), "false", "map UNIVERSAL::isa('0', '1') to false");
is( $nonref_cjson->encode( UNIVERSAL::isa('0', '1') ), "false", "map UNIVERSAL::isa('0', '1') to false");
is( $nonref_cjson->encode( UNIVERSAL::isa('UNIVERSAL', 'UNIVERSAL') ), "true", "map UNIVERSAL::isa('UNIVERSAL', 'UNIVERSAL') to true");
is( $nonref_cjson->encode( UNIVERSAL::isa('UNIVERSAL', 'UNIVERSAL') ), "true", "map UNIVERSAL::isa('UNIVERSAL', 'UNIVERSAL') to true");

# GH #39
# XS function utf8::is_utf8 returns sv_no or sv_yes
SKIP: {
  skip 'Perl 5.8.1 is needed for boolean tests based on utf8::upgrade()+utf8::is_utf8()', 4
    if $] < 5.008001;
  skip "Devel::Cover #92", 4 if $INC{'Devel/Cover.pm'};

  is( $nonref_cjson->encode( do{utf8::is_utf8(my $a)} ), "false", "map do{utf8::is_utf8(my \$a)} to false");
  is( $nonref_cjson->encode( do{utf8::is_utf8(my $a)} ), "false", "map do{utf8::is_utf8(my \$a)} to false");
  my $utf8 = '';
  utf8::upgrade($utf8);
  is( $nonref_cjson->encode( do{utf8::is_utf8($utf8)} ), "true", "map do{utf8::is_utf8(\$utf8)} to true");
  is( $nonref_cjson->encode( do{utf8::is_utf8($utf8)} ), "true", "map do{utf8::is_utf8(\$utf8)} to true");
}

# GH #39 stringification. enabled with 5.16, stable fix with 5.20
if ($] < 5.020 && $Config{useithreads}) {
  # random results threaded
  my ($strue, $sfalse) = (qr/^(1|true)$/, qr/^(""||false)$/);
  like( $nonref_cjson->encode( !1 ), $sfalse, "map !1 to false");
  like( $nonref_cjson->encode( !1 ), $sfalse, "map !1 to false");
  like( $nonref_cjson->encode( !0 ), $strue, "map !0 to 1/true");
  like( $nonref_cjson->encode( !0 ), $strue, "map !0 to 1/true");
} else {
  # perl expression which evaluates to stable sv_no or sv_yes
  my ($strue, $sfalse) = ("true", "false");
  is( $nonref_cjson->encode( !1 ), $sfalse, "map !1 to false");
  is( $nonref_cjson->encode( !1 ), $sfalse, "map !1 to false");
  is( $nonref_cjson->encode( !0 ), $strue, "map !0 to true");
  is( $nonref_cjson->encode( !0 ), $strue, "map !0 to true");
}

$js = $cjson->decode( $truefalse );
ok ($js->[0] == $true,  "decode true to yes");
ok ($js->[1] == $false, "decode false to no");
ok( Cpanel::JSON::XS::is_bool($js->[0]), "true is_bool");
ok( Cpanel::JSON::XS::is_bool($js->[1]), "false is_bool");

# GH #53
ok( !Cpanel::JSON::XS::is_bool( [] ), "[] !is_bool");


$js = $unblessed_bool_cjson->decode($booltrue);
SKIP: {
  skip "no Scalar::Util in $]", 1 unless $have_blessed;
  ok(!blessed($js->{is_true}), "->unblessed_bool for JSON true does not return blessed object");
}
cmp_ok($js->{is_true}, "==", 1, "->unblessed_bool for JSON true returns correct Perl bool value");
cmp_ok($js->{is_true}, "eq", "1", "->unblessed_bool for JSON true returns correct Perl bool value");

$js = $unblessed_bool_cjson->decode($boolfalse);
SKIP: {
  skip "no Scalar::Util in $]", 1 unless $have_blessed;
  ok(!blessed($js->{is_false}), "->unblessed_bool for JSON false does not return blessed object");
}
cmp_ok($js->{is_false}, "==", 0, "->unblessed_bool for JSON false returns correct Perl bool value");
cmp_ok($js->{is_false}, "eq", "", "->unblessed_bool for JSON false returns correct Perl bool value");

is($unblessed_bool_cjson->encode(do { my $struct = $unblessed_bool_cjson->decode($truefalse, my $types); ($struct, $types) }), $truefalse, "encode(decode(boolean)) is identity with ->unblessed_bool");
is($cjson->encode(do { my $struct = $unblessed_bool_cjson->decode($truefalse, my $types); ($struct, $types) }), $truefalse, "booleans decoded by ->unblessed_bool(1) are encoded by ->unblessed_bool(0) in the same way");

$js = $unblessed_bool_cjson->decode($truefalse);
ok eval { $js->[0] = "new value 0" }, "decoded 'true' is modifiable" or diag($@);
ok eval { $js->[1] = "new value 1" }, "decoded 'false' is modifiable" or diag($@);


# GH #207: boolean eq/ne must not match undef (which stringifies to "")
# NOTE: we intentionally differ from JSON::PP by accepting "false" and ""
# as eq to false, and "true" as eq to true (semantic boolean matching).
ok(!($false eq undef),    'false ne undef via eq');    # the bug fix
ok(!($true  eq undef),    'true ne undef via eq');
ok( $false eq "",         q{false eq "" via eq});       # intentional: !!0 / SV_NO
ok( $false eq "false",    q{false eq "false" via eq});   # intentional: semantic
ok( $true  eq "true",     q{true eq "true" via eq});     # intentional: semantic
ok( $true  ne "",         q{true ne "" via eq});
ok( $false eq 0,          'false eq 0 via eq');
ok( $false eq "0",        q{false eq "0" via eq});
ok( $true  eq 1,          'true eq 1 via eq');
ok( $true  eq "1",        q{true eq "1" via eq});
ok( $false eq !!0,        'false eq !!0 (SV_NO) via eq'); # intentional
# ne (must be consistent with eq)
ok( $false ne undef,      'false ne undef via ne');
ok(!($false ne ""),       q{false eq "" via ne});
ok(!($false ne 0),        'false eq 0 via ne');
# cmp must agree with eq for the undef case (GH #207)
is($false cmp undef, 1, 'false cmp undef -> 1 (ne)');
is($false cmp "",    1, q{false cmp "" -> 1 (ne, but eq is true)});
is($false cmp 0,     0, 'false cmp 0 -> 0 (eq)');
# boolean-to-boolean eq
ok( $false eq $false,    'false eq false');
ok( $true  eq $true,      'true eq true');
ok(!($false eq $true),   'false ne true');
ok(!($true  eq $false),   'true ne false');
if(HAVE_BOOLEANS) {
  no if HAVE_BOOLEANS, warnings => "experimental::builtin";
  is($cjson->encode({t => builtin::true}), q({"t":true}),
    'true core booleans encode as boolean');
  is($cjson->encode({f => builtin::false}), q({"f":false}),
    'false core booleans encode as boolean');
}
