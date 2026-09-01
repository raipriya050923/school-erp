@echo off
setlocal EnableExtensions
title School ERP - dev launcher

REM ===========================================================================
REM  Starts the .NET API and the Angular frontend, each in its own window.
REM
REM  Ports come from the projects themselves, not from this file:
REM    API  5204  (Properties\launchSettings.json, profile "http")
REM    web  4300  (angular.json -> architect.serve.options.port)
REM  The frontend derives its API base from the hostname and expects 5204,
REM  so changing that one means changing src\environments\environment.ts too.
REM  The web port is passed explicitly below as well, so this window and a
REM  hand-run "ng serve" can never disagree about it.
REM
REM  Note: no EnableDelayedExpansion here. It makes "!" a special character,
REM  which silently ate the "!" out of every [!] warning this script prints.
REM
REM  Close this window to leave both running; use stop-dev.bat to stop them.
REM ===========================================================================

set "ROOT=%~dp0"
set "API_DIR=%ROOT%SchoolErp.Api\src\SchoolErp.Api"
set "WEB_DIR=%ROOT%school-erp-frontend"
set "API_PORT=5204"
set "WEB_PORT=4300"
set "WEB_URL=http://localhost:%WEB_PORT%"
set "API_URL=http://localhost:%API_PORT%/swagger"

echo.
echo  ==========================================================
echo    School ERP - starting API and frontend
echo  ==========================================================
echo.

REM ---------------------------------------------------------------- checks --
where dotnet >nul 2>&1
if errorlevel 1 (
    echo  [X] "dotnet" is not on PATH. Install the .NET 8 SDK first.
    goto :fail
)

where npm >nul 2>&1
if errorlevel 1 (
    echo  [X] "npm" is not on PATH. Install Node.js first.
    goto :fail
)

if not exist "%API_DIR%\SchoolErp.Api.csproj" (
    echo  [X] API project not found at:
    echo      %API_DIR%
    goto :fail
)

if not exist "%WEB_DIR%\package.json" (
    echo  [X] Frontend not found at:
    echo      %WEB_DIR%
    goto :fail
)

REM Angular will not serve without its packages, and the error it gives when
REM they are missing does not say so plainly.
if not exist "%WEB_DIR%\node_modules" (
    echo  [i] node_modules is missing - running "npm install" once.
    echo      This takes a few minutes on a first run.
    echo.
    pushd "%WEB_DIR%"
    call npm install
    if errorlevel 1 (
        popd
        echo  [X] npm install failed. Fix the error above and re-run.
        goto :fail
    )
    popd
    echo.
)

REM ------------------------------------------------------------------ API ---
call :isportbusy %API_PORT%
if "%BUSY%"=="1" (
    echo  [=] API already listening on %API_PORT% - leaving it alone.
) else (
    echo  [^>] Starting API      ... http://localhost:%API_PORT%
    start "School ERP API" cmd /k "cd /d "%API_DIR%" && dotnet run --launch-profile http"
)

REM ------------------------------------------------------------- frontend ---
call :isportbusy %WEB_PORT%
if "%BUSY%"=="1" (
    echo  [=] Frontend already listening on %WEB_PORT% - leaving it alone.
) else (
    echo  [^>] Starting frontend ... %WEB_URL%
    start "School ERP Web" cmd /k "cd /d "%WEB_DIR%" && npm start -- --port %WEB_PORT%"
)

echo.
echo  Waiting for both to come up...

call :waitport %API_PORT% 90
if errorlevel 1 (
    echo  [!] API did not answer on %API_PORT% within 90s - check its window.
) else (
    echo  [OK] API      %API_URL%
)

REM The first Angular build is the slow one, so it gets a longer budget.
call :waitport %WEB_PORT% 180
if errorlevel 1 (
    echo  [!] Frontend did not answer on %WEB_PORT% within 180s - check its window.
    goto :done
)
echo  [OK] Frontend %WEB_URL%

echo.
echo  Opening %WEB_URL%
start "" "%WEB_URL%"

:done
echo.
echo  Both run in their own windows. Close those windows or run stop-dev.bat.
echo.
pause
exit /b 0

:fail
echo.
pause
exit /b 1


REM ===========================================================================
REM  Subroutines
REM ===========================================================================

REM Sets BUSY=1 when something is already LISTENING on the given port.
REM The trailing space in the pattern stops :4300 matching :43001.
:isportbusy
set "BUSY=0"
for /f "delims=" %%A in ('netstat -ano ^| findstr /r /c:"LISTENING" ^| findstr /c:":%~1 "') do set "BUSY=1"
exit /b 0

REM :waitport <port> <seconds> - returns 0 once the port accepts a connection.
:waitport
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$end=[DateTime]::Now.AddSeconds(%~2);" ^
  "while([DateTime]::Now -lt $end){" ^
  "  try{$c=New-Object Net.Sockets.TcpClient;$c.Connect('127.0.0.1',%~1);$c.Close();exit 0}" ^
  "  catch{Start-Sleep -Milliseconds 700}" ^
  "}; exit 1"
exit /b %errorlevel%
