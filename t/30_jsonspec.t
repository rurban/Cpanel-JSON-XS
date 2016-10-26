# regressions and differences from the JSON Specs and JSON::PP
# detected by http://seriot.ch/json/parsing.html
use Test::More;
use Cpanel::JSON::XS;
my $json = Cpanel::JSON::XS->new->utf8->allow_nonref;
my $relaxed = Cpanel::JSON::XS->new->utf8->allow_nonref->relaxed;

# parser need to fail
sub n_error {
  my ($str, $name) = @_;
  my $result = eval { $json->decode($str) };
  isnt($@, "", "parsing error with $name");
  is($result, undef, "undef result with $name");
}
# parser need to succeed, result should be valid
sub y_pass {
  my ($str, $name) = @_;
  my $result = eval { $json->decode($str) };
  is($@, "", "no parsing error with $name");
  if ($str eq 'null') {
    is($result, undef, "valid result with $name");
  } else {
    isnt($result, undef, "valid result with $name");
  }
}

# fixme:
# detect and accept BOM
# i_structure_UTF-8_BOM_empty_object
# n_number_then_00.json       100 <=> 1
# n_string_UTF8_surrogate_U+D800.json     ["EDA080"] <=> [""]
# y_string_utf16.json     FFFE[00"00E900"00]00 <=> [""]

# undefined i_ tests:
# also pass with relaxed
my %i_pass = map{$_ => 1}
  qw(
      i_number_neg_int_huge_exp
      i_number_pos_double_huge_exp
      i_structure_500_nested_arrays
      i_structure_UTF-8_BOM_empty_object
   );
# also fail with relaxed
my %i_parseerr = map{$_ => 1}
  qw(
      i_object_key_lone_2nd_surrogate
      i_string_1st_surrogate_but_2nd_missing
      i_string_1st_valid_surrogate_2nd_invalid
      i_string_incomplete_surrogate_and_escape_valid
      i_string_incomplete_surrogate_pair
      i_string_incomplete_surrogates_escape_valid
      i_string_inverted_surrogates_U+1D11E
      i_string_lone_second_surrogate
      i_string_truncated-utf-8
      i_string_UTF-16_invalid_lonely_surrogate
      i_string_UTF-16_invalid_surrogate
      i_string_UTF-8_invalid_sequence
      i_string_not_in_unicode_range
      i_string_unicode_U+10FFFE_nonchar
      i_string_unicode_U+1FFFE_nonchar
      i_string_unicode_U+FDD0_nonchar
      i_string_unicode_U+FFFE_nonchar
   );
# should parse and return undef:
my %i_empty    = map{$_ => 1}
  qw(
   );

# result undefined
sub i_undefined {
  my ($str, $name) = @_;
  my $result = eval { $json->decode($str) };
  if ($result) { diag("valid result with $name"); }
  elsif ($@)   { diag("parser error with $name"); }
  else         { diag("no result with $name"); }
  $result    = eval { $relaxed->decode($str) };
  if ($result) { diag("relaxed: valid result with $name"); }
  elsif ($@)   { diag("relaxed: parser error with $name"); }
  else         { diag("relaxed: no result with $name"); }
}
# result undefined, parsing succeeds, result ok
sub i_pass {
  my ($str, $name) = @_;
  my $result = eval { $json->decode($str) };
  is($@, "", "no parsing error with undefined $name");
  isnt($result, undef, "valid result with undefined $name");
  $result    = eval { $relaxed->decode($str) };
  is($@, "", "no parsing error with undefined $name relaxed");
  isnt($result, undef, "valid result with undefined $name relaxed");
}
# result undefined, parsing failed
sub i_error {
  my ($str, $name) = @_;
  my $result = eval { $json->decode($str) };
  isnt($@, "", "parsing error with undefined $name");
  is($result, undef, "no result with undefined $name");
  $result    = eval { $relaxed->decode($str) };
  isnt($@, "", "parsing error with undefined $name relaxed");
  is($result, undef, "no result with undefined $name relaxed");
}

# todo: test_transform also
for my $f (<t/test_parsing/*.json>) {
  local $/;
  my $fh;
  open $fh, "<", $f;
  my $s = <$fh>;
  close $fh;
  my ($base) = ($f =~ m|t/test_parsing/(.*)\.json|);
  if ($base =~ /^y_/) {
    y_pass($s, $base);
  }
  elsif ($base =~ /^n_/) {
    n_error($s, $base);
  }
  elsif ($base =~ /^i_/) {
    if ($i_pass{$base}) {
      i_pass($s, $base);
    } elsif ($i_parseerr{$base}) {
      i_error($s, $base);
    } else {
      i_undefined($s, $base);
    }
  }
}

#n_error("[1,\n1\n,1",      "n_array_unclosed_with_new_lines.json");
#n_error("[\"a\",\n4\n,1,", "n_array_newlines_unclosed.json");
#i_pass("[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]", "i_structure_500_nested_arrays.json");
#n_error("\x{EF}\x{BB}\x{BF}\x{00}{}","i_structure_UTF-8_BOM_empty_object.json");

done_testing;
