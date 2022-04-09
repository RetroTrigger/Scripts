#!/bin/bash
set -euo pipefail


# Enable RPM Repo
sudo dnf -y install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm 
sudo dnf -y install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Speed up DNF
echo 'fastestmirror=1' | sudo tee -a /etc/dnf/dnf.conf
echo 'max_parallel_downloads=10' | sudo tee -a /etc/dnf/dnf.conf

# Ensure the system is up to date
sudo dnf update -y --refresh

# X server and drivers
sudo dnf -y install \
    @base-x \
    xbacklight \
    picom \
    xrandr \
    arandr \
    xsel \
    xclip \
    xkill

# Wireless drivers (the 7260 package contains firmwares for many other Intel cards too)
#dnf -y install \
#    iwl7260-firmware \
#    linux-firmware

# Desktop
sudo dnf -y install \
    bspwm \
    sxhkd \
    rofi \
    sddm \
    ImageMagick \
    feh
    
# System tools
sudo dnf -y install \
    lxpolkit \
    xfce4-power-manager \
    nautilus \
    file-roller \
    nitrogen \
    bluez \
    blueman \
    lxappearance \
    udiskie \
    xdg-utils \
    lm_sensors \
    xsensors \
    dbus-x11 \
    kitty \
    NetworkManager-tui \
    NetworkManager-wifi \
    net-tools \
    bind-utils \
    git \
    flameshot \
    traceroute \
    unzip \
    tree \
    htop \
    neofetch \
    wget \
    curl \
    zsh \
    git \
    fzf 
    
#Install Preload
sudo dnf copr enable elxreno/preload -y && sudo dnf install preload -y

# Codecs
sudo dnf -y install \
    mpv \
    celluloid \
    gstreamer1 \
    gstreamer1-plugins-bad-free \
    gstreamer1-plugins-bad-free-gtk \
    gstreamer1-plugins-base \
    gstreamer1-plugins-good

# Sound
sudo dnf -y install \
#    pulseaudio \
#    pulseaudio-libs \
#    pulseaudio-utils \
#    alsa-plugins-pulseaudio \
#    alsa-utils \
#    pavucontrol \
#    volumeicon

# Install Brave Browser
sudo dnf -y install dnf-plugins-core

sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/x86_64/

sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc

sudo dnf -y install brave-browser

# Set graphical target and enable sddm at boot
sudo systemctl enable sddm.service
sudo systemctl set-default graphical.target

# Copy Config Files
mkdir ~/.config
git clone https://github.com/RetroTrigger/Dotfiles/* ~/.config/

# Boot into the new environment
sync
reboot
