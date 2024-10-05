#!/bin/sh

# Define key directories and variables
BASE_DIR="/opt"
MINECRAFT_DIR="$BASE_DIR/minecraft"
OLD_MINECRAFT_DIR="$BASE_DIR/minecraft.old"
MINECRAFT_URL_API="https://api.modpacks.ch/public/modpack/126"  # Example API for FTB modpack details
INSTALLER_NAME="serverinstaller_latest"
WORLD_DIR="world"
START_SCRIPT="start_minecraft.sh"
LOG_DIR="/var/log/minecraft"
LOG_FILE="$LOG_DIR/update-minecraft.log"
VERSION_FILE="$MINECRAFT_DIR/minecraft_version.txt"
SCRIPT_PATH="/opt/minecraft/update_minecraft.sh"

# Ensure the log directory exists
mkdir -p "$LOG_DIR"

# Function to stop the Minecraft server
stop_minecraft_server() {
    echo "Stopping Minecraft server..." | tee -a "$LOG_FILE"
    rc-service minecraft stop || echo "Minecraft service not found, continuing..." | tee -a "$LOG_FILE"
}

# Function to start the Minecraft server
start_minecraft_server() {
    echo "Starting Minecraft server..." | tee -a "$LOG_FILE"
    rc-service minecraft start || echo "Minecraft service not found, continuing..." | tee -a "$LOG_FILE"
}

# Function to fetch the latest server ID and URL dynamically
get_latest_server_id() {
    # Extract the latest "id" from the "versions" array in the API response
    LATEST_VERSION_ID=$(curl -s "$MINECRAFT_URL_API" | jq -r '.versions[-1].id')

    # Check if the ID was successfully retrieved
    if [ -z "$LATEST_VERSION_ID" ] || [ "$LATEST_VERSION_ID" = "null" ]; then
        echo "Error: Could not retrieve the latest server version ID." | tee -a "$LOG_FILE"
        return 1  # Return error code
    fi

    # Construct the URL for the latest server download
    LATEST_URL="https://api.feed-the-beast.com/v1/modpacks/public/modpack/126/$LATEST_VERSION_ID/server/linux"

    echo "Latest server version ID: $LATEST_VERSION_ID" | tee -a "$LOG_FILE"
    echo "Latest server download URL: $LATEST_URL" | tee -a "$LOG_FILE"
    return 0  # Return success code
}

# Function to check if a new version is available
check_for_new_version() {
    get_latest_server_id
    if [ $? -eq 0 ]; then
        if [ -f "$VERSION_FILE" ]; then
            CURRENT_VERSION_ID=$(cat "$VERSION_FILE")
            if [ "$CURRENT_VERSION_ID" = "$LATEST_VERSION_ID" ]; then
                echo "Minecraft server is up to date. No update needed." | tee -a "$LOG_FILE"
                exit 0  # Exit if no update is needed
            else
                echo "New version available. Proceeding with update..." | tee -a "$LOG_FILE"
            fi
        else
            echo "Version file not found. Proceeding with update..." | tee -a "$LOG_FILE"
        fi
    else
        echo "Failed to retrieve the latest version ID. Exiting..." | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Function to download the latest server installer
download_latest_server() {
    if get_latest_server_id; then
        echo "Downloading the latest FTB Minecraft server installer..." | tee -a "$LOG_FILE"
        wget -O "$MINECRAFT_DIR/$INSTALLER_NAME" "$LATEST_URL"
        chmod +x "$MINECRAFT_DIR/$INSTALLER_NAME"
        echo "$LATEST_VERSION_ID" > "$VERSION_FILE"  # Save the new version ID
    else
        echo "Failed to download the latest server. Exiting..." | tee -a "$LOG_FILE"
        return 1  # Exit the script with error code
    fi
}

# Function to set up the cron job
setup_cron_job() {
    CRON_JOB="0 3 * * * $SCRIPT_PATH >> $LOG_FILE 2>&1"
    # Check if the cron job already exists
    if crontab -l | grep -q "$SCRIPT_PATH"; then
        echo "Cron job already exists. Skipping setup." | tee -a "$LOG_FILE"
    else
        echo "Setting up cron job to check for updates daily at 3 AM..." | tee -a "$LOG_FILE"
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        echo "Cron job set up successfully." | tee -a "$LOG_FILE"
    fi
}

# Step 1: Stop the existing Minecraft server
stop_minecraft_server

# Step 2: Check if a new version is available
check_for_new_version

# Step 3: Back up the existing server
if [ -d "$MINECRAFT_DIR" ]; then
    echo "Backing up existing Minecraft server..." | tee -a "$LOG_FILE"
    mv "$MINECRAFT_DIR" "$OLD_MINECRAFT_DIR"
else
    echo "No existing Minecraft server found. Proceeding with fresh install." | tee -a "$LOG_FILE"
fi

# Step 4: Create new server folder
mkdir "$MINECRAFT_DIR"

# Step 5: Download and run the latest server installer
if download_latest_server; then
    echo "Running server installer..." | tee -a "$LOG_FILE"
    cd "$MINECRAFT_DIR"
    ./$INSTALLER_NAME 126 $LATEST_VERSION_ID --auto --path "$MINECRAFT_DIR"
else
    echo "Update process failed. Exiting..." | tee -a "$LOG_FILE"
    exit 1  # Exit if download fails
fi

# Step 6: Accept the EULA automatically
echo "Accepting Minecraft EULA..." | tee -a "$LOG_FILE"
echo "eula=true" > "$MINECRAFT_DIR/eula.txt"

# Step 7: Stop the new server after setup
stop_minecraft_server

# Step 8: Restore the world folder and the start script
if [ -d "$OLD_MINECRAFT_DIR/$WORLD_DIR" ]; then
    echo "Restoring the world from the previous installation..." | tee -a "$LOG_FILE"
    cp -r "$OLD_MINECRAFT_DIR/$WORLD_DIR" "$MINECRAFT_DIR/"
else
    echo "No previous world folder found, skipping restore." | tee -a "$LOG_FILE"
fi

if [ -f "$OLD_MINECRAFT_DIR/$START_SCRIPT" ]; then
    echo "Restoring the start script from the previous installation..." | tee -a "$LOG_FILE"
    cp "$OLD_MINECRAFT_DIR/$START_SCRIPT" "$MINECRAFT_DIR/"
    chmod +x "$MINECRAFT_DIR/$START_SCRIPT"
else
    echo "No previous start script found, skipping restore." | tee -a "$LOG_FILE"
fi

# Step 9: Start the updated Minecraft server
start_minecraft_server

# Step 10: Set up the cron job to check for updates daily
setup_cron_job

echo "Minecraft server update complete!" | tee -a "$LOG_FILE"
