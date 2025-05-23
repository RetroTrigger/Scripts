#!/bin/bash

# ==========================
# Configuration
# ==========================
MOUNT_ROOT="/mnt/nas"
SYSTEMD_DIR="/etc/systemd/system"
EXPORTS_FILE="/etc/exports"
NFS_SHARES=(
  "10.0.0.2:/volume1/backups"
  "10.0.0.2:/volume1/media"
  "10.0.0.3:/data/projects"
  "10.0.0.4:/exports/iso"
)

# ==========================
# Utility Functions
# ==========================
sanitize() {
  echo "$1" | sed 's|[/:]|-|g'
}

check_nfs_server() {
  if ! command -v exportfs &> /dev/null; then
    echo "NFS server tools not found. Installing nfs-kernel-server..."
    if command -v apt-get &> /dev/null; then
      sudo apt-get update
      sudo apt-get install -y nfs-kernel-server
    elif command -v yum &> /dev/null; then
      sudo yum install -y nfs-utils
    elif command -v dnf &> /dev/null; then
      sudo dnf install -y nfs-utils
    else
      echo "Could not detect package manager. Please install NFS server tools manually."
      exit 1
    fi
  fi
}

# ==========================
# NFS Share Creation
# ==========================
create_nfs_share() {
  local share_path
  local client_ip
  local permissions
  
  # Get share path
  while true; do
    share_path=$(whiptail --inputbox "Enter the absolute path to share:" 10 60 3>&1 1>&2 2>&3) || return 1
    if [ -z "$share_path" ]; then
      whiptail --msgbox "Share path cannot be empty." 10 50
    elif [ ! -d "$share_path" ]; then
      if whiptail --yesno "Directory $share_path does not exist. Create it?" 10 60; then
        sudo mkdir -p "$share_path"
        break
      fi
    else
      break
    fi
  done
  
  # Get client IP or network
  client_ip=$(whiptail --inputbox "Enter client IP or network (e.g., 192.168.1.0/24):" 10 60 3>&1 1>&2 2>&3) || return 1
  
  # Get permissions
  permissions=$(whiptail --menu "Select share permissions:" 15 40 5 \
    "ro" "Read-only" \
    "rw" "Read/Write" \
    "ro,sync" "Read-only with sync" \
    "rw,sync" "Read/Write with sync" \
    "ro,async" "Read-only with async (faster)" 3>&1 1>&2 2>&3) || return 1
  
  # Add to exports
  local export_line="$share_path $client_ip($permissions,no_subtree_check)"
  
  # Check if entry already exists
  if grep -q "^$share_path" "$EXPORTS_FILE"; then
    whiptail --msgbox "An entry for $share_path already exists in $EXPORTS_FILE" 10 60
    return 1
  fi
  
  # Add to exports file
  echo "$export_line" | sudo tee -a "$EXPORTS_FILE" > /dev/null
  
  # Apply changes
  sudo exportfs -a
  sudo systemctl restart nfs-kernel-server
  
  whiptail --msgbox "NFS share created successfully!\n\nShare: $share_path\nAccess: $client_ip\nPermissions: $permissions" 12 60
}

