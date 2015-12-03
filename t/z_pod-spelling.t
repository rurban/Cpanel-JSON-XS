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
interop
Lehmann
bencode
clzf
commandline
fromformat
le
serialised
toformat
yaml
BMP
BSON
CVE
Cpanel
Crockford
DESERIALISATION
ECMAscript
GPL
Iceweasel
KOI
Lehmann
MLEHMANN
Mojo
MovableType
Reini
SERIALISATION
SixApart
TCP
XSS
amd
ascii
autodetection
backported
backrefs
cPanel
codeset
codesets
conformant
contary
datastructure
deserialisation
deserialise
deserialised
deserializer
fatc
hashkey
iso
ithread
ithreads
latin
nan
ness
numifying
onwards
optimizations
parsable
postprocessing
ppport
queryable
recursing
representions
resizes
roundtripping
sanify
serialisation
serialise
serialised
serialiser
serialisers
serialising
src
standardised
superset
testsuite
th
typeless
un
unicode
xs
