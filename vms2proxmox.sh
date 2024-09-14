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
check_and_install whiptail
check_and_install tar

# Check for qemu-img without installing qemu-utils
if ! command -v qemu-img &> /dev/null; then
    whiptail --msgbox "qemu-img is not found. Please ensure QEMU tools are properly installed on your Proxmox system." 10 60
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

# Function to get the next available VMID
get_next_vmid() {
    local vmid=100
    while qm status $vmid &>/dev/null; do
        ((vmid++))
    done
    echo $vmid
}

# Get Proxmox storages and node
PROXMOX_STORAGES=($(get_proxmox_storages))
PROXMOX_NODE=$(get_proxmox_node)

# Display available storages and ask user to choose
STORAGE_OPTIONS=()
for i in "${!PROXMOX_STORAGES[@]}"; do
    STORAGE_OPTIONS+=("$i" "${PROXMOX_STORAGES[$i]}")
done
STORAGE_CHOICE=$(whiptail --title "Proxmox Storage Selection" --menu "Choose a Proxmox storage:" 20 60 10 "${STORAGE_OPTIONS[@]}" 3>&1 1>&2 2>&3)
PROXMOX_STORAGE="${PROXMOX_STORAGES[$STORAGE_CHOICE]}"

# Display available VMs and ask user to choose
VM_FILES=($(find "$SOURCE_DIR" -maxdepth 1 \( -name "*.ova" -o -name "*.vmdk" -o -type d \) -printf '%f\n'))
VM_OPTIONS=()
for i in "${!VM_FILES[@]}"; do
    VM_OPTIONS+=("$i" "${VM_FILES[$i]}")
done
VM_CHOICE=$(whiptail --title "VM Selection" --menu "Choose a VM to convert and import:" 20 60 10 "${VM_OPTIONS[@]}" 3>&1 1>&2 2>&3)
SELECTED_VM="${VM_FILES[$VM_CHOICE]}"

# Function to convert and import a VM
convert_and_import_vm() {
    # ... (previous code remains the same)

    # Convert VMDK or VDI to QCOW2 format
    for DISK in $(grep "<File" "$OVF_FILE" | sed -n 's/.*ovf:href="\(.*\)".*/\1/p'); do
        DISK_PATH="$VM_PATH/$DISK"
        QCOW2_DISK="$VM_PATH/${DISK%.*}.qcow2"
        
        echo "Converting $DISK_PATH to $QCOW2_DISK"
        qemu-img convert -O qcow2 "$DISK_PATH" "$QCOW2_DISK"
        
        # Import the converted disk to Proxmox
        if ! qm importdisk "$VMID" "$QCOW2_DISK" "$PROXMOX_STORAGE" -format qcow2; then
            ERROR_LOG=$(tail -n 20 /var/log/pve/pveproxy.log)
            whiptail --msgbox "Failed to import disk for VM $VM_NAME (VMID: $VMID). Here are the last 20 lines of the Proxmox log:\n\n$ERROR_LOG" 20 76
            return
        fi
    done
    
    # Create the VM in Proxmox using the OVF settings
    echo "Creating VM in Proxmox..."
    if ! qm create "$VMID" --name "$VM_NAME" --ostype other --machine q35 --scsihw virtio-scsi-pci --bootdisk scsi0 --scsi0 "$PROXMOX_STORAGE:vm-$VMID-disk-0"; then
        ERROR_LOG=$(tail -n 20 /var/log/pve/pveproxy.log)
        whiptail --msgbox "Failed to create VM $VM_NAME (VMID: $VMID) in Proxmox. Here are the last 20 lines of the Proxmox log:\n\n$ERROR_LOG" 20 76
        return
    fi
    
    # Clean up temporary directory if used
    if [[ -n "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    whiptail --msgbox "VM $VM_NAME (VMID: $VMID) imported successfully!" 10 60
}
    
    echo "Found OVF file: $OVF_FILE"
    
    # Convert VMDK or VDI to QCOW2 format
    for DISK in $(grep "<File" "$OVF_FILE" | sed -n 's/.*ovf:href="\(.*\)".*/\1/p'); do
        DISK_PATH="$VM_PATH/$DISK"
        QCOW2_DISK="$VM_PATH/${DISK%.*}.qcow2"
        
        echo "Converting $DISK_PATH to $QCOW2_DISK"
        qemu-img convert -O qcow2 "$DISK_PATH" "$QCOW2_DISK"
        
        # Import the converted disk to Proxmox
        if ! qm importdisk "$VMID" "$QCOW2_DISK" "$PROXMOX_STORAGE" -format qcow2; then
            whiptail --msgbox "Failed to import disk for VM $VM_NAME (VMID: $VMID). Please check Proxmox logs for more information." 10 60
            return
        fi
    done
    
    # Create the VM in Proxmox using the OVF settings
    echo "Creating VM in Proxmox..."
    if ! qm create "$VMID" --name "$VM_NAME" --ostype other --machine q35 --scsihw virtio-scsi-pci --bootdisk scsi0 --scsi0 "$PROXMOX_STORAGE:vm-$VMID-disk-0"; then
        whiptail --msgbox "Failed to create VM $VM_NAME (VMID: $VMID) in Proxmox. Please check Proxmox logs for more information." 10 60
        return
    fi
    
    # Clean up temporary directory if used
    if [[ -n "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    whiptail --msgbox "VM $VM_NAME (VMID: $VMID) imported successfully!" 10 60
}

# Confirm settings with the user
if whiptail --yesno "Please confirm the following settings:\n\nSource directory: $SOURCE_DIR\nSelected VM: $SELECTED_VM\nProxmox storage: $PROXMOX_STORAGE\nProxmox node: $PROXMOX_NODE" 20 60; then
    convert_and_import_vm
else
    whiptail --msgbox "Please run the script again with the correct settings." 10 60
    exit 1
fi