# ==========================
# NFS Mount Management
# ==========================
manage_mounts() {
  # Show only shares not already mounted
  AVAILABLE_SHARES=()
  for SHARE in "${NFS_SHARES[@]}"; do
    SAFE_NAME=$(sanitize "$SHARE")
    UNIT_FILE="$SYSTEMD_DIR/mnt-nas-${SAFE_NAME}.mount"
    [[ ! -f "$UNIT_FILE" ]] && AVAILABLE_SHARES+=("$SHARE" "" "OFF")
  done

  if [ "${#AVAILABLE_SHARES[@]}" -gt 0 ]; then
    SELECTED=$(whiptail --title "Select NFS Shares to Mount" \
      --checklist "Pick shares to mount:" 20 78 10 \
      "${AVAILABLE_SHARES[@]}" 3>&1 1>&2 2>&3)

    if [ $? -eq 0 ] && [ -n "$SELECTED" ]; then
      for SHARE in $SELECTED; do
        SHARE=$(echo "$SHARE" | tr -d '"')
        SAFE_NAME=$(sanitize "$SHARE")
        MOUNT_PATH="$MOUNT_ROOT/$SAFE_NAME"
        UNIT_NAME="mnt-nas-${SAFE_NAME}.mount"
        AUTO_NAME="mnt-nas-${SAFE_NAME}.automount"

        sudo mkdir -p "$MOUNT_PATH"

        cat | sudo tee "$SYSTEMD_DIR/$UNIT_NAME" > /dev/null <<EOF
[Unit]
Description=NFS Mount - $SHARE
After=network-online.target
Wants=network-online.target

[Mount]
What=$SHARE
Where=$MOUNT_PATH
Type=nfs
Options=defaults,nfsvers=3,_netdev
TimeoutSec=30

[Install]
WantedBy=multi-user.target
EOF

        cat | sudo tee "$SYSTEMD_DIR/$AUTO_NAME" > /dev/null <<EOF
[Unit]
Description=AutoMount - $SHARE
After=network-online.target
Wants=network-online.target

[Automount]
Where=$MOUNT_PATH
TimeoutIdleSec=600

[Install]
WantedBy=multi-user.target
EOF

        sudo systemctl daemon-reload
        sudo systemctl enable --now "$AUTO_NAME"
        echo "✅ Mounted $SHARE at $MOUNT_PATH"
      done
    fi
  else
    whiptail --msgbox "All configured shares are already mounted." 10 50
  fi

  # Offer to remove mounts
  MOUNTED_UNITS=($(find "$SYSTEMD_DIR" -name "mnt-nas-*.mount" -printf "%f\n" 2>/dev/null))

  if [ "${#MOUNTED_UNITS[@]}" -gt 0 ]; then
    CHECKLIST=()
    for UNIT in "${MOUNTED_UNITS[@]}"; do
      NAME="${UNIT%.mount}"
      DESC=$(grep Description "$SYSTEMD_DIR/$UNIT" | cut -d' ' -f2-)
      CHECKLIST+=("$NAME" "$DESC" "OFF")
    done

    TO_REMOVE=$(whiptail --title "Select Mounts to Remove" \
      --checklist "Pick mounted NFS shares to remove:" 20 78 10 \
      "${CHECKLIST[@]}" 3>&1 1>&2 2>&3)

    if [ $? -eq 0 ] && [ -n "$TO_REMOVE" ]; then
      for NAME in $TO_REMOVE; do
        NAME=$(echo "$NAME" | tr -d '"')
        sudo systemctl disable --now "$NAME.mount" "$NAME.automount"
        sudo rm -f "$SYSTEMD_DIR/$NAME.mount" "$SYSTEMD_DIR/$NAME.automount"
        echo "❌ Removed $NAME"
      done
      sudo systemctl daemon-reexec
      sudo systemctl daemon-reload
    fi
  fi
}

# ==========================
# Main Menu
# ==========================
main_menu() {
  while true; do
    choice=$(whiptail --title "NFS Share Manager" --menu "Choose an option:" 15 60 5 \
      "1" "Mount NFS Shares" \
      "2" "Create NFS Share" \
      "3" "View Current Exports" \
      "4" "Exit" 3>&1 1>&2 2>&3)
    
    case $choice in
      1)
        manage_mounts
        ;;
      2)
        check_nfs_server
        create_nfs_share
        ;;
      3)
        whiptail --title "Current NFS Exports" --textbox "$EXPORTS_FILE" 20 80 --scrolltext
        ;;
      4|*)
        echo "Exiting NFS Share Manager"
        exit 0
        ;;
    esac
  done
}

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

# Create mount root if it doesn't exist
sudo mkdir -p "$MOUNT_ROOT"

# Start the main menu
main_menu
