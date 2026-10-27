@echo off
setlocal
chcp 65001 >nul
set "MYSQL=C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
set "DUMP=C:\Program Files\MySQL\MySQL Server 8.4\bin\mysqldump.exe"
set "PATCH=%~dp0ALTERSHOP_GM_ISLAND.sql"
set "BACKUP=%~dp0acore_world_before_altershop_%RANDOM%_%RANDOM%.sql"

if not exist "%PATCH%" (
  echo ERROR: ALTERSHOP_GM_ISLAND.sql is not in this folder.
  pause
  exit /b 1
)
if not exist "%MYSQL%" (
  echo ERROR: Cannot find %MYSQL%
  echo Edit this .cmd file to point to MySQL 8.4 installation.
  pause
  exit /b 1
)
if not exist "%DUMP%" (
  echo ERROR: Cannot find %DUMP%
  pause
  exit /b 1
)
powershell.exe -NoProfile -Command "if (Get-NetTCPConnection -LocalPort 8085 -State Listen -ErrorAction SilentlyContinue) { exit 10 } else { exit 0 }"
if errorlevel 1 (
  echo ERROR: Worldserver is still listening on port 8085.
  echo Stop Worldserver and run this installer again. Do not stop MySQL.
  pause
  exit /b 1
)
echo ==========================================
echo AzerothCore AlterShop / GM Island installer
echo Database: acore_world
echo This will add custom NPC vendors and teleport alias.
echo Authserver may remain online; Worldserver must be OFF.
echo ==========================================
choice /C YN /M "Proceed with database backup and installation"
if errorlevel 2 exit /b 0
echo Creating database backup: %BACKUP%
"%DUMP%" -h 127.0.0.1 -u root -p --single-transaction --default-character-set=utf8mb4 acore_world > "%BACKUP%"
if errorlevel 1 (
  echo ERROR: Backup failed, no SQL patch was imported.
  pause
  exit /b 1
)
for %%F in ("%BACKUP%") do if %%~zF LSS 1024 (
  echo ERROR: Backup seems empty. Patch not imported.
  pause
  exit /b 1
)
echo Backup complete. Password will be requested again for SQL import.
"%MYSQL%" -h 127.0.0.1 -u root -p --default-character-set=utf8mb4 acore_world < "%PATCH%"
if errorlevel 1 (
  echo ERROR: SQL import failed or partially completed. Review output.
  echo Database backup remains at: %BACKUP%
  pause
  exit /b 1
)
echo ==========================================
echo Import finished. Restart Worldserver.
echo In GM chat: .tele GMIsland
echo Alternative: .tele AlterShop
echo Shop NPC ids: 930101 to 930112
echo ==========================================
pause
exit /b 0
