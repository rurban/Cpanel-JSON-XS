package Cpanel::JSON::XS::Type;

our $VERSION = '4.53_001';

=pod

=head1 NAME

Cpanel::JSON::XS::Type - Type support for JSON encode

=head1 SYNOPSIS

 use Cpanel::JSON::XS;
 use Cpanel::JSON::XS::Type;


 encode_json([10, "10", 10.25], [JSON_TYPE_INT, JSON_TYPE_INT, JSON_TYPE_STRING]);
 # '[10,10,"10.25"]'

 encode_json([10, "10", 10.25], json_type_arrayof(JSON_TYPE_INT));
 # '[10,10,10]'

 encode_json(1, JSON_TYPE_BOOL);
 # 'true'

 my $perl_struct = { key1 => 1, key2 => "2", key3 => 1 };
 my $type_spec = { key1 => JSON_TYPE_STRING, key2 => JSON_TYPE_INT, key3 => JSON_TYPE_BOOL };
 my $json_string = encode_json($perl_struct, $type_spec);
 # '{"key1":"1","key2":2,"key3":true}'

 my $perl_struct = { key1 => "value1", key2 => "value2", key3 => 0, key4 => 1, key5 => "string", key6 => "string2" };
 my $type_spec = json_type_hashof(JSON_TYPE_STRING);
 my $json_string = encode_json($perl_struct, $type_spec);
 # '{"key1":"value1","key2":"value2","key3":"0","key4":"1","key5":"string","key6":"string2"}'

 my $perl_struct = { key1 => { key2 => [ 10, "10", 10.6 ] }, key3 => "10.5" };
 my $type_spec = { key1 => json_type_anyof(JSON_TYPE_FLOAT, json_type_hashof(json_type_arrayof(JSON_TYPE_INT))), key3 => JSON_TYPE_FLOAT };
 my $json_string = encode_json($perl_struct, $type_spec);
 # '{"key1":{"key2":[10,10,10]},"key3":10.5}'


 my $value = decode_json('false', 1, my $type);
 # $value is 0 and $type is JSON_TYPE_BOOL

 my $value = decode_json('0', 1, my $type);
 # $value is 0 and $type is JSON_TYPE_INT

 my $value = decode_json('"0"', 1, my $type);
 # $value is 0 and $type is JSON_TYPE_STRING

 my $json_string = '{"key1":{"key2":[10,"10",10.6]},"key3":"10.5"}';
 my $perl_struct = decode_json($json_string, 0, my $type_spec);
 # $perl_struct is { key1 => { key2 => [ 10, 10, 10.6 ] }, key3 => 10.5 }
 # $type_spec is { key1 => { key2 => [ JSON_TYPE_INT, JSON_TYPE_STRING, JSON_TYPE_FLOAT ] }, key3 => JSON_TYPE_STRING }

=head1 DESCRIPTION

This module provides stable JSON type support for the
L<Cpanel::JSON::XS|Cpanel::JSON::XS> encoder which doesn't depend on
any internal perl scalar flags or characteristics. Also it provides
real JSON types for L<Cpanel::JSON::XS|Cpanel::JSON::XS> decoder.

In most cases perl structures passed to
L<encode_json|Cpanel::JSON::XS/encode_json> come from other functions
or from other modules and caller of Cpanel::JSON::XS module does not
have control of internals or they are subject of change. So it is not
easy to support enforcing types as described in the
L<simple scalars|Cpanel::JSON::XS/simple scalars> section.

For services based on JSON contents it is sometimes needed to correctly
process and enforce JSON types.

The function L<decode_json|Cpanel::JSON::XS/decode_json> takes optional
third scalar parameter and fills it with specification of json types.

The function L<encode_json|Cpanel::JSON::XS/encode_json> takes a perl
structure as its input and optionally also a json type specification in
the second parameter.

If the specification is not provided (or is undef) internal perl
scalar flags are used for the resulting JSON type. The internal flags
can be changed by perl itself, but also by external modules. Which
means that types in resulting JSON string aren't stable. Specially it
does not work reliable for dual vars and scalars which were used in
both numeric and string operations. See L<simple
scalars|Cpanel::JSON::XS/simple scalars>.

To enforce that specification is always provided use C<require_types>.
In this case when C<encode> is called without second argument (or is
undef) then it croaks. It applies recursively for all sub-structures.

=head2 JSON type specification for scalars:

=over 4

=item JSON_TYPE_BOOL

It enforces JSON boolean in resulting JSON, i.e. either C<true> or
C<false>. For determining whether the scalar passed to the encoder
is true, standard perl boolean logic is used.

