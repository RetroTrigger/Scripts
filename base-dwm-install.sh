#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Global variables for package manager and commands
PKG_MANAGER=""
UPDATE_CMD=""
INSTALL_CMD=""

detect_package_manager() {
    echo -e "${CYAN}🔍 Detecting package manager...${RESET}"
    if command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        UPDATE_CMD="sudo pacman -Syyu --noconfirm"
        INSTALL_CMD="sudo pacman -S --noconfirm --needed"
    elif command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
        UPDATE_CMD="sudo apt-get update"
        INSTALL_CMD="sudo apt-get install -y"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        UPDATE_CMD="sudo dnf makecache"
        INSTALL_CMD="sudo dnf install -y"
    else
        echo -e "${RED}❌ Unsupported package manager. This script supports pacman, apt, and dnf.${RESET}" >&2
        exit 1
    fi
    echo -e "${GREEN}✅ Package manager detected: ${BOLD}$PKG_MANAGER${RESET}"
}

# Check if a package is installed
is_package_installed() {
    local pkg="$1"
    case "$PKG_MANAGER" in
        "pacman")
            pacman -Qi "$pkg" &> /dev/null
            ;;
        "apt")
            dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"
            ;;
        "dnf")
            rpm -q "$pkg" &> /dev/null
            ;;
    esac
}

# Filter out already installed packages
get_missing_packages() {
    local packages="$1"
    local missing=""
    for pkg in $packages; do
        if ! is_package_installed "$pkg"; then
            missing="$missing $pkg"
        fi
    done
    echo "$missing"
}

install_packages() {
    echo -e "\n${MAGENTA}📦 Updating system...${RESET}"
    eval $UPDATE_CMD

    echo -e "\n${MAGENTA}⚙️  Installing packages...${RESET}"
    local packages
    local build_essentials

    case "$PKG_MANAGER" in
        "pacman")
            packages="nitrogen steam xorg-server xorg-xinit xorg-xrandr xorg-xsetroot git feh lxappearance arandr thunar thunar-volman thunar-archive-plugin thunar-media-tags-plugin gvfs gvfs-mtp gvfs-gphoto2 gvfs-afc gvfs-nfs gvfs-smb polkit-gnome picom flameshot imagemagick ttf-dejavu ttf-liberation noto-fonts ttf-droid ttf-iosevka-nerd libx11 libxft libxinerama"
            build_essentials="base-devel"
            ;;
        "apt")
            packages="nitrogen steam xserver-xorg xinit x11-xserver-utils git curl wget feh lxappearance arandr thunar thunar-volman thunar-archive-plugin thunar-media-tags-plugin gvfs gvfs-backends gvfs-fuse policykit-1-gnome picom flameshot imagemagick fonts-dejavu fonts-liberation fonts-noto fonts-droid-fallback libx11-dev libxft-dev libxinerama-dev"
            build_essentials="build-essential"
            ;;
        "dnf")
            packages="nitrogen steam xorg-x11-server-Xorg xorg-x11-xinit xorg-x11-server-utils xorg-x11-xrandr git feh lxappearance arandr thunar thunar-volman thunar-archive-plugin thunar-media-tags-plugin gvfs gvfs-mtp gvfs-gphoto2 gvfs-afc gvfs-nfs gvfs-smb polkit-gnome picom flameshot ImageMagick dejavu-sans-fonts liberation-fonts google-noto-sans-fonts droid-sans-fonts libX11-devel libXft-devel libXinerama-devel"
            build_essentials="@development-tools"
            ;;
    esac

    # Filter out already installed packages (pacman --needed handles this natively)
    if [ "$PKG_MANAGER" != "pacman" ]; then
        local all_packages="$build_essentials $packages"
        local missing_packages=$(get_missing_packages "$all_packages")

        if [ -z "$missing_packages" ]; then
            echo -e "${GREEN}✅ All packages are already installed.${RESET}"
        else
            echo -e "${YELLOW}📥 Installing missing packages:${RESET}$missing_packages"
            eval $INSTALL_CMD $missing_packages
        fi
    else
        # Pacman's --needed flag handles this natively
        eval $INSTALL_CMD $build_essentials $packages
    fi
}

