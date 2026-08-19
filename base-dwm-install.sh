#!/usr/bin/env bash

set -Eeuo pipefail

# Pinned upstream revisions. Update these deliberately after reviewing changes.
readonly DWM_REVISION="4c963b33681b277a0ff4d3bf39a27b2feab68950"
readonly ST_REVISION="aa56259643e29080394ee1e36a833d18027a0628"
readonly DMENU_REVISION="c59af646f2d8ccbc31f799111b0ff7a1282efa63"

readonly DWM_REPOSITORY="https://github.com/bakkeby/dwm-flexipatch.git"
readonly ST_REPOSITORY="https://github.com/bakkeby/st-flexipatch.git"
readonly DMENU_REPOSITORY="https://github.com/bakkeby/dmenu-flexipatch.git"

readonly INSTALL_PREFIX="${DWM_INSTALL_PREFIX:-$HOME/.local}"
readonly SUCKLESS_DIR="$HOME/.config/suckless"

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly RESET='\033[0m'

PKG_MANAGER=""
declare -a UPDATE_CMD=()
declare -a INSTALL_CMD=()
declare -a TEMP_FILES=()

cleanup() {
    local file
    for file in "${TEMP_FILES[@]}"; do
        [ ! -e "$file" ] || rm -f -- "$file"
    done
}

report_error() {
    local exit_code=$?
    local line_number=$1
    local command=$2
    printf '%b\n' "${RED}❌ Installation failed at line ${line_number}: ${command}${RESET}" >&2
    exit "$exit_code"
}

trap cleanup EXIT
trap 'report_error "$LINENO" "$BASH_COMMAND"' ERR

die() {
    printf '%b\n' "${RED}❌ $*${RESET}" >&2
    exit 1
}

warn() {
    printf '%b\n' "${YELLOW}⚠️  $*${RESET}" >&2
}

open_tty() {
    { exec 3<>/dev/tty; } 2>/dev/null
}

prompt() {
    local prompt_text=$1
    local response=""

    if open_tty; then
        printf '%b' "$prompt_text" >&3
        IFS= read -r response <&3 || true
        exec 3>&-
    fi
    printf '%s' "$response"
}

preflight() {
    [ "$(id -u)" -ne 0 ] || die "Run this script as your desktop user, not with sudo. It requests sudo only for system changes."
    [ -n "${HOME:-}" ] && [ -d "$HOME" ] || die "HOME is not set to an existing directory."
    command -v sudo >/dev/null 2>&1 || die "sudo is required for package and display-manager installation."
    command -v git >/dev/null 2>&1 || warn "git is not installed yet; the package installation step will install it."
    sudo -v
}

detect_package_manager() {
    local distro_id=""
    local distro_like=""

    printf '%b\n' "${CYAN}🔍 Detecting package manager...${RESET}"
    [ -r /etc/os-release ] || die "Cannot identify this Linux distribution: /etc/os-release is missing."
    # shellcheck disable=SC1091
    . /etc/os-release
    distro_id="${ID:-}"
    distro_like="${ID_LIKE:-}"

    if command -v pacman >/dev/null 2>&1; then
        [[ " $distro_id $distro_like " =~ (arch) ]] || die "pacman was found, but this is not an Arch-family distribution."
        PKG_MANAGER="pacman"
        UPDATE_CMD=()
        INSTALL_CMD=(sudo pacman -S --noconfirm --needed)
    elif command -v apt-get >/dev/null 2>&1; then
        [[ " $distro_id $distro_like " =~ (debian|ubuntu) ]] || die "apt was found, but this is not a supported Debian/Ubuntu-family distribution."
        PKG_MANAGER="apt"
        UPDATE_CMD=(sudo apt-get update)
        INSTALL_CMD=(sudo apt-get install -y)
    elif command -v dnf >/dev/null 2>&1; then
        [[ " $distro_id $distro_like " =~ (fedora) ]] || die "dnf was found, but only Fedora is currently supported by the dnf package list."
        PKG_MANAGER="dnf"
        UPDATE_CMD=(sudo dnf makecache)
        INSTALL_CMD=(sudo dnf install -y)
    else
        die "Unsupported package manager. This script supports Arch, Debian/Ubuntu, and Fedora."
    fi

    printf '%b\n' "${GREEN}✅ Package manager detected: ${BOLD}${PKG_MANAGER}${RESET}"
}

is_package_installed() {
    local package=$1
    case "$PKG_MANAGER" in
        pacman) pacman -Qi "$package" >/dev/null 2>&1 ;;
        apt) dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q '^install ok installed$' ;;
        dnf) rpm -q "$package" >/dev/null 2>&1 ;;
    esac
}

