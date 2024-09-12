#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    SUDO="sudo"
else
    SUDO=""
fi

# Variables
TEMPLATE_DIR="/var/lib/vz/template/imported_templates"
EXPORT_ENTRY="$TEMPLATE_DIR *(rw,sync,no_subtree_check,no_root_squash)"
STORAGE="local-lvm"  # Proxmox storage to use

# Function to check and install NFS utilities
install_nfs_utilities() {
    if ! command -v exportfs &> /dev/null; then
        echo "NFS utilities are not installed. Installing NFS utilities..."

        # Check if the system is Debian-based or Red Hat-based
        if [ -f /etc/debian_version ]; then
            $SUDO apt update
            $SUDO apt install -y nfs-kernel-server
        elif [ -f /etc/redhat-release ]; then
            $SUDO yum install -y nfs-utils
        else
            echo "Unsupported operating system. Please install the NFS utilities manually."
            exit 1
        fi
    else
        echo "NFS utilities are already installed."
    fi

    echo "Starting and enabling NFS server..."
    $SUDO systemctl start nfs-kernel-server
    $SUDO systemctl enable nfs-kernel-server
}

# Ensure NFS utilities are installed before proceeding
install_nfs_utilities

# Create and share the folder
mkdir -p $TEMPLATE_DIR
chmod 775 $TEMPLATE_DIR

# Remove any previous instances of the export entry to avoid duplicates
$SUDO sed -i "\|${TEMPLATE_DIR}|d" /etc/exports

# Add the export entry if it doesn't already exist
if ! grep -qF "$EXPORT_ENTRY" /etc/exports; then
    echo "$EXPORT_ENTRY" | $SUDO tee -a /etc/exports > /dev/null
fi

# Refresh NFS exports
$SUDO exportfs -ra
$SUDO systemctl restart nfs-kernel-server

# Confirm script execution before presenting the menu
echo "NFS configuration is complete. Proceeding to the menu..."
read -p "Press Enter to continue..."

# Main menu using 'select'
PS3='Please enter your choice: '
options=("Convert and create VM" "Download VulnHub template" "Manage VMs" "Exit")
select opt in "${options[@]}"
do
    case $opt in
        "Convert and create VM")
            read -p "Enter VM ID: " VMID
            read -p "Enter VM name: " VM_NAME
            read -p "Enter path to template file: " TEMPLATE_FILE
            read -p "Enter storage type (1 for LVM-Thin, 2 for Directory): " STORAGE_TYPE
            convert_and_create_vm $VMID $VM_NAME $TEMPLATE_FILE $STORAGE_TYPE
            ;;
        "Download VulnHub template")
            download_vuln
            ;;
        "Manage VMs")
            manage_vms
            ;;
        "Exit")
            echo "Exiting..."
            break
            ;;
        *) echo "Invalid option $REPLY";;
    esac
done
