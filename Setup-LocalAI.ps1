<#
.SYNOPSIS
    NoobAI base installer - Ollama + VS Code + Cline + AI models.

.DESCRIPTION
    Installs the minimum needed to run a local AI assistant on Windows 11.
    Safe to re-run; skips anything already installed.

.NOTES
    Project : NoobAiSetup
    Version : 1.0.0
    Repo    : https://github.com/LIN4CRE/NoobAiSetup
    License : MIT
#>

# --- self-elevate to Administrator -----------------------------------------
$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# --- pretty printing -------------------------------------------------------
function Write-Step ($m) { Write-Host "`n============================================================" -ForegroundColor Cyan
                           Write-Host " $m" -ForegroundColor Cyan
                           Write-Host "============================================================" -ForegroundColor Cyan }
function Write-OK   ($m) { Write-Host "  [OK]   $m" -ForegroundColor Green }
function Write-Info ($m) { Write-Host "  [INFO] $m" -ForegroundColor Yellow }
function Write-Warn ($m) { Write-Host "  [WARN] $m" -ForegroundColor Magenta }
function Write-Err  ($m) { Write-Host "  [ERR]  $m" -ForegroundColor Red }

Clear-Host
Write-Host @"
   _                    _      _    ___    ___      _
  | |   ___  __ __ _ __| |    /_\  |_ _|  / __| ___| |_ _  _ _ __
  | |__/ _ \/ _/ _` / _` |   / _ \  | |   \__ \/ -_)  _| || | '_ \
  |____\___/\__\__,_\__,_|  /_/ \_\|___|  |___/\___|\__|\_,_| .__/
                                                            |_|
   Ollama + VS Code + Cline + Qwen3-Coder
"@ -ForegroundColor Cyan

Write-Host "`nThis will install (if missing):"
Write-Host "   - Ollama        (runs AI models locally)"
Write-Host "   - VS Code       (the editor that hosts the agent)"
Write-Host "   - Git           (needed by Cline for many tasks)"
Write-Host "   - Cline         (the VS Code extension - your AI agent)"
Write-Host "   - qwen3-coder   (the AI brain, ~9 GB download)"
Write-Host "   - qwen3:8b      (a smaller, faster fallback model)"
Write-Host "   - A launcher    (Launch-AI.bat on your Desktop)"
Write-Host ""
$go = Read-Host "Press ENTER to continue, or type N then ENTER to cancel"
if ($go -match '^[nN]') { Write-Warn "Cancelled by user."; exit }

# --- 1. winget ------------------------------------------------------------
Write-Step "1/6  Checking winget"
try {
    $null = winget --version
    Write-OK "winget is available."
} catch {
    Write-Err "winget not found. Install 'App Installer' from the Microsoft Store, then re-run this script."
    Read-Host "Press ENTER to exit"
    exit 1
}

# --- 2. apps via winget ---------------------------------------------------
function Install-IfMissing {
    param([string]$Id, [string]$Friendly)

    Write-Info "Checking $Friendly ($Id)..."
    $installed = winget list --id $Id --exact --accept-source-agreements 2>$null | Select-String $Id
    if ($installed) {
        Write-OK "$Friendly already installed."
        return
    }
    Write-Info "Installing $Friendly... (this can take a few minutes)"
    winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -eq 0) { Write-OK "$Friendly installed." }
    else { Write-Warn "$Friendly install returned exit code $LASTEXITCODE - continuing anyway." }
}

Write-Step "2/6  Installing applications"
Install-IfMissing -Id 'Ollama.Ollama'              -Friendly 'Ollama'
Install-IfMissing -Id 'Microsoft.VisualStudioCode' -Friendly 'Visual Studio Code'
Install-IfMissing -Id 'Git.Git'                    -Friendly 'Git'

# Refresh PATH so newly installed tools are usable in THIS session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path","User")

# --- 3. Cline extension ---------------------------------------------------
Write-Step "3/6  Installing the Cline extension in VS Code"

$codeCmd = $null
foreach ($p in @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
    "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
)) { if (Test-Path $p) { $codeCmd = $p; break } }
if (-not $codeCmd) { $codeCmd = (Get-Command code -ErrorAction SilentlyContinue).Source }

if ($codeCmd) {
    & $codeCmd --install-extension saoudrizwan.claude-dev --force | Out-Null
    Write-OK "Cline extension installed."
} else {
    Write-Warn "Could not find 'code' command. Open VS Code once, then re-run this script, OR install Cline manually from Extensions panel (search: Cline)."
}

# --- 4. Ollama + models ---------------------------------------------------
Write-Step "4/6  Starting Ollama and downloading qwen3-coder:14b (~9 GB)"

$ollamaExe = (Get-Command ollama -ErrorAction SilentlyContinue).Source
if (-not $ollamaExe) {
    $candidate = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
    if (Test-Path $candidate) { $ollamaExe = $candidate }
}

if (-not $ollamaExe) {
    Write-Err "Ollama not found on PATH. Reboot once and re-run this script."
    Read-Host "Press ENTER to exit"
    exit 1
}

if (-not (Get-Process ollama -ErrorAction SilentlyContinue)) {
    Write-Info "Starting Ollama in the background..."
    Start-Process -FilePath $ollamaExe -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 5
}
Write-OK "Ollama is running."

