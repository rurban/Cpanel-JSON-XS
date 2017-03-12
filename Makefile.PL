use 5.006002;
use ExtUtils::MakeMaker;
use Config;

my $define = '';
# https://gcc.gnu.org/onlinedocs/gcc-4.0.0/gcc/Warning-Options.html
if ($Config{gccversion} and $Config{gccversion} =~ /^(\d+\.\d+)\./) {
    my $gccver = $1;
    if ($gccver >= 4.3) {
        $define = '-Wall -Werror=declaration-after-statement -Wextra -W';
    } elsif ($gccver >= 3.4) {
        $define = '-Wall -Wdeclaration-after-statement -Wextra -W';
    }
}

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
    'Pod::Text'     => '2.08',
  },
  DEFINE       => $define,
  LICENSE      => 'perl',
  ($] >= 5.005 ?
   (ABSTRACT_FROM  => 'XS.pm',
    AUTHOR         => 'Reini Urban <rurban@cpanel.net>',
    # ORIGINAL_AUTHOR => 'Marc Lehmann <schmorp@schmorp.de>'
   ) : ()),
  ($ExtUtils::MakeMaker::VERSION gt '6.46'
   ? ('META_MERGE'  =>
    {
      prereqs => {
        runtime => {
          requires => { # just the script, not the module
            'Encode'        => '1.9801',
          }
        },
        test => {
          requires => {
            'Encode'        => '1.9801',
            'Time::Piece'   => 0,
          },
          suggests => {
            'common::sense' => '3.5',
            'Mojo::JSON'    => '6.11',
            'JSON'          => 0,
            'JSON::XS'      => 0,
            'JSON::PP'      => 0,
            'Test::LeakTrace' => 0,
            'Test::MinimumVersion' => '0.008',
            'Perl::MinimumVersion' => '1.20',
            'Test::CPAN::Meta'     => '0.12',
            'Test::Pod'            => '1.00',
            'Test::Pod::Coverage'  => '1.04',
          }
        }
      },
      resources =>
      {
        license     => 'http://dev.perl.org/licenses/',
        bugtracker  => 'https://github.com/rurban/Cpanel-JSON-XS/issues',
        # Note: https://rt.cpan.org/Public/Dist/Display.html?Queue=Cpanel-JSON-XS is also observed
        repository  => 'https://github.com/rurban/Cpanel-JSON-XS',
        homepage    => 'http://software.schmorp.de/pkg/JSON-XS.html',
      },
    }
   ) : ()),
  SIGN  => 1,
);

package MY;
sub test {
  local $_ = shift->SUPER::test(@_);
  eval { require common::sense; };
  unless ($@) {
    s/TEST_FILES = /TEST_FILES = -Mcommon::sense /;
  }
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