=item JSON_TYPE_INT

It enforces JSON number without fraction part in the resulting JSON.
Equivalent of perl function L<int|perlfunc/int> is used for conversion.

=item JSON_TYPE_FLOAT

It enforces JSON number with fraction part in the resulting JSON.
Equivalent of perl operation C<+0> is used for conversion.

=item JSON_TYPE_STRING

It enforces JSON string type in the resulting JSON.

=item JSON_TYPE_NULL

It represents JSON C<null> value. Makes sense only when passing
perl's C<undef> value.

=back

For each type, there also exists a type with the suffix C<_OR_NULL>
which encodes perl's C<undef> into JSON C<null>. Without type with
suffix C<_OR_NULL> perl's C<undef> is converted to specific type
according to above rules.

=head2 JSON type specification for arrays:

=over 4

=item [...]

The array must contain the same number of elements as in the perl
array passed for encoding. Each element of the array describes the
JSON type which is enforced for the corresponding element of the
perl array.

=item json_type_arrayof

This function takes a JSON type specification as its argument which
is enforced for every element of the passed perl array.

=back

=head2 JSON type specification for hashes:

=over 4

=item {...}

Each hash value for corresponding key describes the JSON type
specification for values of passed perl hash structure. Keys in hash
which are not present in passed perl hash structure are simple
ignored and not used.

=item json_type_hashof

This function takes a JSON type specification as its argument which
is enforced for every value of passed perl hash structure.

=back

=head2 JSON type specification for alternatives:

=over 4

=item json_type_anyof

This function takes a list of JSON type alternative specifications
(maximally one scalar, one array, and one hash) as its input and the
JSON encoder chooses one that matches.

=item json_type_null_or_anyof

Like L<C<json_type_anyof>|/json_type_anyof>, but scalar can be only
perl's C<undef>.

=back

=head2 Recursive specifications

=over 4

=item json_type_weaken

This function can be used as an argument for L</json_type_arrayof>,
L</json_type_hashof> or L</json_type_anyof> functions to create weak
references suitable for complicated recursive structures. It depends
on L<the weaken function from Scalar::Util|Scalar::Util/weaken> module.
See following example:

  my $struct = {
      type => JSON_TYPE_STRING,
      array => json_type_arrayof(JSON_TYPE_INT),
  };
  $struct->{recursive} = json_type_anyof(
      json_type_weaken($struct),
      json_type_arrayof(JSON_TYPE_STRING),
  );

If you want to encode all perl scalars to JSON string types despite
how complicated is input perl structure you can define JSON type
specification for alternatives recursively. It could be defined as:

  my $type = json_type_anyof();
  $type->[0] = JSON_TYPE_STRING_OR_NULL;
  $type->[1] = json_type_arrayof(json_type_weaken($type));
  $type->[2] = json_type_hashof(json_type_weaken($type));

  print encode_json([ 10, "10", { key => 10 } ], $type);
  # ["10","10",{"key":"10"}]

An alternative solution for encoding all scalars to JSON strings is to
use C<type_all_string> method of L<Cpanel::JSON::XS> itself:

  my $json = Cpanel::JSON::XS->new->type_all_string;
  print $json->encode([ 10, "10", { key => 10 } ]);
  # ["10","10",{"key":"10"}]

=back

=head2 Short scalar type names

As sugar for the constants above, anywhere a scalar JSON type is
accepted (currently: L</check_type> and the encoder's type spec) a
plain string may be used instead:

  Str Int Float Bool Null Any

C<Any> matches any scalar, including C<undef> (it is exactly
C<JSON_TYPE_SCALAR>, the "no constraint, use perl's own flags" type).
Suffix a name with C<?> for the C<_OR_NULL> variant: C<Str?>, C<Int?>,
C<Float?>, C<Bool?>. So a schema can be written the way the L<issue
that requested it|https://github.com/rurban/Cpanel-JSON-XS/issues/238>
suggested, as a plain hash of keys and types:

  my $schema = { name => 'Str', age => 'Int?', active => 'Bool' };

=head2 Optional hash keys

=over 4

=item json_type_optional

Wraps a type so that, when used as a hash schema value for
L</check_type>, the corresponding key is allowed to be entirely
absent from the data (as opposed to C<_OR_NULL>, which requires the
key to be present but allows its value to be C<null>).

  my $schema = { name => 'Str', nickname => json_type_optional('Str') };
  check_type({ name => 'Joe' }, $schema); # ok, nickname is optional

=back

=head2 Schema validation

=over 4

=item check_type

  my @errors = check_type($data, $schema);
  my @errors = check_type($data, $schema, $found_type);

Validates an already-decoded perl structure C<$data> against
C<$schema>, a type specification using the same building blocks as
the encoder's type spec above (C<JSON_TYPE_*> constants or the short
names, C<[...]>/C<json_type_arrayof>, C<{...}>/C<json_type_hashof>,
C<json_type_anyof>, plus C<json_type_optional> for hash keys).
Returns a list of human readable error strings (one per mismatch,
prefixed with a C<$>-rooted path such as C<$-E<gt>{users}-E<gt>[0]-E<gt>{id}>);
an empty list means C<$data> matches C<$schema>.

