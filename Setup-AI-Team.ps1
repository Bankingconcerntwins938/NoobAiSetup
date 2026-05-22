<#
.SYNOPSIS
    Installs Roo Code and configures a multi-agent AI "crew" with a
    Foreman (manager) and specialist workers.

.DESCRIPTION
    Adds to your existing base install:
      - Roo Code VS Code extension (multi-agent framework)
      - A custom team of specialists defined in .roomodes:
          * Foreman      - the boss, picks who does what
          * Sysadmin     - Windows updates, PATH, env vars, installs
          * Coder        - writes/builds/debugs code
          * Librarian    - sorts/renames/organizes files (always dry-runs)
          * Researcher   - looks things up, reads docs, writes plans
          * Inspector    - read-only audits, never changes anything
      - A "Crew" workspace folder
      - Sensible default safety settings

.NOTES
    Project : NoobAiSetup
    Version : 1.0.0
    Repo    : https://github.com/LIN4CRE/NoobAiSetup
    License : MIT
#>

$ErrorActionPreference = 'Stop'

# self-elevate
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

function Write-Step ($m) { Write-Host "`n========== $m ==========" -ForegroundColor Cyan }
function Write-OK   ($m) { Write-Host "  [OK]   $m" -ForegroundColor Green }
function Write-Info ($m) { Write-Host "  [INFO] $m" -ForegroundColor Yellow }
function Write-Warn ($m) { Write-Host "  [WARN] $m" -ForegroundColor Magenta }
function Write-Err  ($m) { Write-Host "  [ERR]  $m" -ForegroundColor Red }

Clear-Host
Write-Host @"
    _    ___    ___                   _____ _____ _   __  __
   / \  |_ _|  / __|_ _ _____ __ __  |_   _| ____/_\ |  \/  |
  / _ \  | |  | (__| '_/ -_) V  V /    | | | _|/ _ \| |\/| |
 /_/ \_\___|  \___|_| \___|\_/\_/     |_| |___/_/ \_\_|  |_|

   Multi-Agent AI Crew Setup
   1 brain. Many specialists. 1 foreman delegating the work.
"@ -ForegroundColor Cyan
Write-Host ""
Write-Host "  This adds a TEAM of AI specialists on top of your existing"
Write-Host "  install. You can keep using Cline too - they don't conflict."
Write-Host ""
Read-Host "  Press ENTER to begin"

# --- 1. Sanity checks -----------------------------------------------------
Write-Step "1.  Checking prerequisites"

$codeCmd = $null
foreach ($p in @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
    "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
)) { if (Test-Path $p) { $codeCmd = $p; break } }
if (-not $codeCmd) { $codeCmd = (Get-Command code -ErrorAction SilentlyContinue).Source }

if (-not $codeCmd) {
    Write-Err "VS Code not found. Run Setup-LocalAI.ps1 first."
    Read-Host "Press ENTER to exit"; exit 1
}
Write-OK "VS Code found."

$ollamaExe = $null
foreach ($p in @(
    "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe",
    "$env:ProgramFiles\Ollama\ollama.exe"
)) { if (Test-Path $p) { $ollamaExe = $p; break } }
if (-not $ollamaExe) { $ollamaExe = (Get-Command ollama -ErrorAction SilentlyContinue).Source }

if (-not $ollamaExe) {
    Write-Err "Ollama not found. Run Setup-LocalAI.ps1 first."
    Read-Host "Press ENTER to exit"; exit 1
}
Write-OK "Ollama found."

