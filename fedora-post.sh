#!/bin/bash

sudo rpm -Uvh http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
sudo rpm -Uvh http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

echo "fastestmirror=true" | sudo tee --append /etc/dnf/dnf.conf
echo "max_parallel_downloads=10" | sudo tee --append /etc/dnf/dnf.conf

sudo dnf update -y

sudo dnf install steam dropbox filezilla exa zsh zsh-syntax-highlighting zsh-autosuggestions autojump celluloid kitty -y

sudo dnf install dnf-plugins-core
sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/x86_64/
sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
sudo dnf install brave-browser -y

sudo dnf groupupdate multimedia --setop="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
sudo dnf groupupdate sound-and-video

sudo wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf -O /usr/share/fonts/MesloLGS%20NF%20Regular.ttf
sudo wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf -O /usr/share/fonts/MesloLGS%20NF%20Bold.ttf
sudo wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf -O /usr/share/fonts/MesloLGS%20NF%20Italic.ttf
sudo wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf -O /usr/share/fonts/MesloLGS%20NF%20Bold%20Italic.ttf
sudo fc-cache -f -v

git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.powerlevel10k
echo 'source ~/.powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc
echo "plugins=(autojump, zsh-autosuggestions, zsh-syntax-highlighting)" | sudo tee --append ~/.zshrc
echo "alias ls='exa -bghHliS'" >> ~/.zshrc
chsh -s $(which zsh)

curl -1sLf \
   'https://dl.cloudsmith.io/public/balena/etcher/setup.rpm.sh' \
   | sudo -E bash

sudo dnf install -y balena-etcher-electron
rm /etc/yum.repos.d/balena-etcher.repo
rm /etc/yum.repos.d/balena-etcher-source.repo
