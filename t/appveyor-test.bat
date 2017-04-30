@echo off

set REQS=Pod::Text Time::Piece common::sense Mojo::JSON JSON Test::LeakTrace Test::MinimumVersion Test::CPAN::Meta Test::Pod Test::Pod::Coverage

if not "%PLATFORM%" == "x64" set WIN64=undef
if "%STRAWBERRY%" == "1" goto gcc
if "%MSVC_CPERL%" == "1" goto msvc

:gcc

set PATH=C:\strawberry\perl\bin;C:\strawberry\perl\site\bin;C:\strawberry\c\bin;%PATH%
cpan -T %REQS%
perl Makefile.PL
dmake
dmake test

exit /b

:msvc
if "%PLATFORM%" == "x64" set PLATFORM=amd64
rem 14 would deviate from cperl, but test inf/nan failures
set MSVC_VERSION=14
call "C:\Program Files (x86)\Microsoft Visual Studio %MSVC_VERSION%.0\VC\vcvarsall.bat" %PLATFORM%

set PATH=C:\cperl\bin;C:\cperl\site\bin;%PATH%
cpan -T %REQS%
cperl Makefile.PL
nmake
nmake test

