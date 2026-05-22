@echo off
REM ============================================================
REM  Standalone launcher for Health-Check.ps1
REM ============================================================
title NoobAI - Health Check
color 0A
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Health-Check.ps1"
