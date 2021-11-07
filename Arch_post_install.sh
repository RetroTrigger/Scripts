#!/bin/bash

#Enable Firewall
sudo ufw enable
sudo ufw status verbose
sudo systemctl enable --now firewalld

#Enable Trim
sudo systemctl enable fstrim.timer

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
	pfetch \
	variety

#yay
yay -S --noconfirm --needed \
dropbox \
shell-color-scripts

##command line utilities
sudo pacman -S --noconfirm --needed \
	bashtop \
	git \
	curl \
	wget \
	imagemagick \
	lolcat \
	base-devel
