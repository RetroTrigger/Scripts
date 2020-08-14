#!/bin/bash

#Debian-Based
#sudo add-apt-repository ppa:regolith-linux/unstable -y
#sudo apt update
#sudo apt install awesome rofi picom lxappearance xfce4-power-manager pnmixer network-manager-gnome policykit-1-gnome kitty micro feh imagemagick bluez blueman xbacklight pcmanfm firefox xsecurelock -y

#Arch-Based
sudo pacman -Syyu -y
sudo pacman -S yay -y
yay -S git awesome rofi picom polkit-gnome lxappearance flameshot volumeicon network-manager-applet xfce4-power-manager kitty micro feh imagemagick bluez blueman xorg-xbacklight pcmanfm firefox xsecurelock -y

#install Fonts
git clone https://github.com/perrychan1/fonts.git
sudo mv  -v ~/fonts /usr/share/fonts/
sudo pacman -S ttf-fira-code -y
#sudo apt install fonts-firacode
fc-cache -f -v

#Download Juno GTK Theme
cd ~
git clone https://github.com/EliverLara/Juno.git
sudo mv  -v ~/Juno /usr/share/themes/

#Clone the configuration
cd ~
git clone https://github.com/RetroTrigger/awesome-config.git 

sudo rm -rf ~/.config/awesome
sudo rm -rf ~/.config/rofi
sudo rm -rf ~/.config/compton.conf

sudo mv  -v ~/awesome-config/awesome ~/.config
sudo mv  -v ~/awesome-config/images ~/.config
sudo mv  -v ~/awesome-config/kitty ~/.config
sudo mv  -v ~/awesome-config/rofi ~/.config
sudo mv  -v ~/awesome-config/picom.conf ~/.config
sudo mv  -v ~/awesome-config/tn0k20exrnb51.jpg ~/.config

sudo rm -rf ~/awesome-config

#Download Tela Green Icons
cd ~
git clone https://github.com/vinceliuice/Tela-icon-theme.git
cd Tela-icon-theme
sudo chmod +x install.sh
./install.sh green
rm -rf ~/Tela-icon-theme
