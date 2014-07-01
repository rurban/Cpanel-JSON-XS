#!perl
use strict;
use warnings;
BEGIN { $| = 1; print "1..1\n"; }
use Cpanel::JSON::XS;

my $json = Cpanel::JSON::XS->new->convert_blessed;

sub Foo::TO_JSON {
    return 1;
}

my $string = "something";
my $object = \$string;
bless $object,'Foo';
Internals::SvREADONLY($string,1);
my $hash = {obj=>$object};

my $enc = $json->encode ($hash);
print $enc eq '{"obj":1}' ? "" : "not ", "ok 1 # $enc\n";
