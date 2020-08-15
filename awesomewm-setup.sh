#!/bin/bash

#Debian-Based
#sudo add-apt-repository ppa:regolith-linux/unstable -y
#sudo apt update
#sudo apt install awesome rofi picom lxappearance xfce4-power-manager pnmixer network-manager-gnome policykit-1-gnome kitty micro feh imagemagick bluez blueman xbacklight pcmanfm firefox xsecurelock -y

#Arch-Based
yes |sudo pacman -Syyu
yes |sudo pacman -S yay brave python-pillow file-roller nitrogen steam gvfs-smb fakeroot gcc binutils
yes |yay -S git awesome rofi picom polkit-gnome nerd-fonts-meslo lxappearance flameshot volumeicon network-manager-applet xfce4-power-manager kitty micro feh imagemagick bluez blueman xorg-xbacklight pcmanfm xsecurelock 

#install Fonts
git clone https://github.com/perrychan1/fonts.git
sudo mv  -v ~/fonts /usr/share/fonts/
yes |sudo pacman -S ttf-fira-code
#sudo apt install fonts-firacode
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

#Install Oh-My-Zsh
sh -c "$(wget https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"

#Install Powerlevel10K
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting

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

echo "All Done Rebooting Now!!"
sleep 3s
sudo reboot
