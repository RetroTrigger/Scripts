#!/bin/bash

# Global variables for package manager and commands
PKG_MANAGER=""
UPDATE_CMD=""
INSTALL_CMD=""

detect_package_manager() {
    if command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        UPDATE_CMD="sudo pacman -Syyu --noconfirm"
        INSTALL_CMD="sudo pacman -S --noconfirm"
    elif command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
        UPDATE_CMD="sudo apt-get update"
        INSTALL_CMD="sudo apt-get install -y"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        UPDATE_CMD="sudo dnf check-update"
        INSTALL_CMD="sudo dnf install -y"
    else
        echo "Unsupported package manager. This script supports pacman, apt, and dnf." >&2
        exit 1
    fi
    echo "Package manager detected: $PKG_MANAGER"
}

install_packages() {
    echo "Updating system..."
    eval $UPDATE_CMD

    echo "Installing packages..."
    local packages
    local build_essentials

    case "$PKG_MANAGER" in
        "pacman")
            packages="nitrogen steam xorg-server xorg-xinit xorg-xrandr xorg-xsetroot git feh lxappearance polybar thunar thunar-volman thunar-archive-plugin thunar-media-tags-plugin gvfs gvfs-mtp gvfs-gphoto2 gvfs-afc gvfs-nfs gvfs-smb polkit-gnome picom flameshot imagemagick ttf-dejavu ttf-liberation noto-fonts ttf-droid ttf-iosevka-nerd libx11 libxft libxinerama"
            build_essentials="base-devel"
            ;;
        "apt")
            packages="nitrogen steam xserver-xorg xinit x11-xserver-utils git curl wget feh lxappearance polybar thunar thunar-volman thunar-archive-plugin thunar-media-tags-plugin gvfs gvfs-backends gvfs-fuse policykit-1-gnome picom flameshot imagemagick fonts-dejavu fonts-liberation fonts-noto fonts-droid-fallback libx11-dev libxft-dev libxinerama-dev"
            build_essentials="build-essential"
            ;;
        "dnf")
            packages="nitrogen steam xorg-x11-server-Xorg xorg-x11-xinit xorg-x11-xrandr git feh lxappearance polybar thunar thunar-volman thunar-archive-plugin thunar-media-tags-plugin gvfs gvfs-mtp gvfs-gphoto2 gvfs-afc gvfs-nfs gvfs-smb polkit-gnome picom flameshot ImageMagick dejavu-sans-fonts liberation-fonts google-noto-sans-fonts droid-sans-fonts libX11-devel libXft-devel libXinerama-devel"
            build_essentials="@development-tools"
            ;;
    esac

    eval $INSTALL_CMD $build_essentials $packages

    # Install third-party packages
    install_third_party_packages
}

install_third_party_packages() {
    echo "Installing third-party packages..."
    case "$PKG_MANAGER" in
        "pacman")
            if ! command -v yay &> /dev/null; then
                echo "Installing yay..."
                git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
                (cd /tmp/yay-bin && makepkg -si --noconfirm)
            fi
            yay -S --noconfirm brave-bin 
            ;;
        "apt")
            # Brave Browser
            if command -v curl &> /dev/null; then
                sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
            elif command -v wget &> /dev/null; then
                sudo wget -qO /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
            else
                echo "Neither curl nor wget found. Skipping Brave browser installation."
                return
            fi
            echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
            eval $UPDATE_CMD
            eval $INSTALL_CMD brave-browser unzip
            ;;
        "dnf")
            # Brave Browser
            sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
            sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
            eval $INSTALL_CMD brave-browser unzip
            ;;
    esac
}

clone_repositories() {
    echo "Cloning repositories..."
    local suckless_dir="$HOME/.config/suckless"
    mkdir -p "$suckless_dir"

    # Clone repositories if they don't exist
    [ ! -d "$suckless_dir/dwm" ] && git clone https://github.com/bakkeby/dwm-flexipatch.git "$suckless_dir/dwm"
    [ ! -d "$suckless_dir/st" ] && git clone https://github.com/bakkeby/st-flexipatch.git "$suckless_dir/st"
    [ ! -d "$suckless_dir/dmenu" ] && git clone https://github.com/bakkeby/dmenu-flexipatch.git "$suckless_dir/dmenu"
}

compile_software() {
    echo "Compiling software..."
    local suckless_dir="$HOME/.config/suckless"
    [ -d "$suckless_dir/dwm" ] && (cd "$suckless_dir/dwm" && sudo make clean install)
    [ -d "$suckless_dir/st" ] && (cd "$suckless_dir/st" && sudo make clean install)
    [ -d "$suckless_dir/dmenu" ] && (cd "$suckless_dir/dmenu" && sudo make clean install)
}

