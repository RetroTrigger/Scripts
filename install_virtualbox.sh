#!/bin/bash

set -e

# Common variables
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
VBOX_BASE_URL="https://download.virtualbox.org/virtualbox"

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "Unsupported distribution: Cannot detect Linux distribution" >&2
        exit 1
    fi
}

# Function to get VirtualBox version
get_vbox_version() {
    if ! command -v VBoxManage &> /dev/null; then
        echo "Error: VBoxManage not found. VirtualBox may not be installed correctly." >&2
        return 1
    fi
    VBOX_FULL_VERSION=$(VBoxManage --version)
    VBOX_VERSION=$(echo "$VBOX_FULL_VERSION" | cut -d'r' -f1)
}

# Function to decode URL encoding
url_decode() {
    echo "$1" | sed 's/%5F/_/g; s/%2E/./g; s/%2D/-/g'
}

# Function to download file
download_file() {
    local url=$1 output=$2
    if wget --header="Accept: */*" --header="User-Agent: $USER_AGENT" "$url" -O "$output" 2>&1 | grep -q "200 OK\|saved"; then
        return 0
    fi
    if command -v curl &> /dev/null; then
        curl -L -f -o "$output" -H "Accept: */*" -H "User-Agent: $USER_AGENT" "$url" 2>/dev/null && return 0
    fi
    return 1
}

# Function to fetch directory listing
fetch_dir_listing() {
    local url=$1 output=$2
    if wget --header="User-Agent: $USER_AGENT" -O "$output" "$url" 2>/dev/null; then
        return 0
    fi
    if command -v curl &> /dev/null; then
        curl -s -L -H "User-Agent: $USER_AGENT" "$url" -o "$output" 2>/dev/null && return 0
    fi
    return 1
}

# Function to discover file from directory listing
discover_file() {
    local version_dir="$VBOX_BASE_URL/${VBOX_VERSION}/" pattern=$1 temp_list=$2
    if ! fetch_dir_listing "$version_dir" "$temp_list"; then
        return 1
    fi
    
    local all_files=$(grep -oE "$pattern" "$temp_list")
    if [ -z "$all_files" ]; then
        rm -f "$temp_list"
        return 1
    fi
    
    # Prefer files without revision number (ends with version.ext, not version-revision.ext)
    local preferred=$(echo "$all_files" | grep -E '[0-9]+\.[0-9]+\.[0-9]+\.(vbox-extpack|iso)$' | head -1)
    local found=$(url_decode "${preferred:-$(echo "$all_files" | head -1)}")
    
    rm -f "$temp_list"
    echo "$found"
}

# Function to install dependencies
install_dependencies() {
    local distro=$1
    echo "Installing dependencies for $distro..."
    case $distro in
        "ubuntu"|"debian"|"pop"|"linuxmint"|"elementary"|"kali"|"zorin"|"mx"|"peppermint"|"kde"|"xubuntu"|"lubuntu"|"kubuntu"|"ubuntu"*)
            sudo apt-get update && sudo apt-get install -y wget curl linux-headers-$(uname -r) build-essential dkms
            ;;
        "fedora"|"rhel"|"centos"|"almalinux"|"rocky"|"ol"|"amzn")
            if command -v dnf &> /dev/null; then
                sudo dnf install -y wget kernel-devel kernel-headers gcc make dkms
            else
                sudo yum install -y wget kernel-devel kernel-headers gcc make dkms
            fi
            ;;
        "arch"|"manjaro"|"endeavouros"|"garuda"|"cachyos")
            sudo pacman -Syu --noconfirm wget linux-headers gcc make dkms
            ;;
        "opensuse-tumbleweed"|"opensuse-leap"|"sles")
            sudo zypper refresh && sudo zypper install -y wget kernel-devel gcc make dkms
            ;;
        *)
            echo "Unsupported distribution: $distro" >&2
            exit 1
            ;;
    esac
}

# Function to add user to vboxusers group (works for all distributions)
add_user_to_vboxusers() {
    # Check if vboxusers group exists (created during VirtualBox installation)
    if ! getent group vboxusers > /dev/null 2>&1; then
        echo "Warning: vboxusers group not found. Creating vboxusers group..."
        sudo groupadd vboxusers 2>/dev/null || echo "Note: Group creation may have failed or group already exists."
    fi
    
    # Check if user is already in the group
    if groups | grep -q vboxusers; then
        echo "User is already in vboxusers group."
        return 0
    fi
    
    echo "Adding user to vboxusers group..."
    sudo usermod -aG vboxusers $USER
    echo "User added to vboxusers group. You may need to log out and back in for this to take effect."
}

