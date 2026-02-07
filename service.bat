@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "LOG_DIR=%SCRIPT_DIR%\logs"
set "LOG_FILE=%LOG_DIR%\service.log"
set "SERVICE_NAME=zapret"
set "SERVICE_DISPLAY_NAME=Zapret Service"
set "SERVICE_BIN=%SCRIPT_DIR%\zapret.exe"
set "MODE_FILE=%SCRIPT_DIR%\config\modes.env"
set "PROFILE_DIR=%SCRIPT_DIR%\profiles"
set "VERSION_FILE=%SCRIPT_DIR%\VERSION"
set "UPDATE_URL="
if exist "%SCRIPT_DIR%\update.url" set /p UPDATE_URL=<"%SCRIPT_DIR%\update.url"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
call :log "Command: %*"

if "%~1"=="" goto :usage

set "cmd=%~1"
if /I "%cmd%"=="admin" goto :cmd_admin
if /I "%cmd%"=="status_zapret" goto :cmd_status
if /I "%cmd%"=="install" goto :cmd_install
if /I "%cmd%"=="remove" goto :cmd_remove
if /I "%cmd%"=="diag" goto :cmd_diag
if /I "%cmd%"=="filter" goto :cmd_filter
if /I "%cmd%"=="ipset" goto :cmd_ipset
if /I "%cmd%"=="update_check" goto :cmd_update_check

echo Unknown command: %cmd%
call :log "Unknown command: %cmd%"
goto :usage

:cmd_admin
call :require_admin || exit /b 1
call :admin_menu
exit /b %errorlevel%

:cmd_status
call :print_status
exit /b %errorlevel%

:cmd_install
call :require_admin || exit /b 1
call :resolve_profile "%~2" || exit /b 1
call :install_service
exit /b %errorlevel%

:cmd_remove
call :require_admin || exit /b 1
call :remove_service
exit /b %errorlevel%

:cmd_diag
call :diagnostics
exit /b %errorlevel%

:cmd_filter
if "%~2"=="" (
    echo Usage: service.bat filter game on^|off
    exit /b 1
)
if /I not "%~2"=="game" (
    echo Only "filter game" is supported.
    exit /b 1
)
if /I "%~3"=="on" (
    call :set_mode "FILTER_GAME" "on"
    exit /b 0
)
if /I "%~3"=="off" (
    call :set_mode "FILTER_GAME" "off"
    exit /b 0
)
echo Usage: service.bat filter game on^|off
exit /b 1

:cmd_ipset
if "%~2"=="" (
    echo Usage: service.bat ipset on^|off^|any
    exit /b 1
)
if /I "%~2"=="on" (
    call :set_mode "IPSET_MODE" "on"
    exit /b 0
)
if /I "%~2"=="off" (
    call :set_mode "IPSET_MODE" "off"
    exit /b 0
)
if /I "%~2"=="any" (
    call :set_mode "IPSET_MODE" "any"
    exit /b 0
)
echo Usage: service.bat ipset on^|off^|any
exit /b 1

:cmd_update_check
call :update_check
exit /b %errorlevel%

:usage
echo Usage:
echo   service.bat admin
echo   service.bat status_zapret
echo   service.bat install ^<profile^>
echo   service.bat remove
echo   service.bat diag
echo   service.bat filter game on^|off
echo   service.bat ipset on^|off^|any
echo   service.bat update_check
exit /b 1

:require_admin
net session >nul 2>&1
if not errorlevel 1 (
    call :log "Admin rights confirmed"
    exit /b 0
)
echo Administrator rights are required.
call :log "ERROR: Admin rights required"
exit /b 1

