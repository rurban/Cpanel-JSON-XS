#!perl
use strict;
use warnings;
use Test::More tests => 15;
use Cpanel::JSON::XS;

my $js = Cpanel::JSON::XS->new;
my @data = ('null', 'true', 'false', "1", "\"test\"");
my %map = ( 'null' => undef, true => 1, false => 0, 
            '1' => 1, '"test"' => "test" );

for my $k (@data) {
  my $data = $js->decode("{\"foo\":$k}");
  my $res = $data->{foo} || $k;
  ok exists $data->{foo}, "foo hvalue exists";
  is $data->{foo}, $map{$k}, "foo hvalue $res";
  ok $data->{foo} = "bar", "foo can be set from $res to 'bar'";
}