# Function to install VirtualBox
install_virtualbox() {
    local distro=$1
    echo "Installing VirtualBox for $distro..."
    case $distro in
        "ubuntu"|"debian"|"pop"|"linuxmint"|"elementary"|"kali"|"zorin"|"mx"|"peppermint"|"kde"|"xubuntu"|"lubuntu"|"kubuntu"|"ubuntu"*)
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list > /dev/null
            wget -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --dearmor --yes --output /usr/share/keyrings/oracle-virtualbox-2016.gpg
            sudo apt-get update && sudo apt-get install -y virtualbox-7.0
            ;;
        "fedora"|"rhel"|"centos"|"almalinux"|"rocky"|"ol"|"amzn")
            sudo dnf install -y @development-tools kernel-headers kernel-devel dkms qt5-qtx11extras libxkbcommon
            sudo dnf config-manager --add-repo https://download.virtualbox.org/virtualbox/rpm/el/virtualbox.repo
            sudo dnf install -y VirtualBox-7.0
            ;;
        "arch"|"manjaro"|"endeavouros"|"garuda"|"cachyos")
            sudo pacman -S --noconfirm virtualbox virtualbox-host-modules-arch
            sudo modprobe vboxdrv vboxnetadp vboxnetflt
            ;;
        "opensuse-tumbleweed"|"opensuse-leap"|"sles")
            sudo zypper addrepo https://download.virtualbox.org/virtualbox/rpm/opensuse/$(grep -oP 'VERSION_ID="\K[0-9.]+' /etc/os-release | cut -d. -f1) virtualbox
            sudo rpm --import https://www.virtualbox.org/download/oracle_vbox.asc
            sudo zypper refresh && sudo zypper install -y virtualbox-7.0
            ;;
    esac
}

# Function to install Extension Pack
install_extension_pack() {
    echo "Installing VirtualBox Extension Pack..."
    get_vbox_version || return 1
    
    local version_dir="$VBOX_BASE_URL/${VBOX_VERSION}/"
    local ext_file="/tmp/Oracle_VirtualBox_Extension_Pack.vbox-extpack"
    local temp_list="/tmp/vbox_dir_list.txt"
    
    echo "Discovering available Extension Pack..."
    local found_pack=$(discover_file 'Oracle[%_]VirtualBox[%_]Extension[%_]Pack-[0-9.-]*\.vbox-extpack' "$temp_list")
    
    if [ -n "$found_pack" ]; then
        local url="${version_dir}${found_pack}"
        echo "Downloading Extension Pack from: $url"
        if download_file "$url" "$ext_file"; then
            echo "y" | sudo VBoxManage extpack install --replace "$ext_file"
            rm -f "$ext_file"
            return 0
        fi
    fi
    
    # Fallback to base version
    echo "Trying base version fallback..."
    if download_file "${version_dir}Oracle_VirtualBox_Extension_Pack-${VBOX_VERSION}.vbox-extpack" "$ext_file"; then
        echo "y" | sudo VBoxManage extpack install --replace "$ext_file"
        rm -f "$ext_file"
        return 0
    fi
    
    echo "Error: Could not download VirtualBox Extension Pack." >&2
    echo "Please check: $version_dir" >&2
    return 1
}

# Function to download Guest Additions ISO
download_guest_additions() {
    echo "Downloading VirtualBox Guest Additions ISO..."
    get_vbox_version || return 1
    
    local ga_dir="$HOME/VirtualBox VMs/VirtualBox Guest Additions"
    mkdir -p "$ga_dir"
    
    local version_dir="$VBOX_BASE_URL/${VBOX_VERSION}/"
    local temp_list="/tmp/vbox_dir_list_ga.txt"
    
    echo "Discovering available Guest Additions ISO..."
    local found_iso=$(discover_file 'VBoxGuestAdditions[%_][0-9.]+\.iso' "$temp_list")
    
    if [ -n "$found_iso" ]; then
        local url="${version_dir}${found_iso}"
        local output="$ga_dir/$found_iso"
        echo "Downloading Guest Additions from: $url"
        if download_file "$url" "$output"; then
            echo "Guest Additions ISO downloaded to: $ga_dir/"
            return 0
        fi
    fi
    
    # Fallback to base version
    local output="$ga_dir/VBoxGuestAdditions_${VBOX_VERSION}.iso"
    if download_file "${version_dir}VBoxGuestAdditions_${VBOX_VERSION}.iso" "$output"; then
        echo "Guest Additions ISO downloaded to: $ga_dir/"
        return 0
    fi
    
    echo "Warning: Could not download Guest Additions ISO automatically." >&2
    return 1
}

# Main script execution
main() {
    [ "$EUID" -eq 0 ] && { echo "Please run this script as a normal user, not as root." >&2; exit 1; }
    
    local distro=$(detect_distro)
    echo "Detected distribution: $distro"
    
    install_dependencies "$distro"
    install_virtualbox "$distro"
    add_user_to_vboxusers
    install_extension_pack
    download_guest_additions
    
    echo ""
    echo "VirtualBox installation completed successfully!"
    echo "Please log out and log back in for all changes to take effect."
}

main "$@"
