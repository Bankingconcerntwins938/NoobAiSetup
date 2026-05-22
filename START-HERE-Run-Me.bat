@echo off
REM ============================================================
REM  Standalone launcher for Setup-LocalAI.ps1
REM  Most users should use LAUNCHER.bat instead - this is here
REM  for people who want to run the steps one at a time.
REM ============================================================
title NoobAI Setup - Base Install
color 0B

echo.
echo  =====================================================
echo    NoobAI - BASE INSTALL
echo  =====================================================
echo.
echo   Installs Ollama, VS Code, Git, the Cline AI agent,
echo   and downloads the qwen3-coder AI model.
echo.
echo   You will see a UAC (Admin) prompt - click YES.
echo.
pause

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-LocalAI.ps1"

echo.
echo  Setup script finished. You can close this window.
pause
