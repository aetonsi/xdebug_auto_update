@echo off
where powershell /q
if errorlevel 1 (echo POWERSHELL IS NEEDED FOR THIS SCRIPT TO WORK. & exit /b 2)

set "script_name=%~n0"
if "%~1" EQU "--no-pause" set nopause=1

powershell -File "./%script_name%.ps1" %*

echo EXIT CODE %errorlevel%
if errorlevel 1 if not defined nopause pause
exit /b %errorlevel%