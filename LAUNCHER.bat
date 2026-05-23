@echo off
REM ============================================================
REM  NoobAI Launcher - friendly GUI front door.
REM  Double-click this. That's the only instruction.
REM
REM  Project : NoobAiSetup
REM  Version : 1.0.0
REM  Repo    : https://github.com/LIN4CRE/NoobAiSetup
REM ============================================================
title NoobAI Launcher
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0NoobAI-Launcher.ps1"
