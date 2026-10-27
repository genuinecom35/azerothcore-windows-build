@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0SETUP_SERVER.ps1"
if errorlevel 1 (
  echo.
  echo Setup did not finish. Read the error above.
)
pause
