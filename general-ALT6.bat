@echo off
setlocal

set "TARGET=%~dp0general-FAKE-TLS-INITIAL.bat"
if not exist "%TARGET%" (
  echo [ERROR] Missing profile: general-FAKE-TLS-INITIAL.bat
  exit /b 1
)

echo [INFO] Redirecting to general-FAKE-TLS-INITIAL.bat
call "%TARGET%" %*
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%
