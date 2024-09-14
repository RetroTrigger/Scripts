#!/bin/bash

set -e

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
    while qm status $vmid &>/dev/null || pct status $vmid &>/dev/null; do
        ((vmid++))
    done
    echo $vmid
}

# Function to convert and import a VM
convert_and_import_vm() {
    VM_PATH="$SOURCE_DIR/$SELECTED_VM"
    VM_NAME="${SELECTED_VM%.*}"
    VMID=$(get_next_vmid)
    
    echo "Processing VM: $VM_NAME (VMID: $VMID)"
    echo "VM Path: $VM_PATH"
    
    if [[ $SELECTED_VM == *.ova ]]; then
        echo "Checking OVA file integrity..."
        if ! tar -tf "$VM_PATH" &>/dev/null; then
            whiptail --msgbox "The OVA file appears to be corrupted or incomplete. Please check the file and try again." 10 60
            return 1
        fi
        echo "Extracting OVA file..."
        TEMP_DIR=$(mktemp -d)
        tar -xvf "$VM_PATH" -C "$TEMP_DIR"
        OVF_FILE=$(find "$TEMP_DIR" -name "*.ovf" | head -n 1)
        VM_PATH="$TEMP_DIR"
    elif [[ $SELECTED_VM == *.vmdk ]]; then
        echo "Creating temporary OVF for VMDK..."
        TEMP_DIR=$(mktemp -d)
        cp "$VM_PATH" "$TEMP_DIR/"
        OVF_FILE="$TEMP_DIR/temp.ovf"
        echo "<Envelope><References><File ovf:href=\"$(basename "$VM_PATH")\"/></References></Envelope>" > "$OVF_FILE"
        VM_PATH="$TEMP_DIR"
    else
        echo "Treating as directory containing disk images..."
        if [[ -d "$VM_PATH" ]]; then
            DISK_FILES=($(find "$VM_PATH" -type f -name "*.vmdk"))
            if [[ ${#DISK_FILES[@]} -eq 0 ]]; then
                whiptail --msgbox "No VMDK files found in $VM_PATH" 10 60
                return 1
            fi
        else
            whiptail --msgbox "Invalid VM path: $VM_PATH" 10 60
            return 1
        fi
    fi
    
    if [[ -n "$OVF_FILE" ]]; then
        DISK_FILES=($(grep "<File" "$OVF_FILE" | sed -n 's/.*ovf:href="\(.*\)".*/\1/p'))
    fi
    
    echo "Found disk files: ${DISK_FILES[*]}"
    
    # Create the VM in Proxmox first
    echo "Creating VM in Proxmox..."
    if ! qm create "$VMID" --name "$VM_NAME" --ostype l26 --memory 2048 --cores 2 --net0 e1000,bridge=vmbr0; then
        echo "Failed to create VM. Command output:"
        qm create "$VMID" --name "$VM_NAME" --ostype l26 --memory 2048 --cores 2 --net0 e1000,bridge=vmbr0
        whiptail --msgbox "Failed to create VM $VM_NAME (VMID: $VMID) in Proxmox. Please check the output above for more information." 10 60
        return 1
    fi
    
    echo "Debug: DISK_FILES contents:"
    for debug_disk in "${DISK_FILES[@]}"; do
        echo "  $debug_disk"
    done
    
    for DISK in "${DISK_FILES[@]}"; do
        DISK_PATH="$VM_PATH/$DISK"
        QCOW2_DISK="${DISK_PATH%.*}.qcow2"
        
        echo "Converting $DISK_PATH to $QCOW2_DISK"
        if ! qemu-img convert -O qcow2 "$DISK_PATH" "$QCOW2_DISK"; then
            echo "Failed to convert disk. Command output:"
            qemu-img convert -O qcow2 "$DISK_PATH" "$QCOW2_DISK"
            whiptail --msgbox "Failed to convert disk for VM $VM_NAME (VMID: $VMID). Please check the output above for more information." 10 60
            return 1
        fi
        
        # Import the converted disk to Proxmox
        echo "Importing disk to Proxmox..."
        IMPORT_OUTPUT=$(qm importdisk "$VMID" "$QCOW2_DISK" "$PROXMOX_STORAGE" -format qcow2)
        if [[ $? -ne 0 ]]; then
            echo "Failed to import disk. Command output:"
            echo "$IMPORT_OUTPUT"
            whiptail --msgbox "Failed to import disk for VM $VM_NAME (VMID: $VMID). Please check the output above for more information." 10 60
            return 1
        fi

        # Extract the imported disk name from the output
        IMPORTED_DISK=$(echo "$IMPORT_OUTPUT" | grep -oP "(?<=as ').*(?=')")
        if [[ -z "$IMPORTED_DISK" ]]; then
            whiptail --msgbox "Failed to extract imported disk name for VM $VM_NAME (VMID: $VMID)." 10 60
            return 1
        fi

        # Attach the imported disk to the VM
        echo "Attaching imported disk to VM..."
        if ! qm set "$VMID" --scsi0 "$IMPORTED_DISK"; then
            echo "Failed to attach disk. Command output:"
            qm set "$VMID" --scsi0 "$IMPORTED_DISK"
            whiptail --msgbox "Failed to attach disk to VM $VM_NAME (VMID: $VMID). Please check the output above for more information." 10 60
            return 1
        fi

        # Set the boot order
        echo "Setting boot order..."
        if ! qm set "$VMID" --boot c --bootdisk scsi0; then
            echo "Failed to set boot order. Command output:"
            qm set "$VMID" --boot c --bootdisk scsi0
            whiptail --msgbox "Failed to set boot order for VM $VM_NAME (VMID: $VMID). Please check the output above for more information." 10 60
            return 1
        fi
    done
    
    # Clean up temporary directory if used
    if [[ -n "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    whiptail --msgbox "VM $VM_NAME (VMID: $VMID) imported successfully!" 10 60
    return 0
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

# Confirm settings with the user
if whiptail --yesno "Please confirm the following settings:\n\nSource directory: $SOURCE_DIR\nSelected VM: $SELECTED_VM\nProxmox storage: $PROXMOX_STORAGE\nProxmox node: $PROXMOX_NODE" 20 60; then
    if convert_and_import_vm; then
        echo "VM import completed successfully."
    else
        echo "VM import failed. Please check the error messages above."
    fi
else
    whiptail --msgbox "Please run the script again with the correct settings." 10 60
    exit 1
fi