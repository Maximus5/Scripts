@echo off

rem If your local ".svn" folders was broken,
rem you may redownload them with "svn co https://..."
rem but how to place them in right place?
rem ".svn" exists in all subfolders of the project...
rem Call this batch from TEMPORARY COPY project root
rem ALL FILES except of ".svn" folders will BE DELETED!
rem After that, you may copy all folders
rem in the right place to restore your local ".svn" copy...

setlocal

if "%~1" == "" goto init
call :do_del "%~1"

:init
set src_dir=%CD%
call cecho "%src_dir%\"
call cecho "Remove ALL non .svn files?"
set /P YES=[y/N]
if /I "%YES%" == "Y" call :do_del "%src_dir%"
goto :EOF

:do_del

cd /d "%~1"
echo '%~1'
del /Q *.*
for /D %%g in (*) do (
if NOT "%%g" == ".svn" call :do_del "%~1\%%g"
)
