@echo off
setlocal
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0win11_hidden-restart-exposer.ps1" %*
set "result=%errorlevel%"
if not "%~1"=="" exit /b %result%
echo.
pause
exit /b %result%
