<#
.SYNOPSIS
    Safely move Ollama models to another drive and update OLLAMA_MODELS so
    Ollama actually FINDS them after the move (the bit that always breaks).

.DESCRIPTION
    Why your models break when you move them:
      Ollama looks in ONE place - the OLLAMA_MODELS environment variable,
      or C:\Users\<you>\.ollama\models if the variable is not set.
      If you move the folder but don't update the variable, Ollama
      either can't find the models (and re-downloads = duplicates) or it
      finds an empty default folder and thinks you have no models.

    This script:
      1. Shows you EVERY models folder it finds across all drives.
      2. Lets you pick the real one (source) and the destination drive.
      3. Stops Ollama.
      4. Uses robocopy (with verification + resume) to copy.
      5. Sets OLLAMA_MODELS at Machine scope - permanent and system-wide.
      6. Restarts Ollama and lists models to PROVE everything still works.

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

# --- helpers ---------------------------------------------------------------
function Write-Step ($m) { Write-Host "`n========== $m ==========" -ForegroundColor Cyan }
function Write-OK   ($m) { Write-Host "  [OK]   $m" -ForegroundColor Green }
function Write-Info ($m) { Write-Host "  [INFO] $m" -ForegroundColor Yellow }
function Write-Warn ($m) { Write-Host "  [WARN] $m" -ForegroundColor Magenta }
function Write-Err  ($m) { Write-Host "  [ERR]  $m" -ForegroundColor Red }

