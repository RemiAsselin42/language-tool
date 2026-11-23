@echo off
cd /d "%~dp0"
:loop
rem browsers.txt (written by setup.ps1) lists the process names to wait for, one per line
tasklist /NH | findstr /I /B /L /G:"%~dp0browsers.txt" >nul
if errorlevel 1 (
    timeout /t 15 /nobreak >nul
    goto loop
)
call "%~dp0lt-up.bat"
exit
