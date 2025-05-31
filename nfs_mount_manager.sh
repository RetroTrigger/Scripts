#!/bin/bash

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use 'sudo $0'"
  exit 1
fi

# ==========================
# Configuration
# ==========================
MOUNT_ROOT="/mnt/nas"
SYSTEMD_DIR="/etc/systemd/system"
EXPORTS_FILE="/etc/exports"
NFS_SHARES=(
  "192.168.0.180:/volume1/Media"
  "192.168.0.180:/volume1/Proxmox_Backups"
  "192.168.0.7:/home/geremy/test_share"
)

# ==========================
# Utility Functions
# ==========================
sanitize() {
  # Convert slashes to single dashes, following systemd unit naming convention
  echo "$1" | sed 's|/|-|g' | sed 's|:|-|g' | sed 's|--|-|g'
}

# Function to convert mount path to systemd unit name format
path_to_unit_name() {
  local path="$1"
  # This must follow systemd's exact escaping rules:
  # 1. Remove leading slash
  # 2. Replace all slashes with single dashes
  # 3. Escape other special characters
  echo "$path" | sed 's|^/||' | sed 's|/|-|g' | sed 's|\.|\\.|g'
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
  local server_hostname
  local shares_list_file="/root/nfs_shares_list.txt"
  
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
  
  # Get server hostname for the share
  server_hostname=$(hostname -I | awk '{print $1}')
  if [ -z "$server_hostname" ]; then
    server_hostname=$(hostname)
  fi
  
  # Create the full share path in NFS format
  local full_share="$server_hostname:$share_path"
  
  # Add to shares list file
  echo "# To add this share to the NFS_SHARES array in the script, add the following line:" | sudo tee -a "$shares_list_file" > /dev/null
  echo "  \"$full_share\"" | sudo tee -a "$shares_list_file" > /dev/null
  echo "# Share created on $(date)" | sudo tee -a "$shares_list_file" > /dev/null
  echo "# --------------------------------------------------" | sudo tee -a "$shares_list_file" > /dev/null
  
  # Apply changes
  sudo exportfs -a
  sudo systemctl restart nfs-kernel-server
  
  whiptail --msgbox "NFS share created successfully!\n\nShare: $share_path\nAccess: $client_ip\nPermissions: $permissions\n\nShare information has been added to $shares_list_file" 15 70
}

