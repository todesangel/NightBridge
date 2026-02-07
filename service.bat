@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "MODE=%~1"
if /I "%MODE%"=="" set "MODE=any"
if /I not "%MODE%"=="on" if /I not "%MODE%"=="off" if /I not "%MODE%"=="any" (
  echo [ERROR] Invalid ipset mode: %MODE%
  echo Usage: %~nx0 ^<on^|off^|any^>
  exit /b 1
)

set "ROOT=%~dp0"
set "LIST_DIR=%ROOT%lists"
set "IPSET_DIR=%ROOT%ipset"

echo [INFO] Mode: %MODE%
echo [INFO] Lists: %LIST_DIR%
echo [INFO] Ipsets: %IPSET_DIR%

if /I "%MODE%"=="off" goto domain_only
if /I "%MODE%"=="on" goto ipset_only

call :apply_domains "%LIST_DIR%\list-general.txt" "%LIST_DIR%\list-google.txt" "%LIST_DIR%\list-exclude.txt"
call :apply_ipsets "%IPSET_DIR%\discord.txt" "%IPSET_DIR%\cloudflare.txt" "%IPSET_DIR%\google.txt" "%IPSET_DIR%\youtube.txt"
goto done

:domain_only
call :apply_domains "%LIST_DIR%\list-general.txt" "%LIST_DIR%\list-google.txt" "%LIST_DIR%\list-exclude.txt"
goto done

:ipset_only
call :apply_ipsets "%IPSET_DIR%\discord.txt" "%IPSET_DIR%\cloudflare.txt" "%IPSET_DIR%\google.txt" "%IPSET_DIR%\youtube.txt"
goto done

:apply_domains
set "EXCLUDE_FILE=%~3"

echo [STEP] Loading domain lists...
for %%F in (%1 %2) do (
  if exist "%%~fF" (
    for /f "usebackq tokens=* delims=" %%D in ("%%~fF") do (
      set "ENTRY=%%D"
      if not "!ENTRY!"=="" if not "!ENTRY:~0,1!"=="#" (
        call :is_excluded "!ENTRY!" "%EXCLUDE_FILE%"
        if errorlevel 1 (
          call :apply_domain "!ENTRY!"
        ) else (
          echo [SKIP] !ENTRY! ^(excluded^)
        )
      )
    )
  ) else (
    echo [WARN] Missing file: %%~fF
  )
)
exit /b 0

:apply_ipsets
echo [STEP] Loading ipset ranges...
for %%F in (%1 %2 %3 %4) do (
  if exist "%%~fF" (
    for /f "usebackq tokens=* delims=" %%I in ("%%~fF") do (
      set "CIDR=%%I"
      if not "!CIDR!"=="" if not "!CIDR:~0,1!"=="#" call :apply_ip "!CIDR!"
    )
  ) else (
    echo [WARN] Missing file: %%~fF
  )
)
exit /b 0

:is_excluded
set "DOMAIN=%~1"
set "EXCLUDE_FILE=%~2"
if not exist "%EXCLUDE_FILE%" exit /b 1
for /f "usebackq tokens=* delims=" %%E in ("%EXCLUDE_FILE%") do (
  set "RULE=%%E"
  if not "!RULE!"=="" if not "!RULE:~0,1!"=="#" (
    if /I "!DOMAIN!"=="!RULE!" exit /b 0
    echo !DOMAIN!| findstr /I /R ".*\!RULE!$" >nul && exit /b 0
  )
)
exit /b 1

:apply_domain
set "D=%~1"
rem Replace this echo with your command for adding domain-based bypass/proxy rules.
echo [DOMAIN] %D%
exit /b 0

:apply_ip
set "RANGE=%~1"
rem Replace this echo with your command for adding ipset based rules.
echo [IPSET] %RANGE%
exit /b 0

:done
echo [OK] Completed.
exit /b 0