get_missing_packages() {
    local package
    local -n requested_packages=$1
    local -n result=$2
    result=()

    for package in "${requested_packages[@]}"; do
        if ! is_package_installed "$package"; then
            result+=("$package")
        fi
    done
}

apt_package_available() {
    local package=$1
    apt-cache policy "$package" 2>/dev/null |
        awk '/^[[:space:]]*Candidate:/ { found=1; available=($2 != "(none)") } END { exit !(found && available) }'
}

install_optional_steam() {
    if is_package_installed steam; then
        printf '%b\n' "${GREEN}✅ Steam is already installed.${RESET}"
        return
    fi

    printf '%b\n' "${MAGENTA}🎮 Attempting optional Steam installation...${RESET}"
    if ! "${INSTALL_CMD[@]}" steam; then
        warn "Steam could not be installed from the enabled repositories. Core DWM installation will continue."
        warn "Enable your distribution's multilib/non-free gaming repository and install Steam separately."
    fi
}

install_packages() {
    local -a packages=()
    local -a missing_packages=()
    local polkit_agent=""

    if ((${#UPDATE_CMD[@]})); then
        printf '\n%b\n' "${MAGENTA}📦 Refreshing package metadata...${RESET}"
        "${UPDATE_CMD[@]}"
    else
        printf '\n%b\n' "${YELLOW}📦 Using the current pacman databases; this installer will not perform a full system upgrade.${RESET}"
    fi

    case "$PKG_MANAGER" in
        pacman)
            packages=(base-devel nitrogen xorg-server xorg-xinit xorg-xrandr xorg-xsetroot git feh lxappearance arandr thunar thunar-volman thunar-archive-plugin thunar-media-tags-plugin gvfs gvfs-mtp gvfs-gphoto2 gvfs-afc gvfs-nfs gvfs-smb polkit-gnome picom flameshot imagemagick ttf-dejavu ttf-liberation noto-fonts ttf-droid ttf-iosevka-nerd libx11 libxft libxinerama)
            ;;
        apt)
            if apt_package_available policykit-1-gnome; then
                polkit_agent="policykit-1-gnome"
            elif apt_package_available mate-polkit-bin; then
                polkit_agent="mate-polkit-bin"
            else
                die "No supported PolicyKit authentication agent is available from the enabled apt repositories."
            fi
            packages=(build-essential nitrogen xserver-xorg xinit x11-xserver-utils git curl wget feh lxappearance arandr thunar thunar-volman thunar-archive-plugin thunar-media-tags-plugin gvfs gvfs-backends gvfs-fuse "$polkit_agent" picom flameshot imagemagick fonts-dejavu fonts-liberation fonts-noto fonts-droid-fallback libx11-dev libxft-dev libxinerama-dev)
            ;;
        dnf)
            packages=("@development-tools" nitrogen xorg-x11-server-Xorg xorg-x11-xinit xorg-x11-server-utils xrandr git feh lxappearance arandr thunar thunar-volman thunar-archive-plugin thunar-media-tags-plugin gvfs gvfs-mtp gvfs-gphoto2 gvfs-afc gvfs-nfs gvfs-smb polkit-gnome picom flameshot ImageMagick dejavu-sans-fonts liberation-fonts google-noto-sans-fonts droid-sans-fonts libX11-devel libXft-devel libXinerama-devel)
            ;;
    esac

    # Package groups cannot be queried like ordinary RPMs, so let dnf handle them.
    if [ "$PKG_MANAGER" = dnf ]; then
        missing_packages=("${packages[@]}")
    else
        get_missing_packages packages missing_packages
    fi

    if ((${#missing_packages[@]})); then
        printf '\n%b\n' "${MAGENTA}⚙️  Installing required packages...${RESET}"
        "${INSTALL_CMD[@]}" "${missing_packages[@]}"
    else
        printf '%b\n' "${GREEN}✅ All required packages are already installed.${RESET}"
    fi

    install_optional_steam
}

ensure_repository() {
    local name=$1
    local repository=$2
    local revision=$3
    local directory="$SUCKLESS_DIR/$name"
    local actual_remote=""
    local actual_revision=""

    if [ ! -e "$directory" ]; then
        printf '%b\n' "${CYAN}  → Cloning ${name} at pinned revision ${revision:0:12}...${RESET}"
        git clone --no-checkout "$repository" "$directory"
        git -C "$directory" checkout --detach "$revision"
        return
    fi

    [ -d "$directory/.git" ] || die "$directory exists but is not a Git repository. Move it aside and rerun."
    actual_remote=$(git -C "$directory" remote get-url origin)
    [ "$actual_remote" = "$repository" ] || die "$directory has unexpected origin '$actual_remote'. Expected '$repository'."
    actual_revision=$(git -C "$directory" rev-parse HEAD)
    [ "$actual_revision" = "$revision" ] || die "$directory is at ${actual_revision:0:12}, not pinned revision ${revision:0:12}. Back up customizations and update it deliberately."

    if [ -n "$(git -C "$directory" status --porcelain)" ]; then
        warn "$directory contains local changes. They will be built without elevated privileges."
    fi
}

clone_repositories() {
    printf '\n%b\n' "${BLUE}📥 Preparing pinned repositories...${RESET}"
    mkdir -p "$SUCKLESS_DIR"
    ensure_repository dwm "$DWM_REPOSITORY" "$DWM_REVISION"
    ensure_repository st "$ST_REPOSITORY" "$ST_REVISION"
    ensure_repository dmenu "$DMENU_REPOSITORY" "$DMENU_REVISION"
}

build_software() {
    local name=$1
    local directory="$SUCKLESS_DIR/$name"

    printf '%b\n' "${CYAN}  → Building ${name}...${RESET}"
    make -C "$directory" clean
    make -C "$directory"
    make -C "$directory" PREFIX="$INSTALL_PREFIX" install
    [ -x "$INSTALL_PREFIX/bin/$name" ] || die "$name did not install to $INSTALL_PREFIX/bin/$name."
}

compile_software() {
    printf '\n%b\n' "${YELLOW}🔨 Compiling software as $(id -un)...${RESET}"
    mkdir -p "$INSTALL_PREFIX/bin"
    build_software dwm
    build_software st
    build_software dmenu
}

create_dwm_session_launcher() {
    local launcher="$INSTALL_PREFIX/bin/dwm-session"

    cat >"$launcher" <<EOF
#!/bin/sh
export PATH="$INSTALL_PREFIX/bin:\$PATH"
exec "$INSTALL_PREFIX/bin/dwm"
EOF
    chmod 0755 "$launcher"
}

setup_xinitrc() {
    local xinitrc="$HOME/.xinitrc"

    printf '\n%b\n' "${MAGENTA}⚙️  Setting up .xinitrc...${RESET}"
    if [ ! -f "$xinitrc" ]; then
        cat >"$xinitrc" <<EOF
#!/bin/sh

if command -v polkit-gnome-authentication-agent-1 >/dev/null 2>&1; then
  polkit-gnome-authentication-agent-1 &
elif command -v mate-polkit >/dev/null 2>&1; then
  mate-polkit &
elif [ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]; then
  /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
elif [ -x /usr/libexec/polkit-gnome-authentication-agent-1 ]; then
  /usr/libexec/polkit-gnome-authentication-agent-1 &
elif [ -x /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 ]; then
  /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 &
fi

exec "$INSTALL_PREFIX/bin/dwm-session"
EOF
        chmod 0755 "$xinitrc"
        printf '%b\n' "${GREEN}  ✅ $xinitrc created successfully${RESET}"
    else
        warn "$xinitrc already exists. Ensure its final command is: exec \"$INSTALL_PREFIX/bin/dwm-session\""
    fi
}

login_startup_file() {
    local login_shell
    login_shell=$(getent passwd "$(id -un)" | awk -F: '{print $7}')

    case "${login_shell##*/}" in
        bash)
            if [ -f "$HOME/.bash_profile" ]; then
                printf '%s' "$HOME/.bash_profile"
            else
                printf '%s' "$HOME/.profile"
            fi
            ;;
        zsh) printf '%s' "$HOME/.zprofile" ;;
        sh|dash|ksh) printf '%s' "$HOME/.profile" ;;
        *) return 1 ;;
    esac
}

