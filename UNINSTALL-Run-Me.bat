@echo off
REM ============================================================
REM  Standalone launcher for Uninstall-LocalAI.ps1
REM ============================================================
title NoobAI - Clean Uninstaller
color 0C

echo.
echo  =====================================================
echo    NOOB AI - CLEAN UNINSTALLER
echo  =====================================================
echo.
echo   This will walk you through removing everything.
echo   You will be asked Y/N for EVERY step. Default is NO.
echo.
pause
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-LocalAI.ps1"
echo.
pause
