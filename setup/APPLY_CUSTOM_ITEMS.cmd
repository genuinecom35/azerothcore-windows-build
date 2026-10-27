@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0APPLY_CUSTOM_ITEMS.ps1"
if errorlevel 1 echo Failed - read the message above.
pause