setup_autostart() {
    local shell_rc
    local marker="# Auto-start X on tty1 login"

    printf '\n%b\n' "${MAGENTA}⚙️  Setting up X and DWM autostart...${RESET}"
    if ! shell_rc=$(login_startup_file); then
        warn "Login shell is unsupported for automatic startx configuration. Run 'startx' manually."
        return
    fi

    touch "$shell_rc"
    if grep -Fq "$marker" "$shell_rc"; then
        printf '%b\n' "${GREEN}  ✅ Autostart is already configured in $shell_rc${RESET}"
        return
    fi

    {
        printf '\n%s\n' "$marker"
        printf '%s\n' 'if [ -z "${DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then exec startx; fi'
    } >>"$shell_rc"
    printf '%b\n' "${GREEN}  ✅ X autostart configured in $shell_rc${RESET}"
}

create_dwm_desktop_entry() {
    local desktop_entry
    desktop_entry=$(mktemp)
    TEMP_FILES+=("$desktop_entry")

    cat >"$desktop_entry" <<EOF
[Desktop Entry]
Name=DWM
Comment=Dynamic Window Manager
Exec="$INSTALL_PREFIX/bin/dwm-session"
Type=Application
DesktopNames=DWM
EOF
    sudo install -D -m 0644 "$desktop_entry" /usr/share/xsessions/dwm.desktop
    printf '%b\n' "${GREEN}  ✅ DWM desktop entry created${RESET}"
}

