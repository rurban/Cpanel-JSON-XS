use strict;
use Cpanel::JSON::XS;
use Test::More tests => 22;

package ZZ;
use overload ('""' => sub { "<ZZ:".${$_[0]}.">" } );

package main;
sub XX::TO_JSON { {"__",""} }

my $o1 = bless { a => 3 }, "XX";       # with TO_JSON
my $o2 = bless \(my $dummy1 = 1), "YY"; # without stringification
my $o3 = bless \(my $dummy2 = 1), "ZZ"; # with stringification

if (eval 'require Hash::Util') {
  if ($Hash::Util::VERSION > 0.05) {
    Hash::Util::lock_ref_keys($o1);
    print "# blessed hash is locked\n";
  }
  else {
    Hash::Util::lock_hash($o1);
    print "# hash is locked\n";
  }
}
else {
  print "# locked hashes are not supported\n";
};

my $js = Cpanel::JSON::XS->new;

eval { $js->encode ($o1) }; ok ($@ =~ /allow_blessed/, 'error no allow_blessed');
eval { $js->encode ($o2) }; ok ($@ =~ /allow_blessed/, 'error w/o TO_JSON');
eval { $js->encode ($o3) }; ok ($@ =~ /allow_blessed/, 'error w stringify');
$js->convert_blessed;
my $r = $js->encode ($o1);
ok ($js->encode ($o1) eq '{"__":""}', "convert_blessed with TO_JSON $r");
$r = "";
eval { $r = $js->encode ($o2) }; ok ($@ =~ /allow_blessed/, "error w/o TO_JSON $r @_");
$r = $js->encode ($o3);
TODO: {
  local $TODO = '5.8.x' if $] < 5.010;
  ok ($r eq '"<ZZ:1>"', "stringify overload with convert_blessed: $r / $o3");
}

$js = Cpanel::JSON::XS->new;
$js->allow_blessed;
ok ($js->encode ($o1) eq "null", 'allow_blessed');
ok ($js->encode ($o2) eq "null");
ok ($js->encode ($o3) eq "null");
$js->allow_blessed->convert_blessed;
ok ($js->encode ($o1) eq '{"__":""}', 'allow_blessed + convert_blessed');
SKIP: {
  skip "5.6", 2 if $[ < 5.008;
  # PP returns null
  $r = $js->encode ($o2);
  ok ($r eq 'null', "$r");
  $r = $js->encode ($o3);
 TODO: {
   local $TODO = '5.8.x' if $] < 5.010;
   ok ($r eq '"<ZZ:1>"', "stringify $r");
  }
}

$js->filter_json_object (sub { 5 });
$js->filter_json_single_key_object (a => sub { shift });
$js->filter_json_single_key_object (b => sub { 7 });

ok ("ARRAY" eq ref $js->decode ("[]"));
ok (5 eq join ":", @{ $js->decode ('[{}]') });
ok (6 eq join ":", @{ $js->decode ('[{"a":6}]') });
ok (5 eq join ":", @{ $js->decode ('[{"a":4,"b":7}]') });

$js->filter_json_object;
ok (7 == $js->decode ('[{"a":4,"b":7}]')->[0]{b});
ok (3 eq join ":", @{ $js->decode ('[{"a":3}]') });

$js->filter_json_object (sub { });
ok (7 == $js->decode ('[{"a":4,"b":7}]')->[0]{b});
ok (9 eq join ":", @{ $js->decode ('[{"a":9}]') });

$js->filter_json_single_key_object ("a");
ok (4 == $js->decode ('[{"a":4}]')->[0]{a});

SKIP: {
  skip "5.6 + 5.8.1", 1 if $] < 5.008002;
  $js->filter_json_single_key_object (a => sub { });
  ok (4 == $js->decode ('[{"a":4}]')->[0]{a});
}