Unlike the encoder's plain C<{...}> hash type spec (which silently
ignores hash keys not mentioned in the spec), a plain hashref schema
here is I<closed>: every key present in C<$data> must be declared in
C<$schema>, and every key declared in C<$schema> must be present in
C<$data> unless wrapped in C<json_type_optional>. Use
C<json_type_hashof> for an open, homogeneous-value hash, exactly like
the encoder.

The optional third argument C<$found_type> is the type structure
L<decode|Cpanel::JSON::XS/decode> fills in via its own third
argument. When given, it is used as the ground truth for scalar
leaves instead of guessing from perl's internal scalar flags, which
removes the usual dual-var / stringified-number ambiguities. This is
exactly what
L<C<$json-E<gt>decode_and_validate>|Cpanel::JSON::XS/decode_and_validate>
does:

  my $json   = Cpanel::JSON::XS->new;
  my $schema = { id => JSON_TYPE_INT, name => 'Str', tags => json_type_arrayof('Str') };
  my $data   = $json->decode_and_validate($json_text, $schema); # croaks on mismatch

=back

=head1 AUTHOR

Pali E<lt>pali@cpan.orgE<gt>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2017, GoodData Corporation. All rights reserved.

This module is available under the same licences as perl, the Artistic
license and the GPL.

=cut

use strict;
use warnings;

BEGIN {
  if (eval { require Scalar::Util }) {
    Scalar::Util->import('weaken', 'looks_like_number');
  } else {
    *weaken = sub($) { die 'Scalar::Util is required for weaken' };
    *looks_like_number = sub($) {
      defined($_[0]) && $_[0] =~ /^\s*-?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][-+]?[0-9]+)?\s*\z/;
    };
  }
}

# This exports needed XS constants to perl
use Cpanel::JSON::XS ();

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = our @EXPORT_OK = qw(
  json_type_arrayof
  json_type_hashof
  json_type_anyof
  json_type_null_or_anyof
  json_type_weaken
  json_type_optional
  check_type
  JSON_TYPE_NULL
  JSON_TYPE_BOOL
  JSON_TYPE_INT
  JSON_TYPE_FLOAT
  JSON_TYPE_STRING
  JSON_TYPE_BOOL_OR_NULL
  JSON_TYPE_INT_OR_NULL
  JSON_TYPE_FLOAT_OR_NULL
  JSON_TYPE_STRING_OR_NULL
  JSON_TYPE_ARRAYOF_CLASS
  JSON_TYPE_HASHOF_CLASS
  JSON_TYPE_ANYOF_CLASS
  JSON_TYPE_OPTIONAL_CLASS
);

use constant JSON_TYPE_WEAKEN_CLASS => 'Cpanel::JSON::XS::Type::Weaken';
use constant JSON_TYPE_OPTIONAL_CLASS => 'Cpanel::JSON::XS::Type::Optional';
use constant JSON_TYPE_SCALAR => 0; # matches C JSON_TYPE_SCALAR: "no constraint" / Any


sub json_type_anyof {
  my ($scalar, $array, $hash);
  my ($scalar_weaken, $array_weaken, $hash_weaken);
  foreach (@_) {
    my $type = $_;
    my $ref = ref($_);
    my $weaken;
    if ($ref eq JSON_TYPE_WEAKEN_CLASS) {
      $type = ${$type};
      $ref = ref($type);
      $weaken = 1;
    }
    if ($ref eq '') {
      die 'Only one scalar type can be specified in anyof' if defined $scalar;
      $scalar = $type;
      $scalar_weaken = $weaken;
    } elsif ($ref eq 'ARRAY' or $ref eq JSON_TYPE_ARRAYOF_CLASS) {
      die 'Only one array type can be specified in anyof' if defined $array;
      $array = $type;
      $array_weaken = $weaken;
    } elsif ($ref eq 'HASH' or $ref eq JSON_TYPE_HASHOF_CLASS) {
      die 'Only one hash type can be specified in anyof' if defined $hash;
      $hash = $type;
      $hash_weaken = $weaken;
    } else {
      die 'Only scalar, array or hash can be specified in anyof';
    }
  }
  my $type = [$scalar, $array, $hash];
  weaken $type->[0] if $scalar_weaken;
  weaken $type->[1] if $array_weaken;
  weaken $type->[2] if $hash_weaken;
  return bless $type, JSON_TYPE_ANYOF_CLASS;
}

