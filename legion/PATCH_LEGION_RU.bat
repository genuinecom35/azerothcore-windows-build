@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
if errorlevel 1 (
  echo ERROR: Cannot open this client folder.
  pause
  exit /b 1
)
echo ==========================================================
echo Legion 7.3.5.26972 - connection_patcher launcher
echo ==========================================================
echo Client folder: %CD%
echo.
if not exist "Wow.exe" (
  echo ERROR: Wow.exe was not found.
  echo Put PATCH_LEGION_RU.bat next to Wow.exe.
  goto :error
)
if exist ".build.info" (
  findstr /C:"7.3.5.26972" ".build.info" >nul 2>&1
  if errorlevel 1 (
    echo ERROR: .build.info does not show build 7.3.5.26972.
    goto :error
  )
  echo Client build 7.3.5.26972 verified.
) else (
  echo WARNING: .build.info not found; verify client version manually.
)
set "PATCHER="
if exist "%~dp0connection_patcher.exe" set "PATCHER=%~dp0connection_patcher.exe"
if not defined PATCHER if exist "C:\WoW-Legion-Server\connection_patcher.exe" set "PATCHER=C:\WoW-Legion-Server\connection_patcher.exe"
if not defined PATCHER if exist "C:\WoW-Legion-Server" (
  for /f "delims=" %%P in ('where /r "C:\WoW-Legion-Server" connection_patcher.exe 2^>nul') do if not defined PATCHER set "PATCHER=%%P"
)
if not defined PATCHER (
  echo ERROR: connection_patcher.exe was not found.
  echo Copy the patcher from YOUR LegionCore server package
  echo into this CLIENT folder next to PATCH_LEGION_RU.bat.
  goto :error
)
echo Patcher found: %PATCHER%
if not exist "Wow.exe.original.bak" (
  copy /b "Wow.exe" "Wow.exe.original.bak" >nul
  if errorlevel 1 (
    echo ERROR: Cannot back up Wow.exe.
    goto :error
  )
)
if exist "Wow_Patched.exe" (
  call :save_old_patched
  if errorlevel 1 goto :error
)
echo Running connection_patcher on Wow.exe...
"%PATCHER%" "%CD%\Wow.exe"
set "PATCH_RC=%ERRORLEVEL%"
echo.
if exist "Wow_Patched.exe" (
  echo SUCCESS: Wow_Patched.exe was created.
  if not "%PATCH_RC%"=="0" echo WARNING: Patcher returned %PATCH_RC%. Review output above.
  echo Set portal in WTF\Config.wtf, start the servers, then start Wow_Patched.exe.
  pause
  exit /b 0
)
echo ERROR: Wow_Patched.exe was not created. Patcher returned %PATCH_RC%.
goto :error
:save_old_patched
set "OLD_PATCHED=Wow_Patched.previous_%RANDOM%_%RANDOM%.exe"
if exist "%OLD_PATCHED%" goto :save_old_patched
move "Wow_Patched.exe" "%OLD_PATCHED%" >nul
if errorlevel 1 (
  echo ERROR: Cannot preserve existing Wow_Patched.exe.
  exit /b 1
)
exit /b 0
:error
echo Patching failed. Server, databases and original Wow.exe were not changed.
pause
exit /b 1
