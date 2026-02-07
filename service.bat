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
set "TMP_DIR=%ROOT%runtime"
set "HOSTLIST_TMP=%TMP_DIR%\hostlist-active.txt"
set "IPSET_TMP=%TMP_DIR%\ipset-active.txt"

set "WINWS=%ROOT%winws.exe"
if not exist "%WINWS%" set "WINWS=winws.exe"

echo [INFO] Mode: %MODE%
echo [INFO] Lists: %LIST_DIR%
echo [INFO] Ipsets: %IPSET_DIR%

call :auto_mkdir "%TMP_DIR%"
if errorlevel 1 exit /b 1

> "%HOSTLIST_TMP%" type nul
> "%IPSET_TMP%" type nul

if /I "%MODE%"=="off" goto domain_only
if /I "%MODE%"=="on" goto ipset_only

call :apply_domains "%LIST_DIR%\list-general.txt" "%LIST_DIR%\list-google.txt" "%LIST_DIR%\list-exclude.txt"
if errorlevel 1 exit /b 1
call :apply_ipsets "%IPSET_DIR%\discord.txt" "%IPSET_DIR%\cloudflare.txt" "%IPSET_DIR%\google.txt" "%IPSET_DIR%\youtube.txt"
if errorlevel 1 exit /b 1
goto launch

:domain_only
call :apply_domains "%LIST_DIR%\list-general.txt" "%LIST_DIR%\list-google.txt" "%LIST_DIR%\list-exclude.txt"
if errorlevel 1 exit /b 1
goto launch

:ipset_only
call :apply_ipsets "%IPSET_DIR%\discord.txt" "%IPSET_DIR%\cloudflare.txt" "%IPSET_DIR%\google.txt" "%IPSET_DIR%\youtube.txt"
if errorlevel 1 exit /b 1
goto launch

:apply_domains
set "EXCLUDE_FILE=%~3"

echo [STEP] Building domain hostlist...
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
echo [STEP] Building ipset list...
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
echo %D%>> "%HOSTLIST_TMP%"
exit /b 0

:apply_ip
set "RANGE=%~1"
echo %RANGE%>> "%IPSET_TMP%"
exit /b 0

:auto_mkdir
set "TARGET_DIR=%~1"
if exist "%TARGET_DIR%" exit /b 0
mkdir "%TARGET_DIR%" >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Cannot create directory: %TARGET_DIR%
  exit /b 1
)
exit /b 0

:launch
if "%DRY_RUN%"=="1" (
  echo [INFO] DRY_RUN=1, skipping winws launch.
  goto done
)

if exist "%WINWS%" (
  rem ok, local executable found
) else (
  where winws.exe >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] winws.exe not found. Put winws.exe next to service.bat or into PATH.
    exit /b 1
  )
  set "WINWS=winws.exe"
)

set "CMD=\"%WINWS%\" --wf-tcp=80,443 --wf-udp=443,50000-50100 --dpi-desync=fake,multisplit --dpi-desync-autottl=2 --dpi-desync-fooling=md5sig"

if /I not "%MODE%"=="on" (
  for %%A in ("%HOSTLIST_TMP%") do if %%~zA GTR 0 set "CMD=!CMD! --hostlist=\"%HOSTLIST_TMP%\""
)
if /I not "%MODE%"=="off" (
  for %%A in ("%IPSET_TMP%") do if %%~zA GTR 0 set "CMD=!CMD! --ipset=\"%IPSET_TMP%\""
)

echo [INFO] Launch command:
echo !CMD!

call !CMD!
set "RC=!ERRORLEVEL!"
if not "!RC!"=="0" (
  echo [ERROR] winws exited with code !RC!
  exit /b !RC!
)

:done
echo [OK] Completed.
exit /b 0