:resolve_profile
set "RESOLVED_PROFILE=%~1"
if "%RESOLVED_PROFILE%"=="" set "RESOLVED_PROFILE=default"
if exist "%PROFILE_DIR%\%RESOLVED_PROFILE%.conf" (
    call :log "Profile resolved: %RESOLVED_PROFILE%"
    exit /b 0
)
if exist "%SCRIPT_DIR%\%RESOLVED_PROFILE%.conf" (
    call :log "Profile resolved (root): %RESOLVED_PROFILE%"
    exit /b 0
)
echo Profile not found: %RESOLVED_PROFILE%
call :log "ERROR: Profile not found: %RESOLVED_PROFILE%"
exit /b 1

:install_service
sc query "%SERVICE_NAME%" >nul 2>&1
if not errorlevel 1 (
    echo Service %SERVICE_NAME% exists. Reinstalling...
    call :log "Existing service detected; removing before install"
    call :remove_service || exit /b 1
)

if not exist "%SERVICE_BIN%" (
    echo Binary not found: %SERVICE_BIN%
    call :log "ERROR: Service binary missing: %SERVICE_BIN%"
    exit /b 1
)

set "BIN_ARGS=\"%SERVICE_BIN%\" --profile %RESOLVED_PROFILE%"
sc create "%SERVICE_NAME%" binPath= "%BIN_ARGS%" start= auto DisplayName= "%SERVICE_DISPLAY_NAME%" >nul
if errorlevel 1 (
    echo Failed to create service.
    call :log "ERROR: sc create failed"
    exit /b 1
)

sc description "%SERVICE_NAME%" "Zapret filtering service (%RESOLVED_PROFILE%)" >nul 2>&1
sc start "%SERVICE_NAME%" >nul 2>&1

echo Service installed with profile: %RESOLVED_PROFILE%
call :log "Service installed profile=%RESOLVED_PROFILE%"
exit /b 0

:remove_service
sc stop "%SERVICE_NAME%" >nul 2>&1
sc delete "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo Failed to remove service or service does not exist.
    call :log "ERROR: sc delete failed"
    exit /b 1
)
echo Service removed.
call :log "Service removed"
exit /b 0

:print_status
echo === Service status: %SERVICE_NAME% ===
sc query "%SERVICE_NAME%"
set "svc_rc=%errorlevel%"

set "proc_found=0"
for /f "tokens=1" %%P in ('tasklist /FI "IMAGENAME eq zapret.exe" /NH 2^>nul ^| findstr /I "zapret.exe"') do set "proc_found=1"
if "%proc_found%"=="1" (
    echo Process: zapret.exe is running
) else (
    echo Process: zapret.exe is not running
)

if exist "%LOG_FILE%" (
    echo Log file exists: %LOG_FILE%
    for %%A in ("%LOG_FILE%") do echo Log size: %%~zA bytes
) else (
    echo Log file is missing: %LOG_FILE%
)

call :log "Status requested svc_rc=%svc_rc% proc=%proc_found%"
exit /b 0

:diagnostics
echo === Diagnostics ===

net session >nul 2>&1
if errorlevel 1 (
    echo Admin rights: NO
    call :log "Diagnostics: admin=no"
) else (
    echo Admin rights: YES
    call :log "Diagnostics: admin=yes"
)

if exist "%SCRIPT_DIR%\WinDivert.dll" (
    echo WinDivert.dll: FOUND
) else (
    echo WinDivert.dll: MISSING
)
if exist "%SCRIPT_DIR%\WinDivert64.sys" (
    echo WinDivert64.sys: FOUND
) else (
    echo WinDivert64.sys: MISSING
)

if exist "%SERVICE_BIN%" (
    echo Service binary: FOUND (%SERVICE_BIN%)
) else (
    echo Service binary: MISSING (%SERVICE_BIN%)
)

if exist "%PROFILE_DIR%" (
    echo Profiles directory: FOUND (%PROFILE_DIR%)
    dir /b "%PROFILE_DIR%\*.conf" 2>nul
) else (
    echo Profiles directory: MISSING (%PROFILE_DIR%)
)

if exist "%SCRIPT_DIR%\lists" (
    echo Lists directory: FOUND (%SCRIPT_DIR%\lists)
) else (
    echo Lists directory: MISSING (%SCRIPT_DIR%\lists)
)

