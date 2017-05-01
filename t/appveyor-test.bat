@echo off

rem Test::MinimumVersion
set REQS=Pod::Text Time::Piece common::sense Mojo::JSON JSON Test::LeakTrace Test::CPAN::Meta Test::Pod Test::Pod::Coverage
set PERL_MM_USE_DEFAULT=1

if not "%PLATFORM%" == "x64" set WIN64=undef
if "%STRAWBERRY%" == "1" goto gcc
if "%MSVC_CPERL%" == "1" goto msvc

:gcc

set PATH=C:\strawberry\perl\bin;C:\strawberry\perl\site\bin;C:\strawberry\c\bin;%PATH%
rem echo cpan -T %REQS%
rem cpan -T %REQS%
echo perl Makefile.PL
perl Makefile.PL
echo dmake
dmake
echo dmake test
dmake test

exit /b

:msvc
if "%PLATFORM%" == "x64" set PLATFORM=amd64
rem 14 deviates from cperl with linker errors for the libc runtime
set MSVC_VERSION=12
call "C:\Program Files (x86)\Microsoft Visual Studio %MSVC_VERSION%.0\VC\vcvarsall.bat" %PLATFORM%

set PATH=C:\cperl\bin;C:\cperl\site\bin;%PATH%
cperl -S cpan -T %REQS%
cperl Makefile.PL
nmake
nmake test

