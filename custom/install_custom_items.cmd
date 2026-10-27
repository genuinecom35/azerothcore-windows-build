@echo off
setlocal
chcp 65001 >nul
set "DB=%~1"
if not defined DB set "DB=acore_world"
where mysql >nul 2>&1
if errorlevel 1 (
  echo MySQL client mysql.exe not found in PATH.
  echo Install MySQL 8.4 client or run the SQL file manually.
  exit /b 1
)
echo Applying custom item templates and ruRU names to database %DB%...
mysql --default-character-set=utf8mb4 -u root -p "%DB%" < "%~dp0custom_items_ruRU.sql"
if errorlevel 1 (
  echo SQL import failed. Review the error above.
  exit /b 1
)
echo Done. Restart worldserver for item templates to reload.
exit /b 0
