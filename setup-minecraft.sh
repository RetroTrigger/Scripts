#!/bin/sh

# Script to install and set up Minecraft FTB server on Alpine Linux

# Update and install necessary packages
echo "Updating system and installing necessary packages..."
apk update
apk add openjdk11 screen wget unzip openrc

# Define server installation directory
MINECRAFT_DIR="/opt/minecraft"
MINECRAFT_URL="YOUR_FTB_SERVER_URL_HERE"  # Replace this with the actual URL of the FTB server pack

# Create the Minecraft server directory
echo "Creating Minecraft server directory..."
mkdir -p $MINECRAFT_DIR
cd $MINECRAFT_DIR

# Download and extract FTB server files
echo "Downloading FTB Direwolf20 server files..."
wget -O ftb-server.zip $MINECRAFT_URL
unzip ftb-server.zip
rm ftb-server.zip

# Accept the EULA
echo "Accepting Minecraft EULA..."
echo "eula=true" > eula.txt

# Create a script to start the Minecraft server using screen
echo "Creating Minecraft server start script..."
cat << 'EOF' > /opt/minecraft/start-minecraft.sh
#!/bin/sh
cd /opt/minecraft
screen -S minecraft -d -m ./ServerStart.sh
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

echo "Setup complete! Minecraft server is installed and set to start on boot."
