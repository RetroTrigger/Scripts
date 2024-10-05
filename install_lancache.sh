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

# Print completion message
echo "Lancache setup complete."
echo "Lancache is running at $LANCACHE_IP. Please configure your router or devices to use this IP as the DNS server."
