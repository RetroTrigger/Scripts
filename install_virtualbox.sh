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
    # Get the revision number (e.g., "123456")
    VBOX_REVISION=$(echo "$VBOX_FULL_VERSION" | cut -d'r' -f2)
    # Convert 'r' to '-' for Extension Pack filename (e.g., "7.2.4-123456")
    VBOX_EXT_VERSION=$(echo "$VBOX_FULL_VERSION" | sed 's/r/-/')
    
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
    
    # Function to check if URL exists
    check_url_exists() {
        local url=$1
        
        # Try with wget --spider
        if wget --spider --header="Accept: */*" \
               --header="User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
               "$url" 2>/dev/null; then
            return 0
        fi
        
        # Alternative: use curl if available
        if command -v curl &> /dev/null; then
            if curl -s -f -o /dev/null -I \
                   -H "Accept: */*" \
                   -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
                   "$url" 2>/dev/null; then
                return 0
            fi
        fi
        
        return 1
    }
    
    # Try to discover the Extension Pack version by checking the directory
    echo "Discovering available Extension Pack version..."
    
    # First, try the exact version match
    EXT_PACK_URL="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/Oracle_VM_VirtualBox_Extension_Pack-${VBOX_EXT_VERSION}.vbox-extpack"
    echo "Attempting to download Extension Pack from: $EXT_PACK_URL"
    
    if download_file "$EXT_PACK_URL" "$EXT_PACK_FILE"; then
        echo "Successfully downloaded Extension Pack"
    else
        # Try variations: check if Extension Pack revision differs from main version
        echo "Trying to find compatible Extension Pack version..."
        
        # Try a few revision number variations (sometimes Extension Pack has different revision)
        if [ -n "$VBOX_REVISION" ] && [ "$VBOX_REVISION" -eq "$VBOX_REVISION" ] 2>/dev/null; then
            for rev_offset in 0 -1 -2 -3 1 2 3; do
                test_rev=$((VBOX_REVISION + rev_offset))
                test_ext_version="${VBOX_VERSION}-${test_rev}"
                test_url="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/Oracle_VM_VirtualBox_Extension_Pack-${test_ext_version}.vbox-extpack"
                
                if check_url_exists "$test_url"; then
                    echo "Found Extension Pack at: $test_url"
                    if download_file "$test_url" "$EXT_PACK_FILE"; then
                        echo "Successfully downloaded Extension Pack"
                        break
                    fi
                fi
            done
        fi
        
        # If still not found, try base version only
        if [ ! -f "$EXT_PACK_FILE" ] || [ ! -s "$EXT_PACK_FILE" ]; then
            echo "Trying with base version only..."
            EXT_PACK_URL="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/Oracle_VM_VirtualBox_Extension_Pack-${VBOX_VERSION}.vbox-extpack"
            if ! download_file "$EXT_PACK_URL" "$EXT_PACK_FILE"; then
                echo "Error: Could not download VirtualBox Extension Pack automatically."
                echo "VirtualBox version: $VBOX_FULL_VERSION"
                echo "Please download the Extension Pack manually from:"
                echo "  https://www.virtualbox.org/wiki/Downloads"
                echo "  Or check: https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/"
                return 1
            fi
        fi
    fi
    
    # Verify the file was downloaded successfully
    if [ ! -f "$EXT_PACK_FILE" ] || [ ! -s "$EXT_PACK_FILE" ]; then
        echo "Error: Extension Pack file is missing or empty after download attempt."
        return 1
    fi
    
    # Install the Extension Pack
    echo "y" | sudo VBoxManage extpack install --replace "$EXT_PACK_FILE"
    
    # Clean up
    rm -f "$EXT_PACK_FILE"
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
    
    # Download the ISO (uses base version in filename)
    GA_ISO_URL="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_FULL_VERSION}.iso"
    GA_ISO_FILE="$HOME/VirtualBox VMs/VirtualBox Guest Additions/VBoxGuestAdditions_${VBOX_FULL_VERSION}.iso"
    
    if ! download_file "$GA_ISO_URL" "$GA_ISO_FILE"; then
        # Fallback: try with base version only
        GA_ISO_URL="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso"
        GA_ISO_FILE="$HOME/VirtualBox VMs/VirtualBox Guest Additions/VBoxGuestAdditions_${VBOX_VERSION}.iso"
        download_file "$GA_ISO_URL" "$GA_ISO_FILE"
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
