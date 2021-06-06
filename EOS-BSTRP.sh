#!/usr/bin/env bash

##Enable PPA##
sudo apt update
sudo apt install software-properties-common

##Install apt-fast##

sudo add-apt-repository -y ppa:apt-fast/stable
sudo apt -y install apt-fast
echo "alias apt='apt-fast'" >> ~/.bashrc 
source ~/.bashrc

##Update OS##
apt update && apt upgrade

##Install git##
apt install git

##Uninstall Apps##
apt purge epiphany-browser epiphany-browser-data
apt purge pantheon-mail
apt purge noise
apt purge audience

##Clean Up OS##
apt autoremove -y
apt autoclean -y

## Tweaking the UI

##Add minimize button##
sudo add-apt-repository ppa:philip.scott/elementary-tweaks
apt install elementary-tweaks

##Bring back Tray icons##
apt install gobject-introspection libglib2.0-dev libgranite-dev libindicator3-dev libwingpanel-2.0-dev valac
git clone https://github.com/donadigo/wingpanel-indicator-namarupa
cd wingpanel-indicator-namarupa
meson build --prefix=/usr && cd build
ninja
sudo ninja install
apt install -f
wget https://github.com/mdh34/elementary-indicators/releases/download/0.1/indicator-application-patched.deb
sudo dpkg -i indicator-application-patched.deb
sudo apt-mark hold indicator-application
sudo reboot

##Icon Pack## 
cd $HOME/.icons
git clone https://github.com/keeferrourke/la-capitaine-icon-theme.git
cd la-capitaine-icon-theme && ./configure

##Cursors## 
sudo add-apt-repository ppa:dyatlov-igor/la-capitaine
apt install la-capitaine-cursor-theme

##Proper Plank##
sudo add-apt-repository ppa:ricotz/docky
apt update
apt install --reinstall plank
killall plank
plank --preferences

## APPS TO DOWNLOAD & INSTALL

##Brave Browser##
sudo apt install apt-transport-https curl

sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list

sudo apt update

sudo apt install brave-browser

##Sublime Text 3##
wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
apt install apt-transport-https
echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
apt update
apt install sublime-text

##Wine
sudo dpkg --add-architecture i386 
wget -nc https://dl.winehq.org/wine-builds/winehq.key
sudo apt-key add winehq.key
sudo add-apt-repository 'deb https://dl.winehq.org/wine-builds/ubuntu/ bionic main'
apt update
apt install --install-recommends winehq-staging

##Java
apt update
apt install openjdk-8-jdk openjdk-8-jre

## APPS TO INSTALL & CONFIGURE VIA TERMINAL


##flash-plugin##
apt install flashplugin-installer pepperflashplugin-nonfree

##Restricted extras and MM Codec##
apt install ubuntu-restricted-extras
apt install libavcodec-extra
apt install libdvd-pkg
sudo dpkg-reconfigure libdvd-pkg

##archive formats##
apt install unace rar unrar p7zip-rar p7zip sharutils uudeview mpack arj cabextract lzip lunzip

## Other Tweaks/Fixes

##ZSH##
sudo apt install zsh zsh-syntax-highlighting autojump zsh-autosuggestions
mkdir ~/zsh
wget -L https://raw.githubusercontent.com/ChrisTitusTech/zsh/master/aliasrc ~/zsh/aliasrc
wget -L https://raw.githubusercontent.com/ChrisTitusTech/zsh/master/.zshrc
touch "$HOME/.cache/zshhistory"
#-- Setup Alias in $HOME/zsh/aliasrc
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc
chsh -s $(which zsh)

##Reduce Overheating & Improve Battery Life##
sudo add-apt-repository ppa:linrunner/tlp
apt install tlp tlp-rdw
tlp start

##WPS Fonts Fix##
cd /tmp
git clone https://github.com/iamdh4/ttf-wps-fonts.git
cd ttf-wps-fonts
bash install.sh
rm -rf /tmp/ttf-wps-fonts

##Fix Lag on Login/Restart## 
sudo mv /etc/xdg/autostart/at-spi-dbus-bus.desktop /etc/xdg/autostart/at-spi-dbus-bus.disabled
sudo mv /usr/share/upstart/xdg/autostart/at-spi-dbus-bus.desktop /usr/share/upstart/xdg/autostart/at-spi-dbus-bus.disabled

##Display Hidden Startup Applications##
sudo sed -i 's/NoDisplay=true/NoDisplay=false/g' /etc/xdg/autostart/#.desktop