clone_repositories() {
    echo -e "\n${BLUE}📥 Cloning repositories...${RESET}"
    local suckless_dir="$HOME/.config/suckless"
    mkdir -p "$suckless_dir"

    # Clone repositories if they don't exist
    [ ! -d "$suckless_dir/dwm" ] && echo -e "${CYAN}  → Cloning dwm-flexipatch...${RESET}" && git clone https://github.com/bakkeby/dwm-flexipatch.git "$suckless_dir/dwm"
    [ ! -d "$suckless_dir/st" ] && echo -e "${CYAN}  → Cloning st-flexipatch...${RESET}" && git clone https://github.com/bakkeby/st-flexipatch.git "$suckless_dir/st"
    [ ! -d "$suckless_dir/dmenu" ] && echo -e "${CYAN}  → Cloning dmenu-flexipatch...${RESET}" && git clone https://github.com/bakkeby/dmenu-flexipatch.git "$suckless_dir/dmenu"
}

compile_software() {
    echo -e "\n${YELLOW}🔨 Compiling software...${RESET}"
    local suckless_dir="$HOME/.config/suckless"
    [ -d "$suckless_dir/dwm" ] && echo -e "${CYAN}  → Building dwm...${RESET}" && (cd "$suckless_dir/dwm" && sudo make clean install)
    [ -d "$suckless_dir/st" ] && echo -e "${CYAN}  → Building st...${RESET}" && (cd "$suckless_dir/st" && sudo make clean install)
    [ -d "$suckless_dir/dmenu" ] && echo -e "${CYAN}  → Building dmenu...${RESET}" && (cd "$suckless_dir/dmenu" && sudo make clean install)
}

setup_xinitrc() {
    echo -e "\n${MAGENTA}⚙️  Setting up .xinitrc...${RESET}"
    # Create .xinitrc if it doesn't exist
    if [ ! -f ~/.xinitrc ]; then
        echo -e "${CYAN}  → Creating ~/.xinitrc...${RESET}"
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
        echo -e "${GREEN}  ✅ ~/.xinitrc created successfully${RESET}"
    else
        echo -e "${YELLOW}  ⚠️  ~/.xinitrc already exists. Please ensure it is configured to start dwm.${RESET}"
    fi
}

setup_autostart() {
    echo -e "\n${MAGENTA}⚙️  Setting up X and DWM autostart...${RESET}"
    local autostart_cmd='if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then exec startx; fi'

    local shell_rc=""
    [ -f "$HOME/.bash_profile" ] && shell_rc="$HOME/.bash_profile" || shell_rc="$HOME/.bashrc"
    [ ! -f "$shell_rc" ] && touch "$HOME/.bash_profile" && shell_rc="$HOME/.bash_profile"

    if grep -q "exec startx" "$shell_rc"; then
        echo -e "${GREEN}  ✅ Autostart for X is already configured in $shell_rc${RESET}"
    else
        echo -e "${CYAN}  → Adding X autostart to $shell_rc${RESET}"
        echo -e "\n# Auto-start X on tty1 login" >> "$shell_rc"
        echo "$autostart_cmd" >> "$shell_rc"
        echo -e "${GREEN}  ✅ X autostart configured${RESET}"
    fi
}

create_dwm_desktop_entry() {
    echo -e "\n${MAGENTA}🖥️  Creating DWM desktop entry...${RESET}"
    local desktop_entry="[Desktop Entry]\nEncoding=UTF-8\nName=DWM\nComment=Dynamic Window Manager\nExec=dwm\nIcon=\nType=XSession"
    echo -e "$desktop_entry" | sudo tee /usr/share/xsessions/dwm.desktop > /dev/null
    echo -e "${GREEN}  ✅ Desktop entry created${RESET}"
}

