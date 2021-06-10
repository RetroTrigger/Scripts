#!/bin/bash

sudo pacman -S --noconfirm --needed  yay zsh zsh-syntax-highlighting zsh-autosuggestions
yay -S --noconfirm --needed autojump

wget https://github.com.ChrisTitusTech/zsh/raw/master/.zshrc -O ~/.zshrc
mkdir -p "$HOME/.zsh"
wget https://github.com/ChrisTitusTech/zsh/raw/master/.zsh/aliasrc -O ~/.zsh/aliasrc
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc

chsh -s $(which zsh)