sub json_type_null_or_anyof {
  foreach (@_) {
    die 'Scalar cannot be specified in null_or_anyof' if ref($_) eq '';
  }
  return json_type_anyof(JSON_TYPE_CAN_BE_NULL, @_);
}

sub json_type_arrayof {
  die 'Exactly one type must be specified in arrayof' if scalar @_ != 1;
  my $type = $_[0];
  if (ref($type) eq JSON_TYPE_WEAKEN_CLASS) {
    $type = ${$type};
    weaken $type;
  }
  return bless \$type, JSON_TYPE_ARRAYOF_CLASS;
}

sub json_type_hashof {
  die 'Exactly one type must be specified in hashof' if scalar @_ != 1;
  my $type = $_[0];
  if (ref($type) eq JSON_TYPE_WEAKEN_CLASS) {
    $type = ${$type};
    weaken $type;
  }
  return bless \$type, JSON_TYPE_HASHOF_CLASS;
}

sub json_type_weaken {
  die 'Exactly one type must be specified in weaken' if scalar @_ != 1;
  die 'Scalar cannot be specfied in weaken' if ref($_[0]) eq '';
  return bless \(my $type = $_[0]), JSON_TYPE_WEAKEN_CLASS;
}

sub json_type_optional {
  die 'Exactly one type must be specified in optional' if scalar @_ != 1;
  return bless \(my $type = $_[0]), JSON_TYPE_OPTIONAL_CLASS;
}

# ---------------------------------------------------------------------
# Schema validation (GH #238): validate an already-decoded perl
# structure against a type specification built from the same pieces
# as the encoder's type spec above, plus json_type_optional() and the
# short scalar type names documented in the POD.
# ---------------------------------------------------------------------

my %SCALAR_TYPE_ALIAS = (
  Any      => JSON_TYPE_SCALAR,
  Str      => JSON_TYPE_STRING,
  Int      => JSON_TYPE_INT,
  Float    => JSON_TYPE_FLOAT,
  Bool     => JSON_TYPE_BOOL,
  Null     => JSON_TYPE_NULL,
  'Str?'   => JSON_TYPE_STRING_OR_NULL,
  'Int?'   => JSON_TYPE_INT_OR_NULL,
  'Float?' => JSON_TYPE_FLOAT_OR_NULL,
  'Bool?'  => JSON_TYPE_BOOL_OR_NULL,
);

my %SCALAR_TYPE_NAME = (
  JSON_TYPE_SCALAR() => 'Any',
  JSON_TYPE_STRING() => 'Str',
  JSON_TYPE_INT()    => 'Int',
  JSON_TYPE_FLOAT()  => 'Float',
  JSON_TYPE_BOOL()   => 'Bool',
  JSON_TYPE_NULL()   => 'Null',
);

sub _schema_scalar_type {
  my ($type) = @_;
  return $type if $type =~ /^-?[0-9]+\z/;
  return $SCALAR_TYPE_ALIAS{$type} if exists $SCALAR_TYPE_ALIAS{$type};
  die "invalid scalar type '$type' in schema (expected a JSON_TYPE_* constant".
      " or one of: " . join(', ', sort keys %SCALAR_TYPE_ALIAS) . ")";
}

sub _scalar_type_name {
  my ($type) = @_;
  return exists $SCALAR_TYPE_NAME{$type} ? $SCALAR_TYPE_NAME{$type} : "type($type)";
}

sub _detect_scalar_type {
  my ($value) = @_;
  return JSON_TYPE_NULL unless defined $value;
  return JSON_TYPE_BOOL if Cpanel::JSON::XS::is_bool($value);
  if (!ref($value) && looks_like_number($value)) {
    return $value =~ /^-?[0-9]+\z/ ? JSON_TYPE_INT : JSON_TYPE_FLOAT;
  }
  return JSON_TYPE_STRING;
}

