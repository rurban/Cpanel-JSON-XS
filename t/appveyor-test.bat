@echo off

rem Test::MinimumVersion JSON
set REQS=Pod::Text Time::Piece common::sense Mojo::JSON Test::LeakTrace Test::CPAN::Meta Test::Pod Test::Pod::Coverage
set PERL_MM_USE_DEFAULT=1

if not "%PLATFORM%" == "x64" set WIN64=undef
if "%STRAWBERRY%" == "1" goto gcc
if "%MSVC_CPERL%" == "1" goto msvc

:gcc

set PATH=C:\strawberry\perl\bin;C:\strawberry\perl\site\bin;C:\strawberry\c\bin;%PATH%
echo cpan -T %REQS%
call cpan -T %REQS% || exit /b 1
echo perl Makefile.PL
perl Makefile.PL || exit /b 1
rem strawberry switched with 5.26 from dmake to gmake
echo $Config{make}
perl -MConfig -e "system({$Config{make}} $Config{make}); exit(($? < 0 || $? & 127) ? 1 : ($? >> 8));" || exit /b 1
echo $Config{make} test
perl -MConfig -e "system({$Config{make}} $Config{make}, 'test'); exit(($? < 0 || $? & 127) ? 1 : ($? >> 8));" || exit /b 1

exit /b

:msvc
if "%PLATFORM%" == "x64" set PLATFORM=amd64
rem 14 deviates from cperl with linker errors for the libc runtime
set MSVC_VERSION=12
call "C:\Program Files (x86)\Microsoft Visual Studio %MSVC_VERSION%.0\VC\vcvarsall.bat" %PLATFORM% || exit /b 1

set PATH=C:\cperl\bin;C:\cperl\site\bin;%PATH%
echo cperl -S cpan -T %REQS%
cperl -S cpan -T %REQS% || exit /b 1
echo cperl Makefile.PL
cperl Makefile.PL || exit /b 1
echo nmake
nmake || exit /b 1
echo nmake test
nmake test || exit /b 1

