#!/bin/sh

# Define key directories and variables
BASE_DIR="/opt"
MINECRAFT_DIR="$BASE_DIR/minecraft"
OLD_MINECRAFT_DIR="$BASE_DIR/minecraft.old"
MINECRAFT_URL_API="https://api.modpacks.ch/public/modpack/126"  # Example API for FTB modpack details
INSTALLER_NAME="serverinstaller_latest"
WORLD_DIR="world"
LOG_FILE="/opt/minecraft/update-minecraft.log"

# Function to stop the Minecraft server
stop_minecraft_server() {
    echo "Stopping Minecraft server..."
    rc-service minecraft stop || echo "Minecraft service not found, continuing..."
}

# Function to start the Minecraft server
start_minecraft_server() {
    echo "Starting Minecraft server..."
    rc-service minecraft start || echo "Minecraft service not found, continuing..."
}

# Function to fetch the latest server ID and URL dynamically
get_latest_server_id() {
    # Extract the latest "id" from the "versions" array in the API response
    LATEST_VERSION_ID=$(curl -s "$MINECRAFT_URL_API" | jq -r '.versions[-1].id')

    # Check if the ID was successfully retrieved
    if [ -z "$LATEST_VERSION_ID" ] || [ "$LATEST_VERSION_ID" = "null" ]; then
        echo "Error: Could not retrieve the latest server version ID."
        return 1  # Return error code
    fi

    # Construct the URL for the latest server download
    LATEST_URL="https://api.feed-the-beast.com/v1/modpacks/public/modpack/126/$LATEST_VERSION_ID/server/linux"

    echo "Latest server version ID: $LATEST_VERSION_ID"
    echo "Latest server download URL: $LATEST_URL"
    return 0  # Return success code
}

# Function to download the latest server installer
download_latest_server() {
    if get_latest_server_id; then
        echo "Downloading the latest FTB Minecraft server installer..."
        wget -O "$MINECRAFT_DIR/$INSTALLER_NAME" "$LATEST_URL"
        chmod +x "$MINECRAFT_DIR/$INSTALLER_NAME"
    else
        echo "Failed to download the latest server. Exiting..."
        return 1  # Exit the script with error code
    fi
}

# Step 1: Stop the existing Minecraft server
stop_minecraft_server

# Step 2: Back up the existing server
if [ -d "$MINECRAFT_DIR" ]; then
    echo "Backing up existing Minecraft server..."
    mv "$MINECRAFT_DIR" "$OLD_MINECRAFT_DIR"
else
    echo "No existing Minecraft server found. Proceeding with fresh install."
fi

# Step 3: Create new server folder
mkdir "$MINECRAFT_DIR"

# Step 4: Download and run the latest server installer
if download_latest_server; then
    echo "Running server installer..."
    cd "$MINECRAFT_DIR"
    ./$INSTALLER_NAME 126 $LATEST_VERSION_ID --auto --path "$MINECRAFT_DIR"
else
    echo "Update process failed. Exiting..."
    exit 1  # Exit if download fails
fi

# Step 5: Accept the EULA automatically
echo "Accepting Minecraft EULA..."
echo "eula=true" > "$MINECRAFT_DIR/eula.txt"

# Step 6: Stop the new server after setup
stop_minecraft_server

# Step 7: Restore the world folder
if [ -d "$OLD_MINECRAFT_DIR/$WORLD_DIR" ]; then
    echo "Restoring the world from the previous installation..."
    cp -r "$OLD_MINECRAFT_DIR/$WORLD_DIR" "$MINECRAFT_DIR/"
else
    echo "No previous world folder found, skipping restore."
fi

# Step 8: Start the updated Minecraft server
start_minecraft_server

echo "Minecraft server update complete!" | tee -a "$LOG_FILE"
