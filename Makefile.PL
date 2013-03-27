#use 5.008002;
use 5.006002;
use ExtUtils::MakeMaker;

WriteMakefile(
  dist	 => {
    PREOP	=> 'pod2text XS.pm | tee README >$(DISTVNAME)/README; chmod -R u=rwX,go=rX . ;',
    COMPRESS	=> 'gzip -9v',
    SUFFIX	=> '.gz',
  },
  EXE_FILES    => [ "bin/cpanel_json_xs" ],
  VERSION_FROM => "XS.pm",
  NAME         => "Cpanel::JSON::XS",
  PREREQ_PM    => {
    'common::sense' => '3.6',
    'Pod::Text'     => '2.08',
    'Pod::Usage'    => '1.51',
  },
  LICENSE  => 'perl',
  ($] >= 5.005 ?
   (ABSTRACT_FROM  => 'XS.pm',
    AUTHOR         => 'Reini Urban <rurban@cpanel.net>',
    # ORIGINAL_AUTHOR => 'Marc Lehmann <schmorp@schmorp.de>'
   ) : ()),
  ($ExtUtils::MakeMaker::VERSION gt '6.46' ?
   ('META_MERGE'  =>
    {"recommends" =>
     {
       'Encode'        => '1.9801',
     },
     resources =>
     {
       license     => 'http://dev.perl.org/licenses/',
       bugtracker  => 'https://github.com/rurban/Cpanel-JSON-XS/issues',
       repository  => 'https://github.com/rurban/Cpanel-JSON-XS',
       homepage    => 'http://home.schmorp.de/',
     },
    }
   ) : ()),
  SIGN  => 1,
);

package MY;
sub test {
  local $_ = shift->SUPER::test(@_);
  s/TEST_FILES = /TEST_FILES = -Mcommon::sense /;
  $_
}

sub top_targets {
  local $_ = shift->SUPER::top_targets(@_);
  s/\$\(FIRST_MAKEFILE\) blibdirs/\$(FIRST_MAKEFILE\) blibdirs README/;
  $_
}

sub depend {
  "
README : \$(VERSION_FROM)
	pod2text \$(VERSION_FROM) > README
"
}
