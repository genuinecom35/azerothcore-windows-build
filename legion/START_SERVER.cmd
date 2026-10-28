@echo off
setlocal
cd /d "%~dp0"

if not exist "bnetserver.conf" (
  echo Missing bnetserver.conf. Run SETUP_DATABASE.cmd first.
  pause
  exit /b 1
)
if not exist "worldserver.conf" (
  echo Missing worldserver.conf. Run SETUP_DATABASE.cmd first.
  pause
  exit /b 1
)
if not exist "bnetserver.cert.pem" (
  echo Missing bnetserver.cert.pem. Battle.net authentication will not start.
  echo Restore original upstream SSL certificate from LegionCore-Reforged.
  pause
  exit /b 1
)
if not exist "bnetserver.key.pem" (
  echo Missing bnetserver.key.pem. Battle.net authentication will not start.
  echo Restore original upstream SSL key from LegionCore-Reforged.
  pause
  exit /b 1
)
if not exist "ClientData\maps" (
  echo Missing ClientData\maps. Run EXTRACT_CLIENT_DATA.cmd first.
  pause
  exit /b 1
)

echo Starting worldserver first. On the first launch it will apply SQL updates.
start "WoW Legion World Server" /D "%~dp0" cmd /k worldserver.exe
echo.
echo Wait in the worldserver window until database updates finish and the server is ready.
echo Then return here and press a key to start bnetserver.
pause >nul
start "WoW Legion Battle.net Server" /D "%~dp0" cmd /k bnetserver.exe
echo.
echo Both launch windows have been opened. Keep them running while you play.
