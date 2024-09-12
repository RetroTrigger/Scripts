#!/bin/bash

# Variables
SHARE_DIR="/srv/samba/vm_temps"
SAMBA_CONF="/etc/samba/smb.conf"

# Update and install Samba
echo "Updating package list and installing Samba..."
apt update && apt install -y samba

# Create the shared directory
echo "Creating shared directory at $SHARE_DIR..."
mkdir -p $SHARE_DIR

# Set permissions
echo "Setting permissions for $SHARE_DIR..."
chmod 0777 $SHARE_DIR

# Backup existing Samba configuration
echo "Backing up existing Samba configuration..."
cp $SAMBA_CONF ${SAMBA_CONF}.bak

# Add Samba share configuration
echo "Configuring Samba share..."
cat <<EOL >> $SAMBA_CONF

[Share]
   path = $SHARE_DIR
   browseable = yes
   writable = yes
   guest ok = yes
   create mask = 0777
   directory mask = 0777
EOL

# Restart Samba services
echo "Restarting Samba services..."
systemctl restart smbd
systemctl restart nmbd

echo "Samba share setup complete. The shared folder is available at \\$(hostname -I | awk '{print $1}')\Share"