sub check_type {
  my ($data, $schema, $found) = @_;
  my @errors;
  _check_type($data, $schema, $found, '$', \@errors);
  return @errors;
}

sub _check_type {
  my ($data, $schema, $found, $path, $errors) = @_;

  if (ref($schema) eq JSON_TYPE_OPTIONAL_CLASS) {
    $schema = ${$schema};
    return unless defined $data;
  }

  my $ref = ref($schema);

  if ($ref eq JSON_TYPE_ANYOF_CLASS) {
    my ($scalar_alt, $array_alt, $hash_alt) = @$schema;
    my $dref = ref($data);
    if ($dref eq 'ARRAY') {
      return push @$errors, "$path: array not allowed by schema" unless defined $array_alt;
      return _check_type($data, $array_alt, $found, $path, $errors);
    } elsif ($dref eq 'HASH') {
      return push @$errors, "$path: hash not allowed by schema" unless defined $hash_alt;
      return _check_type($data, $hash_alt, $found, $path, $errors);
    } else {
      return push @$errors, "$path: scalar not allowed by schema" unless defined $scalar_alt;
      return _check_type($data, $scalar_alt, $found, $path, $errors);
    }
  }
  elsif ($ref eq JSON_TYPE_ARRAYOF_CLASS) {
    if (ref($data) ne 'ARRAY') {
      push @$errors, "$path: expected array, got " . (ref($data) || 'scalar');
      return;
    }
    my $sub = $$schema;
    my $i = 0;
    for my $elem (@$data) {
      my $f = ref($found) eq 'ARRAY' ? $found->[$i] : undef;
      _check_type($elem, $sub, $f, $path . "->[$i]", $errors);
      $i++;
    }
  }
  elsif ($ref eq 'ARRAY') {
    if (ref($data) ne 'ARRAY') {
      push @$errors, "$path: expected array, got " . (ref($data) || 'scalar');
      return;
    }
    if (@$data != @$schema) {
      push @$errors, "$path: expected array of length " . scalar(@$schema) . ", got " . scalar(@$data);
      return;
    }
    for my $i (0 .. $#$schema) {
      my $f = ref($found) eq 'ARRAY' ? $found->[$i] : undef;
      _check_type($data->[$i], $schema->[$i], $f, $path . "->[$i]", $errors);
    }
  }
  elsif ($ref eq JSON_TYPE_HASHOF_CLASS) {
    if (ref($data) ne 'HASH') {
      push @$errors, "$path: expected hash, got " . (ref($data) || 'scalar');
      return;
    }
    my $sub = $$schema;
    for my $key (sort keys %$data) {
      my $f = ref($found) eq 'HASH' ? $found->{$key} : undef;
      _check_type($data->{$key}, $sub, $f, $path . "->{$key}", $errors);
    }
  }
  elsif ($ref eq 'HASH') {
    if (ref($data) ne 'HASH') {
      push @$errors, "$path: expected hash, got " . (ref($data) || 'scalar');
      return;
    }
    for my $key (sort keys %$schema) {
      my $subschema = $schema->{$key};
      unless (exists $data->{$key}) {
        push @$errors, "$path: missing required key '$key'"
          unless ref($subschema) eq JSON_TYPE_OPTIONAL_CLASS;
        next;
      }
      my $f = ref($found) eq 'HASH' ? $found->{$key} : undef;
      _check_type($data->{$key}, $subschema, $f, $path . "->{$key}", $errors);
    }
    for my $key (sort keys %$data) {
      push @$errors, "$path: unexpected key '$key'" unless exists $schema->{$key};
    }
  }
  else {
    my $want = _schema_scalar_type($schema);
    if ($want == JSON_TYPE_SCALAR) {
      # 'Any': matches every value, including undef/null
      return;
    }
    if ($want == JSON_TYPE_NULL) {
      push @$errors, "$path: expected null, got " . _scalar_type_name(_detect_scalar_type($data))
        if defined $data;
      return;
    }
    my $can_null = $want & JSON_TYPE_CAN_BE_NULL;
    my $base = $want & ~JSON_TYPE_CAN_BE_NULL;
    if (!defined $data) {
      push @$errors, "$path: expected " . _scalar_type_name($base) . ", got null"
        unless $can_null;
      return;
    }
    my $actual = defined($found) && !ref($found) ? ($found & ~JSON_TYPE_CAN_BE_NULL) : _detect_scalar_type($data);
    push @$errors, "$path: expected " . _scalar_type_name($base) . ", got " . _scalar_type_name($actual)
      if $actual != $base;
  }
}

1;
