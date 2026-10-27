@echo off
cd /d "%~dp0"
if not exist "%~dp0configs\authserver.conf" (
  echo Missing configs\authserver.conf . Run SETUP_SERVER.cmd first.
  pause
  exit /b 1
)
if not exist "%~dp0configs\worldserver.conf" (
  echo Missing configs\worldserver.conf . Run SETUP_SERVER.cmd first.
  pause
  exit /b 1
)
if not exist "%~dp0Data\dbc" (
  echo Mandatory Data\dbc directory not found.
  echo Extract game data from your own WoW 3.3.5a client first.
  pause
  exit /b 1
)
if not exist "%~dp0Data\maps" (
  echo Mandatory Data\maps directory not found.
  echo Extract game data from your own WoW 3.3.5a client first.
  pause
  exit /b 1
)
start "AzerothCore Authserver" cmd /k call "%~dp0START_AUTH.cmd"
timeout /t 5 /nobreak >nul
start "AzerothCore Worldserver" cmd /k call "%~dp0START_WORLD.cmd"
echo.
echo Two server windows were opened. Do not close them while playing.
echo At first launch, confirm automatic database initialization in the server windows.
pause
