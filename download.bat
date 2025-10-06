@echo off
REM Change directory to the script location
cd /d "%~dp0"
REM Run PowerShell script with temporary bypass
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "dl.ps1" %*
pause