if (-not (Get-Process ollama -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $ollamaExe -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 4
}
Write-OK "Ollama is running."

# --- 2. Install Roo Code --------------------------------------------------
Write-Step "2.  Installing Roo Code (multi-agent VS Code extension)"
& $codeCmd --install-extension rooveterinaryinc.roo-cline --force | Out-Null
Write-OK "Roo Code installed."

# --- 3. Check models ------------------------------------------------------
Write-Step "3.  Checking AI models"

$models = & $ollamaExe list 2>$null
$haveCoder = $models -match 'qwen3-coder'
$haveSmall = $models -match 'qwen3:8b'

if (-not $haveCoder) {
    Write-Info "Pulling qwen3-coder:14b (the main brain)..."
    & $ollamaExe pull qwen3-coder:14b
}
if (-not $haveSmall) {
    Write-Info "Pulling qwen3:8b (the fast brain for the Foreman)..."
    & $ollamaExe pull qwen3:8b
}
Write-OK "Models ready."

# --- 4. Pick the workspace ------------------------------------------------
Write-Step "4.  Pick where your AI Crew will work"

Write-Host ""
Write-Host "  Your AI crew needs a folder to work in. They can read/write"
Write-Host "  ANYWHERE on your PC when needed, but this is their 'home base'."
Write-Host ""
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used } |
    ForEach-Object { Write-Host ("    {0}:  Free: {1:N1} GB" -f $_.Name, ($_.Free / 1GB)) }
Write-Host ""

$default = "$env:USERPROFILE\AI-Crew"
$ws = Read-Host "  Type the full path (or ENTER for default: $default)"
if ([string]::IsNullOrWhiteSpace($ws)) { $ws = $default }

if (-not (Test-Path $ws)) { New-Item -Path $ws -ItemType Directory -Force | Out-Null }
Write-OK "Crew workspace: $ws"

# --- 5. Write .roomodes (the team definition) ----------------------------
Write-Step "5.  Defining the AI crew"

