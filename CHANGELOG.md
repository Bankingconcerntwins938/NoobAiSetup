# Changelog

All notable changes to NoobAiSetup are documented here.
This project uses [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-05-22

First production release. 🎉

### Added
- **GUI launcher** (`LAUNCHER.bat` + `NoobAI-Launcher.ps1`) — native WPF window
  with big buttons, live status panel, and activity log.
- **Icon generator** (`Make-Icon.ps1`) — procedurally draws `NoobAI.ico` and
  creates a friendly robot desktop shortcut.
- **Base installer** (`Setup-LocalAI.ps1`) — Ollama, VS Code, Git, Cline,
  `qwen3-coder:14b` and `qwen3:8b` models.
- **AI Crew installer** (`Setup-AI-Team.ps1`) — installs Roo Code and defines
  6 specialist modes (Foreman, Sysadmin, Coder, Librarian, Researcher, Inspector).
- **MCP Superpowers installer** (`Setup-MCP-Superpowers.ps1`) — adds 8 free
  open-source MCP servers (filesystem, fetch, duckduckgo, git, memory,
  sequential-thinking, time, sqlite).
- **Model mover** (`Move-AI-Models.ps1`) — safely moves models off C: drive,
  fixes the `OLLAMA_MODELS` env var, deletes orphan duplicates.
- **Health check** (`Health-Check.ps1`) — read-only diagnostic showing
  installs, env vars, model locations, GPU, disk space, orphans.
- **Uninstaller** (`Uninstall-LocalAI.ps1`) — step-by-step removal, every
  destructive action opt-in.
- README with quick-start, screenshots, troubleshooting, and credits.
- MIT License.

### Safety
- All scripts self-elevate to Administrator.
- All scripts are idempotent — safe to re-run.
- Inspector specialist is hardcoded read-only at the extension level.
- Librarian specialist always dry-runs before bulk operations.
- Uninstaller defaults every prompt to **No**.
