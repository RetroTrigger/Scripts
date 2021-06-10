#!/bin/bash

#Dependencies
sudo pacman -S --noconfirm --needed yay zsh zsh-syntax-highlighting zsh-autosuggestions
yay -Sy --noconfirm --needed autojump ttf-meslo-nerd-font-powerlevel10k

#Configs
wget https://github.com.ChrisTitusTech/zsh/raw/master/.zshrc -O ~/.zshrc
mkdir -p "$HOME/.zsh"
wget https://github.com/ChrisTitusTech/zsh/raw/master/.zsh/aliasrc -O ~/.zsh/aliasrc
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc

#Change Shell To ZSH
chsh -s $(which zsh)
