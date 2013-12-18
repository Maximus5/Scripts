echo off

call :cvt_name "%~n1"

set ConEmuFakeDT=20%cmtname:~0,2%-%cmtname:~2,2%-%cmtname:~4,2% 21:00
echo %ConEmuFakeDT%
echo %DATE%

if %DATE:~6% == 2013 (
call cecho "Invalid file label! '%cmtname%' - '%~n1'"
exit 2
)

rem call "%~dp0commit.cmd" "[arc] %cmtname% history"
rem call st0

powershell -noprofile "%~dp0ImpArcFiles.ps1"
if errorlevel 1 (
call cecho "powershell rc = %errorlevel%"
exit 1
)

rem call cecho /green "go.cmd %~nx1 finished"
goto :EOF

:cvt_name
set zname=%~x1
set cmtname=%zname:~1%
goto :EOF

:err
call cecho "Error while processing!"
pause
exit 1
