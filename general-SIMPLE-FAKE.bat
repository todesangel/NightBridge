@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ================================================================
rem Профиль: general-SIMPLE-FAKE.bat (упрощенный профиль)
rem Для каких блокировок: типовые SNI/Host-блокировки при умеренно «умном» DPI.
rem Побочные эффекты: минимальные среди fake-профилей, но обход может быть слабее ALT/TLS вариантов.
rem Когда использовать: нужен компромисс между стабильностью и шансом обхода.
rem ================================================================

rem --- Единый блок переменных ---
set "PORTS_HTTP=80,8080"
set "PORTS_HTTPS=443,8443"
set "PORTS_DISCORD=50000-50100"
set "PORTS_GAME=27000-27200"
set "IPSET_MODE=off"
set "RETRY=2"
set "TIMEOUT=3"
set "SNI_MODE=normal"

rem Параметры профиля
set "DESYNC_MODE=fake"
set "DESYNC_FLAGS=--dpi-desync-fooling md5sig"
set "FAKE_TLS_MODE=off"

rem --- Формирование командной строки winws/zapret ---
set "WINWS=%~dp0winws.exe"
if not exist "%WINWS%" set "WINWS=winws.exe"

set "CMD=\"%WINWS%\" --ports-http %PORTS_HTTP% --ports-https %PORTS_HTTPS% --ports-discord %PORTS_DISCORD% --ports-game %PORTS_GAME% --dpi-desync %DESYNC_MODE% --dpi-desync-repeats %RETRY% --dpi-desync-timeout %TIMEOUT% --dpi-desync-sni %SNI_MODE% %DESYNC_FLAGS%"

if /I "%IPSET_MODE%"=="on" set "CMD=!CMD! --ipset-mode on"
if /I "%FAKE_TLS_MODE%"=="on" set "CMD=!CMD! --fake-tls"

echo [INFO] Running: !CMD!
call !CMD!

endlocal
