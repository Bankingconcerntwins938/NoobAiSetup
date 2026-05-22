@echo off
REM ============================================================
REM  Standalone launcher for Make-Icon.ps1
REM ============================================================
title NoobAI - Generate Icon
color 0D

echo.
echo  =====================================================
echo    GENERATE NOOB AI ICON + DESKTOP SHORTCUT
echo  =====================================================
echo.
echo   Creates NoobAI.ico (a friendly robot face) and adds
echo   a shortcut on your Desktop pointing to LAUNCHER.bat
echo   so you have one pretty icon to double-click.
echo.
pause
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Make-Icon.ps1"
