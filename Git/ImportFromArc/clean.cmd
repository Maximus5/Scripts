@echo off
echo Cleaning...
rem cd /d "%~dp0git"
cd /d C:\Projects\Test\mrg3\
if errorlevel 1 exit /B 100

del /Q *.*
for /D %%d in (*.*) do if NOT "%%d" == ".git" call :dl %%d
goto :EOF

:dl
rd /S /Q %1 1> nul 2> nul
if errorlevel 1 exit /B 1
goto :EOF