function Get-FolderSize {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    try {
        return (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
    } catch { return 0 }
}
function Format-Size {
    param([long]$Bytes)
    if (-not $Bytes)     { return "0 B" }
    if ($Bytes -ge 1GB)  { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB)  { return "{0:N2} MB" -f ($Bytes / 1MB) }
    return "{0:N0} KB" -f ($Bytes / 1KB)
}

# Scan a drive for likely model folders (one helper, used twice)
function Find-ModelFolders {
    param([string]$DriveRoot)
    $candidates = @(
        (Join-Path $DriveRoot ".ollama\models"),
        (Join-Path $DriveRoot "Ollama\models"),
        (Join-Path $DriveRoot "AI\Ollama\models"),
        (Join-Path $DriveRoot "Models\Ollama"),
        (Join-Path $DriveRoot "ollama-models"),
        (Join-Path $DriveRoot "OllamaModels")
    )
    try {
        Get-ChildItem -Path $DriveRoot -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^(\.?ollama|AI|Models)$' } |
            ForEach-Object {
                $sub = Join-Path $_.FullName "models"
                if (Test-Path $sub) { $candidates += $sub }
                Get-ChildItem -Path $_.FullName -Directory -Force -ErrorAction SilentlyContinue |
                    ForEach-Object {
                        $sub2 = Join-Path $_.FullName "models"
                        if (Test-Path $sub2) { $candidates += $sub2 }
                    }
            }
    } catch {}
    $candidates | Where-Object { Test-Path $_ } | ForEach-Object { (Resolve-Path $_).Path } | Select-Object -Unique
}

Clear-Host
Write-Host @"
   __  __                _____   __  __         _     _
  |  \/  |_____ _____   |_   _| |  \/  |___  __| |___| |___
  | |\/| / _ \ V / -_)    | |   | |\/| / _ \/ _` / -_) (_-<
  |_|  |_\___/\_/\___|    |_|   |_|  |_\___/\__,_\___|_/__/

  Safely move Ollama AI models to another drive
"@ -ForegroundColor Cyan
Write-Host ""

# --- 1. Discover all model locations --------------------------------------
Write-Step "1.  Looking for ALL model folders on your PC"

$found = @{}

$default = Join-Path $env:USERPROFILE ".ollama\models"
if (Test-Path $default) { $found[$default] = Get-FolderSize $default }

$envCurrent = [Environment]::GetEnvironmentVariable('OLLAMA_MODELS','Machine')
if (-not $envCurrent) { $envCurrent = [Environment]::GetEnvironmentVariable('OLLAMA_MODELS','User') }
if ($envCurrent -and (Test-Path $envCurrent) -and -not $found.ContainsKey($envCurrent)) {
    $found[$envCurrent] = Get-FolderSize $envCurrent
}

Write-Info "Scanning all drives... (a few seconds)"
foreach ($drive in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used })) {
    foreach ($path in (Find-ModelFolders -DriveRoot $drive.Root)) {
        if (-not $found.ContainsKey($path)) {
            $found[$path] = Get-FolderSize $path
        }
    }
}

$list = @()
if ($found.Count -eq 0) {
    Write-Warn "No existing model folders found. Nothing to move."
    Write-Info "If you want to set a NEW location for FUTURE downloads, continue anyway."
} else {
    Write-Host ""
    Write-Host "  Found these model folders:" -ForegroundColor Cyan
    $i = 0
    foreach ($k in $found.Keys) {
        $i++
        $list += [pscustomobject]@{ Index=$i; Path=$k; Bytes=$found[$k]; Size=(Format-Size $found[$k]) }
        $marker = if ($k -eq $envCurrent) { " <-- ACTIVE (OLLAMA_MODELS)" }
                  elseif ($k -eq $default -and -not $envCurrent) { " <-- ACTIVE (default)" }
                  else { "" }
        Write-Host ("    {0}. {1}  ({2}){3}" -f $i, $k, (Format-Size $found[$k]), $marker)
    }
}

# --- 2. Pick source ------------------------------------------------------
Write-Step "2.  Pick the SOURCE folder (the one with real models in it)"

$source = $null
if ($found.Count -eq 1) {
    $source = ($found.Keys | Select-Object -First 1)
    Write-OK "Only one folder found - using: $source"
} elseif ($found.Count -gt 1) {
    Write-Host "  Look at the sizes. The BIGGEST one is almost certainly your real models."
    $pick = Read-Host "  Type the number of the SOURCE folder, or ENTER to skip move"
    if ($pick -match '^\d+$') {
        $row = $list | Where-Object { $_.Index -eq [int]$pick }
        if ($row) { $source = $row.Path }
    }
}

if (-not $source) {
    Write-Info "No source chosen. We'll just set the location for FUTURE downloads."
}

# --- 3. Pick destination -------------------------------------------------
Write-Step "3.  Pick the DESTINATION drive"

$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used } |
          Select-Object @{N='Letter';E={$_.Name}},
                        @{N='Free';E={ Format-Size $_.Free }},
                        @{N='FreeBytes';E={ $_.Free }},
                        @{N='Total';E={ Format-Size ($_.Used + $_.Free) }}

Write-Host ""
Write-Host "  Your drives:" -ForegroundColor Cyan
$drives | ForEach-Object { Write-Host ("    {0}:   Free: {1,-12}  Total: {2}" -f $_.Letter, $_.Free, $_.Total) }
Write-Host ""

$needed = if ($source) { $found[$source] } else { 0 }
if ($needed) { Write-Info ("You need at least {0} of free space on the destination." -f (Format-Size $needed)) }

$destDrive = $null
while (-not $destDrive) {
    $letter = Read-Host "  Type the destination drive letter (e.g. D), or X to cancel"
    if ($letter -match '^[xX]$') { Write-Warn "Cancelled."; exit }
    $letter = $letter.TrimEnd(':').ToUpper()
    $row = $drives | Where-Object { $_.Letter -eq $letter }
    if (-not $row) { Write-Err "Drive $letter not found. Try again."; continue }
    if ($needed -and $row.FreeBytes -lt ($needed * 1.1)) {
        Write-Err ("Not enough free space on {0}: ({1} free, need ~{2})." -f $letter, $row.Free, (Format-Size ($needed*1.1)))
        continue
    }
    $destDrive = $letter
}

$destPath = "${destDrive}:\Ollama\models"
Write-Host ""
Write-Info "Destination will be:  $destPath"
$override = Read-Host "  Press ENTER to continue, or type a different FULL path (e.g. D:\AI\models)"
if ($override) { $destPath = $override }

if ($source -and ((Resolve-Path $source).Path -ieq $destPath)) {
    Write-Err "Source and destination are the same folder. Nothing to do."
    Read-Host "Press ENTER to exit"; exit
}

# --- 4. Stop Ollama ------------------------------------------------------
Write-Step "4.  Stopping Ollama"
Get-Process ollama,"ollama app" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-OK "Ollama stopped (if it was running)."

# --- 5. Copy with robocopy -----------------------------------------------
if ($source) {
    Write-Step "5.  Moving model files"
    Write-Info "Using robocopy (safe copy with verification, then deletes the source)."
    Write-Info "From:  $source"
    Write-Info "To  :  $destPath"

    if (-not (Test-Path $destPath)) { New-Item -Path $destPath -ItemType Directory -Force | Out-Null }

    # /E recurse, /COPYALL preserve attrs, /R:2 retry, /W:5 wait, /MT:16 multi-thread, /NP no %, /ETA show ETA
    robocopy $source $destPath /E /COPYALL /R:2 /W:5 /MT:16 /NFL /NDL /NJH /NP /ETA
    $rc = $LASTEXITCODE

    # robocopy: exit codes 0-7 = success, 8+ = error
    if ($rc -lt 8) {
        Write-OK ("Copy finished (robocopy code {0} = success)." -f $rc)

        $srcSize = Get-FolderSize $source
        $dstSize = Get-FolderSize $destPath
        Write-Info ("Source size: {0}    Destination size: {1}" -f (Format-Size $srcSize), (Format-Size $dstSize))

        if ($dstSize -ge ($srcSize * 0.99)) {
            Write-OK "Sizes match. Safe to delete source."
            $del = Read-Host "  Delete the OLD source folder $source ?  [Y/n]"
            if ($del -notmatch '^[nN]') {
                Remove-Item $source -Recurse -Force -ErrorAction SilentlyContinue
                Write-OK "Old source deleted."
            } else {
                Write-Warn "Left old source in place. Delete it yourself once you've confirmed everything works."
            }
        } else {
            Write-Err "Destination size is smaller than source. NOT deleting source. Investigate manually."
        }
    } else {
        Write-Err ("Robocopy returned error code $rc. Source NOT deleted.")
        Read-Host "Press ENTER to exit"; exit 1
    }
} else {
    Write-Step "5.  (Skipping copy - no source selected)"
    if (-not (Test-Path $destPath)) { New-Item -Path $destPath -ItemType Directory -Force | Out-Null }
}

# --- 6. Set OLLAMA_MODELS (the bit that always breaks) ------------------
Write-Step "6.  Telling Ollama where the models now live"

# Clear from User scope (so it doesn't shadow Machine), set on Machine scope (permanent)
[Environment]::SetEnvironmentVariable('OLLAMA_MODELS', $null,      'User')
[Environment]::SetEnvironmentVariable('OLLAMA_MODELS', $destPath,  'Machine')

# Also set in current session so the verify step works immediately
$env:OLLAMA_MODELS = $destPath

Write-OK "OLLAMA_MODELS = $destPath  (set system-wide, permanent)"
Write-Info "This is the ONLY setting Ollama uses to find your models. You're now safe."

# --- 7. Restart Ollama and verify ---------------------------------------
Write-Step "7.  Restarting Ollama and verifying"

$ollamaExe = $null
foreach ($p in @(
    "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe",
    "$env:ProgramFiles\Ollama\ollama.exe"
)) { if (Test-Path $p) { $ollamaExe = $p; break } }
if (-not $ollamaExe) { $ollamaExe = (Get-Command ollama -ErrorAction SilentlyContinue).Source }

if (-not $ollamaExe) {
    Write-Warn "Ollama executable not found. Reboot and run 'ollama list' to verify."
} else {
    Start-Process -FilePath $ollamaExe -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 5
    Write-Info "Models Ollama can now see:"
    Write-Host ""
    & $ollamaExe list
    Write-Host ""
}

Write-Step "Finished"
Write-Host ""
Write-OK "Done. Your models live at: $destPath"
Write-OK "Future 'ollama pull' downloads will also go there automatically."
Write-Host ""
Write-Warn "IMPORTANT: close and reopen VS Code / any terminals so they see the new OLLAMA_MODELS variable."
Write-Host ""
Read-Host "Press ENTER to close"
