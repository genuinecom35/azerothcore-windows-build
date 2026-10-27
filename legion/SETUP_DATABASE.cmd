@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0SETUP_DATABASE.ps1"
if errorlevel 1 (
  echo.
  echo Setup failed. Read the error above. Existing WotLK databases were not targeted.
  pause
  exit /b 1
)
echo.
echo Database setup finished.
pause
