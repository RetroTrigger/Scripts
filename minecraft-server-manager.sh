#!/bin/sh

# Minecraft Server Manager Script
# This script handles both installation and updates for a Minecraft FTB server on Alpine Linux
# Also provides Samba share functionality for the world folder

# Samba configuration
SAMBA_CONF="/etc/samba/smb.conf"
SAMBA_SHARE_NAME="minecraft_world"
# This script handles both installation and updates for a Minecraft FTB server on Alpine Linux

# Define key directories and variables
BASE_DIR="/opt"
MINECRAFT_DIR="$BASE_DIR/minecraft"
OLD_MINECRAFT_DIR="$BASE_DIR/minecraft.old"
MINECRAFT_URL_API="https://api.modpacks.ch/public/modpack/126"  # API for FTB Direwolf20 modpack details
INSTALLER_NAME="serverinstaller_latest"
WORLD_DIR="world"
START_SCRIPT="start-minecraft.sh"
LOG_DIR="/var/log/minecraft"
LOG_FILE="$LOG_DIR/minecraft-server-manager.log"
VERSION_FILE="$MINECRAFT_DIR/minecraft_version.txt"
SCRIPT_PATH="$MINECRAFT_DIR/minecraft-server-manager.sh"
MODPACK_ID="126"  # FTB Direwolf20 modpack ID

# Ensure the log directory exists
mkdir -p "$LOG_DIR"

# Log function to write to both console and log file
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Function to stop the Minecraft server
stop_minecraft_server() {
    log "Stopping Minecraft server..."
    rc-service minecraft stop || log "Minecraft service not found, continuing..."
}

# Function to start the Minecraft server
start_minecraft_server() {
    log "Starting Minecraft server..."
    rc-service minecraft start || log "Minecraft service not found, continuing..."
}

# Function to fetch the latest server ID and URL dynamically
get_latest_server_id() {
    # Extract the latest "id" from the "versions" array in the API response
    LATEST_VERSION_ID=$(curl -s "$MINECRAFT_URL_API" | jq -r '.versions[-1].id')

    # Check if the ID was successfully retrieved
    if [ -z "$LATEST_VERSION_ID" ] || [ "$LATEST_VERSION_ID" = "null" ]; then
        log "Error: Could not retrieve the latest server version ID."
        return 1  # Return error code
    fi

    # Construct the URL for the latest server download
    LATEST_URL="https://api.feed-the-beast.com/v1/modpacks/public/modpack/$MODPACK_ID/$LATEST_VERSION_ID/server/linux"

    log "Latest server version ID: $LATEST_VERSION_ID"
    log "Latest server download URL: $LATEST_URL"
    return 0  # Return success code
}

# Function to check if a new version is available
check_for_new_version() {
    get_latest_server_id
    if [ $? -eq 0 ]; then
        if [ -f "$VERSION_FILE" ]; then
            CURRENT_VERSION_ID=$(cat "$VERSION_FILE")
            if [ "$CURRENT_VERSION_ID" = "$LATEST_VERSION_ID" ]; then
                log "Minecraft server is up to date. No update needed."
                return 1  # Return code indicating no update needed
            else
                log "New version available. Proceeding with update..."
                return 0  # Return code indicating update needed
            fi
        else
            log "Version file not found. Proceeding with update..."
            return 0  # Return code indicating update needed
        fi
    else
        log "Failed to retrieve the latest version ID. Exiting..."
        return 2  # Return error code
    fi
}

# Function to set up Samba share for the Minecraft world
setup_samba_share() {
    log "Setting up Samba share for Minecraft world..."
    
    # Install Samba if not already installed
    if ! command -v samba >/dev/null 2>&1; then
        log "Installing Samba..."
        apk add --no-cache samba samba-common-tools
    fi
    
    # Create backup of existing Samba config if it exists
    if [ -f "$SAMBA_CONF" ]; then
        cp "$SAMBA_CONF" "${SAMBA_CONF}.bak"
        log "Backed up existing Samba configuration to ${SAMBA_CONF}.bak"
    fi
    
    # Configure Samba share
    log "Configuring Samba share for $MINECRAFT_DIR/$WORLD_DIR..."
    
    # Set permissions on the world directory
    chmod -R 777 "$MINECRAFT_DIR/$WORLD_DIR"
    chown -R nobody:nobody "$MINECRAFT_DIR/$WORLD_DIR"
    
    # Add the share configuration to smb.conf
    if ! grep -q "\[$SAMBA_SHARE_NAME\]" "$SAMBA_CONF" 2>/dev/null; then
        cat << EOF >> "$SAMBA_CONF"

[$SAMBA_SHARE_NAME]
   comment = Minecraft World Folder
   path = $MINECRAFT_DIR/$WORLD_DIR
   browseable = yes
   read only = no
   writable = yes
   guest ok = yes
   create mask = 0777
   directory mask = 0777
   force create mode = 0777
   force directory mode = 0777
   force user = nobody
   force group = nobody
   public = yes
EOF
        log "Added Samba share configuration for $SAMBA_SHARE_NAME"
    else
        log "Samba share $SAMBA_SHARE_NAME already exists in $SAMBA_CONF"
    fi
    
    # Ensure Samba service is enabled and started
    rc-update add samba default 2>/dev/null || true
    rc-service samba restart
    
    log "Samba share setup complete. You can access the share at \\$(hostname -I | awk '{print $1}')\minecraft_world"
}

