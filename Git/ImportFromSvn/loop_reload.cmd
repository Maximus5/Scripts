@echo off

:loop
call C:\Project\Maximus5\Test\temp\reload.cmd
if errorlevel 1 goto err

cd C:\Project\Maximus5\Test\cur\
if errorlevel 1 goto err

C:\Utils\Lans\GIT\bin\git.exe rebase --continue
echo git rc = %errorlevel%
rem pause
if errorlevel 1 goto loop
goto :EOF

:err
call cecho "Failed"
pause
