#!/bin/sh

# Script to install and set up Minecraft FTB server on Alpine Linux

# Update and install necessary packages
echo "Updating system and installing necessary packages..."
apk update
apk add openjdk11 screen wget curl unzip openrc

# Define server installation directory
MINECRAFT_DIR="/opt/minecraft"
MINECRAFT_URL="https://api.modpacks.ch/public/modpack/126/12494/server/linux"  # Replace with the correct FTB download URL if necessary

# Create the Minecraft server directory
echo "Creating Minecraft server directory at $MINECRAFT_DIR..."
mkdir -p $MINECRAFT_DIR
cd $MINECRAFT_DIR

# Download FTB server files
echo "Downloading FTB Direwolf20 server files..."
wget -O serverinstaller_126_12494 $MINECRAFT_URL

# Give execute permissions to the downloaded server installer
echo "Setting execute permissions for the server installer..."
chmod +x serverinstaller_126_12494

# Run the server installer
echo "Running the server installer..."
./serverinstaller_126_12494

# Create a script to start the Minecraft server using screen
echo "Creating Minecraft server start script..."
cat << 'EOF' > /opt/minecraft/start-minecraft.sh
#!/bin/sh
cd /opt/minecraft
screen -S minecraft -d -m sh start.sh
EOF

# Make the start script executable
chmod +x /opt/minecraft/start-minecraft.sh

# Create OpenRC service file for Minecraft server
echo "Creating OpenRC service for Minecraft server..."
cat << 'EOF' > /etc/init.d/minecraft
#!/sbin/openrc-run

description="Minecraft FTB Direwolf20 Server"

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
echo "Enabling Minecraft server service..."
rc-update add minecraft default

# Start the Minecraft server service
echo "Starting Minecraft server..."
rc-service minecraft start

# Add helpful Minecraft server commands to the shell profile

# For bash
if [ -f ~/.bashrc ]; then
    echo "Adding helpful commands to ~/.bashrc..."
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
EOF
fi

# For ash (Alpine's default shell)
if [ -f ~/.profile ]; then
    echo "Adding helpful commands to ~/.profile..."
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
EOF
fi

echo "Setup complete! Minecraft server is installed and set to start on boot."
