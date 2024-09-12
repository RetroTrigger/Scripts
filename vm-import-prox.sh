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

# Alternative Menu Using read and Case
while true; do
    echo "1) Convert and create VM"
   