# Function to download the latest server installer
download_latest_server() {
    if get_latest_server_id; then
        log "Downloading the latest FTB Minecraft server installer..."
        wget -O "$MINECRAFT_DIR/$INSTALLER_NAME" "$LATEST_URL"
        chmod +x "$MINECRAFT_DIR/$INSTALLER_NAME"
        echo "$LATEST_VERSION_ID" > "$VERSION_FILE"  # Save the new version ID
        return 0
    else
        log "Failed to download the latest server. Exiting..."
        return 1  # Exit with error code
    fi
}

# Function to set up the cron job for daily updates
setup_cron_job() {
    CRON_JOB="0 3 * * * $SCRIPT_PATH update >> $LOG_FILE 2>&1"
    # Check if the cron job already exists
    if crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"; then
        log "Cron job already exists. Skipping setup."
    else
        log "Setting up cron job to check for updates daily at 3 AM..."
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        log "Cron job set up successfully."
    fi
}

# Function to create OpenRC service
create_service() {
    log "Creating OpenRC service for Minecraft server..."
    cat << 'EOF' > /etc/init.d/minecraft
#!/sbin/openrc-run

description="Minecraft FTB Server"

depend() {
    need net
}

start() {
    ebegin "Starting Minecraft server"
    start-stop-daemon --start --background --make-pidfile --pidfile /run/minecraft.pid \
                      --exec /opt/minecraft/start-minecraft.sh
    eend $?
}

stop() {
    ebegin "Stopping Minecraft server"
    start-stop-daemon --stop --pidfile /run/minecraft.pid
    eend $?
}
EOF

    # Make the service executable
    chmod +x /etc/init.d/minecraft

    # Add the service to OpenRC and enable it on boot
    log "Enabling Minecraft server service..."
    rc-update add minecraft default
}

# Function to create server start script
create_start_script() {
    log "Creating Minecraft server start script..."
    cat << 'EOF' > "$MINECRAFT_DIR/$START_SCRIPT"
#!/bin/sh
cd /opt/minecraft
screen -S minecraft -d -m sh start.sh
EOF

    # Make the start script executable
    chmod +x "$MINECRAFT_DIR/$START_SCRIPT"
}

# Function to add helpful commands to shell profiles
add_shell_commands() {
    # For bash
    if [ -f ~/.bashrc ]; then
        log "Adding helpful commands to ~/.bashrc..."
        cat << 'EOF' >> ~/.bashrc

# Minecraft Server Management Commands
echo ""
echo "Check the Server:"
echo "You can monitor the server by reattaching to the screen session:"
echo ""
echo "  screen -r minecraft"
echo ""
echo "Additional Commands:"
echo "Stop the server manually:"
echo ""
echo "  rc-service minecraft stop"
echo ""
echo "Start the server manually:"
echo ""
echo "  rc-service minecraft start"
echo ""
echo "Update the server:"
echo ""
echo "  /opt/minecraft/minecraft-server-manager.sh update"
echo ""
EOF
    fi

    # For ash (Alpine's default shell)
    if [ -f ~/.profile ]; then
        log "Adding helpful commands to ~/.profile..."
        cat << 'EOF' >> ~/.profile

# Minecraft Server Management Commands
echo ""
echo "Check the Server:"
echo "You can monitor the server by reattaching to the screen session:"
echo ""
echo "  screen -r minecraft"
echo ""
echo "Additional Commands:"
echo "Stop the server manually:"
echo ""
echo "  rc-service minecraft stop"
echo ""
echo "Start the server manually:"
echo ""
echo "  rc-service minecraft start"
echo ""
echo "Update the server:"
echo ""
echo "  /opt/minecraft/minecraft-server-manager.sh update"
echo ""
EOF
    fi
}

