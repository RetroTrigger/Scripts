#!/bin/bash

# Check if running as root
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Update system packages
echo "Updating system packages..."
apt update && apt upgrade -y

# Install necessary dependencies
echo "Installing required packages..."
apt install -y git curl docker.io docker-compose unzip

# Enable and start Docker service
echo "Enabling and starting Docker..."
systemctl enable docker
systemctl start docker

# Clone Lancache-Docker repository
echo "Cloning Lancache repository..."
git clone https://github.com/lancachenet/docker-compose /opt/lancache
cd /opt/lancache

# Get the IP address of the LXC container
LANCACHE_IP=$(hostname -I | awk '{print $1}')

# Set Cache size to 750GB
CACHE_DISK_SIZE=750000000000

# Configure environment variables for Lancache in .env file
echo "Setting up environment configuration..."
cat <<EOL > .env
LANCACHE_IP=$LANCACHE_IP
DNS_BIND_IP=$LANCACHE_IP
CACHE_DISK_SIZE=$CACHE_DISK_SIZE
UPSTREAM_DNS=1.1.1.1  # Cloudflare DNS for non-cached content
EOL

# Start Lancache using Docker Compose
echo "Starting Lancache with Docker Compose..."
docker-compose up -d

# Install SteamPrefill
echo "Downloading and installing SteamPrefill..."
curl -Lo steamprefill.zip https://github.com/tpill90/SteamPrefill/releases/latest/download/SteamPrefill_Linux_x64.zip
unzip steamprefill.zip -d /usr/local/bin/
chmod +x /usr/local/bin/SteamPrefill
rm steamprefill.zip

# Install BattleNetPrefill
echo "Downloading and installing BattleNetPrefill..."
curl -Lo battlenetprefill.zip https://github.com/tpill90/BattleNetPrefill/releases/latest/download/BattleNetPrefill_Linux_x64.zip
unzip battlenetprefill.zip -d /usr/local/bin/
chmod +x /usr/local/bin/BattleNetPrefill
rm battlenetprefill.zip

# Install EpicPrefill
echo "Downloading and installing EpicPrefill..."
curl -Lo epicprefill.zip https://github.com/tpill90/EpicPrefill/releases/latest/download/EpicPrefill_Linux_x64.zip
unzip epicprefill.zip -d /usr/local/bin/
chmod +x /usr/local/bin/EpicPrefill
rm epicprefill.zip

# Print completion message
echo "Lancache and prefill tools setup complete."
echo "Lancache is running at $LANCACHE_IP. Please configure your router or devices to use this IP as the DNS server."
echo "Use '/usr/local/bin/SteamPrefill', '/usr/local/bin/BattleNetPrefill', or '/usr/local/bin/EpicPrefill' to prefill your game caches."
