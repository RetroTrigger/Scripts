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
        "arch" | "manjaro" | "endeavouros" | "garuda" )
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
        "arch" | "manjaro" | "endeavouros" | "garuda" )
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
    
    # Get the latest version number
    VBOX_VERSION=$(VBoxManage --version | cut -d'r' -f1)
    
    # Download the Extension Pack
    wget https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/Oracle_VM_VirtualBox_Extension_Pack-${VBOX_VERSION}.vbox-extpack -O /tmp/Oracle_VM_VirtualBox_Extension_Pack.vbox-extpack
    
    # Install the Extension Pack
    echo "y" | sudo VBoxManage extpack install --replace /tmp/Oracle_VM_VirtualBox_Extension_Pack.vbox-extpack
    
    # Clean up
    rm /tmp/Oracle_VM_VirtualBox_Extension_Pack.vbox-extpack
}

# Function to download Guest Additions ISO
download_guest_additions() {
    echo "Downloading VirtualBox Guest Additions ISO..."
    
    # Get the latest version number
    VBOX_VERSION=$(VBoxManage --version | cut -d'r' -f1)
    
    # Create directory for Guest Additions if it doesn't exist
    mkdir -p ~/VirtualBox\ VMs/VirtualBox\ Guest\ Additions
    
    # Download the ISO
    wget https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso -O ~/VirtualBox\ VMs/VirtualBox\ Guest\ Additions/VBoxGuestAdditions_${VBOX_VERSION}.iso
    
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
