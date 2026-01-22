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

# Function to get the latest VirtualBox version from download server
get_latest_vbox_version() {
    local temp_file="/tmp/vbox_versions.html"
    echo "Fetching latest VirtualBox version..." >&2

    # Fetch the directory listing
    if command -v wget &> /dev/null; then
        wget -q --header="User-Agent: $USER_AGENT" -O "$temp_file" "$VBOX_BASE_URL/" 2>/dev/null
    elif command -v curl &> /dev/null; then
        curl -sL -H "User-Agent: $USER_AGENT" "$VBOX_BASE_URL/" -o "$temp_file" 2>/dev/null
    fi

    if [ ! -s "$temp_file" ]; then
        echo "Error: Could not fetch VirtualBox version list" >&2
        rm -f "$temp_file"
        return 1
    fi

    # Extract version numbers and get the latest (highest) stable version
    # Versions look like "7.1.4/" - we want the major.minor (7.1) for package names
    local latest=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+/' "$temp_file" | tr -d '/' | sort -V | tail -1)
    rm -f "$temp_file"

    if [ -z "$latest" ]; then
        echo "Error: Could not determine latest VirtualBox version" >&2
        return 1
    fi

    # Return major.minor for package installation (e.g., "7.1" from "7.1.4")
    echo "$latest" | cut -d. -f1,2
}

# Function to get Ubuntu/Debian codename from os-release or map from derivative
get_debian_codename() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        # Try UBUNTU_CODENAME first (works for Ubuntu and many derivatives)
        if [ -n "$UBUNTU_CODENAME" ]; then
            echo "$UBUNTU_CODENAME"
            return
        fi
        # Try VERSION_CODENAME (Debian, some derivatives)
        if [ -n "$VERSION_CODENAME" ]; then
            echo "$VERSION_CODENAME"
            return
        fi
        # Fallback: map ID_LIKE or known derivatives to Ubuntu codename
        case "$ID" in
            pop|elementary|zorin|linuxmint)
                # These are typically based on Ubuntu LTS - try to extract from VERSION_ID
                case "$VERSION_ID" in
                    22.*|21.*) echo "jammy" ;;   # Ubuntu 22.04 based
                    24.*|23.*) echo "noble" ;;   # Ubuntu 24.04 based
                    20.*|19.*) echo "focal" ;;   # Ubuntu 20.04 based
                    *) echo "jammy" ;;           # Default to jammy as safe fallback
                esac
                ;;
            debian|kali|mx)
                # Debian-based, use VERSION_ID to map
                case "$VERSION_ID" in
                    12|2023.*|2024.*) echo "bookworm" ;;
                    11|2021.*|2022.*) echo "bullseye" ;;
                    *) echo "bookworm" ;;
                esac
                ;;
            *)
                # Last resort fallback
                echo "jammy"
                ;;
        esac
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
    # Try wget first, check exit code directly
    if command -v wget &> /dev/null; then
        if wget -q --header="Accept: */*" --header="User-Agent: $USER_AGENT" "$url" -O "$output" 2>/dev/null; then
            [ -s "$output" ] && return 0  # Verify file is not empty
        fi
    fi
    # Fallback to curl
    if command -v curl &> /dev/null; then
        if curl -sL -f -o "$output" -H "Accept: */*" -H "User-Agent: $USER_AGENT" "$url" 2>/dev/null; then
            [ -s "$output" ] && return 0  # Verify file is not empty
        fi
    fi
    rm -f "$output" 2>/dev/null
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
        ubuntu|debian|pop|linuxmint|elementary|kali|zorin|mx|peppermint|xubuntu|lubuntu|kubuntu)
            sudo apt-get update && sudo apt-get install -y wget curl linux-headers-$(uname -r) build-essential dkms
            ;;
        fedora|rhel|centos|almalinux|rocky|ol|amzn)
            if command -v dnf &> /dev/null; then
                sudo dnf install -y dnf-plugins-core wget curl kernel-devel kernel-headers gcc make dkms
            else
                sudo yum install -y wget curl kernel-devel kernel-headers gcc make dkms
            fi
            ;;
        arch|manjaro|endeavouros|garuda|cachyos)
            sudo pacman -Syu --noconfirm wget curl base-devel dkms
            ;;
        opensuse-tumbleweed|opensuse-leap|sles)
            sudo zypper refresh && sudo zypper install -y wget curl kernel-devel gcc make dkms
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

    # Check if user is already in the group using getent (checks /etc/group, not session)
    if getent group vboxusers | grep -qw "$USER"; then
        echo "User is already in vboxusers group."
        return 0
    fi

    echo "Adding user to vboxusers group..."
    sudo usermod -aG vboxusers "$USER"
    echo "User added to vboxusers group. You may need to log out and back in for this to take effect."
}