Write-Info "Pulling qwen3-coder:14b ... (grab a coffee, this is a big download)"
& $ollamaExe pull qwen3-coder:14b
if ($LASTEXITCODE -eq 0) { Write-OK "Main model downloaded." }
else { Write-Warn "Main model pull returned exit code $LASTEXITCODE. Re-run later with:  ollama pull qwen3-coder:14b" }

Write-Info "Pulling qwen3:8b (small fast fallback)..."
& $ollamaExe pull qwen3:8b
if ($LASTEXITCODE -eq 0) { Write-OK "Fallback model downloaded." }
else { Write-Warn "Fallback model pull returned exit code $LASTEXITCODE." }

# --- 5. Desktop launchers + README ---------------------------------------
Write-Step "5/6  Creating Desktop launchers"

$desktop = [Environment]::GetFolderPath("Desktop")

# 5a. Main launcher
$mainBat = Join-Path $desktop "Launch-AI.bat"
@"
@echo off
title Local AI Assistant
color 0B
echo.
echo =====================================================
echo   Starting your Local AI Assistant...
echo =====================================================
echo.

REM Start Ollama in background if it's not already running
tasklist /FI "IMAGENAME eq ollama.exe" 2>NUL | find /I "ollama.exe" >NUL
if errorlevel 1 (
    echo  - Starting Ollama service...
    start "" /B "%LOCALAPPDATA%\Programs\Ollama\ollama.exe" serve
    timeout /t 4 /nobreak >NUL
) else (
    echo  - Ollama is already running.
)

echo  - Opening VS Code...
if not exist "%USERPROFILE%\AI-Workspace" mkdir "%USERPROFILE%\AI-Workspace"
start "" "%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe" "%USERPROFILE%\AI-Workspace"

echo.
echo  Ready! In VS Code:
echo    1. Click the Cline icon in the left sidebar (looks like a robot)
echo    2. Provider: Ollama   Model: qwen3-coder:14b
echo    3. Type what you want it to do.
echo.
echo  This window will close in 8 seconds...
timeout /t 8 /nobreak >NUL
exit
"@ | Set-Content -Path $mainBat -Encoding ASCII
Write-OK "Created: $mainBat"

# 5b. Quick chat-only launcher
$chatBat = Join-Path $desktop "Quick-AI-Chat.bat"
@"
@echo off
title Quick AI Chat (qwen3:8b)
color 0A
tasklist /FI "IMAGENAME eq ollama.exe" 2>NUL | find /I "ollama.exe" >NUL
if errorlevel 1 (
    start "" /B "%LOCALAPPDATA%\Programs\Ollama\ollama.exe" serve
    timeout /t 4 /nobreak >NUL
)
echo Type your question. Type /bye to quit.
echo.
"%LOCALAPPDATA%\Programs\Ollama\ollama.exe" run qwen3:8b
"@ | Set-Content -Path $chatBat -Encoding ASCII
Write-OK "Created: $chatBat"

# 5c. Desktop README
$readme = Join-Path $desktop "AI-README.txt"
@"
LOCAL AI ASSISTANT - QUICK GUIDE
================================

You now have TWO shortcuts on your desktop:

1) Launch-AI.bat       <- The BIG one. Opens VS Code with the Cline agent.
                          Use this for file reading/writing, running commands,
                          updating Windows, sorting folders, building code, etc.

2) Quick-AI-Chat.bat   <- A simple chat window in the terminal.
                          Use this for quick questions (no file access).

FIRST TIME USING CLINE (one-time setup, 30 seconds):
----------------------------------------------------
  a. Double-click Launch-AI.bat
  b. In VS Code, click the Cline robot icon on the left sidebar.
  c. When asked for API Provider, choose:  Ollama
  d. Base URL:  http://localhost:11434   (the default)
  e. Model:     qwen3-coder:14b
  f. Click Done. You're ready.

HOW TO TALK TO IT:
------------------
  - "Plan" mode  = it explains what it WILL do (safe, read-only).
  - "Act"  mode  = it actually does it (asks permission before each command).

  Always start with Plan mode if you're unsure.

MAINTENANCE COMMANDS (run in PowerShell):
-----------------------------------------
  ollama list                 -> see installed models
  ollama pull <model-name>    -> download a new model
  ollama rm <model-name>      -> delete a model to free space
  ollama ps                   -> see what's currently loaded in VRAM

SAFETY TIPS:
  - Cline shows EVERY command before running it. READ them.
  - If you don't understand a command, ask the AI to explain it first.
  - Keep "Auto-approve" turned OFF until you trust it.
  - Back up important folders before letting it "sort" or "clean" them.

Have fun!

  -- Project: https://github.com/LIN4CRE/NoobAiSetup
"@ | Set-Content -Path $readme -Encoding UTF8
Write-OK "Created: $readme"

# --- 6. done -------------------------------------------------------------
Write-Step "6/6  All done!"
Write-Host ""
Write-OK "Local AI Assistant is installed."
Write-Host ""
Write-Host "  Next step:" -ForegroundColor Cyan
Write-Host "    Go to your DESKTOP and double-click 'Launch-AI.bat'" -ForegroundColor White
Write-Host ""
Write-Host "  Read 'AI-README.txt' on your desktop for instructions." -ForegroundColor Cyan
Write-Host ""
Read-Host "Press ENTER to close this window"
