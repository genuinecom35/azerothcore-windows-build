@echo off
setlocal
cd /d "%~dp0"
echo Copy the data extraction tools into your own WoW 3.3.5a folder.
set /p "WOWPATH=Enter full path to WoW 3.3.5a folder (containing Wow.exe): "
if not exist "%WOWPATH%\Wow.exe" (
  echo Wow.exe not found in that folder.
  pause
  exit /b 1
)
for %%F in (map_extractor.exe vmap4_extractor.exe vmap4_assembler.exe mmaps_generator.exe mmaps-config.yaml extractor.bat) do (
  if exist "%~dp0%%F" (
    copy /Y "%~dp0%%F" "%WOWPATH%\%%F" >nul
  ) else (
    echo WARNING: missing %%F in server folder
  )
)
echo.
echo In the WoW folder, run extractor.bat and follow its menu.
echo When done, copy the generated dbc, maps, vmaps, mmaps directories
echo into "%~dp0Data"
pause