$roomodes = @'
{
  "customModes": [
    {
      "slug": "foreman",
      "name": "👷 Foreman (Manager)",
      "roleDefinition": "You are the FOREMAN of an AI crew. You do NOT do work yourself. Your only job is to: (1) UNDERSTAND what the user wants in plain English, (2) BREAK IT DOWN into clear sub-tasks, (3) DELEGATE each sub-task to the right specialist using the new_task tool, (4) WAIT for each specialist to report back, (5) CHAIN their results together, (6) REPORT progress to the user in simple language. You are friendly, patient, and explain things like the user is learning. You always confirm a plan with the user before delegating risky work. When unsure who is best for a task, ask the user. Available crew: sysadmin (Windows/PATH/installs), coder (programming), librarian (files/folders), researcher (web/docs/planning), inspector (read-only audits).",
      "whenToUse": "Use this for ANY multi-step request. The Foreman picks specialists and coordinates them.",
      "groups": ["read", "mcp"],
      "customInstructions": "ALWAYS explain your plan in plain English BEFORE delegating. If the user says 'just do it' you may skip confirmation. Use the new_task tool to hand work to specialists. Never run shell commands yourself - that's a specialist's job. Keep status updates short and clear."
    },
    {
      "slug": "sysadmin",
      "name": "🛠️ Sysadmin (Windows specialist)",
      "roleDefinition": "You are a Windows 11 system administrator. You handle: Windows Updates, winget package updates, PATH and environment variables, drivers, services, scheduled tasks, registry edits, disk cleanup, and installing/uninstalling software. You ALWAYS use PowerShell. You ALWAYS show the user the command and explain what it does before running it. You refuse destructive commands (rm -rf style, registry wipes, format) without explicit user confirmation. You prefer winget over manual installers.",
      "whenToUse": "Updates, installs, uninstalls, PATH problems, environment variables, services, anything Windows-config-related.",
      "groups": ["read", "edit", "command", "mcp"],
      "customInstructions": "Default to PowerShell. Always preview commands. For env-var changes, use [Environment]::SetEnvironmentVariable with the correct scope (Machine for system-wide, User for current user). Remind the user to restart their terminal/VS Code after PATH changes."
    },
    {
      "slug": "coder",
      "name": "💻 Coder (Programmer)",
      "roleDefinition": "You are a senior software engineer. You write, refactor, debug, build, and test code in any language. You follow the existing code style of a project. You write small, focused commits. You explain WHY you made a change, not just what. You always run the build/tests after a change when possible. You never invent APIs - if you're not sure, you check the docs or ask.",
      "whenToUse": "Writing scripts or programs, building projects, fixing bugs, code reviews, refactoring.",
      "groups": ["read", "edit", "command", "browser", "mcp"],
      "customInstructions": "Prefer Python, PowerShell, or TypeScript unless the user says otherwise. For new projects, set up a virtual environment / package.json properly. Always test before declaring done."
    },
    {
      "slug": "librarian",
      "name": "📚 Librarian (File organizer)",
      "roleDefinition": "You are a meticulous file organizer. You sort, rename, deduplicate, tag, and structure folders. You NEVER delete a file without explicit confirmation. You ALWAYS do a dry-run first (list what you WOULD do) before doing it. You preserve original timestamps. You use safe operations (move not delete, copy then verify before remove). For photos you can read EXIF data. For documents you can read content to categorize.",
      "whenToUse": "Sorting Downloads, organizing photos, renaming files in bulk, finding duplicates, cleaning folders.",
      "groups": ["read", "edit", "command", "mcp"],
      "customInstructions": "ALWAYS dry-run first. Show the user a sample of 5-10 proposed changes and wait for approval before bulk operations. Use Move-Item not Remove-Item. Log every action to a 'librarian-log-<date>.txt' in the same folder so the user can undo if needed."
    },
    {
      "slug": "researcher",
      "name": "🔍 Researcher (Planner)",
      "roleDefinition": "You research topics, read documentation, compare options, and produce written plans. You DO NOT modify files or run system commands - you only read, browse, and write notes/plans into markdown files. You cite your sources. You list pros and cons. You give concrete recommendations, not wishy-washy 'it depends' answers.",
      "whenToUse": "Researching software options, reading docs, comparing approaches, writing project plans before the Coder starts.",
      "groups": ["read", "browser", ["edit", { "fileRegex": "\\.(md|txt)$", "description": "Only markdown and text notes" }], "mcp"],
      "customInstructions": "Output is always a markdown file with: Summary, Options, Pros/Cons table, Recommendation, Sources. Keep it under 500 words unless asked for more."
    },
    {
      "slug": "inspector",
      "name": "🔎 Inspector (Read-only auditor)",
      "roleDefinition": "You investigate problems WITHOUT changing anything. You read files, run read-only commands (Get-*, ls, cat, ps, ipconfig, etc.), check logs, and report findings. You are FORBIDDEN from writing files, modifying settings, installing anything, or running destructive commands. You produce a clear report of what you found and what you'd recommend - but you never act on it. The user or Foreman decides what to do.",
      "whenToUse": "Diagnosing problems, auditing a system, 'what's wrong with...', 'why isn't this working', before any risky operation.",
      "groups": ["read", ["command", { "commandRegex": "^(Get-|Test-|Resolve-|Select-|Where-|Measure-|Compare-|Find-|Search-|ls|dir|cat|type|echo|ps|tasklist|ipconfig|whoami|hostname|systeminfo|winget list|ollama list|git status|git log|git diff|node -v|python --version|pwsh -v|where)", "description": "Read-only commands only" }], "mcp"],
      "customInstructions": "If a command would change state, REFUSE and ask the Foreman to delegate to the right specialist. Output is always a structured report: Findings, Likely Cause, Recommendation, Suggested Specialist."
    }
  ]
}
'@

$roomodesPath = Join-Path $ws ".roomodes"
$roomodes | Set-Content -Path $roomodesPath -Encoding UTF8
Write-OK "Crew defined in: $roomodesPath"

# --- 6. README inside workspace ------------------------------------------
$crewReadme = @"
# Your AI Crew

You have 6 AI specialists in one place. Always talk to the **Foreman** first
unless you know exactly which specialist you want.

## The crew

| Mode | Specialist | Use for |
|---|---|---|
| 👷 Foreman | Manager | Anything multi-step. Picks who does what. **START HERE.** |
| 🛠️ Sysadmin | Windows expert | Updates, installs, PATH, env vars, services |
| 💻 Coder | Programmer | Write/build/debug code |
| 📚 Librarian | File organizer | Sort, rename, dedupe (safe, dry-run first) |
| 🔍 Researcher | Planner | Read docs, compare options, write plans |
| 🔎 Inspector | Read-only auditor | Diagnose problems WITHOUT changing anything |

