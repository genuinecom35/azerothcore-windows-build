@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0EXTRACT_CLIENT_DATA.ps1"
if errorlevel 1 (
  echo.
  echo Extraction failed. Read the error above.
  pause
  exit /b 1
)
echo.
echo Client data extraction finished.
pause
