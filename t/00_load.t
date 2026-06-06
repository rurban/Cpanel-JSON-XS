BEGIN { $| = 1; print "1..5\n"; }
END {print "not ok 1\n" unless $loaded;}
use Cpanel::JSON::XS;
$loaded = 1;
print "ok 1\n";

# GH #93: $obj->new must work (not create a broken object)
my $obj = Cpanel::JSON::XS->new->utf8;
my $obj2 = eval { $obj->new };
print $@ ? "not ok 2 - GH #93 \$obj->new crashed: $@" : "ok 2 - GH #93 \$obj->new\n";
print ref($obj2) eq 'Cpanel::JSON::XS'
  ? "ok 3 - GH #93 result is Cpanel::JSON::XS\n"
  : "not ok 3 - GH #93 result is ", ref($obj2) // "undef", "\n";

# GH #93: subclass $obj->new preserves class
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
