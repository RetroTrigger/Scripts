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
if [ ! -d "/opt/lancache" ]; then
  echo "Cloning Lancache repository..."
  git clone https://github.com/lancachenet/docker-compose /opt/lancache
fi
cd /opt/lancache

# Get the IP address of the LXC container
LANCACHE_IP=$(hostname -I | awk '{print $1}')

# Set Cache size to 750GB
CACHE_DISK_SIZE=750000000000

# Ensure the .env file exists
if [ ! -f ".env" ]; then
  echo "Creating .env file..."
  touch .env
fi

# Update or append entries in the .env file
echo "Updating .env configuration..."

# Update LANCACHE_IP
if grep -q '^LANCACHE_IP=' .env; then
  sed -i "s/^LANCACHE_IP=.*/LANCACHE_IP=$LANCACHE_IP/" .env
else
  echo "LANCACHE_IP=$LANCACHE_IP" >> .env
fi

# Update DNS_BIND_IP
if grep -q '^DNS_BIND_IP=' .env; then
  sed -i "s/^DNS_BIND_IP=.*/DNS_BIND_IP=$LANCACHE_IP/" .env
else
  echo "DNS_BIND_IP=$LANCACHE_IP" >> .env
fi

# Update CACHE_DISK_SIZE
if grep -q '^CACHE_DISK_SIZE=' .env; then
  sed -i "s/^CACHE_DISK_SIZE=.*/CACHE_DISK_SIZE=$CACHE_DISK_SIZE/" .env
else
  echo "CACHE_DISK_SIZE=$CACHE_DISK_SIZE" >> .env
fi

# Update UPSTREAM_DNS
if grep -q '^UPSTREAM_DNS=' .env; then
  sed -i "s/^UPSTREAM_DNS=.*/UPSTREAM_DNS=1.1.1.1/" .env
else
  echo "UPSTREAM_DNS=1.1.1.1" >> .env
fi

# Start Lancache using Docker Compose
echo "Starting Lancache with Docker Compose..."
docker-compose up -d

# Print completion message
echo "Lancache setup complete."
echo "Lancache is running at $LANCACHE_IP. Please configure your router or devices to use this IP as the DNS server."

