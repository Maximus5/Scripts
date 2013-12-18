@echo off
rem cd /d "%~dp0git"
cd /d C:\Projects\Test\mrg3\
if errorlevel 1 exit /B 100

if "%~1" == "" (
cecho "Build must be specified!"
exit /B 100
)

set cmtname=%~1

set ConEmuFakeDT=20%cmtname:~0,2%-%cmtname:~2,2%-%cmtname:~4,2% 21:00
echo %ConEmuFakeDT%
echo %DATE%

C:\Utils\GIT\bin\git.exe commit -m "[arc] %cmtname% history"

if errorlevel 1 (
set ConEmuFakeDT=
exit /B 100
)

set ConEmuFakeDT=