# Function to create MOTD with essential commands
create_motd() {
    log "Creating Message of the Day (MOTD) with essential commands..."
    cat << 'EOF' > /etc/motd

==========================================================
   ___ ___  __  __ ___ _  _ ___  ___ ___    _  ___ ___ 
  |_ _/ _ \|  \/  |_ _| \| | __/ __|_ _|  /_\| __| __|  
   | | (_) | |\/| || || .` | _| (__ | |  / _ \ _|| _|   
  |___\___/|_|  |_|___|_|\_|___\___|___/_/ \_\___|___|  
  / __| __| _ \ \   / / __| _ \                        
  \__ \ _||   /\ \ / /| _||   /                        
  |___/___|_|_\ \_/ / |___|_|_\                         

==========================================================

ESSENTIAL MINECRAFT SERVER COMMANDS:

  MONITOR SERVER:       screen -r minecraft
  START SERVER:         rc-service minecraft start
  STOP SERVER:          rc-service minecraft stop
  RESTART SERVER:       rc-service minecraft restart
  UPDATE SERVER:        /opt/minecraft/minecraft-server-manager.sh update
  CHECK LOGS:           tail -f /var/log/minecraft/minecraft-server-manager.log
  SERVER STATUS:        rc-service minecraft status

Server directory: /opt/minecraft
World directory: /opt/minecraft/world

==========================================================

EOF
}

# Function to install required packages
install_packages() {
    log "Updating system and installing necessary packages..."
    apk update
    apk add openjdk11 screen wget curl unzip openrc jq
}

# Function to install the Minecraft server
install_minecraft() {
    # Create the Minecraft server directory
    log "Creating Minecraft server directory at $MINECRAFT_DIR..."
    mkdir -p $MINECRAFT_DIR
    
    # Download and install server
    if download_latest_server; then
        log "Running server installer..."
        cd "$MINECRAFT_DIR"
        ./$INSTALLER_NAME $MODPACK_ID $LATEST_VERSION_ID --auto --path "$MINECRAFT_DIR"
        
        # Accept the EULA automatically
        log "Accepting Minecraft EULA..."
        echo "eula=true" > "$MINECRAFT_DIR/eula.txt"
        
        # Create start script and service
        create_start_script
        create_service
        
        # Copy this script to the minecraft directory for updates
        cp "$0" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
        
        # Set up cron job for updates
        setup_cron_job
        
        # Add helpful commands to shell profiles
        add_shell_commands
        
        # Create MOTD with essential commands
        create_motd
        
        # Start the server
        start_minecraft_server
        
        log "Installation complete! Minecraft server is installed and set to start on boot."
    else
        log "Installation failed. Could not download server installer."
        exit 1
    fi
}

# Function to update the Minecraft server
update_minecraft() {
    # Check if an update is needed
    check_for_new_version
    UPDATE_NEEDED=$?
    
    if [ $UPDATE_NEEDED -eq 1 ]; then
        # No update needed
        exit 0
    elif [ $UPDATE_NEEDED -eq 2 ]; then
        # Error occurred
        exit 1
    fi
    
    # Stop the server before updating
    stop_minecraft_server
    
    # Back up the existing server
    if [ -d "$MINECRAFT_DIR" ]; then
        log "Backing up existing Minecraft server..."
        if [ -d "$OLD_MINECRAFT_DIR" ]; then
            rm -rf "$OLD_MINECRAFT_DIR"
        fi
        mv "$MINECRAFT_DIR" "$OLD_MINECRAFT_DIR"
    else
        log "No existing Minecraft server found. Proceeding with fresh install."
    fi
    
    # Create new server folder
    mkdir -p "$MINECRAFT_DIR"
    
    # Download and run the latest server installer
    if download_latest_server; then
        log "Running server installer..."
        cd "$MINECRAFT_DIR"
        ./$INSTALLER_NAME $MODPACK_ID $LATEST_VERSION_ID --auto --path "$MINECRAFT_DIR"
        
        # Accept the EULA automatically
        log "Accepting Minecraft EULA..."
        echo "eula=true" > "$MINECRAFT_DIR/eula.txt"
        
        # Copy this script to the minecraft directory for future updates
        cp "$0" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
        
        # Restore the world folder and the start script
        if [ -d "$OLD_MINECRAFT_DIR/$WORLD_DIR" ]; then
            log "Restoring the world from the previous installation..."
            cp -r "$OLD_MINECRAFT_DIR/$WORLD_DIR" "$MINECRAFT_DIR/"
        else
            log "No previous world folder found, skipping restore."
        fi
        
        # Create or restore the start script
        if [ -f "$OLD_MINECRAFT_DIR/$START_SCRIPT" ]; then
            log "Restoring the start script from the previous installation..."
            cp "$OLD_MINECRAFT_DIR/$START_SCRIPT" "$MINECRAFT_DIR/"
            chmod +x "$MINECRAFT_DIR/$START_SCRIPT"
        else
            create_start_script
        fi
        
        # Start the updated Minecraft server
        start_minecraft_server
        
        log "Minecraft server update complete!"
    else
        log "Update process failed. Exiting..."
        # Restore the old server if update fails
        if [ -d "$OLD_MINECRAFT_DIR" ]; then
            log "Restoring previous server installation..."
            rm -rf "$MINECRAFT_DIR"
            mv "$OLD_MINECRAFT_DIR" "$MINECRAFT_DIR"
            start_minecraft_server
        fi
        exit 1
    fi
}

# Main script execution
case "$1" in
    install)
        log "Starting Minecraft server installation..."
        install_packages
        install_minecraft
        ;;
    update)
        log "Starting Minecraft server update check..."
        update_minecraft
        ;;
    samba)
        setup_samba_share
        ;;
    *)
        echo "Usage: $0 {install|update|samba}"
        echo ""
        echo "Commands:"
        echo "  install - Install a new Minecraft server"
        echo "  update  - Check for and apply server updates"
        echo "  samba   - Set up Samba share for Minecraft world folder"
        exit 1
        ;;
esac

exit 0
