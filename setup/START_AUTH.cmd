@echo off
cd /d "%~dp0"
echo Starting local AzerothCore authserver...
"%~dp0authserver.exe" -c "%~dp0configs\authserver.conf"
echo.
echo Authserver stopped. Check the message above.
pause
