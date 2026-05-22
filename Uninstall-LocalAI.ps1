<#
.SYNOPSIS
    Cleanly removes everything the NoobAI setup installed.

.DESCRIPTION
    Walks through removal step-by-step. Every destructive action is opt-in.
    Default for every prompt is NO (just press Enter to skip).

    Removes (only what you say yes to):
      - All Ollama models (from C: AND any custom drive you set)
      - Ollama itself
      - The Cline + Roo Code VS Code extensions
      - VS Code, Git, Node.js (asked separately)
      - All Ollama environment variables (OLLAMA_MODELS etc.)
      - Desktop shortcuts and the AI-Crew workspace folder

.NOTES
    Project : NoobAiSetup
    Version : 1.0.0
    Repo    : https://github.com/LIN4CRE/NoobAiSetup
    License : MIT
#>

$ErrorActionPreference = 'Continue'

# self-elevate
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# --- helpers --------------------------------------------------------------
function Write-Step ($m) { Write-Host "`n========== $m ==========" -ForegroundColor Cyan }
function Write-OK   ($m) { Write-Host "  [OK]   $m" -ForegroundColor Green }
function Write-Info ($m) { Write-Host "  [INFO] $m" -ForegroundColor Yellow }
function Write-Warn ($m) { Write-Host "  [WARN] $m" -ForegroundColor Magenta }
function Write-Err  ($m) { Write-Host "  [ERR]  $m" -ForegroundColor Red }

function Ask-YN {
    param([string]$Question, [bool]$DefaultNo = $true)
    $hint = if ($DefaultNo) { "[y/N]" } else { "[Y/n]" }
    $a = Read-Host "  $Question $hint"
    if ([string]::IsNullOrWhiteSpace($a)) { return -not $DefaultNo }
    return ($a -match '^[yY]')
}

function Get-FolderSize {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return "0 GB" }
    try {
        $bytes = (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue |
                  Measure-Object -Property Length -Sum).Sum
        if (-not $bytes) { return "0 GB" }
        return "{0:N2} GB" -f ($bytes / 1GB)
    } catch { return "?" }
}

