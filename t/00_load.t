BEGIN { $| = 1; print "1..5\n"; }
END {print "not ok 1\n" unless $loaded;}
use Cpanel::JSON::XS;
$loaded = 1;
print "ok 1\n";

# GH #93: $obj->new must work (not create a broken object)
my $obj = eval { Cpanel::JSON::XS->new->utf8 };
my $obj2 = eval { $obj->new };
print $@ ? "not ok 2 - GH #93 \$obj->new crashed: $@" : "ok 2 - GH #93 \$obj->new\n";
my $class = ref($obj2);
print $class && $class eq 'Cpanel::JSON::XS'
  ? "ok 3 - GH #93 result is Cpanel::JSON::XS\n"
  : "not ok 3 - GH #93 result is ", ($class || "undef"), "\n";

# GH #93: subclass $obj->new preserves class (needs Perl 5.10+ for parent.pm)
if ($] >= 5.010) {
  package MyJSON93;
  use parent -norequire, 'Cpanel::JSON::XS';
  package main;
  my $sub = MyJSON93->new;
  my $sub2 = $sub->new;
  print eval { $sub2->isa('MyJSON93') }
    ? "ok 4 - GH #93 subclass ->new preserves class\n"
    : "not ok 4 - GH #93\n";
  print eval { $sub2->isa('Cpanel::JSON::XS') }
    ? "ok 5 - GH #93 subclass ->new still ISA Cpanel::JSON::XS\n"
    : "not ok 5 - GH #93\n";
} else {
  print "ok 4 # skip parent.pm not available\n";
  print "ok 5 # skip parent.pm not available\n";
}
