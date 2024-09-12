#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    SUDO="sudo"
else
    SUDO=""
fi

# Variables
TEMPLATE_DIR="/var/lib/vz/template/imported_templates"
NETWORK_SHARE="/mnt/templates"
STORAGE="local-lvm"  # Proxmox storage to use

# Function to check and install NFS utilities
install_nfs_utilities() {
    if ! command -v exportfs &> /dev/null; then
        echo "NFS utilities are not installed. Installing NFS utilities..."

        # Check if the system is Debian-based or Red Hat-based
        if [ -f /etc/debian_version ]; then
            # Removing non-interactive flag to allow interaction
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

# Share the folder via NFS
echo "$TEMPLATE_DIR *(rw,sync,no_root_squash)" | $SUDO tee -a /etc/exports
$SUDO exportfs -a
$SUDO systemctl restart nfs-kernel-server

# Function to convert OVA/VMDK files and create a VM
convert_and_create_vm() {
    VMID=$1
    VM_NAME=$2
    TEMPLATE_FILE="$3"
    STORAGE_TYPE=$4

    echo "Converting and creating VM with ID $VMID and name $VM_NAME..."

    if [[ $TEMPLATE_FILE == *.ova ]]; then
        echo "Converting OVA file..."
        qm importovf $VMID $TEMPLATE_FILE $STORAGE --format qcow2
    elif [[ $TEMPLATE_FILE == *.vmdk ]]; then
        echo "Converting VMDK file..."
        qm importdisk $VMID $TEMPLATE_FILE $STORAGE --format qcow2
        qm set $VMID --scsihw virtio-scsi-pci --scsi0 $STORAGE:vm-$VMID-disk-0
    else
        echo "Unsupported file type: $TEMPLATE_FILE"
        return 1
    fi

    # Configure the VM
    qm create $VMID --name $VM_NAME --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
    qm set $VMID --boot c --bootdisk scsi0 --serial0 socket --vga serial0

    # Start the VM
    qm start $VMID
    echo "VM $VM_NAME with ID $VMID has been created and started."
}

# Function to download VulnHub templates (optional)
download_vuln() {
    read -p "Enter the download link: " LINK
    echo "Downloading template from $LINK..."
    wget $LINK -P $TEMPLATE_DIR
    tar -xvf $TEMPLATE_DIR/$(basename $LINK) -C $TEMPLATE_DIR
    echo "Template downloaded and extracted to $TEMPLATE_DIR."
}

# Function to manage VMs
manage_vms() {
    echo "1) Start VM"
    echo "2) Stop VM"
    echo "3) Destroy VM"
    read -p "Choose an action: " ACTION
    read -p "Enter the VM ID: " VMID

    case $ACTION in
        1)
            qm start $VMID
            echo "VM $VMID started."
            ;;
        2)
            qm stop $VMID
            echo "VM $VMID stopped."
            ;;
        3)
            qm destroy $VMID
            echo "VM $VMID destroyed."
            ;;
        *)
            echo "Invalid action."
            ;;
    esac
}

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