display_manager_installed() {
    command -v systemctl >/dev/null 2>&1 || return 1
    [ -d /run/systemd/system ] || return 1
    systemctl list-unit-files lightdm.service gdm.service gdm3.service sddm.service --no-legend 2>/dev/null |
        awk '$2 != "not-found" { found=1 } END { exit !found }'
}

install_lightdm() {
    local -a dm_packages=()
    local -a missing_dm=()

    case "$PKG_MANAGER" in
        pacman|apt) dm_packages=(lightdm lightdm-gtk-greeter) ;;
        dnf) dm_packages=(lightdm lightdm-gtk) ;;
    esac

    get_missing_packages dm_packages missing_dm
    if ((${#missing_dm[@]})); then
        printf '%b\n' "${MAGENTA}📥 Installing LightDM...${RESET}"
        "${INSTALL_CMD[@]}" "${missing_dm[@]}"
    fi

    command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ] || die "LightDM was installed, but this system is not running systemd; enable it with your init system."
    sudo systemctl enable lightdm.service
    systemctl is-enabled --quiet lightdm.service || die "LightDM could not be enabled."
    printf '%b\n' "${GREEN}✅ LightDM has been installed and enabled. Please reboot after installation.${RESET}"
}

setup_display() {
    local choice
    local install_dm

    printf '\n%b\n' "${BOLD}${CYAN}🖥️  Select how you want to start DWM:${RESET}"
    printf '%b\n' "${YELLOW}1)${RESET} Use a Display Manager (LightDM, GDM, or SDDM) - ${GREEN}Recommended${RESET}"
    printf '%b\n' "${YELLOW}2)${RESET} Use startx from tty1"
    choice=$(prompt "${BOLD}Enter your choice [1-2]:${RESET} ")

    if [[ ! "$choice" =~ ^[12]$ ]]; then
        warn "Invalid, empty, or non-interactive choice. Defaulting to option 1."
        choice=1
    fi

    case "$choice" in
        1)
            create_dwm_desktop_entry
            if display_manager_installed; then
                printf '%b\n' "${GREEN}✅ Found an installed display manager. DWM is available as a session.${RESET}"
            else
                warn "No supported display manager unit was found."
                install_dm=$(prompt "${BOLD}Would you like to install LightDM? [y/N]:${RESET} ")
                if [[ "$install_dm" =~ ^[yY]([eE][sS])?$ ]]; then
                    install_lightdm
                else
                    warn "Display-manager installation skipped. Install and enable one before rebooting into a graphical session."
                fi
            fi
            printf '\n%b\n' "${BOLD}${GREEN}🚀 Installation complete.${RESET}"
            printf '%b\n' "${CYAN}   Reboot and select DWM from your display manager's session list.${RESET}"
            ;;
        2)
            setup_xinitrc
            setup_autostart
            printf '\n%b\n' "${BOLD}${GREEN}🚀 Installation complete.${RESET}"
            printf '%b\n' "${CYAN}   Log in on tty1 to start X automatically, or run startx manually.${RESET}"
            ;;
    esac
}

main() {
    printf '%b' "${BOLD}${MAGENTA}"
    printf '%s\n' \
        '╔═══════════════════════════════════════════════════════╗' \
        '║                                                       ║' \
        '║           🏗️  DWM Installation Script 🏗️             ║' \
        '║                                                       ║' \
        '║   Installing Dynamic Window Manager & Suckless Tools ║' \
        '║                                                       ║' \
        '╚═══════════════════════════════════════════════════════╝'
    printf '%b\n\n' "$RESET"

    preflight
    detect_package_manager
    install_packages
    clone_repositories
    compile_software
    create_dwm_session_launcher
    setup_display
}

if [ "${DWM_INSTALL_TESTING:-0}" != 1 ]; then
    main "$@"
fi
