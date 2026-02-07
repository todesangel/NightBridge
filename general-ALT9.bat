@echo off
setlocal

set "TARGET=%~dp0general-ALT-BADSEQ.bat"
if not exist "%TARGET%" (
  echo [ERROR] Missing profile: general-ALT-BADSEQ.bat
  exit /b 1
)

echo [INFO] Redirecting to general-ALT-BADSEQ.bat
call "%TARGET%" %*
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%
