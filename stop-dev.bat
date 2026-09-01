@echo off
setlocal EnableExtensions
title School ERP - stop dev servers

REM ===========================================================================
REM  Stops whatever is listening on the two dev ports.
REM
REM  It kills by port, not by image name, so it never touches an unrelated
REM  dotnet or node process you have running for something else.
REM
REM  Two things this gets right that the obvious version does not:
REM
REM  1. A listener shows up in netstat twice - once for 127.0.0.1 and once for
REM     [::1] - with the SAME pid. Killing per row killed it, then tried again
REM     and reported a failure for a process that was already gone. Pids are
REM     de-duplicated with a "SEEN_<pid>" marker before anything is killed.
REM
REM  2. No EnableDelayedExpansion. With it on, "!" is a special character and
REM     every [!] warning printed as [] with the mark stripped out.
REM ===========================================================================

call :killport 5204 API
call :killport 4300 Frontend

REM 4200 was the frontend port before it moved to 4300; clean up a stale one.
REM The label must not contain parentheses - it is echoed inside an if-block,
REM where an unquoted ")" closes the block early and the parser gives up.
call :killport 4200 "Frontend on old port"

echo.
pause
exit /b 0


:killport
set "PORT=%~1"
set "LABEL=%~2"
set "FOUND=0"

for /f "tokens=5" %%P in ('netstat -ano ^| findstr /r /c:"LISTENING" ^| findstr /c:":%PORT% "') do (
    if not "%%P"=="0" if not defined SEEN_%%P (
        set "SEEN_%%P=1"
        set "FOUND=1"
        echo  [^>] Stopping %LABEL% on %PORT% ^(pid %%P^)
        taskkill /PID %%P /T /F >nul 2>&1
    )
)

if "%FOUND%"=="0" (
    echo  [=] Nothing listening on %PORT% - %LABEL% is not running.
    exit /b 0
)

REM Trust the port, not taskkill's exit code: a child process dying with its
REM parent can make taskkill report an error for work that actually succeeded.
call :isportbusy %PORT%
if "%BUSY%"=="1" (
    echo  [!] %PORT% is still in use - try running this as administrator.
) else (
    echo  [OK] %LABEL% stopped.
)
exit /b 0


:isportbusy
set "BUSY=0"
for /f "delims=" %%A in ('netstat -ano ^| findstr /r /c:"LISTENING" ^| findstr /c:":%~1 "') do set "BUSY=1"
exit /b 0
