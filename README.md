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

### Arch Linux

#### Post-Installation Setup
Sets up a fresh Arch Linux installation with essential packages, drivers, and configuration.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/Arch_post_install.sh | bash
```

### Elementary OS

#### System Bootstrap
Configures Elementary OS with essential applications, themes, and system settings.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/EOS-BSTRP.sh | bash
```

### Fedora

#### Post-Installation Setup
Optimizes Fedora with additional repositories, packages, and system configurations.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/fedora-post.sh | bash
```

### Ubuntu

#### System Setup
Configures Ubuntu with essential packages, repositories, and system optimizations.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/Ubuntu-setup.sh | bash
```

## Window Managers

### AwesomeWM

#### Arch Linux Setup
Installs and configures AwesomeWM on Arch Linux with useful widgets and themes.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/awesomewm-setup-arch.sh | bash
```

#### Debian/Ubuntu Setup
Sets up AwesomeWM on Debian/Ubuntu systems with productivity tools and theming.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/awesomewm-setup-debian.sh | bash
```

### DWM Installation
Installs and configures DWM (Dynamic Window Manager) with essential patches and tools.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/dwm-install.sh | bash
```

### Openbox Configuration
Sets up Openbox window manager with a complete desktop environment and useful tools.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/openbox-starter-kit-install.sh | bash
```

## Development Environment

### ZSH Installation
Installs and configures ZSH with Oh-My-Zsh and popular plugins.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/zsh.sh | bash
```

### GNOME Extensions
Installs and configures useful GNOME Shell extensions for better productivity.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/install_gnome_extensions.sh | bash
```

## Server Management

### Lancache DNS Setup
Configures DNS for Lancache to optimize game downloads and updates.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/install_lancache.sh | bash
```

### Proxmox

#### Share Creation
Sets up shared storage on a Proxmox VE server for VM storage.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/proxmox_share_create.sh | bash
```

#### VM Conversion and Import
Converts and imports VMs into Proxmox VE from various formats.
```bash
curl -sSL https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/vms2proxmox.sh -o vms2proxmox.sh \
  && chmod +x vms2proxmox.sh \
  && ./vms2proxmox.sh
```

## Gaming

### Linux Gaming Setup
Installs and configures everything needed for gaming on Linux (Proton, Wine, etc.).
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/Ultimate-Linux-Gaming.sh | bash
```

### ATLauncher Installation
Installs the ATLauncher for managing Minecraft modpacks on Linux.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/linux-install-atlauncher.sh | bash
```

### FTB Direwolf20 Server
Sets up a Feed The Beast Direwolf20 Minecraft server with all required dependencies.
```bash
sh -c "$(wget -qO- https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/setup-minecraft.sh)"
```

### Minecraft Server Manager
Manages a Minecraft server with automatic updates and maintenance tasks.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/minecraft-server-manager.sh | bash
```

### Update Minecraft Server
Updates an existing Minecraft server to the latest version.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/update-minecraft.sh | bash
```

### Convert Xbox Games (GUI)
Provides a graphical interface to convert Xbox game files for use on PC.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/convert-xbox-games-gui.sh | bash
```

### Mount and Extract PS3 ISOs
Mounts and extracts PlayStation 3 ISO files for backup or modding.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/mount_and_extract_ps3_isos.sh | bash
```

## Utilities

### Display IP on Login
Shows system IP address and other useful information at login.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/display-ip-motd.sh | bash
```

### Sort Folders
Organizes files into categorized folders based on file types.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/sort_folders.sh | bash
```

### Unzip Files (Enhanced)
Enhanced unzip utility with better handling of various archive formats.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/new_unzip.sh | bash
```

### VM Import (Alternative)
Alternative script for importing VMs into Proxmox VE.
```bash
wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/vm-import-prox.sh | bash
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
