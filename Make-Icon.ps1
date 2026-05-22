<#
.SYNOPSIS
    Generates NoobAI.ico (a friendly robot icon) and creates a desktop
    shortcut to LAUNCHER.bat that uses it.

.DESCRIPTION
    Draws the icon procedurally with System.Drawing - no external image
    files needed. Wraps a 256x256 PNG in a proper .ico container so
    Windows renders it cleanly at any size.

.NOTES
    Project : NoobAiSetup
    Version : 1.0.0
    Repo    : https://github.com/LIN4CRE/NoobAiSetup
    License : MIT
#>

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$IconPath  = Join-Path $ScriptDir "NoobAI.ico"
$PngPath   = Join-Path $env:TEMP   "NoobAI_temp.png"

Write-Host "Drawing icon..." -ForegroundColor Cyan

# --- 1. Draw 256x256 PNG -------------------------------------------------
$size = 256
$bmp  = New-Object System.Drawing.Bitmap $size, $size
$g    = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.TextRenderingHint  = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# Diagonal blue->mauve gradient background (Catppuccin Mocha palette)
$gradBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point 0, 0),
    (New-Object System.Drawing.Point $size, $size),
    [System.Drawing.Color]::FromArgb(255, 137, 180, 250),   # Blue   #89B4FA
    [System.Drawing.Color]::FromArgb(255, 203, 166, 247)    # Mauve  #CBA6F7
)

function New-RoundedRect {
    param([int]$X, [int]$Y, [int]$W, [int]$H, [int]$R)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $R * 2
    $path.AddArc($X,           $Y,           $d, $d, 180, 90)
    $path.AddArc($X + $W - $d, $Y,           $d, $d, 270, 90)
    $path.AddArc($X + $W - $d, $Y + $H - $d, $d, $d,   0, 90)
    $path.AddArc($X,           $Y + $H - $d, $d, $d,  90, 90)
    $path.CloseFigure()
    return $path
}

$bgPath = New-RoundedRect 0 0 $size $size 48
$g.FillPath($gradBrush, $bgPath)

# Subtle top highlight
$highlight = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point 0, 0),
    (New-Object System.Drawing.Point 0, ($size/2)),
    [System.Drawing.Color]::FromArgb(60, 255, 255, 255),
    [System.Drawing.Color]::FromArgb( 0, 255, 255, 255)
)
$g.FillPath($highlight, $bgPath)

# Robot head
$headW = 150; $headH = 130
$headX = ($size - $headW) / 2
$headY = 80
$headPath  = New-RoundedRect $headX $headY $headW $headH 28
$headBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 30, 30, 46))
$g.FillPath($headBrush, $headPath)
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 17, 17, 27)), 3
$g.DrawPath($pen, $headPath)

# Antenna stalk
$antennaPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 30, 30, 46)), 6
$antennaPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$antennaPen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
$cx = $size / 2
$g.DrawLine($antennaPen, [single]$cx, [single]$headY, [single]$cx, [single]($headY - 32))

# Antenna ball + glow
$glowSize = 38
$glowBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(80, 245, 194, 231))
$g.FillEllipse($glowBrush, [int]($cx - $glowSize/2), [int]($headY - 32 - 22 - ($glowSize-22)/2), $glowSize, $glowSize)
$ballSize  = 22
$ballBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 245, 194, 231))
$g.FillEllipse($ballBrush, [int]($cx - $ballSize/2), [int]($headY - 32 - $ballSize), $ballSize, $ballSize)

# Eyes
$eyeSize = 28
$eyeY = $headY + 38
$leftEyeX  = $headX + 28
$rightEyeX = $headX + $headW - 28 - $eyeSize
$eyeBrush  = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 148, 226, 213))
$g.FillEllipse($eyeBrush, $leftEyeX,  $eyeY, $eyeSize, $eyeSize)
$g.FillEllipse($eyeBrush, $rightEyeX, $eyeY, $eyeSize, $eyeSize)

# Eye sparkles
$sparkleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
$g.FillEllipse($sparkleBrush, ($leftEyeX  + 6), ($eyeY + 6), 8, 8)
$g.FillEllipse($sparkleBrush, ($rightEyeX + 6), ($eyeY + 6), 8, 8)

# Smile
$mouthRect = New-Object System.Drawing.Rectangle ($headX + 40), ($headY + 70), ($headW - 80), 40
$mouthPen  = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 148, 226, 213)), 6
$mouthPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$mouthPen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawArc($mouthPen, $mouthRect, 20, 140)

$bmp.Save($PngPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()

# --- 2. Wrap PNG into a proper .ico container ---------------------------
Write-Host "Wrapping PNG into .ico container..." -ForegroundColor Cyan

$pngBytes = [System.IO.File]::ReadAllBytes($PngPath)
$pngSize  = $pngBytes.Length

$fs = [System.IO.File]::Open($IconPath, 'Create')
$bw = New-Object System.IO.BinaryWriter $fs
try {
    # ICONDIR (6 bytes)
    $bw.Write([uint16]0)              # reserved
    $bw.Write([uint16]1)              # type 1 = icon
    $bw.Write([uint16]1)              # 1 image

    # ICONDIRENTRY (16 bytes)
    $bw.Write([byte]0)                # width  (0 = 256)
    $bw.Write([byte]0)                # height (0 = 256)
    $bw.Write([byte]0)                # color palette
    $bw.Write([byte]0)                # reserved
    $bw.Write([uint16]1)              # color planes
    $bw.Write([uint16]32)             # bits per pixel
    $bw.Write([uint32]$pngSize)       # size of image data
    $bw.Write([uint32]22)             # offset to image data

    $bw.Write($pngBytes)
} finally {
    $bw.Close()
    $fs.Close()
}

Remove-Item $PngPath -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "  Icon saved: $IconPath" -ForegroundColor Green

# --- 3. Create desktop shortcut ----------------------------------------
$launcherBat = Join-Path $ScriptDir "LAUNCHER.bat"
if (-not (Test-Path $launcherBat)) {
    Write-Host ""
    Write-Host "  NOTE: LAUNCHER.bat not found in this folder, so no desktop shortcut was created." -ForegroundColor Yellow
    Write-Host "  Put Make-Icon.ps1 in the same folder as LAUNCHER.bat and re-run to get the shortcut." -ForegroundColor Yellow
} else {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $lnkPath = Join-Path $desktop "NoobAI.lnk"

    $wsh = New-Object -ComObject WScript.Shell
    $sc  = $wsh.CreateShortcut($lnkPath)
    $sc.TargetPath       = $launcherBat
    $sc.WorkingDirectory = $ScriptDir
    $sc.IconLocation     = "$IconPath,0"
    $sc.Description      = "NoobAI Launcher - your local AI assistant"
    $sc.WindowStyle      = 1
    $sc.Save()

    Write-Host "  Desktop shortcut: $lnkPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Look on your Desktop for the friendly robot face icon!" -ForegroundColor Cyan
}

Write-Host ""
Read-Host "Press ENTER to close"
