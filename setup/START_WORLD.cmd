@echo off
cd /d "%~dp0"
echo Starting local AzerothCore worldserver...
"%~dp0worldserver.exe" -c "%~dp0configs\worldserver.conf"
echo.
echo Worldserver stopped. Check the message above.
pause
