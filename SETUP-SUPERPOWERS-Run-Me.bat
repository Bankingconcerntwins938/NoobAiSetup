@echo off
REM ============================================================
REM  Standalone launcher for Setup-MCP-Superpowers.ps1
REM ============================================================
title NoobAI - MCP Superpowers (100%% Free)
color 0D

echo.
echo  =====================================================
echo    MCP SUPERPOWERS - 100%% FREE
echo  =====================================================
echo.
echo   No API keys. No accounts. No credit cards.
echo   No "free trial". No phone-home.
echo   Everything runs on YOUR PC.
echo.
echo   Adds these abilities to your AI crew:
echo     - Web search (DuckDuckGo, no key needed)
echo     - Web page reading
echo     - Long-term memory across chats
echo     - Step-by-step reasoning
echo     - Git operations
echo     - SQLite databases
echo     - Fast filesystem access
echo     - Time/date math
echo.
echo   Run SETUP-CREW-Run-Me.bat FIRST if you haven't.
echo.
pause
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-MCP-Superpowers.ps1"
echo.
pause
