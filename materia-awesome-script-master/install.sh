#!/bin/bash

dpkg -l | grep -qw gdebi || sudo apt-get install -yyq gdebi

# Install Dependencies

sudo apt install  -yy \
awesome fonts-roboto rofi compton i3lock-fancy xclip gnome-keyring policykit-1-gnome qt5-style-plugins materia-gtk-theme \
lxappearance xbacklight kde-spectacle lightdm lightdm-gtk-greeter git pcmanfm conky terminator pulseaudio

# Install Theme
wget -qO- https://git.io/papirus-icon-theme-install | sh

# Clone the configuration
git clone https://github.com/ChrisTitusTech/material-awesome.git ~/.config/awesome
dpkg -l | grep -qw gdebi || sudo apt-get install -yyq gdebi
sudo dpkg --add-architecture i386

# Add Repositories
sudo add-apt-repository ppa:lutris-team/lutris \
ppa:graphics-drivers/ppa \
'deb https://dl.winehq.org/wine-builds/ubuntu/ focal main' -y

# Fix Faudio Dependencies
wget https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/xUbuntu_18.04/amd64/libfaudio0_19.07-0~bionic_amd64.deb
wget https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/xUbuntu_18.04/i386/libfaudio0_19.07-0~bionic_i386.deb
sudo dpkg -i libfaudio0_19.07-0~bionic_amd64.deb libfaudio0_19.07-0~bionic_i386.deb

# Add Wine Repository Key
wget -nc https://dl.winehq.org/wine-builds/winehq.key
sudo apt-key add winehq.key

# Initial Software
sudo apt update && sudo apt upgrade -y

sudo apt install \
libgnutls30:i386 libldap-2.4-2:i386 libgpg-error0:i386 libxml2:i386 \
libasound2-plugins:i386 libsdl2-2.0-0:i386 libfreetype6:i386 libdbus-1-3:i386 libsqlite3-0:i386 \
net-tools htop lame git mc audacity \
openssh-server sshfs gedit-plugin-text-size nano \
ubuntu-restricted-extras mpv vlc gthumb \
qt5-style-plugins spell synaptic terminator \ 
meson libsystemd-dev pkg-config ninja-build libdbus-1-dev libinih-dev \
--install-recommends winehq-staging -yy

# Install Video Drivers 
sudo apt install nvidia-driver-440 libnvidia-gl-440 libnvidia-gl-440:i386 libvulkan1 libvulkan1:i386 -yy

# Add me to any groups I might need to be a part of:

# Remove undesirable packages:

# Install Vivaldi:
echo "echo deb http://repo.vivaldi.com/stable/deb/ stable main > /etc/apt/sources.list.d/vivaldi.list" | sudo sh
curl http://repo.vivaldi.com/stable/linux_signing_key.pub | sudo apt-key add -
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 1397BC53640DB551
sudo apt-get update
sudo apt-get install -y vivaldi-stable

## Remove junk

## Multimedia

## Games
sudo apt-get install -yy
steam-installer lutris

# Build and Install GameMode
git clone https://github.com/FeralInteractive/gamemode.git
cd gamemode
sudo chmod u+x bootstrap.sh
sudo ./bootstrap.sh

echo $'\n'$"*** All done! Please reboot now. ***"