setup_xinitrc() {
    echo "Setting up .xinitrc..."
    # Create .xinitrc if it doesn't exist
    if [ ! -f ~/.xinitrc ]; then
        echo "Creating ~/.xinitrc..."
        cat > ~/.xinitrc <<'EOF'
#!/bin/sh

if command -v polkit-gnome-authentication-agent-1 >/dev/null 2>&1; then
  polkit-gnome-authentication-agent-1 &
elif [ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]; then
  /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
elif [ -x /usr/libexec/polkit-gnome-authentication-agent-1 ]; then
  /usr/libexec/polkit-gnome-authentication-agent-1 &
elif [ -x /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 ]; then
  /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 &
fi

exec dwm
EOF
        chmod +x ~/.xinitrc
    else
        echo "~/.xinitrc already exists. Please ensure it is configured to start dwm."
    fi
}

setup_autostart() {
    echo "Setting up X and DWM autostart..."
    local autostart_cmd='if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then exec startx; fi'
    
    local shell_rc=""
    [ -f "$HOME/.bash_profile" ] && shell_rc="$HOME/.bash_profile" || shell_rc="$HOME/.bashrc"
    [ ! -f "$shell_rc" ] && touch "$HOME/.bash_profile" && shell_rc="$HOME/.bash_profile"

    if grep -q "exec startx" "$shell_rc"; then
        echo "Autostart for X is already configured in $shell_rc"
    else
        echo "Adding X autostart to $shell_rc"
        echo -e "\n# Auto-start X on tty1 login" >> "$shell_rc"
        echo "$autostart_cmd" >> "$shell_rc"
    fi
}

create_dwm_desktop_entry() {
    echo "Creating DWM desktop entry..."
    local desktop_entry="[Desktop Entry]\nEncoding=UTF-8\nName=DWM\nComment=Dynamic Window Manager\nExec=dwm\nIcon=\nType=XSession"
    echo -e "$desktop_entry" | sudo tee /usr/share/xsessions/dwm.desktop > /dev/null
}

setup_display() {
    # Send prompts to /dev/tty so they're visible even when script is piped
    if [ -c /dev/tty ]; then
        {
            echo "Select how you want to start DWM:"
            echo "1) Use a Display Manager (e.g., LightDM, GDM, SDDM) - Recommended"
            echo "2) Use startx (manual start from tty)"
            printf "Enter your choice [1-2]: "
        } > /dev/tty
        read choice < /dev/tty
        echo "" > /dev/tty  # New line after input
    else
        # Fallback if /dev/tty is not available
        echo "Select how you want to start DWM:"
        echo "1) Use a Display Manager (e.g., LightDM, GDM, SDDM) - Recommended"
        echo "2) Use startx (manual start from tty)"
        echo "No terminal available. Defaulting to option 1 (Display Manager)."
        choice=1
    fi
    
    # Validate input
    if [[ ! "$choice" =~ ^[12]$ ]]; then
        if [ -c /dev/tty ]; then
            echo "Invalid or empty choice. Defaulting to option 1 (Display Manager)." > /dev/tty
        else
            echo "Invalid or empty choice. Defaulting to option 1 (Display Manager)."
        fi
        choice=1
    fi

    case $choice in
        1) # Display Manager
            create_dwm_desktop_entry
            local dm_installed=$(systemctl list-units --type=service | grep -E 'lightdm|gdm|sddm')
            if [ -n "$dm_installed" ]; then
                echo "Found an existing display manager. DWM will be available as a session."
            else
                echo "No display manager found."
                if [ -c /dev/tty ]; then
                    printf "Would you like to install one? (lightdm) [y/N]: " > /dev/tty
                    read install_dm < /dev/tty
                    # Default to 'n' if empty
                    install_dm="${install_dm:-n}"
                else
                    echo "Skipping display manager installation (non-interactive mode)."
                    install_dm="n"
                fi
                if [[ "$install_dm" =~ ^[yY](es)?$ ]]; then
                    case "$PKG_MANAGER" in
                        "pacman")
                            sudo pacman -S --noconfirm lightdm lightdm-gtk-greeter
                            ;;
                        "apt")
                            eval $INSTALL_CMD lightdm lightdm-gtk-greeter
                            ;;
                        "dnf")
                            eval $INSTALL_CMD lightdm lightdm-gtk-greeter
                            ;;
                    esac
                    sudo systemctl enable lightdm.service
                    echo "LightDM has been installed and enabled. Please reboot after installation."
                fi
            fi
            echo -e "\nInstallation complete! Reboot and select DWM from your display manager's session list."
            ;;
        2) # startx
            setup_xinitrc
            setup_autostart
            echo -e "\nInstallation complete!"
            echo -e "\nTo start DWM, log in to tty1 and X will start automatically, or type 'startx'."
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
}

main() {
    detect_package_manager
    install_packages
    clone_repositories
    compile_software
    setup_display
}

# Run the main function
main
