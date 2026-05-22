<#
.SYNOPSIS
    Gives your AI crew "superpowers" via free, open-source MCP servers.

.DESCRIPTION
    MCP = Model Context Protocol. Think of it as USB ports for AI agents -
    you plug in a "server" and the AI gains a new ability.

    EVERYTHING IN THIS SCRIPT IS 100% FREE. No API keys. No accounts.
    No credit cards. No "free trial that expires".

    Adds these abilities to your crew:
      - filesystem        : safer, faster file ops across whitelisted folders
      - fetch             : grab any web page as clean text
      - duckduckgo        : web SEARCH that needs no API key
      - git               : full git operations (clone, commit, diff, etc.)
      - memory            : long-term memory across chats (knowledge graph)
      - sequential-thinking : forces step-by-step reasoning (smarter answers)
      - time              : current time/date/timezone math
      - sqlite            : query/manage local databases

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

function Hdr ($m) { Write-Host "`n========== $m ==========" -ForegroundColor Cyan }
function OK  ($m) { Write-Host "  [OK]   $m" -ForegroundColor Green }
function Inf ($m) { Write-Host "  [INFO] $m" -ForegroundColor Yellow }
function Bad ($m) { Write-Host "  [ERR]  $m" -ForegroundColor Red }

Clear-Host
Write-Host @"
   __  __  ___ ___    ___                                      _
  |  \/  |/ __| _ \  / __|_  _ _ __  ___ _ _ _ __  _____ __ _ (_)__ ___ ___
  | |\/| | (__|  _/  \__ \ || | '_ \/ -_) '_| '_ \/ _ \ V  V /(_-</ -_|_-<
  |_|  |_|\___|_|    |___/\_,_| .__/\___|_| | .__/\___/\_/\_/  /__/\___/__/
                              |_|           |_|
   100% Free MCP Servers - No keys, no accounts, no money
"@ -ForegroundColor Cyan
Write-Host ""
Read-Host "  Press ENTER to begin"

# --- 1. Node.js (for most MCP servers) -----------------------------------
Hdr "1.  Installing Node.js (free, needed to run MCP servers)"

if (Get-Command node -ErrorAction SilentlyContinue) {
    OK "Node.js already installed: $(node --version)"
} else {
    Inf "Installing Node.js LTS via winget..."
    winget install --id OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
    if (Get-Command node -ErrorAction SilentlyContinue) { OK "Node.js installed: $(node --version)" }
    else { Bad "Node.js install may need a reboot. Re-run this script after rebooting." }
}

# --- 2. uv (for Python-based MCP servers) --------------------------------
Hdr "2.  Installing uv (free Python tool runner)"

if (Get-Command uvx -ErrorAction SilentlyContinue) {
    OK "uv already installed."
} else {
    Inf "Installing uv via winget..."
    winget install --id astral-sh.uv --silent --accept-package-agreements --accept-source-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
    if (Get-Command uvx -ErrorAction SilentlyContinue) { OK "uv installed." }
    else { Inf "uv install may need a new terminal. Continuing anyway." }
}

# --- 3. Optional: Everything (instant filename search) ------------------
Hdr "3.  Optional: Everything search tool (FREE, instant filename search)"

$installEverything = Read-Host "  Install Everything by voidtools? (gives the AI instant file search)  [Y/n]"
if ($installEverything -notmatch '^[nN]') {
    Inf "Installing Everything..."
    winget install --id voidtools.Everything --silent --accept-package-agreements --accept-source-agreements 2>$null
    OK "Everything installed (or already present)."
} else {
    Inf "Skipping Everything (you can install it later)."
}

# --- 4. Note about server fetching --------------------------------------
# npx and uvx fetch and cache servers on first use. We don't need to
# pre-install them - just mention it so first invocation isn't a surprise.
Hdr "4.  About MCP server downloads"
Inf "MCP servers are fetched on first use (5-30 seconds each)."
Inf "After that they're cached locally and start instantly."

# --- 5. Pick allowed folders --------------------------------------------
Hdr "5.  Pick which folders the AI is allowed to read/write"

Write-Host ""
Write-Host "  For safety, the filesystem MCP server only sees folders you list."
Write-Host "  Common choices: $env:USERPROFILE, D:\, E:\"
Write-Host "  Separate multiple with semicolons."
Write-Host ""
$default = "$env:USERPROFILE;$env:USERPROFILE\Desktop;$env:USERPROFILE\Downloads;$env:USERPROFILE\Documents"
$folders = Read-Host "  Folders (ENTER for default: home + Desktop + Downloads + Documents)"
if ([string]::IsNullOrWhiteSpace($folders)) { $folders = $default }
$folderList = $folders -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and (Test-Path $_) }

if (-not $folderList -or $folderList.Count -eq 0) {
    Bad "No valid folders given. Using your home folder."
    $folderList = @($env:USERPROFILE)
}
foreach ($f in $folderList) { OK "Allowed: $f" }

# --- 6. Write Roo Code MCP settings -------------------------------------
Hdr "6.  Configuring Roo Code to use the MCP servers"

$rooSettingsDir = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
if (-not (Test-Path $rooSettingsDir)) { New-Item -Path $rooSettingsDir -ItemType Directory -Force | Out-Null }
$rooMcpPath = Join-Path $rooSettingsDir "mcp_settings.json"

