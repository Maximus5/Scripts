@echo off
if "%~6" == "" (
  Echo Usage: %~nx0 ^<commit^> ^<title^> ^<descr^> ^<user^> ^<project^> "<file1|file2>"
  exit /b 1
)
@call "%~dp0SetPwd.cmd"
powershell -noprofile -command "& {%~dp0GithubReleaseAny.ps1 -token %GitHubToken% -tag '%~1' -name '%~2' -descr '%~3' -user '%~4' -project '%~5' -file '%~6' }"
