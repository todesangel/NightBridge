@echo off
setlocal

set "TARGET=%~dp0general-ALT-MULTISPLIT.bat"
if not exist "%TARGET%" (
  echo [ERROR] Missing profile: general-ALT-MULTISPLIT.bat
  exit /b 1
)

echo [INFO] Redirecting to general-ALT-MULTISPLIT.bat
call "%TARGET%" %*
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%
