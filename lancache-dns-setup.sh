#!/bin/bash

# Step 1: Prompt the user for the Lancache DNS IP
read -p "Please enter your Lancache DNS IP: " LANCACHE_DNS

# Step 2: Disable NetworkManager DNS management
echo -e "[main]\ndns=none\n" | sudo tee /etc/NetworkManager/conf.d/00-use-custom-dns.conf > /dev/null

# Step 3: Restart NetworkManager to apply the change
sudo systemctl restart NetworkManager

# Step 4: Backup existing resolv.conf
sudo cp /etc/resolv.conf /etc/resolv.conf.bak

# Step 5: Modify resolv.conf to use Lancache DNS
echo -e "nameserver $LANCACHE_DNS\n" | sudo tee /etc/resolv.conf > /dev/null

# Step 6: Set immutable flag to prevent any changes to resolv.conf
sudo chattr +i /etc/resolv.conf

# Step 7: Test connectivity by pinging Steam CDN domains
echo "Testing if Lancache is being used by pinging Steam CDN domains..."

# List of Steam CDN domains to test
STEAM_CDNS=(
    "cdn.steamstatic.com"
    "cs.steampowered.com"
    "client-download.steampowered.com"
    "content.steampowered.com"
    "akamai.steamstatic.com"
)

# Ping each Steam CDN and check for success
for CDN in "${STEAM_CDNS[@]}"; do
    echo "Pinging $CDN..."
    ping -c 4 $CDN
done

echo "If you see responses from your Lancache server IP for the Steam CDN domains, Lancache DNS is working."
