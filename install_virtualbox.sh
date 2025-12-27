#!/bin/bash

# Exit on error and print commands for debugging
set -e

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "Unsupported distribution: Cannot detect Linux distribution"
        exit 1
    fi
}

# Function to install dependencies based on distribution
install_dependencies() {
    local distro=$1
    echo "Installing dependencies for $distro..."
    
    case $distro in
        "ubuntu" | "debian" | "pop" | "linuxmint" | "elementary" | "kali" | "zorin" | "mx" | "peppermint" | "kde" | "xubuntu" | "lubuntu" | "kubuntu" | "xubuntu" | "ubuntu"* )
            sudo apt-get update
            sudo apt-get install -y wget curl linux-headers-$(uname -r) build-essential dkms
            ;;
        "fedora" | "rhel" | "centos" | "almalinux" | "rocky" | "ol" | "amzn" )
            if command -v dnf &> /dev/null; then
                sudo dnf install -y wget kernel-devel kernel-headers gcc make dkms
            else
                sudo yum install -y wget kernel-devel kernel-headers gcc make dkms
            fi
            ;;
        "arch" | "manjaro" | "endeavouros" | "garuda" | "cachyos" )
            sudo pacman -Syu --noconfirm wget linux-headers gcc make dkms
            ;;
        "opensuse-tumbleweed" | "opensuse-leap" | "sles" )
            sudo zypper refresh
            sudo zypper install -y wget kernel-devel gcc make dkms
            ;;
        *)
            echo "Unsupported distribution: $distro"
            exit 1
            ;;
    esac
}

# Function to install VirtualBox
install_virtualbox() {
    local distro=$1
    echo "Installing VirtualBox for $distro..."
    
    case $distro in
        "ubuntu" | "debian" | "pop" | "linuxmint" | "elementary" | "kali" | "zorin" | "mx" | "peppermint" | "kde" | "xubuntu" | "lubuntu" | "kubuntu" | "xubuntu" | "ubuntu"* )
            # Add Oracle VirtualBox repository
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list
            
            # Add Oracle public key
            wget -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --dearmor --yes --output /usr/share/keyrings/oracle-virtualbox-2016.gpg
            
            # Install VirtualBox
            sudo apt-get update
            sudo apt-get install -y virtualbox-7.0
            ;;
        "fedora" | "rhel" | "centos" | "almalinux" | "rocky" | "ol" | "amzn" )
            # For RHEL-based systems
            sudo dnf install -y @development-tools
            sudo dnf install -y kernel-headers kernel-devel dkms qt5-qtx11extras libxkbcommon
            
            # Add VirtualBox repository
            sudo dnf config-manager --add-repo https://download.virtualbox.org/virtualbox/rpm/el/virtualbox.repo
            
            # Install VirtualBox
            sudo dnf install -y VirtualBox-7.0
            ;;
        "arch" | "manjaro" | "endeavouros" | "garuda" | "cachyos" )
            # Install VirtualBox and dependencies
            sudo pacman -S --noconfirm virtualbox virtualbox-host-modules-arch
            
            # Load VirtualBox kernel modules
            sudo modprobe vboxdrv
            sudo modprobe vboxnetadp
            sudo modprobe vboxnetflt
            
            # Add user to vboxusers group
            sudo usermod -aG vboxusers $USER
            ;;
        "opensuse-tumbleweed" | "opensuse-leap" | "sles" )
            # Add VirtualBox repository
            sudo zypper addrepo https://download.virtualbox.org/virtualbox/rpm/opensuse/$(grep -oP 'VERSION_ID="\K[0-9.]+' /etc/os-release | cut -d. -f1) virtualbox
            
            # Add repository key
            sudo rpm --import https://www.virtualbox.org/download/oracle_vbox.asc
            
            # Install VirtualBox
            sudo zypper refresh
            sudo zypper install -y virtualbox-7.0
            ;;
    esac
}

