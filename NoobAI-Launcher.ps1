<#
.SYNOPSIS
    NoobAI Launcher - a friendly GUI for the whole toolkit.

.DESCRIPTION
    One window. Big buttons. Status lights. Live activity log.
    Uses WPF (built into Windows) so no extra installs needed.

.NOTES
    Project : NoobAiSetup
    Version : 1.0.0
    Repo    : https://github.com/LIN4CRE/NoobAiSetup
    License : MIT
#>

# --- self-elevate ---------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Script directory (where all the .ps1 files live)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Shared script-scope state (visible to event handlers without runspace gymnastics)
$script:RunningProcess = $null

# --- XAML window definition ----------------------------------------------
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="NoobAI Launcher" Height="720" Width="900"
        WindowStartupLocation="CenterScreen"
        Background="#1E1E2E" FontFamily="Segoe UI" FontSize="13">
  <Window.Resources>
    <Style x:Key="BigBtn" TargetType="Button">
      <Setter Property="Background" Value="#313244"/>
      <Setter Property="Foreground" Value="#CDD6F4"/>
      <Setter Property="BorderBrush" Value="#45475A"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="14,10"/>
      <Setter Property="Margin" Value="0,4"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="HorizontalContentAlignment" Value="Left"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}"
                    CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#45475A"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.5"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="H1" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#89B4FA"/>
      <Setter Property="FontSize" Value="22"/>
      <Setter Property="FontWeight" Value="Bold"/>
    </Style>
    <Style x:Key="H2" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#F5C2E7"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Margin" Value="0,12,0,4"/>
    </Style>
  </Window.Resources>

  <Grid Margin="16">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="360"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <StackPanel Grid.Row="0" Grid.ColumnSpan="2" Margin="0,0,0,12">
      <TextBlock Text="🤖 NoobAI Launcher" Style="{StaticResource H1}"/>
      <TextBlock Foreground="#A6ADC8" Text="Pick a button on the left. Watch the log on the right. That's it."/>
    </StackPanel>

    <ScrollViewer Grid.Row="1" Grid.Column="0" VerticalScrollBarVisibility="Auto" Margin="0,0,12,0">
      <StackPanel>
        <TextBlock Text="STEP 1 - INSTALL" Style="{StaticResource H2}"/>
        <Button x:Name="btnInstall" Style="{StaticResource BigBtn}" Content="📦  Install everything (base)"/>
        <Button x:Name="btnMove"    Style="{StaticResource BigBtn}" Content="🚚  Move AI models to another drive"/>
        <Button x:Name="btnCrew"    Style="{StaticResource BigBtn}" Content="👷  Add the AI Crew (specialists)"/>
        <Button x:Name="btnPowers"  Style="{StaticResource BigBtn}" Content="⚡  Add MCP Superpowers (free)"/>

        <TextBlock Text="DAILY USE" Style="{StaticResource H2}"/>
        <Button x:Name="btnLaunchCrew" Style="{StaticResource BigBtn}" Content="🚀  Launch the AI Crew"/>
        <Button x:Name="btnQuickChat"  Style="{StaticResource BigBtn}" Content="💬  Quick chat (terminal)"/>

        <TextBlock Text="MAINTENANCE" Style="{StaticResource H2}"/>
        <Button x:Name="btnHealth"       Style="{StaticResource BigBtn}" Content="🩺  Health Check"/>
        <Button x:Name="btnUpdateModels" Style="{StaticResource BigBtn}" Content="🔄  Update AI models"/>
        <Button x:Name="btnOpenFolder"   Style="{StaticResource BigBtn}" Content="📁  Open Crew workspace folder"/>
        <Button x:Name="btnMakeIcon"     Style="{StaticResource BigBtn}" Content="🎨  Regenerate desktop icon"/>

        <TextBlock Text="DANGER ZONE" Style="{StaticResource H2}" Foreground="#F38BA8"/>
        <Button x:Name="btnUninstall" Style="{StaticResource BigBtn}" Content="🗑️  Uninstall everything"/>
      </StackPanel>
    </ScrollViewer>

    <Grid Grid.Row="1" Grid.Column="1">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>

      <Border Grid.Row="0" Background="#181825" CornerRadius="6" Padding="12" Margin="0,0,0,8">
        <StackPanel>
          <TextBlock Text="System Status" Foreground="#89B4FA" FontWeight="Bold" Margin="0,0,0,8"/>
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0">
              <TextBlock x:Name="stOllama"   Foreground="#A6ADC8" Text="• Ollama:   checking..."/>
              <TextBlock x:Name="stVSCode"   Foreground="#A6ADC8" Text="• VS Code:  checking..."/>
              <TextBlock x:Name="stCline"    Foreground="#A6ADC8" Text="• Cline:    checking..."/>
              <TextBlock x:Name="stRoo"      Foreground="#A6ADC8" Text="• Roo Code: checking..."/>
            </StackPanel>
            <StackPanel Grid.Column="1">
              <TextBlock x:Name="stModels"     Foreground="#A6ADC8" Text="• Models:   checking..."/>
              <TextBlock x:Name="stModelsPath" Foreground="#A6ADC8" Text="• Location: checking..."/>
              <TextBlock x:Name="stGpu"        Foreground="#A6ADC8" Text="• GPU:      checking..."/>
              <TextBlock x:Name="stOrphans"    Foreground="#A6ADC8" Text="• Orphans:  checking..."/>
            </StackPanel>
          </Grid>
          <Button x:Name="btnRefresh" Style="{StaticResource BigBtn}" Content="🔄  Refresh status"
                  HorizontalAlignment="Left" Margin="0,8,0,0" Padding="10,4"/>
        </StackPanel>
      </Border>

      <Border Grid.Row="1" Background="#11111B" CornerRadius="6" Padding="0">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <Grid Grid.Row="0" Background="#181825">
            <TextBlock Text="  Activity Log" Foreground="#89B4FA" FontWeight="Bold" Padding="8,6"/>
            <Button x:Name="btnClearLog" Content="Clear" HorizontalAlignment="Right" Margin="0,4,8,4"
                    Padding="8,2" Background="#313244" Foreground="#CDD6F4" BorderBrush="#45475A"/>
          </Grid>
          <TextBox x:Name="txtLog" Grid.Row="1"
                   Background="#11111B" Foreground="#CDD6F4" BorderThickness="0"
                   FontFamily="Cascadia Mono, Consolas" FontSize="12"
                   IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"
                   Padding="10"/>
        </Grid>
      </Border>
    </Grid>

    <Grid Grid.Row="2" Grid.ColumnSpan="2" Margin="0,12,0,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <ProgressBar x:Name="pb" Grid.Column="0" Height="6" Background="#313244" Foreground="#89B4FA"
                   BorderThickness="0" IsIndeterminate="False"/>
      <TextBlock Grid.Column="1" Foreground="#6C7086" Margin="12,0,0,0"
                 Text="NoobAI Launcher v1.0 · github.com/LIN4CRE/NoobAiSetup"/>
    </Grid>
  </Grid>
