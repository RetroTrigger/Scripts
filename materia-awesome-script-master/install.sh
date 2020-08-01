#!/bin/bash

# Install Dependencies
sudo apt install awesome lightdm lightdm-gtk-greeter git terminator fonts-roboto rofi compton i3lock xclip qt5-style-plugins materia-gtk-theme lxappearance nautilus xfce4-power-manager pnmixer network-manager-applet -y

# Install Theme
wget -qO- https://git.io/papirus-icon-theme-install | sh

# Clone the configuration
git clone https://github.com/ChrisTitusTech/material-awesome.git ~/.config/awesome

# Install Brave Browser
sudo apt install apt-transport-https curl

curl -s https://brave-browser-apt-release.s3.brave.com/brave-core.asc | sudo apt-key --keyring /etc/apt/trusted.gpg.d/brave-browser-release.gpg add -

echo "deb [arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list

sudo apt update

sudo apt install brave-browser

echo $'\n'$"*** All done! Please reboot now. ***"