setup_display() {
    # Send prompts to /dev/tty so they're visible even when script is piped
    if [ -c /dev/tty ]; then
        {
            echo -e "\n${BOLD}${CYAN}🖥️  Select how you want to start DWM:${RESET}"
            echo -e "${YELLOW}1)${RESET} Use a Display Manager (e.g., LightDM, GDM, SDDM) - ${GREEN}Recommended${RESET}"
            echo -e "${YELLOW}2)${RESET} Use startx (manual start from tty)"
            printf "${BOLD}Enter your choice [1-2]:${RESET} "
        } > /dev/tty
        read choice < /dev/tty
        echo "" > /dev/tty  # New line after input
    else
        # Fallback if /dev/tty is not available
        echo -e "\n${BOLD}${CYAN}🖥️  Select how you want to start DWM:${RESET}"
        echo -e "${YELLOW}1)${RESET} Use a Display Manager (e.g., LightDM, GDM, SDDM) - ${GREEN}Recommended${RESET}"
        echo -e "${YELLOW}2)${RESET} Use startx (manual start from tty)"
        echo -e "${YELLOW}⚠️  No terminal available. Defaulting to option 1 (Display Manager).${RESET}"
        choice=1
    fi
    
    # Validate input
    if [[ ! "$choice" =~ ^[12]$ ]]; then
        if [ -c /dev/tty ]; then
            echo -e "${YELLOW}⚠️  Invalid or empty choice. Defaulting to option 1 (Display Manager).${RESET}" > /dev/tty
        else
            echo -e "${YELLOW}⚠️  Invalid or empty choice. Defaulting to option 1 (Display Manager).${RESET}"
        fi
        choice=1
    fi

    case $choice in
        1) # Display Manager
            create_dwm_desktop_entry
            local dm_installed=$(systemctl list-units --type=service | grep -E 'lightdm|gdm|sddm')
            if [ -n "$dm_installed" ]; then
                echo -e "${GREEN}✅ Found an existing display manager. DWM will be available as a session.${RESET}"
            else
                echo -e "${YELLOW}⚠️  No display manager found.${RESET}"
                if [ -c /dev/tty ]; then
                    printf "${BOLD}Would you like to install one? (lightdm) [y/N]:${RESET} " > /dev/tty
                    read install_dm < /dev/tty
                    # Default to 'n' if empty
                    install_dm="${install_dm:-n}"
                else
                    echo -e "${YELLOW}⚠️  Skipping display manager installation (non-interactive mode).${RESET}"
                    install_dm="n"
                fi
                if [[ "$install_dm" =~ ^[yY](es)?$ ]]; then
                    echo -e "${MAGENTA}📥 Installing LightDM...${RESET}"
                    local dm_packages="lightdm lightdm-gtk-greeter"
                    local missing_dm=$(get_missing_packages "$dm_packages")
                    if [ -n "$missing_dm" ]; then
                        case "$PKG_MANAGER" in
                            "pacman")
                                sudo pacman -S --noconfirm --needed $dm_packages
                                ;;
                            "apt")
                                eval $INSTALL_CMD $missing_dm
                                ;;
                            "dnf")
                                eval $INSTALL_CMD $missing_dm
                                ;;
                        esac
                    else
                        echo -e "${GREEN}✅ LightDM is already installed.${RESET}"
                    fi
                    sudo systemctl enable lightdm.service
                    echo -e "${GREEN}✅ LightDM has been installed and enabled. Please reboot after installation.${RESET}"
                fi
            fi
            echo -e "\n${BOLD}${GREEN}🚀 Installation complete!${RESET}"
            echo -e "${CYAN}   Reboot and select DWM from your display manager's session list.${RESET}"
            ;;
        2) # startx
            setup_xinitrc
            setup_autostart
            echo -e "\n${BOLD}${GREEN}🚀 Installation complete!${RESET}"
            echo -e "${CYAN}   To start DWM, log in to tty1 and X will start automatically, or type 'startx'.${RESET}"
            ;;
    esac
}

main() {
    echo -e "${BOLD}${MAGENTA}"
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║                                                       ║"
    echo "║           🏗️  DWM Installation Script 🏗️             ║"
    echo "║                                                       ║"
    echo "║   Installing Dynamic Window Manager & Suckless Tools ║"
    echo "║                                                       ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo -e "${RESET}\n"

    detect_package_manager
    install_packages
    clone_repositories
    compile_software
    setup_display
}

# Run the main function
main