</Window>
"@

# --- Load XAML ----------------------------------------------------------
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Collect named controls
$ctrl = @{}
foreach ($name in @(
    'btnInstall','btnMove','btnCrew','btnPowers',
    'btnLaunchCrew','btnQuickChat',
    'btnHealth','btnUpdateModels','btnOpenFolder','btnMakeIcon',
    'btnUninstall','btnRefresh','btnClearLog',
    'stOllama','stVSCode','stCline','stRoo','stModels','stModelsPath','stGpu','stOrphans',
    'txtLog','pb'
)) {
    $ctrl[$name] = $window.FindName($name)
}

# --- Helpers ------------------------------------------------------------
function Write-Log {
    param([string]$Message, [string]$Color = '#CDD6F4')
    $stamp = (Get-Date).ToString('HH:mm:ss')
    $ctrl.txtLog.Dispatcher.Invoke([Action]{
        $ctrl.txtLog.AppendText("[$stamp] $Message`r`n")
        $ctrl.txtLog.ScrollToEnd()
    })
}

function Set-StatusLine {
    param($Label, [string]$Text, $Ok)
    $color = switch ($Ok) {
        $true  { '#A6E3A1' }
        $false { '#F38BA8' }
        default { '#A6ADC8' }
    }
    $Label.Dispatcher.Invoke([Action]{
        $Label.Text = $Text
        $Label.Foreground = $color
    })
}

