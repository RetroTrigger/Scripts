# Personal Scripts Collection

A collection of handy scripts for system setup, maintenance, and automation across different Linux distributions and platforms.

## Table of Contents
- [System Setup](#system-setup)
- [Window Managers](#window-managers)
- [Development Environment](#development-environment)
- [Server Management](#server-management)
- [Gaming](#gaming)
- [Utilities](#utilities)
- [Contribution](#contribution)

## System Setup

### Alpine Linux

#### Plexamp Kiosk
Transforms Alpine Linux into a dedicated Plexamp music kiosk with X11/Openbox, Flatpak, PipeWire audio (USB DAC/HDMI/onboard), auto-login, and daily auto-updates.
```bash
# Run as root (su - first, or from Alpine installer)
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/alpine-plexamp-kiosk.sh | sh
```

### Arch Linux

#### Post-Installation Setup
Installs essential packages, enables firewall and trim, and sets up graphical applications and command-line utilities for Arch Linux.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/Arch_post_install.sh | bash
```

### Ubuntu

#### System Setup
Configures Ubuntu with Wine, Lutris, Steam, NVIDIA drivers, Xanmod kernel, GameMode, and custom Proton for gaming.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/Ubuntu-setup.sh | bash
```

## Window Managers

### AwesomeWM

#### Arch Linux Setup
Installs and configures AwesomeWM on Arch Linux with rofi, picom, fonts, themes, icons, and dotfiles from GitHub.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/awesomewm-setup-arch.sh | bash
```

#### Debian/Ubuntu Setup
Sets up AwesomeWM on Debian/Ubuntu systems with rofi, picom, fonts, themes, icons, and dotfiles configuration.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/awesomewm-setup-debian.sh | bash
```

#### Fedora Setup
Installs AwesomeWM on Fedora with dependencies, Papirus icons, and Titus Awesome configuration.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/titus-awesome-fedora.sh | bash
```

### DWM Installation
Cross-distribution script that detects package manager, installs DWM with flexipatch, compiles suckless tools (dwm, st, dmenu), and sets up display manager or startx.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/base-dwm-install.sh | bash
```

### BSPWM Installation
Installs and configures BSPWM window manager with kitty, picom, rofi, and other essential tools across multiple Linux distributions.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/BSPWM-Install.sh | bash
```

### DWM Recompile
Recompiles DWM after configuration changes, moves config.h to config.def.h, and restarts DWM.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/recompile.sh | bash
```

## Development Environment

### ZSH Installation
Installs ZSH with Powerlevel10k theme, syntax highlighting, autosuggestions, autojump, and custom configuration from ChrisTitusTech.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/zsh.sh | bash
```

### GNOME Extensions
Interactive menu-driven installer for GNOME Shell extensions with backup/restore functionality and extension management.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/install_gnome_extensions.sh | bash
```

### VirtualBox Installation
Cross-distribution VirtualBox installer that detects OS, installs dependencies, VirtualBox, extension pack, and downloads Guest Additions ISO.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/install_virtualbox.sh | bash
```

### Flatpak Installation
Installs Flatpak and Flathub repository, configures GTK theme overrides, and installs a curated list of Flatpak applications.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/flatpack-install | bash
```

## Server Management

### Proxmox

#### Share Creation
Creates a Samba share on Proxmox for VM template storage with proper permissions and guest access.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/proxmox_share_create.sh | bash
```

#### VM Import (Bash)
Interactive script to convert and import VMs (OVA, VMDK, or directories) into Proxmox VE with storage selection and automatic VMID assignment.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/vms2proxmox.sh | bash
```

#### VM Import (Python)
Python-based GUI tool using dialog for converting and importing VMs into Proxmox, managing templates, and downloading VulnHub templates.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/vm-import-prox.py | bash
```

#### VM Import (Alternative)
Alternative bash script for importing VMs into Proxmox with NFS template directory setup and interactive menu.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/vm-import-prox.sh | bash
```

## Network

### NFS Mount Manager
Interactive menu-driven tool to create NFS shares, mount existing shares with systemd automount, and manage NFS exports.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/nfs_mount_manager.sh | sudo bash
```

## Gaming

### Linux Gaming Setup
Comprehensive gaming setup for Ubuntu with NVIDIA drivers, Xanmod kernel, Wine, Lutris, Steam, GameMode, and custom Proton installation.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/Ultimate-Linux-Gaming.sh | bash
```

### Lancache Prefill Installation
Installs and configures Steam, Battle.net, and Epic Games Lancache prefill tools with systemd timers and cron jobs for automated caching.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/prefill_install.sh | bash
```

### Minecraft Server Manager
Full-featured Minecraft FTB server manager for Alpine Linux with automatic updates, OpenRC service, Samba share setup, and cron scheduling.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/minecraft-server-manager.sh | bash
```

### Update Minecraft Server
Updates an existing FTB Minecraft server to the latest version, backs up world data, and restores it after update.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/update-minecraft.sh | bash
```

### Convert Xbox Games (GUI)
Graphical tool using Zenity to convert Xbox game folders to compressed ISO.squashfs files with progress tracking and compression options.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/convert-xbox-games-gui.sh | bash
```

### Mount and Extract PS3 ISOs
Mounts PS3 ISO files, extracts contents, and compresses them into squashfs format with zstd compression for space-efficient storage.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/mount_and_extract_ps3_isos.sh | bash
```

### Check Complete Games Set
Python script that scrapes Wikipedia for PlayStation 2 game list and checks which games are missing from a local collection.
```bash
python3 check\ complete\ games\ set.py
```

### Total Steam Cache Size
Python script that calculates total size of a Steam library by fetching game sizes from SteamDB using Steam API.
```bash
python3 total-steamcache-size.py
```

## Utilities

### Display IP on Login
Creates a MOTD (Message of the Day) script that displays system IP address and hostname information at login.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/display-ip-motd.sh | bash
```

### Sort Folders
Organizes folders alphabetically into letter-based directories (A-Z, # for numbers), handling "The" prefix and showing progress.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/sort_folders.sh | bash
```

### Unzip Files (Enhanced)
Enhanced unzip utility that extracts ZIP files into directories named after the archive, handles nested directories, and removes ZIP files after extraction.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/new_unzip.sh | bash
```

### Unzip Files (Simple)
Simple script that extracts all ZIP files in current directory into folders named after each ZIP file.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/unzip.sh | bash
```

## Contribution

Contributions are welcome! If you'd like to add or improve any scripts, please follow these steps:

1. Fork the repository
2. Create a new branch for your feature/fix
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

Please ensure your code follows the existing style and includes appropriate documentation.

## License

This project is open source and available under the [MIT License](LICENSE).
