@echo off

set REQS=Pod::Text Time::Piece common::sense Mojo::JSON JSON Test::LeakTrace Test::MinimumVersion Test::CPAN::Meta Test::Pod Test::Pod::Coverage Encode

if not "%PLATFORM%" == "x64" set WIN64=undef
if "%STRAWBERRY%" == "1" goto gcc
if "%MSVC_VERSION%" == "10" goto msvc_10
if "%MSVC_VERSION%" == "12" goto msvc_12
if "%MSVC_VERSION%" == "14" goto msvc_14

:gcc

set PATH=C:\strawberry\perl\bin;C:\strawberry\perl\site\bin;C:\strawberry\c\bin;%PATH%
set make=dmake
goto cont

:msvc_10

call "C:\Program Files\Microsoft SDKs\Windows\v7.1\Bin\SetEnv.cmd" /%PLATFORM%
rem if "%PLATFORM%" == "x64" ( set "PATH=C:\windows\system32;c:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\Bin\amd64;C:\Program Files\Microsoft SDKs\Windows\v7.1\Bin\x64;C:\Program Files\Microsoft SDKs\Windows\v7.1\Bin;C:\windows;C:\Program Files\Git\cmd;C:\Program Files\Git\usr\bin;C:\Program Files\7-Zip;" ) ELSE ( set "PATH=C:\windows\system32;c:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\Bin;C:\Program Files (x86)\Microsoft Visual Studio 10.0\Common7\IDE;C:\Program Files\Microsoft SDKs\Windows\v7.1\Bin;C:\windows;C:\Program Files\Git\cmd;C:\Program Files\Git\usr\bin;C:\Windows\System32\WindowsPowerShell\v1.0\;C:\Program Files\7-Zip;" )

set make=nmake
goto cont

:msvc_12
if "%PLATFORM%" == "x64" set PLATFORM=amd64
call "C:\Program Files (x86)\Microsoft Visual Studio %MSVC_VERSION%.0\VC\vcvarsall.bat" %PLATFORM%
rem if "%PLATFORM%" == "X64" ( set "PATH=C:\windows\system32;C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\BIN\amd64;C:\Program Files (x86)\Windows Kits\8.1\bin\x64;C:\Program Files (x86)\Windows Kits\8.1\bin\x86;C:\windows;C:\Program Files\Git\cmd;C:\Program Files\Git\usr\bin;C:\Program Files\7-Zip;" ) ELSE ( set "PATH=C:\windows\system32;C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\BIN;C:\Program Files (x86)\Windows Kits\8.1\bin\x86;C:\windows;C:\Program Files\Git\cmd;C:\Program Files\Git\usr\bin;C:\Windows\System32\WindowsPowerShell\v1.0\;C:\Program Files\7-Zip;" )

set make=nmake
goto cont

:msvc_14
if "%PLATFORM%" == "x64" set PLATFORM=amd64
call "C:\Program Files (x86)\Microsoft Visual Studio %MSVC_VERSION%.0\VC\vcvarsall.bat" %PLATFORM%
set
rem if "%PLATFORM%" == "X64" ( set "PATH=C:\windows\system32;C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\BIN\amd64;C:\Program Files (x86)\Windows Kits\8.1\bin\x64;C:\Program Files (x86)\Windows Kits\8.1\bin\x86;C:\windows;C:\Program Files\Git\cmd;C:\Program Files\Git\usr\bin;C:\Program Files\7-Zip;" ) ELSE ( set "PATH=C:\windows\system32;C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\BIN;C:\Program Files (x86)\Windows Kits\8.1\bin\x86;C:\windows;C:\Program Files\Git\cmd;C:\Program Files\Git\usr\bin;C:\Windows\System32\WindowsPowerShell\v1.0\;C:\Program Files\7-Zip;" )

set make=nmake

:cont
rem cpan -T %REQS%
perl Makefile.PL
%make%
%make% test