function Set-ButtonsEnabled {
    param([bool]$Enabled)
    $window.Dispatcher.Invoke([Action]{
        $ctrl.pb.IsIndeterminate = -not $Enabled
        foreach ($k in $ctrl.Keys) {
            if ($k -like 'btn*') { $ctrl[$k].IsEnabled = $Enabled }
        }
    })
}

# --- Status refresh -----------------------------------------------------
function Update-Status {
    Write-Log "Refreshing status..."

    # Ollama
    $ollamaExe = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
    $ollamaInstalled = Test-Path $ollamaExe
    $ollamaRunning   = [bool](Get-Process ollama -ErrorAction SilentlyContinue)
    if ($ollamaInstalled) {
        $txt = if ($ollamaRunning) { "• Ollama:   running ✓" } else { "• Ollama:   installed (stopped)" }
        Set-StatusLine $ctrl.stOllama $txt $ollamaRunning
    } else {
        Set-StatusLine $ctrl.stOllama "• Ollama:   NOT installed" $false
    }

    # VS Code
    $vscode = (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe") -or `
              (Test-Path "$env:ProgramFiles\Microsoft VS Code\Code.exe")
    Set-StatusLine $ctrl.stVSCode ("• VS Code:  " + $(if ($vscode) {"installed ✓"} else {"NOT installed"})) $vscode

    # Extensions
    $codeCmd = $null
    foreach ($p in @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
    )) { if (Test-Path $p) { $codeCmd = $p; break } }
    if ($codeCmd) {
        $exts = & $codeCmd --list-extensions 2>$null
        $haveCline = $exts -contains 'saoudrizwan.claude-dev'
        $haveRoo   = $exts -contains 'rooveterinaryinc.roo-cline'
        Set-StatusLine $ctrl.stCline ("• Cline:    " + $(if ($haveCline) {"installed ✓"} else {"not installed"})) $haveCline
        Set-StatusLine $ctrl.stRoo   ("• Roo Code: " + $(if ($haveRoo)   {"installed ✓"} else {"not installed"})) $haveRoo
    } else {
        Set-StatusLine $ctrl.stCline "• Cline:    (need VS Code)" $null
        Set-StatusLine $ctrl.stRoo   "• Roo Code: (need VS Code)" $null
    }

    # Models path
    $mMachine = [Environment]::GetEnvironmentVariable('OLLAMA_MODELS','Machine')
    $mUser    = [Environment]::GetEnvironmentVariable('OLLAMA_MODELS','User')
    $effective = if ($mMachine) { $mMachine } elseif ($mUser) { $mUser } else { Join-Path $env:USERPROFILE ".ollama\models" }
    Set-StatusLine $ctrl.stModelsPath ("• Location: $effective") $true

    # Models count
    if ($ollamaInstalled -and $ollamaRunning) {
        try {
            $r = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -TimeoutSec 3
            $count = @($r.models).Count
            Set-StatusLine $ctrl.stModels ("• Models:   $count installed") ($count -gt 0)
        } catch {
            Set-StatusLine $ctrl.stModels "• Models:   API not responding" $false
        }
    } else {
        Set-StatusLine $ctrl.stModels "• Models:   (start Ollama to see)" $null
    }

    # GPU
    try {
        $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match 'NVIDIA|AMD|Intel Arc' } | Select-Object -First 1
        if ($gpu) {
            Set-StatusLine $ctrl.stGpu ("• GPU:      " + $gpu.Name) $true
        } else {
            Set-StatusLine $ctrl.stGpu "• GPU:      no discrete GPU" $null
        }
    } catch {
        Set-StatusLine $ctrl.stGpu "• GPU:      detection failed" $null
    }

    # Orphan model folders (fast scan)
    $found = New-Object System.Collections.Generic.HashSet[string]
    foreach ($drive in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used })) {
        foreach ($c in @(
            (Join-Path $drive.Root ".ollama\models"),
            (Join-Path $drive.Root "Ollama\models"),
            (Join-Path $drive.Root "AI\Ollama\models")
        )) {
            if (Test-Path $c) { [void]$found.Add((Resolve-Path $c).Path) }
        }
    }
    $orphans = @($found | Where-Object { $_ -ine $effective })
    if ($orphans.Count -eq 0) {
        Set-StatusLine $ctrl.stOrphans "• Orphans:  none ✓" $true
    } else {
        Set-StatusLine $ctrl.stOrphans ("• Orphans:  $($orphans.Count) found - run 'Move models'") $false
    }

    Write-Log "Status refresh complete."
}