# Function to install Extension Pack
install_extension_pack() {
    echo "Installing VirtualBox Extension Pack..."
    
    # Check if VBoxManage is available
    if ! command -v VBoxManage &> /dev/null; then
        echo "Error: VBoxManage not found. VirtualBox may not be installed correctly."
        return 1
    fi
    
    # Get the full version string (e.g., "7.2.4r123456")
    VBOX_FULL_VERSION=$(VBoxManage --version)
    # Get the base version for the URL path (e.g., "7.2.4")
    VBOX_VERSION=$(echo "$VBOX_FULL_VERSION" | cut -d'r' -f1)
    
    EXT_PACK_FILE="/tmp/Oracle_VM_VirtualBox_Extension_Pack.vbox-extpack"
    
    # Function to download file
    download_file() {
        local url=$1
        local output=$2
        
        # Try with wget first
        local wget_output
        wget_output=$(wget --header="Accept: */*" \
               --header="User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
               "$url" -O "$output" 2>&1)
        
        if echo "$wget_output" | grep -q "200 OK\|saved"; then
            return 0
        fi
        
        # If wget failed, show the error
        if echo "$wget_output" | grep -q "404\|Not Found"; then
            echo "  Error: File not found (404) at: $url"
        elif echo "$wget_output" | grep -q "403\|Forbidden"; then
            echo "  Error: Access forbidden (403) at: $url"
        else
            echo "  Error: Download failed - $(echo "$wget_output" | head -1)"
        fi
        
        # Alternative: try with curl if available
        if command -v curl &> /dev/null; then
            if curl -L -f -o "$output" \
                   -H "Accept: */*" \
                   -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
                   "$url" 2>/dev/null; then
                return 0
            fi
        fi
        
        return 1
    }
    
    # Function to discover available Extension Pack by checking directory listing
    discover_extension_pack() {
        local version_dir="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/"
        local temp_list="/tmp/vbox_dir_list.txt"
        
        echo "Checking available Extension Packs in version directory..."
        
        # Try to get directory listing
        if wget --header="User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
               -O "$temp_list" "$version_dir" 2>/dev/null; then
            # Extract Extension Pack filenames from the listing (handle URL encoding)
            # Look for both URL-encoded (%5F for _) and regular format
            # Prefer the one without revision number (simpler, less likely to cause name mismatch)
            local ext_packs
            # Get all Extension Pack files
            local all_packs
            all_packs=$(grep -oE 'Oracle[%_]VirtualBox[%_]Extension[%_]Pack-[0-9.-]*\.vbox-extpack' "$temp_list")
            
            # First try to find one without revision: version.vbox-extpack (no dash-revision before extension)
            # Pattern: ends with -X.Y.Z.vbox-extpack (not -X.Y.Z-revision.vbox-extpack)
            ext_packs=$(echo "$all_packs" | grep -E '[0-9]+\.[0-9]+\.[0-9]+\.vbox-extpack$' | head -1)
            
            # If not found, use any Extension Pack (with revision)
            if [ -z "$ext_packs" ]; then
                ext_packs=$(echo "$all_packs" | head -1)
            fi
            
            if [ -n "$ext_packs" ]; then
                # Decode URL encoding: %5F -> _, %2E -> .
                local found_pack
                found_pack=$(echo "$ext_packs" | sed 's/%5F/_/g' | sed 's/%2E/./g' | sed 's/%2D/-/g')
                echo "Found Extension Pack: $found_pack"
                EXT_PACK_URL="${version_dir}${found_pack}"
                rm -f "$temp_list"
                return 0
            fi
            rm -f "$temp_list"
        fi
        
        # Alternative: try with curl
        if command -v curl &> /dev/null; then
            if curl -s -L -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
                   "$version_dir" -o "$temp_list" 2>/dev/null; then
                local ext_packs
                # Get all Extension Pack files
                local all_packs
                all_packs=$(grep -oE 'Oracle[%_]VirtualBox[%_]Extension[%_]Pack-[0-9.-]*\.vbox-extpack' "$temp_list")
                
                # First try to find one without revision: version.vbox-extpack (no dash-revision before extension)
                # Pattern: ends with -X.Y.Z.vbox-extpack (not -X.Y.Z-revision.vbox-extpack)
                ext_packs=$(echo "$all_packs" | grep -E '[0-9]+\.[0-9]+\.[0-9]+\.vbox-extpack$' | head -1)
                
                # If not found, use any Extension Pack (with revision)
                if [ -z "$ext_packs" ]; then
                    ext_packs=$(echo "$all_packs" | head -1)
                fi
                
                if [ -n "$ext_packs" ]; then
                    # Decode URL encoding
                    local found_pack
                    found_pack=$(echo "$ext_packs" | sed 's/%5F/_/g' | sed 's/%2E/./g' | sed 's/%2D/-/g')
                    echo "Found Extension Pack: $found_pack"
                    EXT_PACK_URL="${version_dir}${found_pack}"
                    rm -f "$temp_list"
                    return 0
                fi
                rm -f "$temp_list"
            fi
        fi
        
        return 1
    }
    
    # Try to discover the Extension Pack version by checking the directory
    echo "Discovering available Extension Pack version..."
    
    # First, try to discover what Extension Packs are actually available
    if discover_extension_pack; then
        echo "Attempting to download Extension Pack from: $EXT_PACK_URL"
        if download_file "$EXT_PACK_URL" "$EXT_PACK_FILE"; then
            echo "Successfully downloaded Extension Pack"
        else
            echo "Failed to download discovered Extension Pack, trying fallback methods..."
        fi
    fi
    
    # If discovery didn't work or download failed, try fallback with base version
    if [ ! -f "$EXT_PACK_FILE" ] || [ ! -s "$EXT_PACK_FILE" ]; then
        echo "Discovery failed, trying base version fallback..."
        EXT_PACK_URL="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/Oracle_VirtualBox_Extension_Pack-${VBOX_VERSION}.vbox-extpack"
        if ! download_file "$EXT_PACK_URL" "$EXT_PACK_FILE"; then
            echo "Error: Could not download VirtualBox Extension Pack automatically."
            echo "VirtualBox version: $VBOX_FULL_VERSION"
            echo "Please check what Extension Packs are available at:"
            echo "  https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/"
            echo "Or download manually from:"
            echo "  https://www.virtualbox.org/wiki/Downloads"
            return 1
        fi
    fi
    
    # Verify the file was downloaded successfully
    if [ ! -f "$EXT_PACK_FILE" ] || [ ! -s "$EXT_PACK_FILE" ]; then
        echo "Error: Extension Pack file is missing or empty after download attempt."
        return 1
    fi
    
    # Rename the file to a simpler name that VBoxManage expects
    # VBoxManage compares the filename to the XML metadata, so use a name that matches
    SIMPLE_EXT_PACK_FILE="/tmp/Oracle_VirtualBox_Extension_Pack.vbox-extpack"
    cp "$EXT_PACK_FILE" "$SIMPLE_EXT_PACK_FILE"
    
    # Install the Extension Pack
    echo "y" | sudo VBoxManage extpack install --replace "$SIMPLE_EXT_PACK_FILE"
    
    # Clean up
    rm -f "$EXT_PACK_FILE" "$SIMPLE_EXT_PACK_FILE"
}

