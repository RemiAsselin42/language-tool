@echo off
cd /d "%~dp0"
:loop
tasklist /FI "IMAGENAME eq zen.exe" | find /I "zen.exe" >nul
if errorlevel 1 (
    timeout /t 15 /nobreak >nul
    goto loop
)
call "%~dp0lt-up.bat"
exit