# --- Run a script in a new admin window, with completion polling --------
function Invoke-Script {
    param([string]$ScriptName, [string]$Friendly)

    $path = Join-Path $ScriptDir $ScriptName
    if (-not (Test-Path $path)) {
        Write-Log "ERROR: Cannot find $ScriptName in $ScriptDir" '#F38BA8'
        [System.Windows.MessageBox]::Show(
            "Couldn't find:`n$path`n`nMake sure all the script files are in the same folder as this launcher.",
            "File missing", 'OK', 'Error') | Out-Null
        return
    }

    if ($script:RunningProcess -and -not $script:RunningProcess.HasExited) {
        Write-Log "Another script is still running. Wait for it to finish." '#F9E2AF'
        return
    }

    Write-Log ""
    Write-Log "================ $Friendly ================" '#89B4FA'
    Write-Log "Running: $ScriptName"
    Write-Log "(A new PowerShell window will open. Follow the prompts there.)"

    Set-ButtonsEnabled $false

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName  = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$path`""
        $psi.UseShellExecute = $true        # opens a real window the user can interact with
        $psi.Verb            = "runas"      # admin elevation

        $script:RunningProcess = [System.Diagnostics.Process]::Start($psi)

        # Poll for completion using a DispatcherTimer (no runspace scoping problems)
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromMilliseconds(500)
        $timer.Add_Tick({
            if ($script:RunningProcess.HasExited) {
                $timer.Stop()
                $ec = $script:RunningProcess.ExitCode
                $script:RunningProcess = $null
                $color = if ($ec -eq 0) { '#A6E3A1' } else { '#F9E2AF' }
                Write-Log "Script finished (exit code $ec)." $color
                Set-ButtonsEnabled $true
                Update-Status
            }
        })
        $timer.Start()
    } catch {
        Write-Log "Failed to start script: $_" '#F38BA8'
        Set-ButtonsEnabled $true
    }
}

# --- Button handlers ----------------------------------------------------
$ctrl.btnInstall.Add_Click({       Invoke-Script -ScriptName 'Setup-LocalAI.ps1'         -Friendly 'Install base (Ollama + VS Code + model)' })
$ctrl.btnMove.Add_Click({          Invoke-Script -ScriptName 'Move-AI-Models.ps1'        -Friendly 'Move AI models to another drive' })
$ctrl.btnCrew.Add_Click({          Invoke-Script -ScriptName 'Setup-AI-Team.ps1'         -Friendly 'Install AI Crew (specialists)' })
$ctrl.btnPowers.Add_Click({        Invoke-Script -ScriptName 'Setup-MCP-Superpowers.ps1' -Friendly 'Add MCP Superpowers' })
$ctrl.btnHealth.Add_Click({        Invoke-Script -ScriptName 'Health-Check.ps1'          -Friendly 'Health Check' })
$ctrl.btnMakeIcon.Add_Click({      Invoke-Script -ScriptName 'Make-Icon.ps1'             -Friendly 'Generate desktop icon' })

$ctrl.btnUninstall.Add_Click({
    $r = [System.Windows.MessageBox]::Show(
        "This will walk you through removing everything.`n`nEvery destructive step asks Y/N first - default is NO.`n`nContinue?",
        'Uninstall', 'YesNo', 'Warning')
    if ($r -eq 'Yes') { Invoke-Script -ScriptName 'Uninstall-LocalAI.ps1' -Friendly 'Uninstall (step-by-step)' }
})

$ctrl.btnLaunchCrew.Add_Click({
    $bat = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Launch-AI-Crew.bat'
    if (Test-Path $bat) {
        Write-Log "Launching the AI Crew..."
        Start-Process $bat
    } else {
        Write-Log "Launch-AI-Crew.bat not found on Desktop. Run 'Add the AI Crew' first." '#F9E2AF'
        [System.Windows.MessageBox]::Show("You need to run 'Add the AI Crew' first.",'Crew not installed','OK','Information') | Out-Null
    }
})

$ctrl.btnQuickChat.Add_Click({
    $bat = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Quick-AI-Chat.bat'
    if (Test-Path $bat) {
        Write-Log "Opening quick chat..."
        Start-Process $bat
    } else {
        Write-Log "Quick-AI-Chat.bat not found on Desktop. Run 'Install everything' first." '#F9E2AF'
    }
})

$ctrl.btnUpdateModels.Add_Click({
    $ollamaExe = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
    if (-not (Test-Path $ollamaExe)) {
        Write-Log "Ollama not installed yet." '#F9E2AF'
        return
    }
    Write-Log "Updating AI models (pulls latest qwen3-coder:14b and qwen3:8b)..."
    Set-ButtonsEnabled $false
    try {
        Start-Process powershell.exe -ArgumentList @(
            "-NoProfile","-Command",
            "& '$ollamaExe' pull qwen3-coder:14b; & '$ollamaExe' pull qwen3:8b; Read-Host 'Done. Press ENTER to close'"
        ) -Wait
        Write-Log "Model update finished."
    } finally {
        Set-ButtonsEnabled $true
        Update-Status
    }
})

$ctrl.btnOpenFolder.Add_Click({
    foreach ($f in @("$env:USERPROFILE\AI-Crew","$env:USERPROFILE\AI-Workspace")) {
        if (Test-Path $f) {
            Start-Process explorer.exe $f
            Write-Log "Opened: $f"
            return
        }
    }
    Write-Log "Neither AI-Crew nor AI-Workspace exists yet. Install the crew first." '#F9E2AF'
})

$ctrl.btnRefresh.Add_Click({ Update-Status })
$ctrl.btnClearLog.Add_Click({ $ctrl.txtLog.Clear() })

# --- Welcome banner + initial status ------------------------------------
$ctrl.txtLog.AppendText("Welcome to NoobAI Launcher!`r`n")
$ctrl.txtLog.AppendText("------------------------------------------------------------`r`n")
$ctrl.txtLog.AppendText("First time? Click the buttons in order, top to bottom:`r`n")
$ctrl.txtLog.AppendText("   1. Install everything (base)`r`n")
$ctrl.txtLog.AppendText("   2. Move AI models  (optional, but recommended)`r`n")
$ctrl.txtLog.AppendText("   3. Add the AI Crew`r`n")
$ctrl.txtLog.AppendText("   4. Add MCP Superpowers`r`n")
$ctrl.txtLog.AppendText("Then use 'Launch the AI Crew' to start chatting.`r`n")
$ctrl.txtLog.AppendText("------------------------------------------------------------`r`n`r`n")

Update-Status

# --- Show window --------------------------------------------------------
$null = $window.ShowDialog()
