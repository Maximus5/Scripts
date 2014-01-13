@echo off
cd /d "%~dp0git"

set /P commit=<C:\Project\Maximus5\Test\cur\.git\rebase-apply\patch
set commit=%commit:~0,16%
echo Commit: %commit%

C:\Utils\Lans\GIT\bin\git.exe checkout -f %commit%
if errorlevel 1 goto err

if exist C:\Project\Maximus5\Test\cur\Release rd /s /q C:\Project\Maximus5\Test\cur\Release
if errorlevel 1 goto err
if exist C:\Project\Maximus5\Test\cur\src rd /s /q C:\Project\Maximus5\Test\cur\src
if errorlevel 1 goto err

rem pause
echo Sleeping 2 sec ]9;1;2000\

move C:\Project\Maximus5\Test\temp\git\Release C:\Project\Maximus5\Test\cur\
if errorlevel 1 goto err

move C:\Project\Maximus5\Test\temp\git\src C:\Project\Maximus5\Test\cur\
if errorlevel 1 goto err

cd /d C:\Project\Maximus5\Test\cur\

cd

powershell -noprofile "%~dp0UpdateIndex.ps1"
if errorlevel 1 (
call cecho "powershell rc = %errorlevel%"
exit 1
)

goto :EOF

:err
call cecho "Command failed!"
exit 99
