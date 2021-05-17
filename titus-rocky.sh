#!/usr/bin/env

##Enable PowerTools and RPMFusion Repositories
sudo dnf upgrade -y
sudo dnf install --nogpgcheck https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
sudo dnf install --nogpgcheck https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-8.noarch.rpm
sudo dnf config-manager --set-enabled PowerTools

https://dl.fedoraproject.org/pub/fedora/linux/releases/34/Everything/source/tree/Packages/a/awesome-4.3-9.fc34.src.rpm

##Dependencies
sudo dnf update -y
sudo dnf install xorg-x11-server-Xorg xorg-x11-xauth xorg-x11-apps -y
sudo dnf install awesome fonts-roboto rofi compton i3lock xclip qt5-style-plugins materia-gtk-theme lxappearance xbacklight flameshot nautilus xfce4-power-manager pnmixer network-manager-gnome policykit-1-gnome -y
wget -qO- https://git.io/papirus-icon-theme-install | sh

##Set Graphical Interface on Startup
sudo systemctl set-default graphical.target
sudo systemctl enable sddm

##Setup your Development Tools for Builds
sudo dnf groupinstall "Development Tools"
sudo dnf install cmake gcc-c++ libX11-devel libXext-devel qt5-qtx11extras-devel qt5-qtbase-devel qt5-qtsvg-devel qt5-qttools-devel kf5-kwindowsystem-devel make procps-ng curl file git

##Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval $(~/.linuxbrew/bin/brew shellenv)

##Install Tools of your Choice
sudo dnf install terminator zsh

##Install Brave Browser
sudo dnf install dnf-plugins-core
sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/x86_64/
sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
sudo dnf install brave-browser

##VSCodium on Rocky Linux
sudo rpm --import https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg
printf "[gitlab.com_paulcarroty_vscodium_repo]\nname=gitlab.com_paulcarroty_vscodium_repo\nbaseurl=https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/rpms/\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg" |sudo tee -a /etc/yum.repos.d/vscodium.repo
sudo dnf install codium

##New Packages with AppImage or Flatpak
sudo dnf install flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak install flathub com.valvesoftware.Steam #--Install Steam
sudo flatpak install https://flathub.org/repo/appstream/org.gimp.GIMP.flatpakref #--Install Gimp

##

