#!/bin/bash

install_packages() {
    echo "Updating system and installing packages..."
    sudo pacman -Syyu --noconfirm
    
    # Install official repository packages
    echo "Installing official repository packages..."
    sudo pacman -S --noconfirm \
        nitrogen \
        steam \
        xorg-server xorg-xinit xorg-xrandr xorg-xsetroot \
        git \
        lightdm lightdm-gtk-greeter \
        base-devel \
        feh \
        lxappearance \
        polybar \
        thunar thunar-volman thunar-archive-plugin thunar-media-tags-plugin \
        gvfs gvfs-mtp gvfs-gphoto2 gvfs-afc gvfs-nfs gvfs-smb \
        mate-polkit \
        picom \
        flameshot \
        imagemagick \
        ttf-dejavu ttf-liberation noto-fonts  # Basic fonts
    
    # Install yay if not already installed
    if ! command -v yay &> /dev/null; then
        echo "Installing yay..."
        git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
        (cd /tmp/yay-bin && makepkg -si --noconfirm)
    fi
    
    # Install AUR packages
    echo "Installing AUR packages..."
    yay -S --noconfirm \
        brave-bin \
        ttf-meslo-nerd-font-powerlevel10k
}

clone_repositories() {
    echo "Cloning repositories..."
    mkdir -p ~/.config
    
    # Clone repositories if they don't exist
    [ ! -d "$HOME/.config/dwm" ] && git clone https://github.com/bakkeby/dwm-flexipatch.git ~/.config/dwm
    [ ! -d "$HOME/.config/st" ] && git clone https://github.com/bakkeby/st-flexipatch.git ~/.config/st
    [ ! -d "$HOME/.config/dmenu" ] && git clone https://github.com/bakkeby/dmenu-flexipatch.git ~/.config/dmenu
}

compile_software() {
    echo "Compiling software..."
    [ -d "$HOME/.config/dwm" ] && (cd ~/.config/dwm && sudo make clean install)
    [ -d "$HOME/.config/st" ] && (cd ~/.config/st && sudo make clean install)
    [ -d "$HOME/.config/dmenu" ] && (cd ~/.config/dmenu && sudo make clean install)
}

setup_lightdm() {
    echo "Setting up LightDM..."
    sudo systemctl enable lightdm
    
    # Create lightdm config directory if it doesn't exist
    sudo mkdir -p /etc/lightdm
    
    # Configure lightdm to use the greeter
    echo "[Seat:*]\ngreeter-session=lightdm-gtk-greeter" | sudo tee /etc/lightdm/lightdm.conf
}

create_dwm_desktop_entry() {
    echo "Creating dwm.desktop entry..."
    sudo mkdir -p /usr/share/xsessions
    
    # Create a proper desktop entry for dwm
    echo "[Desktop Entry]\n\
Name=Dwm\n\
Comment=Dynamic Window Manager\n\
Exec=dwm\n\
Type=XSession" | sudo tee /usr/share/xsessions/dwm.desktop
}

main() {
    install_packages
    clone_repositories
    compile_software
    setup_lightdm
    create_dwm_desktop_entry
    
    echo "\nInstallation complete! Please reboot your system to start using DWM."
    echo "You can select DWM from your display manager's session menu."
}

# Run the main function
main
