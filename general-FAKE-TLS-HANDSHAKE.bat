@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ================================================================
rem Профиль: general-FAKE-TLS-HANDSHAKE.bat
rem Для каких блокировок: DPI, который режет TLS по ClientHello/SNI сигнатурам.
rem Побочные эффекты: иногда ломает нестандартные TLS-сервисы, возможны редкие timeouts.
rem Когда использовать: если HTTPS/QUIC блокируется по TLS-отпечаткам.
rem ================================================================

rem --- Единый блок переменных ---
set "PORTS_HTTP=80,8080"
set "PORTS_HTTPS=443,8443"
set "PORTS_DISCORD=50000-50100"
set "PORTS_GAME=27000-27200"
set "IPSET_MODE=off"
set "RETRY=3"
set "TIMEOUT=4"
set "SNI_MODE=strict"

rem Параметры профиля
set "DESYNC_MODE=fake"
set "DESYNC_FLAGS=--dpi-desync-fake-tls hello --dpi-desync-fooling md5sig"
set "FAKE_TLS_MODE=on"

rem --- Формирование командной строки winws/zapret ---
set "WINWS=%~dp0winws.exe"
if not exist "%WINWS%" set "WINWS=winws.exe"

set "CMD=\"%WINWS%\" --ports-http %PORTS_HTTP% --ports-https %PORTS_HTTPS% --ports-discord %PORTS_DISCORD% --ports-game %PORTS_GAME% --dpi-desync %DESYNC_MODE% --dpi-desync-repeats %RETRY% --dpi-desync-timeout %TIMEOUT% --dpi-desync-sni %SNI_MODE% %DESYNC_FLAGS%"

if /I "%IPSET_MODE%"=="on" set "CMD=!CMD! --ipset-mode on"
if /I "%FAKE_TLS_MODE%"=="on" set "CMD=!CMD! --fake-tls"

echo [INFO] Running: !CMD!
call !CMD!

endlocal
