#!/bin/sh

# Define directories and URLs
BASE_DIR="/opt"
MINECRAFT_DIR="$BASE_DIR/minecraft"
OLD_MINECRAFT_DIR="$BASE_DIR/minecraft.old"
MINECRAFT_URL_API="https://api.modpacks.ch/public/modpack"
INSTALLER_NAME="serverinstaller_latest"
WORLD_DIR="world"
START_SCRIPT="start-minecraft.sh"
LOG_DIR="/var/log/minecraft"
LOG_FILE="$LOG_DIR/minecraft-install-update.log"
VERSION_FILE="$MINECRAFT_DIR/minecraft_version.txt"
SCRIPT_PATH="$BASE_DIR/update_minecraft.sh"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Function to stop Minecraft server
stop_minecraft_server() {
    echo "Stopping Minecraft server..." | tee -a "$LOG_FILE"
    rc-service minecraft stop || echo "Minecraft service not found, continuing..." | tee -a "$LOG_FILE"
}

# Function to start Minecraft server
start_minecraft_server() {
    echo "Starting Minecraft server..." | tee -a "$LOG_FILE"
    rc-service minecraft start || echo "Minecraft service not found, continuing..." | tee -a "$LOG_FILE"
}

# Function to get the latest version of the selected modpack
get_latest_server_id() {
    MODPACK_ID=$1
    LATEST_VERSION_ID=$(curl -s "$MINECRAFT_URL_API/$MODPACK_ID" | jq -r '.versions[-1].id')
    
    if [ -z "$LATEST_VERSION_ID" ] || [ "$LATEST_VERSION_ID" = "null" ]; then
        echo "Error: Could not retrieve the latest server version ID." | tee -a "$LOG_FILE"
        return 1
    fi

    LATEST_URL="$MINECRAFT_URL_API/$MODPACK_ID/$LATEST_VERSION_ID/server/linux"
    echo "Latest server version ID: $LATEST_VERSION_ID" | tee -a "$LOG_FILE"
    echo "Latest server download URL: $LATEST_URL" | tee -a "$LOG_FILE"
}

# Function to download and install the server
download_and_install_server() {
    MODPACK_ID=$1
    get_latest_server_id $MODPACK_ID
    echo "Downloading the latest server installer..." | tee -a "$LOG_FILE"
    wget -O "$MINECRAFT_DIR/$INSTALLER_NAME" "$LATEST_URL"
    chmod +x "$MINECRAFT_DIR/$INSTALLER_NAME"
    echo "$LATEST_VERSION_ID" > "$VERSION_FILE"
}

# Function to set up OpenRC service
setup_openrc_service() {
    echo "Setting up OpenRC service..." | tee -a "$LOG_FILE"
    cat << 'EOF' > /etc/init.d/minecraft
#!/sbin/openrc-run
description="Minecraft Server"
depend() { need net; }
start() { ebegin "Starting Minecraft server"; start-stop-daemon --start --background --make-pidfile --pidfile /run/minecraft.pid --exec /opt/minecraft/start-minecraft.sh; eend $?; }
stop() { ebegin "Stopping Minecraft server"; start-stop-daemon --stop --pidfile /run/minecraft.pid; eend $?; }
EOF
    chmod +x /etc/init.d/minecraft
    rc-update add minecraft default
}

# Function to display menu for modpack selection
choose_modpack() {
    echo "Please choose a modpack:"
    echo "1) FTB Direwolf20"
    echo "2) FTB Revelation"
    echo "3) FTB SkyFactory"
    read -p "Enter the number of the modpack you want to install: " choice

    case $choice in
        1) MODPACK_ID="126" ;;  # Direwolf20
        2) MODPACK_ID="287" ;;  # Revelation
        3) MODPACK_ID="298" ;;  # SkyFactory
        *) echo "Invalid choice. Exiting."; exit 1 ;;
    esac
}

# Function to install Minecraft server
install_minecraft_server() {
    choose_modpack
    echo "Installing Minecraft server..." | tee -a "$LOG_FILE"
    mkdir -p "$MINECRAFT_DIR"
    download_and_install_server $MODPACK_ID
    setup_openrc_service
    start_minecraft_server
}

# Function to update Minecraft server
update_minecraft_server() {
    echo "Updating Minecraft server..." | tee -a "$LOG_FILE"
    choose_modpack
    stop_minecraft_server
    check_for_new_version $MODPACK_ID
    mv "$MINECRAFT_DIR" "$OLD_MINECRAFT_DIR"
    mkdir "$MINECRAFT_DIR"
    download_and_install_server $MODPACK_ID
    cp -r "$OLD_MINECRAFT_DIR/$WORLD_DIR" "$MINECRAFT_DIR/"
    cp "$OLD_MINECRAFT_DIR/$START_SCRIPT" "$MINECRAFT_DIR/"
    chmod +x "$MINECRAFT_DIR/$START_SCRIPT"
    start_minecraft_server
}

# Main menu
echo "Welcome to the Minecraft Server Management Script"
echo "1) Install Minecraft Server"
echo "2) Update Minecraft Server"
read -p "Choose an option: " action

case $action in
    1) install_minecraft_server ;;
    2) update_minecraft_server ;;
    *) echo "Invalid option. Exiting."; exit 1 ;;
esac
