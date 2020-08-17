#!/bin/bash

#Debian-Based
sudo add-apt-repository ppa:regolith-linux/unstable -y
sudo apt update && sudo apt upgrade -y
sudo apt install git zsh awesome rofi picom lxappearance xfce4-power-manager pnmixer network-manager-gnome volumeicon-alsa policykit-1-gnome nitrogen terminator imagemagick bluez blueman xbacklight xsecurelock steam python3-dev python3-setuptools libjpeg8-dev zlib1g-dev libfreetype6-dev -y 

#install Fonts
git clone https://github.com/perrychan1/fonts.git
sudo mv  -v ~/fonts /usr/share/fonts/
sudo apt install fonts-firacode -y
sudo wget -P /usr/share/fonts https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
sudo wget -P /usr/share/fonts https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf
sudo wget -P /usr/share/fonts https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf
sudo wget -P /usr/share/fonts https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf
fc-cache -f -v

#Download Juno GTK Theme
cd ~
git clone https://github.com/EliverLara/Juno.git
sudo mv  -v ~/Juno /usr/share/themes/

#Install Wallpaper-reddit
cd ~
git clone https://github.com/ChrisTitusTech/wallpaper-reddit.git
cd wallpaper-reddit
sudo python3 setup.py install
sudo rm -rf ~/user/wallpaper-reddit

#Clone the configuration
cd ~
git clone https://github.com/RetroTrigger/dotfiles.git 

sudo mv  -v ~/.config/awesome ~/.config/old.awesome
sudo rm -rf ~/.config/rofi
sudo rm -rf ~/.config/compton.conf
sudo rm -rf ~/.config/wallpaper-reddit
sudo rm -rf ~/.zshrc

sudo mv  -v ~/dotfiles/.config/awesome ~/.config
sudo mv  -v ~/dotfiles/.config/nitrogen ~/.config
sudo mv  -v ~/dotfiles/.config/volumeicon~/.config
sudo mv  -v ~/dotfiles/.config/wallpaper-reddit ~/.config
sudo mv  -v ~/dotfiles/.config/tn0k20exrnb51.jpg ~/.config
sudo mv  -v ~/dotfiles/.config/images ~/.config
sudo mv  -v ~/dotfiles/.config/kitty ~/.config
sudo mv  -v ~/dotfiles/.config/rofi ~/.config
sudo mv  -v ~/dotfiles/.config/picom.conf ~/.config
sudo mv  -v ~/dotfiles/.fehbg ~/
sudo mv  -v ~/dotfiles/.p10k.zsh ~/
sudo mv  -v ~/dotfiles/.zshrc ~/

sudo rm -rf ~/dotfiles

#Download Tela Green Icons
cd ~
git clone https://github.com/vinceliuice/Tela-icon-theme.git
cd Tela-icon-theme
sudo chmod +x install.sh
./install.sh green
rm -rf ~/Tela-icon-theme

#Install Oh-My-Zsh
sh -c "$(wget https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting

#Install Powerlevel10K
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

#echo "All Done Rebooting Now!!"
#sleep 3s
#sudo reboot