$crewDir = "$env:USERPROFILE\AI-Crew"
if (-not (Test-Path $crewDir)) { New-Item -Path $crewDir -ItemType Directory -Force | Out-Null }

# filesystem server takes folder paths as positional args
$fsArgs = @('-y','@modelcontextprotocol/server-filesystem') + $folderList

$mcpConfig = [ordered]@{
    mcpServers = [ordered]@{
        filesystem = @{
            command     = "npx"
            args        = $fsArgs
            disabled    = $false
            alwaysAllow = @('list_allowed_directories','list_directory','read_file','search_files','get_file_info')
        }
        fetch = @{
            command     = "uvx"
            args        = @("mcp-server-fetch")
            disabled    = $false
            alwaysAllow = @('fetch')
        }
        "duckduckgo-search" = @{
            command     = "npx"
            args        = @("-y","duckduckgo-mcp-server")
            disabled    = $false
            alwaysAllow = @('search')
        }
        git = @{
            command     = "uvx"
            args        = @("mcp-server-git")
            disabled    = $false
            alwaysAllow = @('git_status','git_diff','git_log','git_show')
        }
        memory = @{
            command     = "npx"
            args        = @("-y","@modelcontextprotocol/server-memory")
            disabled    = $false
            alwaysAllow = @('read_graph','search_nodes','open_nodes')
            env         = @{ MEMORY_FILE_PATH = "$crewDir\memory.json" }
        }
        "sequential-thinking" = @{
            command     = "npx"
            args        = @("-y","@modelcontextprotocol/server-sequential-thinking")
            disabled    = $false
            alwaysAllow = @('sequentialthinking')
        }
        time = @{
            command     = "uvx"
            args        = @("mcp-server-time")
            disabled    = $false
            alwaysAllow = @('get_current_time','convert_time')
        }
        sqlite = @{
            command     = "uvx"
            args        = @("mcp-server-sqlite","--db-path","$crewDir\crew.db")
            disabled    = $false
            alwaysAllow = @('list_tables','describe_table','read_query')
        }
    }
}

$mcpConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $rooMcpPath -Encoding UTF8
OK "MCP settings written: $rooMcpPath"

# Also write for Cline if present
$clineSettingsDir = "$env:APPDATA\Code\User\globalStorage\saoudrizwan.claude-dev\settings"
if (Test-Path $clineSettingsDir) {
    $clineMcpPath = Join-Path $clineSettingsDir "cline_mcp_settings.json"
    $mcpConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $clineMcpPath -Encoding UTF8
    OK "Also wrote MCP settings for Cline: $clineMcpPath"
}

# --- 7. Cheat sheet on desktop ------------------------------------------
Hdr "7.  Writing cheat sheet"

$cheat = @"
# Your Crew's New Superpowers (all 100% free)

| Superpower | What it does | Try saying... |
|---|---|---|
| filesystem | Read/write files across allowed drives, fast | "Find every PDF over 10 MB in my Documents" |
| fetch | Grab any web page as clean text | "Fetch the latest changelog from ollama.com/blog" |
| duckduckgo | Search the web (NO API key needed) | "Search for the latest RTX 3070 Ti driver" |
| git | Full git operations | "What's changed since my last commit?" |
| memory | Remembers facts across chats forever | "Remember that my main drive is D:" then in a new chat: "What's my main drive?" |
| sequential-thinking | Forces step-by-step reasoning | "Plan a backup strategy step by step" |
| time | Current time, timezones, date math | "What time is it in Tokyo right now?" |
| sqlite | Query/build local databases | "Make a SQLite db of my installed apps" |

## Allowed folders for filesystem
$($folderList -join "`n")

## Memory file
$crewDir\memory.json  (you can read/edit it yourself)

## Where the AI keeps its database
$crewDir\crew.db

## How to add MORE servers later
Roo Code MCP settings:
  $rooMcpPath

Browse free MCP servers:
  - https://github.com/modelcontextprotocol/servers
  - https://github.com/punkpeye/awesome-mcp-servers

## How to TURN OFF a server
Edit the file above and change "disabled": false  ->  "disabled": true

## Costs
ZERO. Nothing here phones home. Nothing here requires an account.
Everything runs on YOUR PC.

  -- Project: https://github.com/LIN4CRE/NoobAiSetup
"@

$cheat | Set-Content -Path "$([Environment]::GetFolderPath('Desktop'))\AI-Superpowers-Cheatsheet.md" -Encoding UTF8
OK "Cheat sheet saved to your desktop."

Hdr "Done!"
Write-Host ""
OK "Your crew now has 8 free superpowers."
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Cyan
Write-Host "    1. Close VS Code if it's open."
Write-Host "    2. Double-click Launch-AI-Crew.bat on your desktop."
Write-Host "    3. Click the Roo Code icon, then click 'MCP Servers' near the top."
Write-Host "    4. You should see all 8 servers with a green dot."
Write-Host "    5. Ask the Foreman: 'What MCP tools do you have available?'"
Write-Host ""
Inf "First time each server runs it'll download (~5-30 sec). After that it's instant."
Write-Host ""
Read-Host "Press ENTER to close"
