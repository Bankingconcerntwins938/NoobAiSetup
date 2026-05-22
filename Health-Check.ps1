<#
.SYNOPSIS
    NoobAI Health Check - shows the state of your local AI setup at a glance.

.DESCRIPTION
    Read-only. Safe to run any time. Doesn't change anything.
    Highlights problems in red, healthy items in green.

.NOTES
    Project : NoobAiSetup
    Version : 1.0.0
    Repo    : https://github.com/LIN4CRE/NoobAiSetup
    License : MIT
#>

$ErrorActionPreference = 'Continue'

function Hdr ($t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function OK  ($t) { Write-Host "  [OK]   $t" -ForegroundColor Green }
function Bad ($t) { Write-Host "  [BAD]  $t" -ForegroundColor Red }
function Inf ($t) { Write-Host "  [info] $t" -ForegroundColor Yellow }

function Format-Size {
    param([long]$Bytes)
    if (-not $Bytes)    { return "0 B" }
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes/1GB) }
    if ($Bytes -ge 1MB) { return "{0:N1} MB" -f ($Bytes/1MB) }
    return "{0:N0} KB" -f ($Bytes/1KB)
}

Clear-Host
Write-Host "  NoobAI - Health Check  ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))" -ForegroundColor Cyan
Write-Host "  ------------------------------------------------------"

# --- Apps installed ------------------------------------------------------
Hdr "Installed apps"
$apps = @(
    [pscustomobject]@{ Name='Ollama';  Path="$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"; Cmd=$null },
    [pscustomobject]@{ Name='VS Code'; Path="$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"; Cmd=$null },
    [pscustomobject]@{ Name='Git';     Path=$null; Cmd='git' },
    [pscustomobject]@{ Name='Node.js'; Path=$null; Cmd='node' },
    [pscustomobject]@{ Name='uv';      Path=$null; Cmd='uvx' }
)
foreach ($app in $apps) {
    if ($app.Path -and (Test-Path $app.Path)) { OK "$($app.Name) installed: $($app.Path)" }
    elseif ($app.Cmd -and (Get-Command $app.Cmd -ErrorAction SilentlyContinue)) { OK "$($app.Name) installed (on PATH)" }
    else { Bad "$($app.Name) NOT installed" }
}

# --- VS Code extensions --------------------------------------------------
Hdr "VS Code extensions"
$codeCmd = $null
foreach ($p in @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
    "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
)) { if (Test-Path $p) { $codeCmd = $p; break } }

if ($codeCmd) {
    $exts = & $codeCmd --list-extensions 2>$null
    foreach ($want in @('saoudrizwan.claude-dev','rooveterinaryinc.roo-cline')) {
        if ($exts -contains $want) { OK "Extension installed: $want" }
        else { Inf "Extension NOT installed: $want" }
    }
} else { Bad "Could not find VS Code 'code' command." }

# --- Ollama service ------------------------------------------------------
Hdr "Ollama service"
if (Get-Process ollama -ErrorAction SilentlyContinue) { OK "Ollama is RUNNING." }
else { Bad "Ollama is NOT running. Start it: ollama serve" }

try {
    $null = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -TimeoutSec 3
    OK "Ollama API responding on http://localhost:11434"
} catch { Bad "Ollama API not responding." }

# --- OLLAMA_MODELS env var ----------------------------------------------
Hdr "OLLAMA_MODELS environment variable (THE important one)"
$mUser    = [Environment]::GetEnvironmentVariable('OLLAMA_MODELS','User')
$mMachine = [Environment]::GetEnvironmentVariable('OLLAMA_MODELS','Machine')
if ($mUser)    { Inf "User scope    : $mUser" }    else { Inf "User scope    : (not set)" }
if ($mMachine) { Inf "Machine scope : $mMachine" } else { Inf "Machine scope : (not set)" }

$effective = if ($mMachine) { $mMachine } elseif ($mUser) { $mUser } else { Join-Path $env:USERPROFILE ".ollama\models" }
Inf "EFFECTIVE path: $effective"

