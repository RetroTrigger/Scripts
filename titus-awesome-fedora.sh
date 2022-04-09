#!/bin/bash

#install Dependencies
sudo dnf install -y \
awesome \
git \
google-roboto-fonts \
rofi \
picom \
i3lock \
xclipboard.x86_64 \
qt5-qtstyleplugins.x86_64 \
materia-gtk-theme \
lxappearance \
xbacklight \
flameshot \
nautilus \
xfce4-power-manager \
network-manager-applet.x86_64 \
polkit-gnome.x86_64 \
pavucontrol

#Papirus Theme
wget -qO- https://git.io/papirus-icon-theme-install | sh

#clone Repository
rm -rf ~/.config/awesome
git clone https://github.com/ChrisTitusTech/titus-awesome ~/.config/awesome

#set rofi theme
mkdir -p ~/.config/rofi
cp $HOME/.config/awesome/theme/config.rasi ~/.config/rofi/config.rasi
sed -i '/@import/c\@import "'$HOME'/.config/awesome/theme/sidebar.rasi"' ~/.config/rofi/config.rasi