# Function to download Guest Additions ISO
download_guest_additions() {
    echo "Downloading VirtualBox Guest Additions ISO..."
    
    # Get the full version string (e.g., "7.2.4r123456")
    VBOX_FULL_VERSION=$(VBoxManage --version)
    # Get the base version for the URL path (e.g., "7.2.4")
    VBOX_VERSION=$(echo "$VBOX_FULL_VERSION" | cut -d'r' -f1)
    
    # Create directory for Guest Additions if it doesn't exist
    mkdir -p ~/VirtualBox\ VMs/VirtualBox\ Guest\ Additions
    
    # Initialize variables
    GA_ISO_URL=""
    GA_ISO_FILE=""
    
    # Function to download file (same as Extension Pack function)
    download_file() {
        local url=$1
        local output=$2
        
        # Try with wget first
        if wget --header="Accept: */*" \
               --header="User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
               "$url" -O "$output" 2>&1 | grep -q "200 OK\|saved"; then
            return 0
        fi
        
        # Alternative: try with curl if available
        if command -v curl &> /dev/null; then
            if curl -L -f -o "$output" \
                   -H "Accept: */*" \
                   -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
                   "$url" 2>/dev/null; then
                return 0
            fi
        fi
        
        return 1
    }
    
    # Function to discover available Guest Additions ISO by checking directory listing
    discover_guest_additions() {
        local version_dir="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/"
        local temp_list="/tmp/vbox_dir_list_ga.txt"
        
        echo "Checking available Guest Additions ISO in version directory..."
        
        # Try to get directory listing
        if wget --header="User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
               -O "$temp_list" "$version_dir" 2>/dev/null; then
            # Extract Guest Additions ISO filename from the listing (handle URL encoding)
            local ga_iso
            ga_iso=$(grep -oE 'VBoxGuestAdditions[%_][0-9.]+\.iso' "$temp_list" | head -1)
            
            if [ -n "$ga_iso" ]; then
                # Decode URL encoding: %5F -> _, %2E -> .
                local found_iso
                found_iso=$(echo "$ga_iso" | sed 's/%5F/_/g' | sed 's/%2E/./g')
                echo "Found Guest Additions ISO: $found_iso"
                GA_ISO_URL="${version_dir}${found_iso}"
                rm -f "$temp_list"
                return 0
            fi
            rm -f "$temp_list"
        fi
        
        # Alternative: try with curl
        if command -v curl &> /dev/null; then
            if curl -s -L -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
                   "$version_dir" -o "$temp_list" 2>/dev/null; then
                local ga_iso
                ga_iso=$(grep -oE 'VBoxGuestAdditions[%_][0-9.]+\.iso' "$temp_list" | head -1)
                
                if [ -n "$ga_iso" ]; then
                    # Decode URL encoding
                    local found_iso
                    found_iso=$(echo "$ga_iso" | sed 's/%5F/_/g' | sed 's/%2E/./g')
                    echo "Found Guest Additions ISO: $found_iso"
                    GA_ISO_URL="${version_dir}${found_iso}"
                    rm -f "$temp_list"
                    return 0
                fi
                rm -f "$temp_list"
            fi
        fi
        
        return 1
    }
    
    # Try to discover Guest Additions ISO first
    if discover_guest_additions; then
        # Use discovered filename for the local file
        local discovered_filename
        discovered_filename=$(basename "$GA_ISO_URL")
        GA_ISO_FILE="$HOME/VirtualBox VMs/VirtualBox Guest Additions/${discovered_filename}"
        echo "Attempting to download Guest Additions from: $GA_ISO_URL"
        if download_file "$GA_ISO_URL" "$GA_ISO_FILE"; then
            echo "Successfully downloaded Guest Additions ISO"
        else
            echo "Failed to download discovered Guest Additions, trying fallback methods..."
        fi
    fi
    
    # If discovery didn't work or download failed, try constructed URLs
    if [ -z "$GA_ISO_FILE" ] || [ ! -f "$GA_ISO_FILE" ] || [ ! -s "$GA_ISO_FILE" ]; then
        # Try with base version first (most common format: VBoxGuestAdditions_7.2.4.iso)
        GA_ISO_URL="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso"
        GA_ISO_FILE="$HOME/VirtualBox VMs/VirtualBox Guest Additions/VBoxGuestAdditions_${VBOX_VERSION}.iso"
        
        if ! download_file "$GA_ISO_URL" "$GA_ISO_FILE"; then
            # Fallback: try with full version (less common)
            GA_ISO_URL="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_FULL_VERSION}.iso"
            GA_ISO_FILE="$HOME/VirtualBox VMs/VirtualBox Guest Additions/VBoxGuestAdditions_${VBOX_FULL_VERSION}.iso"
            download_file "$GA_ISO_URL" "$GA_ISO_FILE"
        fi
    fi
    
    echo "Guest Additions ISO downloaded to: ~/VirtualBox VMs/VirtualBox Guest Additions/"
}

# Main script execution
main() {
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        echo "Please run this script as a normal user, not as root."
        exit 1
    fi
    
    # Detect distribution
    DISTRO=$(detect_distro)
    echo "Detected distribution: $DISTRO"
    
    # Install dependencies
    install_dependencies "$DISTRO"
    
    # Install VirtualBox
    install_virtualbox "$DISTRO"
    
    # Install Extension Pack
    install_extension_pack
    
    # Download Guest Additions ISO
    download_guest_additions
    
    echo ""
    echo "VirtualBox installation completed successfully!"
    echo "Please log out and log back in for all changes to take effect."
    echo "Guest Additions ISO is available in: ~/VirtualBox VMs/VirtualBox Guest Additions/"
}

# Run the main function
main "$@"