if ($mUser -and $mMachine -and $mUser -ne $mMachine) {
    Bad "CONFLICT: User and Machine OLLAMA_MODELS are different! Fix by clearing the User one."
}

# --- Actual model folders -----------------------------------------------
Hdr "Looking for model folders on every drive"
$found = @()
foreach ($drive in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used })) {
    $candidates = @(
        (Join-Path $drive.Root ".ollama\models"),
        (Join-Path $drive.Root "Ollama\models"),
        (Join-Path $drive.Root "AI\Ollama\models"),
        (Join-Path $drive.Root "Models\Ollama"),
        (Join-Path $drive.Root "ollama-models")
    )
    try {
        Get-ChildItem -Path $drive.Root -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^(\.?ollama|AI|Models)$' } |
            ForEach-Object {
                $sub = Join-Path $_.FullName "models"
                if (Test-Path $sub) { $candidates += $sub }
            }
    } catch {}
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            $resolved = (Resolve-Path $c).Path
            if ($found.Path -notcontains $resolved) {
                $size = (Get-ChildItem $resolved -Recurse -Force -ErrorAction SilentlyContinue |
                         Measure-Object Length -Sum).Sum
                $found += [pscustomobject]@{ Path=$resolved; Size=$size }
            }
        }
    }
}

if ($found.Count -eq 0) {
    Bad "No model folders found anywhere."
} else {
    foreach ($f in $found) {
        $isActive = $f.Path -ieq $effective
        $marker = if ($isActive) { "  <-- ACTIVE (matches OLLAMA_MODELS)" } else { "  <-- ORPHAN (not being used!)" }
        $tag    = if ($isActive) { "OK   " } else { "BAD  " }
        $color  = if ($isActive) { "Green" } else { "Red" }
        Write-Host ("  [{0}] {1}  ({2}){3}" -f $tag, $f.Path, (Format-Size $f.Size), $marker) -ForegroundColor $color
    }
    $orphans = $found | Where-Object { $_.Path -ine $effective }
    if ($orphans) {
        Write-Host ""
        Bad ("You have {0} ORPHAN model folder(s) wasting disk space." -f $orphans.Count)
        Inf "Run MOVE-MODELS-Run-Me.bat to consolidate, or UNINSTALL-Run-Me.bat to clean up."
    }
}

# --- Models Ollama can see ----------------------------------------------
Hdr "Models Ollama can see right now"
$ollamaExe = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
if (Test-Path $ollamaExe) { & $ollamaExe list }
else { Bad "Cannot find ollama.exe" }

# --- GPU -----------------------------------------------------------------
Hdr "GPU"
try {
    $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -match 'NVIDIA|AMD|Intel Arc' } | Select-Object -First 1
    if ($gpu) {
        $vram = "{0:N1} GB" -f ($gpu.AdapterRAM / 1GB)
        OK "$($gpu.Name)  (VRAM reported: $vram)"
    } else { Inf "No discrete GPU detected." }
} catch {}

if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    Inf "nvidia-smi snapshot:"
    nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader
}

# --- Disk space ---------------------------------------------------------
Hdr "Disk space"
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used } |
    ForEach-Object {
        $free = "{0:N1} GB" -f ($_.Free/1GB)
        $tot  = "{0:N1} GB" -f (($_.Used+$_.Free)/1GB)
        Write-Host ("  {0}:  {1} free of {2}" -f $_.Name, $free, $tot)
    }

# --- Summary ------------------------------------------------------------
Hdr "Summary"
Write-Host "  If everything above is green, you're healthy."
Write-Host "  If you see RED items, the fix is usually one of:"
Write-Host "    - MOVE-MODELS-Run-Me.bat  (consolidate orphan models, fix OLLAMA_MODELS)"
Write-Host "    - START-HERE-Run-Me.bat   (re-install anything missing)"
Write-Host "    - UNINSTALL-Run-Me.bat    (nuke and start over)"
Write-Host ""
Read-Host "Press ENTER to close"
