# -*- perl -*-
use strict;
use Test::More;

plan skip_all => 'This test is only run for the module author'
  unless -d '.git' || $ENV{AUTHOR_TESTING};

eval "use Test::Spelling;";
plan skip_all => "Test::Spelling required"
  if $@;

add_stopwords(<DATA>);
all_pod_files_spelling_ok();

__DATA__
BMP
BOM
BOM's
BSON
CBOR
CVE
Cpanel
Crockford
Crockford's
DESERIALIZATION
Deserializing
ECMAscript
GPL
GoodData
IETF
Iceweasel
JSON
JSON's
KOI
Lehmann
Lehmann
MLEHMANN
Mojo
MongoDB
MovableType
NOK
NaN's
OO
QNAN
Reini
SNAN
STDIN
STDOUT
SixApart
Storable
TCP
UTF
XSS
amd
arg
arrayrefs
ascii
autodetection
backported
backrefs
bencode
bugtracker
cPanel
cbor
classname
clzf
codepoints
codeset
codesets
commandline
conformant
cpan
datastructure
deserialization
deserialize
deserialized
deserializer
deserializing
fromformat
github
hashrefs
interop
interoperability
ithread
ithreads
javascript
javascript's
json
latin
le
nan
nd
ness
noncharacters
nonref
numifying
onwards
optimizations
parsable
parsers
postprocessing
ppport
qnan
queryable
recurses
recursing
repo
resizes
roundtripping
runtime
sanify
serializer
serializers
snan
src
storable
stringifies
stringifying
superset
syck
testsuite
th
toformat
typeless
un
unblessed
unicode
utf
xs
yaml
