# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

A personal collection of standalone shell and Python scripts for Linux system setup, server management, and automation. Scripts are designed to be fetched and piped to bash directly (e.g., `wget -O - <url> | bash`), so each script must be self-contained.

## Running Scripts

Scripts are standalone — run them directly:

```bash
bash <script-name>.sh
python3 <script-name>.py
```

No build step, test suite, or package manager is used. ShellCheck can be used for linting shell scripts:

```bash
shellcheck <script-name>.sh
```

## Script Conventions

**Shell scripts:**
- Use `set -e` or `set -euo pipefail` at the top for safe execution
- Define color variables and logging functions (`log`, `log_success`, `log_warn`, `log_error`) early in the script
- Detect the OS/package manager at runtime using patterns like checking for `pacman`, `apt`, `dnf`, `apk`
- Check for root/sudo at the start when elevated privileges are needed
- Use interactive TUI menus via `whiptail` or `dialog` for user prompts
- Variables are UPPER_CASE; functions are lower_snake_case

**Python scripts:**
- Require Python 3; dependencies are `requests` and `beautifulsoup4`
- No virtualenv or requirements.txt — dependencies must be installed system-wide

## Script Categories

- **System setup** (`alpine-plexamp-kiosk.sh`, `Ubuntu-setup.sh`, `Arch_post_install.sh`) — distro-specific post-install configuration
- **Window managers** (`base-dwm-install.sh`, `BSPWM-Install.sh`, `awesomewm-setup-*.sh`) — cross-distro WM installers with flexipatch/suckless tooling
- **Server/Proxmox** (`vms2proxmox.sh`, `vm-import-prox.*`, `nfs_mount_manager.sh`) — VM import, NFS/Samba share management
- **Gaming** (`minecraft-server-manager.sh`, `prefill_install.sh`, `convert-xbox-games-gui.sh`) — game server management and media tools
- **Utilities** (`sort_folders.sh`, `new_unzip.sh`, `bw_key_install.sh`) — file management and SSH key restoration via Bitwarden
- **Configuration** (`docker-compose.yml`, `recyclarr.yaml`) — media server stack (Sonarr, Radarr, Prowlarr, etc.)

## Key Architectural Pattern

Each script is fully independent with no shared library or sourced common file. When adding functionality that multiple scripts share (color output, OS detection, etc.), copy the pattern inline rather than extracting to a shared file — this preserves the "pipe to bash" usability.

The `base-dwm-install.sh` is the most complex script and is a good reference for the preferred structure: config variables at top, helper functions, OS detection, then sequential install phases with status output.
