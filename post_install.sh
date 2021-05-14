#!/bin/bash

##graphical applications
#pacman
sudo pacman -S --noconfirm --needed \
	atom \
	deluge \
	brave \
	etcher \
	filezilla \
	steam \
	lutris \
	xscreensaver \
	vlc \
	terminator \
	neofetch \
	nitrogen \
	rofi

#yay
yay -S --noconfirm --needed \
dropbox \
shell-color-scripts

##command line utilities
sudo pacman -S --noconfirm --needed \
	zsh \
	yay \
	feh \
	bashtop \
	git \
	curl \
	wget \
	imagemagick \
	lolcat \
	base-devel \
	w3m

##fonts 
sudo pacman -S --noconfirm --needed noto-fonts ttf-roboto
yay -S --noconfirm --needed ttf-meslo-nerd-font-powerlevel10k ttf-ms-fonts ttf-vista-fonts
fc-cache

##oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

##change shell
chsh -s $(which zsh)