## How to use it

1. Open this folder in VS Code (the Launch-AI-Crew.bat shortcut does this for you).
2. Click the **Roo Code** icon in the left sidebar (kangaroo logo).
3. At the bottom of the chat, click the **mode dropdown** and pick **👷 Foreman**.
4. Type your request in plain English.

## Example requests

- "My Downloads folder is a mess - sort it out."
  -> Foreman delegates to Librarian, who dry-runs first.

- "Why is my GPU not being used by Ollama?"
  -> Foreman delegates to Inspector, who diagnoses, then to Sysadmin to fix.

- "Update everything on my PC and clean up junk."
  -> Foreman delegates to Sysadmin (winget upgrade, Windows Update, cleanmgr).

- "Build me a Python script that backs up my Documents to D: every night."
  -> Foreman delegates to Researcher (plan), then Coder (write), then Sysadmin
    (register as a scheduled task).

- "Something's wrong with my PATH - things won't run from the terminal."
  -> Foreman delegates to Inspector (report), then Sysadmin (fix).

## Safety

- Roo Code shows you EVERY command before running it. Read them.
- The Inspector is hard-coded to be read-only - safe to let loose.
- The Librarian always dry-runs and logs.
- The Sysadmin asks before destructive commands.
- The Foreman never touches your system directly.

## Tweaking the crew

The crew is defined in `.roomodes` in this folder. You can edit it to:
- Change a specialist's personality or rules
- Add new specialists (e.g. "Photo Editor", "DJ", "Tax Helper")
- Restrict which folders a specialist can touch

Open `.roomodes` in VS Code and edit. Roo Code reloads it automatically.

  -- Project: https://github.com/LIN4CRE/NoobAiSetup
"@
$crewReadme | Set-Content -Path (Join-Path $ws "README-AI-Crew.md") -Encoding UTF8
Write-OK "README written."

# --- 7. Desktop launcher --------------------------------------------------
Write-Step "6.  Creating desktop launcher"
$desktop = [Environment]::GetFolderPath("Desktop")
$batPath = Join-Path $desktop "Launch-AI-Crew.bat"

@"
@echo off
title AI Crew
color 0B
echo.
echo  ============================================
echo    Starting your AI Crew...
echo  ============================================
echo.

tasklist /FI "IMAGENAME eq ollama.exe" 2>NUL | find /I "ollama.exe" >NUL
if errorlevel 1 (
    echo  - Starting Ollama...
    start "" /B "%LOCALAPPDATA%\Programs\Ollama\ollama.exe" serve
    timeout /t 4 /nobreak >NUL
) else (
    echo  - Ollama already running.
)

echo  - Opening VS Code in the Crew workspace...
start "" "%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe" "$ws"

echo.
echo  In VS Code:
echo    1. Click the Roo Code (kangaroo) icon on the left
echo    2. Pick mode: Foreman
echo    3. Tell it what you want
echo.
timeout /t 6 /nobreak >NUL
exit
"@ | Set-Content -Path $batPath -Encoding ASCII
Write-OK "Created: $batPath"

Write-Step "All done!"
Write-Host ""
Write-OK "Your AI Crew is ready."
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Cyan
Write-Host "    1. Double-click 'Launch-AI-Crew.bat' on your desktop"
Write-Host "    2. Click the Roo Code (kangaroo) icon in VS Code's sidebar"
Write-Host "    3. First time only: API Provider = Ollama, Model = qwen3-coder:14b"
Write-Host "    4. Pick mode: Foreman"
Write-Host "    5. Tell it what you want in plain English."
Write-Host ""
Write-Host "  Read README-AI-Crew.md inside the workspace for examples." -ForegroundColor Cyan
Write-Host ""
Read-Host "Press ENTER to close"
