#!/bin/bash

set -e

echo "Updating and upgrading the system..."
apt update && apt full-upgrade -y

# Function to check and install dependencies
check_and_install() {
    if ! command -v "$1" &> /dev/null; then
        echo "$1 is not installed. Installing..."
        apt-get update && apt-get install -y "$1" || {
            echo "Failed to install $1. Please install it manually."
            exit 1
        }
    fi
}

# Check and install dependencies
check_and_install jq

# Check for qemu-img without installing qemu-utils
if ! command -v qemu-img &> /dev/null; then
    echo "qemu-img is not found. Please ensure QEMU tools are properly installed on your Proxmox system."
    exit 1
fi

# Set the permanent source directory
SOURCE_DIR="/srv/samba/vm_temps"

# Function to get available Proxmox storages
get_proxmox_storages() {
    pvesh get storage --output-format=json | jq -r '.[].storage'
}

# Function to get Proxmox node name
get_proxmox_node() {
    pvesh get nodes --output-format=json | jq -r '.[0].node'
}

# Get Proxmox storages and node
PROXMOX_STORAGES=($(get_proxmox_storages))
PROXMOX_NODE=$(get_proxmox_node)

# Display available storages and ask user to choose
echo "Available Proxmox storages:"
for i in "${!PROXMOX_STORAGES[@]}"; do
    echo "$((i+1)). ${PROXMOX_STORAGES[$i]}"
done

read -p "Enter the number of the Proxmox storage to use: " STORAGE_CHOICE
PROXMOX_STORAGE="${PROXMOX_STORAGES[$((STORAGE_CHOICE-1))]}"

# Display available VMs and ask user to choose
echo "Available VMs in $SOURCE_DIR:"
VM_DIRS=($(find "$SOURCE_DIR" -maxdepth 1 -type d -printf '%f\n' | tail -n +2))
for i in "${!VM_DIRS[@]}"; do
    echo "$((i+1)). ${VM_DIRS[$i]}"
done

read -p "Enter the number of the VM to convert and import: " VM_CHOICE
SELECTED_VM="${VM_DIRS[$((VM_CHOICE-1))]}"

# Function to convert and import a VM
convert_and_import_vm() {
    VM_PATH="$SOURCE_DIR/$SELECTED_VM"
    VM_NAME="$SELECTED_VM"
    
    echo "Processing VM: $VM_NAME"
    
    # Extract the OVF file
    OVF_FILE=$(find "$VM_PATH" -name "*.ovf" | head -n 1)
    if [ -z "$OVF_FILE" ]; then
        echo "No OVF file found in $VM_PATH, skipping..."
        return
    fi
    
    echo "Found OVF file: $OVF_FILE"
    
    # Convert VMDK or VDI to QCOW2 format
    for DISK in $(grep "<File" "$OVF_FILE" | sed -n 's/.*ovf:href="\(.*\)".*/\1/p'); do
        DISK_PATH="$VM_PATH/$DISK"
        QCOW2_DISK="$VM_PATH/${DISK%.*}.qcow2"
        
        echo "Converting $DISK_PATH to $QCOW2_DISK"
        qemu-img convert -O qcow2 "$DISK_PATH" "$QCOW2_DISK"
        
        # Import the converted disk to Proxmox
        qm importdisk "$VM_NAME" "$QCOW2_DISK" "$PROXMOX_STORAGE" -format qcow2
    done
    
    # Create the VM in Proxmox using the OVF settings
    echo "Creating VM in Proxmox..."
    qm create "$VM_NAME" --name "$VM_NAME" --ostype other --machine q35 --scsihw virtio-scsi-pci --bootdisk scsi0 --scsi0 "$PROXMOX_STORAGE:vm-$VM_NAME-disk-0"
    
    echo "VM $VM_NAME imported successfully!"
}

# Confirm settings with the user
echo "Please confirm the following settings:"
echo "Source directory: $SOURCE_DIR"
echo "Selected VM: $SELECTED_VM"
echo "Proxmox storage: $PROXMOX_STORAGE"
echo "Proxmox node: $PROXMOX_NODE"
read -p "Are these settings correct? (y/n): " CONFIRM

if [[ $CONFIRM =~ ^[Yy]$ ]]; then
    convert_and_import_vm
else
    echo "Please run the script again with the correct settings."
    exit 1
fi
