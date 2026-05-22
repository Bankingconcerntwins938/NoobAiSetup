@echo off
REM ============================================================
REM  Standalone launcher for Setup-AI-Team.ps1
REM ============================================================
title NoobAI - Setup AI Crew
color 0B

echo.
echo  =====================================================
echo    AI CREW SETUP - Foreman + Specialist Workers
echo  =====================================================
echo.
echo   Adds a TEAM of AI specialists to your install:
echo.
echo     Foreman    - the boss, picks who does what
echo     Sysadmin   - Windows updates, PATH, installs
echo     Coder      - writes, builds, debugs code
echo     Librarian  - sorts and organises files (safely)
echo     Researcher - reads docs, writes plans
echo     Inspector  - diagnoses (read-only, safe)
echo.
echo   Run START-HERE-Run-Me.bat FIRST if you haven't.
echo.
pause
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-AI-Team.ps1"
echo.
pause
