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

echo [INFO] General profile mode: %MODE%

if /I "%MODE%"=="off" goto domains
if /I "%MODE%"=="on" goto ranges

call :domains_apply
call :ranges_apply
goto done

:domains
call :domains_apply
goto done

:ranges
call :ranges_apply
goto done

:domains_apply
for %%F in ("%LIST_DIR%\list-general.txt") do (
  if exist "%%~fF" (
    for /f "usebackq tokens=* delims=" %%D in ("%%~fF") do (
      set "ENTRY=%%D"
      if not "!ENTRY!"=="" if not "!ENTRY:~0,1!"=="#" call :apply_domain "!ENTRY!"
    )
  ) else (
    echo [WARN] Missing file: %%~fF
  )
)
exit /b 0

:ranges_apply
for %%F in ("%IPSET_DIR%\discord.txt" "%IPSET_DIR%\cloudflare.txt") do (
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

:apply_domain
echo [GENERAL-DOMAIN] %~1
exit /b 0

:apply_ip
echo [GENERAL-IPSET] %~1
exit /b 0

:done
echo [OK] General profile applied.
exit /b 0