# ==========================
# NFS Mount Management
# ==========================
manage_mounts() {
  # Check if nfs-common is installed
  if ! command -v mount.nfs &> /dev/null; then
    whiptail --msgbox "NFS client tools not found. Installing nfs-common..." 10 60
    apt-get update
    apt-get install -y nfs-common
  fi

  # Prepare list of available shares
  AVAILABLE_SHARES=()
  MOUNTED_SHARES=()
  
  for SHARE in "${NFS_SHARES[@]}"; do
    # Create a proper directory name for the mountpoint
    SAFE_NAME=$(sanitize "$SHARE")
    MOUNT_PATH="$MOUNT_ROOT/$SAFE_NAME"
    
    # Use simplified unit naming
    MOUNT_UNIT="mnt-nas-$SAFE_NAME.mount"
    AUTO_UNIT="mnt-nas-$SAFE_NAME.automount"
    
    # Check if already mounted
    if mountpoint -q "$MOUNT_PATH" 2>/dev/null; then
      MOUNTED_SHARES+=("$SHARE" "Currently mounted at $MOUNT_PATH" "OFF")
    # Check if systemd unit exists but not mounted
    elif [ -f "$SYSTEMD_DIR/$MOUNT_UNIT" ] || [ -f "$SYSTEMD_DIR/$AUTO_UNIT" ]; then
      AVAILABLE_SHARES+=("$SHARE" "Configured but not mounted" "ON")
    else
      AVAILABLE_SHARES+=("$SHARE" "Not configured" "OFF")
    fi
  done
  
  # Display mounted shares if any
  if [ "${#MOUNTED_SHARES[@]}" -gt 0 ]; then
    whiptail --title "Currently Mounted NFS Shares" --msgbox "The following shares are already mounted:\n\n$(for s in "${MOUNTED_SHARES[@]}"; do echo "- $s"; done | grep -v OFF)" 15 70
  fi

  if [ "${#AVAILABLE_SHARES[@]}" -gt 0 ]; then
    SELECTED=$(whiptail --title "Select NFS Shares to Mount" \
      --checklist "Pick shares to mount:" 20 78 10 \
      "${AVAILABLE_SHARES[@]}" 3>&1 1>&2 2>&3)

    if [ $? -eq 0 ] && [ -n "$SELECTED" ]; then
      for SHARE in $SELECTED; do
        SHARE=$(echo "$SHARE" | tr -d '"')
        
        # Create a proper directory name (can contain multiple dashes)
        DIR_NAME=$(sanitize "$SHARE")
        MOUNT_PATH="$MOUNT_ROOT/$DIR_NAME"
        
        # Create systemd unit names that follow the convention
        # Unit name must match the mount point path with slashes replaced by dashes
        UNIT_PATH=$(path_to_unit_name "$MOUNT_PATH")
        UNIT_NAME="$UNIT_PATH.mount"
        AUTO_NAME="$UNIT_PATH.automount"

        # Create mount directory if it doesn't exist
        if [ ! -d "$MOUNT_PATH" ]; then
          mkdir -p "$MOUNT_PATH"
          echo "Created directory $MOUNT_PATH"
        fi

        # Check if already mounted
        if mountpoint -q "$MOUNT_PATH" 2>/dev/null; then
          echo "$MOUNT_PATH is already mounted"
          whiptail --msgbox "$SHARE is already mounted at $MOUNT_PATH" 10 60
          continue
        fi
        
        # Create simplified unit files with standard naming
        # Use the mount path directly for unit names
        MOUNT_UNIT="mnt-nas-$SAFE_NAME.mount"
        AUTO_UNIT="mnt-nas-$SAFE_NAME.automount"
        
        echo "Creating systemd units: $MOUNT_UNIT and $AUTO_UNIT"

        # Create mount unit with improved options
        cat > "$SYSTEMD_DIR/$MOUNT_UNIT" <<EOF
[Unit]
Description=NFS Mount for ${SHARE}
After=network-online.target
Wants=network-online.target

[Mount]
What=${SHARE}
Where=${MOUNT_PATH}
Type=nfs
Options=rw,noatime,intr,_netdev
TimeoutSec=60

[Install]
WantedBy=multi-user.target
EOF

        # Create automount unit
        cat > "$SYSTEMD_DIR/$AUTO_UNIT" <<EOF
[Unit]
Description=AutoMount for ${SHARE}
After=network-online.target
Wants=network-online.target

[Automount]
Where=${MOUNT_PATH}

[Install]
WantedBy=multi-user.target
EOF

        # Reload systemd and enable/start units
        echo "Reloading systemd daemon..."
        systemctl daemon-reload
        
        echo "Enabling and starting automount unit..."
        systemctl enable "$AUTO_UNIT"
        systemctl start "$AUTO_UNIT"
        
        # Try to access the mount to trigger automount
        echo "Attempting to access $MOUNT_PATH to trigger automount..."
        ls -la "$MOUNT_PATH" &>/dev/null
        sleep 2  # Give it a moment to mount
        
        # Verify mount was successful
        if mountpoint -q "$MOUNT_PATH" 2>/dev/null; then
          echo "✅ Successfully mounted $SHARE at $MOUNT_PATH"
          # Check if there are files in the mount
          if [ "$(ls -A "$MOUNT_PATH" 2>/dev/null)" ]; then
            echo "Mount contains files/directories"
            whiptail --msgbox "Successfully mounted $SHARE at $MOUNT_PATH\n\nMount contains files/directories." 12 70
          else
            echo "Mount appears to be empty"
            whiptail --msgbox "Successfully mounted $SHARE at $MOUNT_PATH\n\nMount appears to be empty." 12 70
          fi
        else
          echo "⚠️ Automount didn't trigger. Please check systemd logs with 'journalctl -u $AUTO_UNIT'"
          whiptail --msgbox "Failed to mount $SHARE at $MOUNT_PATH\n\nPlease check systemd logs with:\njournalctl -u $AUTO_UNIT" 12 70
          echo "❌ Failed to mount $SHARE at $MOUNT_PATH"
          SERVER=$(echo "$SHARE" | cut -d: -f1)
          if ping -c 1 -W 2 "$SERVER" &>/dev/null; then
            echo "NFS server $SERVER is reachable, but mount failed"
            whiptail --msgbox "NFS server $SERVER is reachable, but mount failed.\n\nPlease check if the share path is correct and accessible." 12 70
          else
            echo "NFS server $SERVER is not reachable"
            whiptail --msgbox "NFS server $SERVER is not reachable.\n\nPlease check network connectivity." 12 70
          fi
        fi
      done
    fi
  else
    whiptail --msgbox "No NFS shares available to mount." 10 50
  fi

  # Offer to remove mounts
  echo "Checking for mounted NFS shares..."
  MOUNTED_PATHS=($(find "$MOUNT_ROOT" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" 2>/dev/null))

  if [ "${#MOUNTED_PATHS[@]}" -gt 0 ]; then
    CHECKLIST=()
    for PATH_NAME in "${MOUNTED_PATHS[@]}"; do
      FULL_PATH="$MOUNT_ROOT/$PATH_NAME"
      # Use simplified unit naming
      SAFE_NAME="$PATH_NAME"
      MOUNT_UNIT="mnt-nas-$SAFE_NAME.mount"
      AUTO_UNIT="mnt-nas-$SAFE_NAME.automount"
      
      if mountpoint -q "$FULL_PATH" 2>/dev/null; then
        MOUNT_INFO=$(mount | grep "$FULL_PATH" | head -1)
        CHECKLIST+=("$PATH_NAME" "$MOUNT_INFO" "OFF")
      elif [ -f "$SYSTEMD_DIR/$MOUNT_UNIT" ]; then
        DESC=$(grep Description "$SYSTEMD_DIR/$MOUNT_UNIT" | cut -d' ' -f2-)
        CHECKLIST+=("$PATH_NAME" "$DESC (Not mounted)" "OFF")
      else
        CHECKLIST+=("$PATH_NAME" "Directory only" "OFF")
      fi
    done

    if [ "${#CHECKLIST[@]}" -gt 0 ]; then
      TO_REMOVE=$(whiptail --title "Select Mounts to Remove" \
        --checklist "Pick NFS shares to remove:" 20 78 10 \
        "${CHECKLIST[@]}" 3>&1 1>&2 2>&3)

      if [ $? -eq 0 ] && [ -n "$TO_REMOVE" ]; then
        for NAME in $TO_REMOVE; do
          NAME=$(echo "$NAME" | tr -d '"')
          FULL_PATH="$MOUNT_ROOT/$NAME"
          
          # Use simplified unit naming
          SAFE_NAME="$NAME"
          MOUNT_UNIT="mnt-nas-$SAFE_NAME.mount"
          AUTO_UNIT="mnt-nas-$SAFE_NAME.automount"
          
          # Stop and disable systemd units if they exist
          if [ -f "$SYSTEMD_DIR/$AUTO_UNIT" ]; then
            echo "Disabling automount unit for $NAME..."
            systemctl disable --now "$AUTO_UNIT" 2>/dev/null
            rm -f "$SYSTEMD_DIR/$AUTO_UNIT"
          fi
          
          if [ -f "$SYSTEMD_DIR/$MOUNT_UNIT" ]; then
            echo "Disabling mount unit for $NAME..."
            systemctl disable "$MOUNT_UNIT" 2>/dev/null
            systemctl stop "$MOUNT_UNIT" 2>/dev/null
            rm -f "$SYSTEMD_DIR/$MOUNT_UNIT"
          fi
          
          # Unmount if still mounted
          if mountpoint -q "$FULL_PATH" 2>/dev/null; then
            echo "Unmounting $FULL_PATH..."
            umount -f "$FULL_PATH" 2>/dev/null
            if [ $? -ne 0 ]; then
              echo "Warning: Could not unmount $FULL_PATH. Trying lazy unmount..."
              umount -l "$FULL_PATH" 2>/dev/null
            fi
          fi
          
          # Remove directory
          if [ -d "$FULL_PATH" ]; then
            echo "Removing directory $FULL_PATH..."
            rmdir "$FULL_PATH" 2>/dev/null
          fi
          
          echo "❌ Removed $NAME"
        done
        
        systemctl daemon-reload
        whiptail --msgbox "Selected mounts have been removed." 10 50
      fi
    else
      whiptail --msgbox "No mounted NFS shares found." 10 50
    fi
  else
    whiptail --msgbox "No NFS shares found in $MOUNT_ROOT." 10 50
  fi
}

# ==========================
# Remove NFS Share
# ==========================
remove_nfs_share() {
  # Check if there are any exports
  if [ ! -s "$EXPORTS_FILE" ]; then
    whiptail --msgbox "No NFS exports found in $EXPORTS_FILE" 10 60
    return 1
  fi

  # Parse exports file to create a list of shares
  local EXPORTS=()
  while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments and empty lines
    if [[ ! $line =~ ^\s*# && -n $line ]]; then
      # Extract share path (first part before space)
      local share_path=$(echo "$line" | awk '{print $1}')
      local clients=$(echo "$line" | cut -d' ' -f2-)
      EXPORTS+=("$share_path" "$clients" "OFF")
    fi
  done < "$EXPORTS_FILE"

  if [ ${#EXPORTS[@]} -eq 0 ]; then
    whiptail --msgbox "No valid exports found in $EXPORTS_FILE" 10 60
    return 1
  fi

  # Let user select shares to remove
  local TO_REMOVE=$(whiptail --title "Remove NFS Shares" \
    --checklist "Select shares to remove:" 20 78 10 \
    "${EXPORTS[@]}" 3>&1 1>&2 2>&3)

  if [ $? -ne 0 ] || [ -z "$TO_REMOVE" ]; then
    return 0
  fi

  # Process selected shares
  for SHARE in $TO_REMOVE; do
    SHARE=$(echo "$SHARE" | tr -d '"')
    
    # Create backup of exports file
    cp "$EXPORTS_FILE" "${EXPORTS_FILE}.bak"
    
    # Remove the share from exports file
    grep -v "^$SHARE " "${EXPORTS_FILE}.bak" > "$EXPORTS_FILE"
    
    # Update the shares list file if it exists
    local shares_list_file="/root/nfs_shares_list.txt"
    if [ -f "$shares_list_file" ]; then
      # Get server hostname
      local server_hostname=$(hostname -I | awk '{print $1}')
      if [ -z "$server_hostname" ]; then
        server_hostname=$(hostname)
      fi
      
      # Add removal note to shares list file
      echo "# Share $SHARE removed on $(date)" | sudo tee -a "$shares_list_file" > /dev/null
      echo "# --------------------------------------------------" | sudo tee -a "$shares_list_file" > /dev/null
    fi
    
    echo "Removed share: $SHARE"
  done

  # Apply changes
  exportfs -a
  systemctl restart nfs-kernel-server

  whiptail --msgbox "Selected NFS shares have been removed.\n\nRemember to update your NFS_SHARES array in the script if needed." 12 70
}

# ==========================
# Main Menu
# ==========================
main_menu() {
  while true; do
    choice=$(whiptail --title "NFS Share Manager" --menu "Choose an option:" 16 60 6 \
      "1" "Mount NFS Shares" \
      "2" "Create NFS Share" \
      "3" "Remove NFS Share" \
      "4" "View Current Exports" \
      "5" "Exit" 3>&1 1>&2 2>&3)
    
    case $choice in
      1)
        manage_mounts
        ;;
      2)
        check_nfs_server
        create_nfs_share
        ;;
      3)
        check_nfs_server
        remove_nfs_share
        ;;
      4)
        whiptail --title "Current NFS Exports" --textbox "$EXPORTS_FILE" 20 80 --scrolltext
        ;;
      5|*)
        echo "Exiting NFS Share Manager"
        exit 0
        ;;
    esac
  done
}

# Create mount root if it doesn't exist
mkdir -p "$MOUNT_ROOT"

# Start the main menu
main_menu