call :log "Diagnostics completed"
exit /b 0

:set_mode
set "mode_key=%~1"
set "mode_val=%~2"
if not exist "%SCRIPT_DIR%\config" mkdir "%SCRIPT_DIR%\config" >nul 2>&1

if exist "%MODE_FILE%" (
    powershell -NoProfile -Command "(Get-Content -LiteralPath '%MODE_FILE%') -replace '^%mode_key%=.*','%mode_key%=%mode_val%' | Set-Content -LiteralPath '%MODE_FILE%'" >nul 2>&1
    findstr /B /C:"%mode_key%=" "%MODE_FILE%" >nul 2>&1
    if errorlevel 1 echo %mode_key%=%mode_val%>>"%MODE_FILE%"
) else (
    >"%MODE_FILE%" echo %mode_key%=%mode_val%
)

echo %mode_key% set to %mode_val%
call :log "Mode switch %mode_key%=%mode_val%"
exit /b 0

:update_check
set "local_version=unknown"
if exist "%VERSION_FILE%" set /p local_version=<"%VERSION_FILE%"
echo Local version: %local_version%
call :log "Update check local_version=%local_version%"

if "%UPDATE_URL%"=="" (
    echo Remote check: skipped ^(update.url is not configured^)
    call :log "Update check skipped: no update.url"
    exit /b 0
)

echo Checking remote config/version: %UPDATE_URL%
for /f "usebackq delims=" %%R in (`powershell -NoProfile -Command "try { (Invoke-WebRequest -UseBasicParsing '%UPDATE_URL%').Content } catch { exit 2 }"`) do set "remote_payload=%%R"
if errorlevel 1 (
    echo Remote check: failed
    call :log "Update check failed url=%UPDATE_URL%"
    exit /b 1
)

echo Remote payload: %remote_payload%
call :log "Update check success url=%UPDATE_URL% payload=%remote_payload%"
exit /b 0

:admin_menu
echo.
echo === Service admin menu ===
echo 1^)^ Install/reinstall service ^(auto-start^)
echo 2^)^ Install service ^(manual start^)
echo 3^)^ Remove service
echo 4^)^ Status
echo 5^)^ Diagnostics
set /p "menu_choice=Select action [1-5]: "

if "%menu_choice%"=="1" (
    set /p "chosen_profile=Profile name [default]: "
    call :resolve_profile "%chosen_profile%" || exit /b 1
    call :install_service
    exit /b %errorlevel%
)
if "%menu_choice%"=="2" (
    set /p "chosen_profile=Profile name [default]: "
    call :resolve_profile "%chosen_profile%" || exit /b 1
    sc query "%SERVICE_NAME%" >nul 2>&1
    if not errorlevel 1 call :remove_service || exit /b 1
    if not exist "%SERVICE_BIN%" (
        echo Binary not found: %SERVICE_BIN%
        exit /b 1
    )
    set "BIN_ARGS=\"%SERVICE_BIN%\" --profile %RESOLVED_PROFILE%"
    sc create "%SERVICE_NAME%" binPath= "%BIN_ARGS%" start= demand DisplayName= "%SERVICE_DISPLAY_NAME%" >nul
    if errorlevel 1 (
        echo Failed to create service.
        call :log "ERROR: admin menu manual install failed"
        exit /b 1
    )
    echo Service installed in manual mode.
    call :log "Service installed manual profile=%RESOLVED_PROFILE%"
    exit /b 0
)
if "%menu_choice%"=="3" (
    call :remove_service
    exit /b %errorlevel%
)
if "%menu_choice%"=="4" (
    call :print_status
    exit /b %errorlevel%
)
if "%menu_choice%"=="5" (
    call :diagnostics
    exit /b %errorlevel%
)

echo Invalid menu option.
exit /b 1

:log
set "ts=%date% %time%"
>>"%LOG_FILE%" echo [%ts%] %~1
exit /b 0
