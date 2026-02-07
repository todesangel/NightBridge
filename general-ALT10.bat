@echo off
setlocal

set "TARGET=%~dp0general-SIMPLE-FAKE.bat"
if not exist "%TARGET%" (
  echo [ERROR] Missing profile: general-SIMPLE-FAKE.bat
  exit /b 1
)

echo [INFO] Redirecting to general-SIMPLE-FAKE.bat
call "%TARGET%" %*
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%
