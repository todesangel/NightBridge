@echo off
setlocal

set "TARGET=%~dp0general-FAKE-TLS-HANDSHAKE.bat"
if not exist "%TARGET%" (
  echo [ERROR] Missing profile: general-FAKE-TLS-HANDSHAKE.bat
  exit /b 1
)

echo [INFO] Redirecting to general-FAKE-TLS-HANDSHAKE.bat
call "%TARGET%" %*
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%
