@echo off

for %%g in (C:\Projects\ConEmu-Deploy\Pack\imp_src\*.7z) do call :go "%%g"

:go
rem call cecho "%~1"
if NOT exist %1 goto :EOF
call "%~dp0go.cmd" %1
rem if NOT "%gitbranch:~0,-1%" == " [history-arc]" (
rem   cecho /yellow "Check current state! %gitbranch:~0,-1%"
rem   pause
rem   exit 1
rem )
rem goto :EOF
if errorlevel 1 (
exit 1
)
rem pause
