@echo off
setlocal

set "TARGET=%~dp0general-ALT-HOSTFAKESPLIT.bat"
if not exist "%TARGET%" (
  echo [ERROR] Missing profile: general-ALT-HOSTFAKESPLIT.bat
  exit /b 1
)

echo [INFO] Redirecting to general-ALT-HOSTFAKESPLIT.bat
call "%TARGET%" %*
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%
