use 5.006002;
use ExtUtils::MakeMaker;
use Config;

my $define = '';
# https://gcc.gnu.org/onlinedocs/gcc-4.0.0/gcc/Warning-Options.html
if ($Config{gccversion} and $Config{gccversion} =~ /^(\d+\.\d+)\./) {
  my $gccver = $1;
  if ($] > 5.035004) {
    $define = '-Wall -Wextra -W';
  } elsif ($gccver >= 4.3) {
    $define = '-Wall -Werror=declaration-after-statement -Wextra -W';
  } elsif ($gccver >= 3.4) {
    $define = '-Wall -Wdeclaration-after-statement -Wextra -W';
  }
}
if ($] < 5.022 && $Config{d_setlocale} && $Config{usethreads}) {
  if (-e "/usr/include/xlocale.h") {
    $define .= " -DI_XLOCALE -DHAS_USELOCALE";
  } else {
    print "probe for xlocale.h... ";
    open PROBE, "> tmp.c";
    print PROBE <<'EOT'; close(PROBE);
#include <stdio.h>
#include <xlocale.h>
int main(int argc, char** argv, char** env) {
    printf("found\n");
    uselocale((locale_t)0);
    return 0;
}
EOT
    my $exe = "tmp$Config{exe_ext}";
    my $cc_cmd = "$Config{cc} $Config{ccflags}" .
                 " -o $exe $Config{ldflags} tmp.c $Config{libs}";
    my $rc = system($cc_cmd);
    if ($rc) {
      print "not found\n";
      print "$cc_cmd\n";
    } else {
      $define .= " -DI_XLOCALE -DHAS_USELOCALE";
    }
    unlink("tmp.c", $exe, "tmp$Config{obj_ext}");
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
  CONFIGURE_REQUIRES => {
    'Config'              => 0,
    'ExtUtils::MakeMaker' => 0,
  },
  PREREQ_PM    => {
    'overload'      => 0,
    'strict'        => 0,
    'warnings'      => 0,
    'Carp'          => 0,
    'Encode'        => '1.9801',
    'Exporter'      => 0,
    'Pod::Text'     => '2.08',
    'XSLoader'      => 0,
  },
  TEST_REQUIRES => {
    'charnames'     => 0,
    'lib'           => 0,
    'utf8'          => 0,
    'B'             => 0,
    'Config'        => 0,
    'Data::Dumper'  => 0,
    'Devel::Peek'   => 0,
    'POSIX'         => 0,
    'Test'          => 0,
    'Test::More'    => 0,
    'Tie::Array'    => 0,
    'Tie::Hash'     => 0,
  },
  DEFINE       => $define,
  ($] >= 5.005 ?
   (ABSTRACT_FROM  => 'XS.pm',
    AUTHOR         => 'Reini Urban <rurban@cpan.org>',
    # ORIGINAL_AUTHOR => 'Marc Lehmann <schmorp@schmorp.de>'
   ) : ()),
  ($ExtUtils::MakeMaker::VERSION >= 6.3002 ?
   ('LICENSE'  => 'perl', ) : ()),
  ($ExtUtils::MakeMaker::VERSION gt '6.46'
   ? ('META_MERGE'  =>
    {
      'meta-spec' => {
        version => 2,
      },
      dynamic_config => 0,
      prereqs => {
        runtime => {
          requires => { # just the script, not the module
            'Encode'        => '1.9801',
          },
          recommends => {
            'Math::BigInt'   => 0,
            'Math::BigFloat' => '1.16',
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
            'Test::Spelling'       => 0,
            'Pod::Spell::CommonMistakes' => 0,
            'Test::CPAN::Changes'  => '0.40',
            'Test::CheckChanges'   => '1.14',
            'Class::XSAccessor'    => 0,
            'Text::CSV_XS'         => 0,
            'List::MoreUtils'      => 0,
            'Test::Kwalitee'       => 0,
          }
        }
      },
      resources =>
      {
        license     => [ 'http://dev.perl.org/licenses/' ],
        bugtracker  => { web => 'https://github.com/rurban/Cpanel-JSON-XS/issues' },
        # Note: https://rt.cpan.org/Public/Dist/Display.html?Queue=Cpanel-JSON-XS is also observed
        repository  => { url => 'https://github.com/rurban/Cpanel-JSON-XS', type => 'git' },
      },
      x_contributors => [
        'Ashley Willis <ashleyw@cpan.org>',
        'Chip Salzenberg <chip@pobox.com>',
        'Christopher J. Madsen <cjm@cjmweb.net>',
        'Colin Kuskie <colink@perldreamer.com>',
        'Daniel Dragan <bulk88@hotmail.com>',
        'David Golden <xdg@xdg.me>',
        'David Steinbrunner <dsteinbrunner@pobox.com>',
        'E. Choroba <choroba@users.noreply.github.com>',
        'Gianni Ceccarelli <gianni.ceccarelli@net-a-porter.com>',
        'Gilmar Santos Jr <jgasjr@gmail.com>',
        'Graham Knop <haarg@haarg.org>',
        'James Rouzier <rouzier@gmail.com>',
        'J. Nick Koston <nick@cpanel.net>',
        'Karen Etheridge <ether@cpan.org>',
        'Lubomir Rintel <lkundrak@v3.sk>',
        'Lukas Mai <l.mai@web.de>',
        'Matthew Horsfall <wolfsage@gmail.com>',
        'Michael G. Schwern <schwern@pobox.com>',
        'Pali <pali@cpan.org>',
        'Patrick Cronin <PatrickCronin@users.noreply.github.com>',
        'Quim Rovira <quim@rovira.cat>',
        'Sergey Aleynikov <sergey.aleynikov@gmail.com>',
        'Syohei Yoshida <syohex@gmail.com>',
        'tevfik1903 <tevfik1903@users.noreply.github.com>',
      ],
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

release : xtest dist
	-git tag -f \$(VERSION)
	cpan-upload \$(DISTVNAME).tar\$(SUFFIX)
	git push
	git push --tags

xtest :: test
	\$(MAKE) test TEST_FILES=xt/*.t

const-c.inc const-xs.inc : Makefile.PL

# versioned gcc needs overrides
GCOV = gcov
test_cover :: pure_all
	\$(RM_RF) cover_db
	+\$(PERLRUNINST) -S cover -test

test_coveralls :: pure_all
	+\$(PERLRUNINST) -S cover -test -report coveralls

gcov : \$(BASEEXT).c.gcov \$(BASEEXT).gcov cover_db/\$(BASEEXT)-xs.html

\$(BASEEXT).c.gcov \$(BASEEXT).xs.gcov : \$(BASEEXT).xs
	\$(MAKE) CCFLAGS=\"\$(CCFLAGS) -fprofile-arcs -ftest-coverage\" LDDLFLAGS=\"\$(LDDLFLAGS) -fprofile-arcs -ftest-coverage\"
	\$(GCOV) \$(BASEEXT).c \$(BASEEXT).xs

cover_db/\$(BASEEXT)-xs.html : \$(BASEEXT).xs.gcov
	PERL5OPT=-MDevel::Cover make test
	-$^X -S gcov2perl \$(BASEEXT).c.gcov \$(BASEEXT).xs.gcov
	$^X -S cover

gprof :
	\$(MAKE) CCFLAGS=\"\$(CCFLAGS) -pg\" LDDLFLAGS=\"\$(LDDLFLAGS) -pg\"
"
}
