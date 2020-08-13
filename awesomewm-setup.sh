#!/bin/bash

#Debian-Based
sudo add-apt-repository ppa:regolith-linux/unstable -y
sudo apt update
sudo apt install awesome rofi picom lxappearance xfce4-power-manager pnmixer network-manager-gnome policykit-1-gnome kitty micro feh imagemagick bluez blueman xbacklight pcmanfm firefox xsecurelock -y

#Arch-Based
#yay -S awesome rofi picom i3lock-fancy xclip ttf-roboto gnome-polkit materia-gtk-theme lxappearance flameshot pnmixer network-manager-applet xfce4-power-manager -y
#wget -qO- https://git.io/papirus-icon-theme-install | sh

#install Fonts
git clone https://github.com/perrychan1/fonts.git
sudo mv  -v ~/fonts/* /usr/share/fonts/
rm -rf ~/fonts
sudo apt install fonts-firacode
fc-cache -f -v

#Download Juno GTK Theme
cd ~
git clone https://github.com/EliverLara/Juno.git
sudo mv  -v ~/Juno /usr/share/themes/

#Clone the configuration
rm -rf ~/.config/awesome
git clone https://github.com/RetroTrigger/awesome-config.git ~/.config

#Download Tela Green Icons
cd ~
git clone https://github.com/vinceliuice/Tela-icon-theme.git
cd Tela-icon-theme
sudo chmod +x install.sh
./install.sh green
rm -rf ~/Tela-icon-theme
