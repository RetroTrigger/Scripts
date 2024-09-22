#!/bin/bash

# Check which Linux distribution is being used
if [ -f /etc/os-release ]; then
    # For newer versions of Debian, Ubuntu and other similar distros
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
    # For older versions of Debian, Ubuntu and other similar distros
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
elif [ -f /etc/arch-release ]; then
    # For Arch Linux
    OS="Arch Linux"
    VER=$(uname -r)
elif [ -f /etc/fedora-release ]; then
    # For Fedora
    OS="Fedora"
    VER=$(cat /etc/fedora-release | awk '{print $3}')
else
    # If we can't determine the Linux distribution, exit the script
    echo "Unable to determine the Linux distribution."
    exit 1
fi

# Update the package list
case "$OS" in
    Ubuntu|Linux\ Mint)
        sudo apt update
        ;;
    Debian\ GNU/Linux)
        sudo apt-get update
        ;;
    Arch\ Linux)
        sudo pacman -Sy
        ;;
    Fedora)
        sudo dnf update
        ;;
    *)
        echo "Unsupported Linux distribution."
        exit 1
esac

# Upgrade all installed packages
case "$OS" in
    Ubuntu|Linux\ Mint)
        sudo apt upgrade -y
        ;;
    Debian\ GNU/Linux)
        sudo apt-get upgrade -y
        ;;
    Arch\ Linux)
        sudo pacman -Syu --noconfirm
        ;;
    Fedora)
        sudo dnf upgrade -y
        ;;
esac

# Install packages
TERM=kitty
CMP=picom
WM=bspwm
FM=nautilus
DM=sddm
BROWSER=librewolf
LAUNCHER=rofi
FONTS=fonts-meslo-lgc
PKGS="$TERM $CMP $WM $FM $DM $BROWSER $LAUNCHER $FONTS"
case "$OS" in
    Ubuntu|Linux\ Mint)
        sudo apt install $PKGS -y
        ;;
    Debian\ GNU/Linux)
        sudo apt-get install $PKGS -y
        ;;
    Arch\ Linux)
        sudo pacman -S $PKGS --noconfirm
        ;;
    Fedora)
        sudo dnf install $PKGS -y
        ;;
esac

# Download and install configuration files
CONFIGS=(~/.config/kitty ~/.config/bspwm ~/.config/sxhkd ~/.config/eww)
URLS=(https://raw.githubusercontent.com/user/repo/master/kitty.conf
      https://raw.githubusercontent.com/user/repo/master/bspwmrc
      https://raw.githubusercontent.com/user/repo/master/sxhkdrc
      https://raw.githubusercontent.com/user/repo/master/eww.ini)
for i in ${!CONFIGS[@]}; do
    curl -sSL ${URLS[$i]} > ${CONFIGS[$i]}
done
