@echo off
REM ============================================================
REM  Standalone launcher for Move-AI-Models.ps1
REM ============================================================
title NoobAI - Move AI Models
color 0E

echo.
echo  =====================================================
echo    MOVE OLLAMA AI MODELS SAFELY
echo  =====================================================
echo.
echo   Finds ALL your model folders (even old broken ones
echo   from past moves), lets you pick where they should
echo   live, moves them safely, and updates OLLAMA_MODELS
echo   so Ollama actually FINDS them.
echo.
echo   No more duplicates. No more broken installs.
echo.
pause
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Move-AI-Models.ps1"
echo.
pause
