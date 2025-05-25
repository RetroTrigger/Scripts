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
        ttf-dejavu ttf-liberation noto-fonts ttf-droid ttf-iosevka-nerd  # Basic and additional fonts
    
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

setup_xinitrc() {
    echo "Setting up .xinitrc..."
    # Create .xinitrc if it doesn't exist
    if [ ! -f ~/.xinitrc ]; then
        echo "Creating ~/.xinitrc..."
        echo "#!/bin/sh\n\n# Start DWM with mate-polkit\nexec mate-polkit &\nexec dwm" > ~/.xinitrc
        chmod +x ~/.xinitrc
    else
        echo "~/.xinitrc already exists. Please add the following lines to start dwm with mate-polkit:"
        echo "\n# Start DWM with mate-polkit"
        echo "exec mate-polkit &"
        echo "exec dwm"
    fi
}

setup_autostart() {
    echo "Setting up X and DWM autostart..."
    local autostart_cmd='if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then exec startx; fi'
    
    # Check which shell profile files exist
    local shell_rc=""
    if [ -f "$HOME/.bash_profile" ]; then
        shell_rc="$HOME/.bash_profile"
    elif [ -f "$HOME/.bashrc" ]; then
        shell_rc="$HOME/.bashrc"
    else
        shell_rc="$HOME/.bash_profile"
        touch "$shell_rc"
    fi
    
    # Check if autostart is already set up
    if grep -q "exec startx" "$shell_rc"; then
        echo "Autostart for X is already configured in $shell_rc"
    else
        echo "Adding X autostart to $shell_rc"
        echo -e "\n# Auto-start X on tty1 login" >> "$shell_rc"
        echo "$autostart_cmd" >> "$shell_rc"
        echo "Autostart configuration added to $shell_rc"
    fi
}

main() {
    install_packages
    clone_repositories
    compile_software
    setup_xinitrc
    setup_autostart
    
    echo -e "\nInstallation complete!"
    echo -e "\nTo start DWM, simply log in to tty1 and X will start automatically."
    echo -e "If you need to start DWM manually, type 'startx' after logging in."
}

# Run the main function
main
