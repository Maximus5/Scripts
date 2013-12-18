@echo off
echo Extracting...
rem cd /d "%~dp0git"
cd /d C:\Projects\Test\mrg3\
if errorlevel 1 exit /B 100

set x7z=-x!*.exe -x!*.dll -x!*.7z -x!*.rar -x!*.zip -x!*.pdb -x!*.obj -x!*.map -x!*.bat -x!*.cmd -x!*.exe -x!*.dll
set x7z=%x7z% -x!*.xcf -x!*.idc -x!*.ion -x!*.png -x!*.xcf -x!*.psd -x!*.ini -x!*.xml -x!!*.txt -x!*.log -x!Bugs
set x7z=%x7z% -x!*.pdb -x!*.opt -x!*.lib -x!*.exp -x!*.suo -x!*.user -x!*test* -x!*debug* -x!links -x!help -x!*.plg
set x7z=%x7z% -x!*.base -x!*.tmp -x!enc_temp_folder -x!*.aps -x!*.dl_ -x!ConMan -x!Pics -x!*.db -x!*.bak -x!*.pgc
set x7z=%x7z% -x!*.pgd -x!1.*.txt -x!makefile*.xxx -x!makefile*.ok -x!1 -x!enc*.tmp* -x!PictureView -x!Release.x64
set x7z=%x7z% -x!MouseWheelTilt.reg -x!090517.Show.Elevation.status.txt -x!*.diff -x!*.patch -x!*.cache
set x7z=%x7z% -x!final.*.* -x!release.*.* -x!debug.*.* -x!ConEmu.cer -x!drag -x!*.dsw -x!*.dsp -x!DragDropNew.*
set x7z=%x7z% -x!help -x!src.help -x!src.new_pipe -x!src.no_pipe -x!Win32 "-x!D&D_Orig" "-x!D&D_Tmp"
set x7z=%x7z% -x!Command*.reg -x!png -x!picview2 -x!*_.cpp -x!*.t32 -x!*.t64 -x!mp3 -x!icons -x!old -x!Lite

set arc_name=%~1
if "%arc_name:~-7%" == ".rel.7z" (
if NOT exist Release md Release
cd Release
)

7z x -y -r "%~1" * %x7z%

if errorlevel 1 (
echo 7z fails with code %errorlevel%
exit /B 100
)

if exist src\conemu-stable.sln (
  if NOT exist src\conemu.sln (
    ren src\conemu-stable.sln conemu.sln
  )
)