Clear-Host
Write-Host @"
   _   _      _         _        _ _
  | | | |_ _ (_)_ _  __| |_ __ _| | |
  | |_| | ' \| | ' \(_-<  _/ _` | | |
   \___/|_||_|_|_||_/__/\__\__,_|_|_|

   NoobAI - CLEAN UNINSTALLER
"@ -ForegroundColor Magenta

Write-Host ""
Write-Host "  This will walk you through removing the local AI setup."
Write-Host "  You will be asked Y/N for EVERY step. The default is NO."
Write-Host "  Press ENTER (without typing anything) to SKIP a step." -ForegroundColor Yellow
Write-Host ""
Read-Host "  Press ENTER to begin"

# --- 1. Stop Ollama -----------------------------------------------------
Write-Step "1.  Stopping Ollama"
$ollamaProcs = Get-Process ollama, "ollama app" -ErrorAction SilentlyContinue
if ($ollamaProcs) {
    Write-Info "Found running Ollama processes - stopping them..."
    $ollamaProcs | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Write-OK "Ollama stopped."
} else {
    Write-OK "Ollama is not running."
}

# --- 2. Find & delete model folders -------------------------------------
Write-Step "2.  Finding ALL model storage locations"

$modelPaths = New-Object System.Collections.Generic.HashSet[string]

$default = Join-Path $env:USERPROFILE ".ollama\models"
if (Test-Path $default) { [void]$modelPaths.Add($default) }

foreach ($scope in 'User','Machine') {
    $envVal = [Environment]::GetEnvironmentVariable('OLLAMA_MODELS', $scope)
    if ($envVal -and (Test-Path $envVal)) { [void]$modelPaths.Add($envVal) }
}

Write-Info "Scanning all drives for stray model folders (this is fast)..."
foreach ($drive in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used })) {
    $root = $drive.Root
    $candidates = @(
        (Join-Path $root ".ollama\models"),
        (Join-Path $root "Ollama\models"),
        (Join-Path $root "AI\Ollama\models"),
        (Join-Path $root "Models\Ollama"),
        (Join-Path $root "ollama-models")
    )
    try {
        Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue -Force |
            Where-Object { $_.Name -in '.ollama','Ollama','AI','Models','ollama' } |
            ForEach-Object {
                $sub = Join-Path $_.FullName "models"
                if (Test-Path $sub) { $candidates += $sub }
                Get-ChildItem -Path $_.FullName -Directory -ErrorAction SilentlyContinue -Force |
                    ForEach-Object {
                        $sub2 = Join-Path $_.FullName "models"
                        if (Test-Path $sub2) { $candidates += $sub2 }
                    }
            }
    } catch {}
    foreach ($c in $candidates) {
        if (Test-Path $c) { [void]$modelPaths.Add((Resolve-Path $c).Path) }
    }
}

if ($modelPaths.Count -eq 0) {
    Write-OK "No model folders found anywhere."
} else {
    Write-Host ""
    Write-Host "  Found these model folders:" -ForegroundColor Cyan
    $i = 0
    foreach ($p in $modelPaths) {
        $i++
        $size = Get-FolderSize $p
        Write-Host ("    {0}. {1}   ({2})" -f $i, $p, $size) -ForegroundColor White
    }
    Write-Host ""
    foreach ($p in $modelPaths) {
        if (Ask-YN -Question "Delete this folder?  $p") {
            try {
                Remove-Item -Path $p -Recurse -Force -ErrorAction Stop
                Write-OK "Deleted: $p"
            } catch {
                Write-Err "Could not delete $p  ($_)"
            }
        } else {
            Write-Info "Skipped:  $p"
        }
    }
}

# --- 3. Clear env variables --------------------------------------------
Write-Step "3.  Clearing Ollama environment variables"

$envVars = @('OLLAMA_MODELS','OLLAMA_HOST','OLLAMA_KEEP_ALIVE','OLLAMA_NUM_PARALLEL')
$foundVars = @()
foreach ($v in $envVars) {
    foreach ($scope in 'User','Machine') {
        $val = [Environment]::GetEnvironmentVariable($v, $scope)
        if ($val) { $foundVars += [pscustomobject]@{ Name=$v; Scope=$scope; Value=$val } }
    }
}

if (-not $foundVars) {
    Write-OK "No Ollama environment variables set."
} else {
    Write-Host ""
    Write-Host "  Found these environment variables:" -ForegroundColor Cyan
    $foundVars | ForEach-Object { Write-Host ("    {0,-20} ({1,-7}) = {2}" -f $_.Name, $_.Scope, $_.Value) -ForegroundColor White }
    Write-Host ""
    if (Ask-YN -Question "Remove ALL of the above environment variables?") {
        foreach ($f in $foundVars) {
            [Environment]::SetEnvironmentVariable($f.Name, $null, $f.Scope)
            Write-OK "Removed $($f.Name) ($($f.Scope))"
        }
    } else {
        Write-Info "Kept all environment variables."
    }
}

# --- 4. Uninstall VS Code extensions -----------------------------------
Write-Step "4.  Uninstalling VS Code extensions"

$codeCmd = $null
foreach ($p in @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
    "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
)) { if (Test-Path $p) { $codeCmd = $p; break } }
if (-not $codeCmd) { $codeCmd = (Get-Command code -ErrorAction SilentlyContinue).Source }

if ($codeCmd) {
    foreach ($ext in @(
        @{Id='saoudrizwan.claude-dev';      Name='Cline'},
        @{Id='rooveterinaryinc.roo-cline';  Name='Roo Code'}
    )) {
        if (Ask-YN -Question "Uninstall the $($ext.Name) extension?") {
            & $codeCmd --uninstall-extension $ext.Id 2>$null | Out-Null
            Write-OK "$($ext.Name) extension removed."
        } else {
            Write-Info "Kept $($ext.Name) extension."
        }
    }
} else {
    Write-Info "VS Code 'code' command not found - skipping extension removal."
}

# --- 5. Uninstall apps -------------------------------------------------
Write-Step "5.  Uninstalling applications"

function Uninstall-App {
    param([string]$Id, [string]$Friendly)
    if (Ask-YN -Question "Uninstall $Friendly ?") {
        Write-Info "Uninstalling $Friendly..."
        winget uninstall --id $Id --exact --silent --accept-source-agreements 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-OK "$Friendly removed." }
        else { Write-Warn "$Friendly uninstall returned $LASTEXITCODE (may already be gone)." }
    } else {
        Write-Info "Kept $Friendly."
    }
}

Uninstall-App -Id 'Ollama.Ollama'              -Friendly 'Ollama'
Uninstall-App -Id 'Microsoft.VisualStudioCode' -Friendly 'Visual Studio Code'
Uninstall-App -Id 'Git.Git'                    -Friendly 'Git'
Uninstall-App -Id 'OpenJS.NodeJS.LTS'          -Friendly 'Node.js'
Uninstall-App -Id 'astral-sh.uv'               -Friendly 'uv (Python runner)'

# --- 6. Clean up leftover folders --------------------------------------
Write-Step "6.  Cleaning up leftover folders"

$leftovers = @(
    "$env:LOCALAPPDATA\Programs\Ollama",
    "$env:LOCALAPPDATA\Ollama",
    "$env:USERPROFILE\.ollama"
)
foreach ($f in $leftovers) {
    if (Test-Path $f) {
        $size = Get-FolderSize $f
        if (Ask-YN -Question "Delete leftover folder $f  ($size) ?") {
            try { Remove-Item $f -Recurse -Force -ErrorAction Stop; Write-OK "Deleted $f" }
            catch { Write-Err "Could not delete $f  ($_)" }
        } else { Write-Info "Kept $f" }
    }
}

# AI-Crew / AI-Workspace
foreach ($ws in @("$env:USERPROFILE\AI-Crew","$env:USERPROFILE\AI-Workspace")) {
    if (Test-Path $ws) {
        $size = Get-FolderSize $ws
        if (Ask-YN -Question "Delete $ws  ($size)  -- this may contain files you want!") {
            Remove-Item $ws -Recurse -Force -ErrorAction SilentlyContinue
            Write-OK "Deleted $ws."
        } else { Write-Info "Kept $ws." }
    }
}

# --- 7. Remove desktop shortcuts ---------------------------------------
Write-Step "7.  Removing desktop shortcuts"
$desktop = [Environment]::GetFolderPath('Desktop')
$shortcuts = @(
    'Launch-AI.bat','Launch-AI-Crew.bat','Quick-AI-Chat.bat',
    'AI-README.txt','AI-Superpowers-Cheatsheet.md','NoobAI.lnk'
)
foreach ($s in $shortcuts) {
    $f = Join-Path $desktop $s
    if (Test-Path $f) {
        Remove-Item $f -Force -ErrorAction SilentlyContinue
        Write-OK "Removed $s"
    }
}

# --- Done --------------------------------------------------------------
Write-Step "Finished"
Write-Host ""
Write-OK "Uninstall complete. You can now re-run Setup-LocalAI.ps1 for a fresh install."
Write-Host ""
Read-Host "Press ENTER to close"
