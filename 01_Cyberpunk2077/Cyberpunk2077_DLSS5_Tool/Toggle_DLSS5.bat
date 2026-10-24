@echo off
setlocal
title Cyberpunk2077 DLSS5 Tool
powershell.exe -NoLogo -NoProfile -File "%~dp0DLSS5Control.ps1" -Action Menu
if errorlevel 1 (
 echo Tool stopped. Review the error above. No security policy is changed by this launcher.
 pause
)
endlocal