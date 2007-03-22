=head1 NAME

JSON::XS - JSON serialising/deserialising, done correctly and fast

=head1 SYNOPSIS

 use JSON::XS;

=head1 DESCRIPTION

This module converts Perl data structures to JSON and vice versa. Its
primary goal is to be I<correct> and its secondary goal is to be
I<fast>. To reach the latter goal it was written in C.

As this is the n-th-something JSON module on CPAN, what was the reason
to write yet another JSON module? While it seems there are many JSON
modules, none of them correctly handle all corner cases, and in most cases
their maintainers are unresponsive, gone missing, or not listening to bug
reports for other reasons.

See COMPARISON, below, for a comparison to some other JSON modules.

=head2 FEATURES

=over 4

=item * correct handling of unicode issues

This module knows how to handle Unicode, and even documents how it does so.

=item * round-trip integrity

When you serialise a perl data structure using only datatypes supported
by JSON, the deserialised data structure is identical on the Perl level.
(e.g. the string "2.0" doesn't suddenly become "2").

=item * strict checking of JSON correctness

There is no guessing, no generating of illegal JSON strings by default,
and only JSON is accepted as input (the latter is a security feature).

=item * fast

compared to other JSON modules, this module compares favourably.

=item * simple to use

This module has both a simple functional interface as well as an OO
interface.

=item * reasonably versatile output formats

You can choose between the most compact format possible, a pure-ascii
format, or a pretty-printed format. Or you can combine those features in
whatever way you like.

=back

=cut

package JSON::XS;

BEGIN {
   $VERSION = '0.1';
   @ISA = qw(Exporter);

   @EXPORT = qw(to_json from_json);
   require Exporter;

   require XSLoader;
   XSLoader::load JSON::XS::, $VERSION;
}

=head1 FUNCTIONAL INTERFACE

The following convinience methods are provided by this module. They are
exported by default:

=over 4

=item $json_string = to_json $perl_scalar

Converts the given Perl data structure (a simple scalar or a reference to
a hash or array) to a UTF-8 encoded, binary string (that is, the string contains
octets only). Croaks on error.

This function call is functionally identical to C<< JSON::XS->new->utf8
(1)->encode ($perl_scalar) >>.

=item $perl_scalar = from_json $json_string

The opposite of C<to_json>: expects an UTF-8 (binary) string and tries to
parse that as an UTF-8 encoded JSON string, returning the resulting simple
scalar or reference. Croaks on error.

This function call is functionally identical to C<< JSON::XS->new->utf8
(1)->decode ($json_string) >>.

=back

=head1 OBJECT-ORIENTED INTERFACE

The object oriented interface lets you configure your own encoding or
decoding style, within the limits of supported formats.

=over 4

=item $json = new JSON::XS

Creates a new JSON::XS object that can be used to de/encode JSON
strings. All boolean flags described below are by default I<disabled>.

The mutators for flags all return the JSON object again and thus calls can
be chained:

   my $json = JSON::XS->new->utf8(1)->space_after(1)->encode ({a => [1,2]})
   => {"a": [1, 2]}

=item $json = $json->ascii ($enable)

If C<$enable> is true, then the C<encode> method will not generate
characters outside the code range C<0..127>. Any unicode characters
outside that range will be escaped using either a single \uXXXX (BMP
characters) or a double \uHHHH\uLLLLL escape sequence, as per RFC4627.

If C<$enable> is false, then the C<encode> method will not escape Unicode
characters unless necessary.

  JSON::XS->new->ascii (1)->encode (chr 0x10401)
  => \ud801\udc01

=item $json = $json->utf8 ($enable)

If C<$enable> is true, then the C<encode> method will encode the JSON
string into UTF-8, as required by many protocols, while the C<decode>
method expects to be handled an UTF-8-encoded string.  Please note that
UTF-8-encoded strings do not contain any characters outside the range
C<0..255>, they are thus useful for bytewise/binary I/O.

If C<$enable> is false, then the C<encode> method will return the JSON
string as a (non-encoded) unicode string, while C<decode> expects thus a
unicode string.  Any decoding or encoding (e.g. to UTF-8 or UTF-16) needs
to be done yourself, e.g. using the Encode module.

=item $json = $json->pretty ($enable)

This enables (or disables) all of the C<indent>, C<space_before> and
C<space_after> (and in the future possibly more) flags in one call to
generate the most readable (or most compact) form possible.

   my $json = JSON::XS->new->pretty(1)->encode ({a => [1,2]})
   =>
   {
      "a" : [
         1,
         2
      ]
   }

=item $json = $json->indent ($enable)

If C<$enable> is true, then the C<encode> method will use a multiline
format as output, putting every array member or object/hash key-value pair
into its own line, identing them properly.

If C<$enable> is false, no newlines or indenting will be produced, and the
resulting JSON strings is guarenteed not to contain any C<newlines>.

This setting has no effect when decoding JSON strings.

=item $json = $json->space_before ($enable)

If C<$enable> is true, then the C<encode> method will add an extra
optional space before the C<:> separating keys from values in JSON objects.

If C<$enable> is false, then the C<encode> method will not add any extra
space at those places.

This setting has no effect when decoding JSON strings. You will also most
likely combine this setting with C<space_after>.

=item $json = $json->space_after ($enable)

If C<$enable> is true, then the C<encode> method will add an extra
optional space after the C<:> separating keys from values in JSON objects
and extra whitespace after the C<,> separating key-value pairs and array
members.

If C<$enable> is false, then the C<encode> method will not add any extra
space at those places.

This setting has no effect when decoding JSON strings.

=item $json = $json->canonical ($enable)

If C<$enable> is true, then the C<encode> method will output JSON objects
by sorting their keys. This is adding a comparatively high overhead.

If C<$enable> is false, then the C<encode> method will output key-value
pairs in the order Perl stores them (which will likely change between runs
of the same script).

This option is useful if you want the same data structure to be encoded as
the same JSON string (given the same overall settings). If it is disabled,
the same hash migh be encoded differently even if contains the same data,
as key-value pairs have no inherent ordering in Perl.

This setting has no effect when decoding JSON strings.

=item $json = $json->allow_nonref ($enable)

If C<$enable> is true, then the C<encode> method can convert a
non-reference into its corresponding string, number or null JSON value,
which is an extension to RFC4627. Likewise, C<decode> will accept those JSON
values instead of croaking.

If C<$enable> is false, then the C<encode> method will croak if it isn't
passed an arrayref or hashref, as JSON strings must either be an object
or array. Likewise, C<decode> will croak if given something that is not a
JSON object or array.

=item $json_string = $json->encode ($perl_scalar)

Converts the given Perl data structure (a simple scalar or a reference
to a hash or array) to its JSON representation. Simple scalars will be
converted into JSON string or number sequences, while references to arrays
become JSON arrays and references to hashes become JSON objects. Undefined
Perl values (e.g. C<undef>) become JSON C<null> values. Neither C<true>
nor C<false> values will be generated.

=item $perl_scalar = $json->decode ($json_string)

The opposite of C<encode>: expects a JSON string and tries to parse it,
returning the resulting simple scalar or reference. Croaks on error.

JSON numbers and strings become simple Perl scalars. JSON arrays become
Perl arrayrefs and JSON objects become Perl hashrefs. C<true> becomes
C<1>, C<false> becomes C<0> and C<null> becomes C<undef>.

=back

=head1 COMPARISON

As already mentioned, this module was created because none of the existing
JSON modules could be made to work correctly. First I will describe the
problems (or pleasures) I encountered with various existing JSON modules,
followed by some benchmark values. JSON::XS was designed not to suffer
from any of these problems or limitations.

=over 4

=item JSON

Slow (but very portable, as it is written in pure Perl).

Undocumented/buggy Unicode handling (how JSON handles unicode values is
undocumented. One can get far by feeding it unicode strings and doing
en-/decoding oneself, but unicode escapes are not working properly).

No roundtripping (strings get clobbered if they look like numbers, e.g.
the string C<2.0> will encode to C<2.0> instead of C<"2.0">, and that will
decode into the number 2.

=item JSON::PC

Very fast.

Undocumented/buggy Unicode handling.

No roundtripping.

Has problems handling many Perl values (e.g. regex results and other magic
values will make it croak).

Does not even generate valid JSON (C<{1,2}> gets converted to C<{1:2}>
which is not a valid JSON string.

Unmaintained (maintainer unresponsive for many months, bugs are not
getting fixed).

=item JSON::Syck

Very buggy (often crashes).

Very inflexible (no human-readable format supported, format pretty much
undocumented. I need at least a format for easy reading by humans and a
single-line compact format for use in a protocol, and preferably a way to
generate ASCII-only JSON strings).

Completely broken (and confusingly documented) Unicode handling (unicode
escapes are not working properly, you need to set ImplicitUnicode to
I<different> values on en- and decoding to get symmetric behaviour).

No roundtripping (simple cases work, but this depends on wether the scalar
value was used in a numeric context or not).

Dumping hashes may skip hash values depending on iterator state.

Unmaintained (maintainer unresponsive for many months, bugs are not
getting fixed).

Does not check input for validity (i.e. will accept non-JSON input and
return "something" instead of raising an exception. This is a security
issue: imagine two banks transfering money between each other using
JSON. One bank might parse a given non-JSON request and deduct money,
while the other might reject the transaction with a syntax error. While a
good protocol will at least recover, that is extra unnecessary work and
the transaction will still not succeed).

=item JSON::DWIW

Very fast. Very natural. Very nice.

Undocumented unicode handling (but the best of the pack. Unicode escapes
still don't get parsed properly).

Very inflexible.

No roundtripping.

Does not generate valid JSON (key strings are often unquoted, empty keys
result in nothing being output)

Does not check input for validity.

=back

=head2 SPEED

It seems that JSON::XS is surprisingly fast, as shown in the following
tables. They have been generated with the help of the C<eg/bench> program
in the JSON::XS distribution, to make it easy to compare on your own
system.

First is a comparison between various modules using a very simple JSON
string, showing the number of encodes/decodes per second (JSON::XS is
the functional interface, while JSON::XS/2 is the OO interface with
pretty-printing and hashkey sorting enabled).

   module     |     encode |     decode |
   -----------|------------|------------|
   JSON       |      14006 |       6820 |
   JSON::DWIW |     200937 |     120386 |
   JSON::PC   |      85065 |     129366 |
   JSON::Syck |      59898 |      44232 |
   JSON::XS   |    1171478 |     342435 |
   JSON::XS/2 |     730760 |     328714 |
   -----------+------------+------------+

That is, JSON::XS is 6 times faster than than JSON::DWIW and about 80
times faster than JSON, even with pretty-printing and key sorting.

Using a longer test string (roughly 8KB, generated from Yahoo! Locals
search API (http://nanoref.com/yahooapis/mgPdGg):

   module     |     encode |     decode |
   -----------|------------|------------|
   JSON       |        673 |         38 |
   JSON::DWIW |       5271 |        770 |
   JSON::PC   |       9901 |       2491 |
   JSON::Syck |       2360 |        786 |
   JSON::XS   |      37398 |       3202 |
   JSON::XS/2 |      13765 |       3153 |
   -----------+------------+------------+

Again, JSON::XS leads by far in the encoding case, while still beating
every other module in the decoding case.

Last example is an almost 8MB large hash with many large binary values
(PNG files), resulting in a lot of escaping:

=head1 BUGS

While the goal of this module is to be correct, that unfortunately does
not mean its bug-free, only that I think its design is bug-free. It is
still very young and not well-tested. If you keep reporting bugs they will
be fixed swiftly, though.

=cut

1;

=head1 AUTHOR

 Marc Lehmann <schmorp@schmorp.de>
 http://home.schmorp.de/

=cut