# Function to detect running kernel type for Arch-based systems
get_arch_kernel_module_package() {
    local kernel_version=$(uname -r)
    case "$kernel_version" in
        *-lts*)     echo "virtualbox-host-modules-lts" ;;
        *-zen*)     echo "virtualbox-host-modules-zen" ;;
        *-hardened*) echo "virtualbox-host-modules-hardened" ;;
        *)          echo "virtualbox-host-modules-arch" ;;
    esac
}

# Function to get openSUSE repo path
get_opensuse_repo_path() {
    . /etc/os-release
    case "$ID" in
        opensuse-tumbleweed)
            echo "opensuse/tumbleweed"
            ;;
        opensuse-leap|sles)
            # Use full version for Leap (e.g., 15.5)
            echo "opensuse/${VERSION_ID}"
            ;;
        *)
            echo "opensuse/tumbleweed"  # fallback
            ;;
    esac
}

# Function to install VirtualBox
install_virtualbox() {
    local distro=$1

    # Get latest version (Arch uses its own repos, so skip for Arch-based)
    local vbox_version=""
    if [[ ! "$distro" =~ ^(arch|manjaro|endeavouros|garuda|cachyos)$ ]]; then
        vbox_version=$(get_latest_vbox_version)
        if [ -z "$vbox_version" ]; then
            echo "Error: Could not determine VirtualBox version to install" >&2
            exit 1
        fi
        echo "Latest VirtualBox version: $vbox_version"
    fi

    echo "Installing VirtualBox for $distro..."
    case $distro in
        ubuntu|debian|pop|linuxmint|elementary|kali|zorin|mx|peppermint|xubuntu|lubuntu|kubuntu)
            local codename=$(get_debian_codename)
            echo "Using codename: $codename"
            # Import GPG key FIRST, before adding the repository
            wget -qO- https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --dearmor --yes --output /usr/share/keyrings/oracle-virtualbox-2016.gpg
            # Now add the repository
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian $codename contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list > /dev/null
            sudo apt-get update && sudo apt-get install -y "virtualbox-${vbox_version}"
            ;;
        fedora|rhel|centos|almalinux|rocky|ol|amzn)
            sudo dnf install -y @development-tools kernel-headers kernel-devel dkms qt5-qtx11extras libxkbcommon
            sudo dnf config-manager --add-repo https://download.virtualbox.org/virtualbox/rpm/el/virtualbox.repo
            sudo dnf install -y "VirtualBox-${vbox_version}"
            ;;
        arch|manjaro|endeavouros|garuda|cachyos)
            # Arch repos always have the latest version
            local kernel_module=$(get_arch_kernel_module_package)
            echo "Detected kernel module package: $kernel_module"
            sudo pacman -S --noconfirm virtualbox "$kernel_module"
            sudo modprobe vboxdrv vboxnetadp vboxnetflt 2>/dev/null || echo "Note: Kernel modules will load on next reboot"
            ;;
        opensuse-tumbleweed|opensuse-leap|sles)
            local repo_path=$(get_opensuse_repo_path)
            echo "Using openSUSE repo path: $repo_path"
            # Import key first
            sudo rpm --import https://www.virtualbox.org/download/oracle_vbox_2016.asc
            # Check if repo already exists
            if ! sudo zypper repos | grep -q virtualbox; then
                sudo zypper addrepo "https://download.virtualbox.org/virtualbox/rpm/${repo_path}" virtualbox
            fi
            sudo zypper refresh && sudo zypper install -y "VirtualBox-${vbox_version}"
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
    local found_pack=$(discover_file 'Oracle[_%][Vv]irtual[Bb]ox[_%][Ee]xtension[_%][Pp]ack-[0-9.-]*\.vbox-extpack' "$temp_list")
    
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
    local found_iso=$(discover_file 'VBoxGuestAdditions[_][0-9.]+\.iso' "$temp_list")
    
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
