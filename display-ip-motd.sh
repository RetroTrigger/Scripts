#!/bin/bash
# Script to display system IP address as Message of the Day
# This script creates/updates a simple MOTD that shows the system's IP address
# Works across various Linux distributions

# Function to get local IP address (excluding loopback)
get_local_ip_address() {
    # Try different commands based on what's available
    if command -v ip &> /dev/null; then
        # Modern Linux distributions using 'ip' command
        # Get only the first local IP address
        ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1
    elif command -v ifconfig &> /dev/null; then
        # Older distributions using 'ifconfig'
        # Get only the first local IP address
        ifconfig | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1
    else
        # Fallback method - get first IP address
        hostname -I | awk '{print $1}'
    fi
}

# Function to update the MOTD
update_motd() {
    # Determine the appropriate MOTD location based on distribution
    if [ -d "/etc/update-motd.d" ]; then
        # Ubuntu/Debian style
        MOTD_FILE="/etc/update-motd.d/99-ip-address"
    else
        # Fallback to generic location
        MOTD_FILE="/etc/motd.d/ip-address"
        mkdir -p /etc/motd.d 2>/dev/null
    fi

    # Create the MOTD script
    cat > "$MOTD_FILE" << 'EOF'
#!/bin/bash
# Display IP address in MOTD

# Function to get local IP address (excluding loopback)
get_local_ip_address() {
    # Try different commands based on what's available
    if command -v ip &> /dev/null; then
        # Modern Linux distributions using 'ip' command
        # Get only the first local IP address
        ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1
    elif command -v ifconfig &> /dev/null; then
        # Older distributions using 'ifconfig'
        # Get only the first local IP address
        ifconfig | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1
    else
        # Fallback method - get first IP address
        hostname -I | awk '{print $1}'
    fi
}

# Get system information
HOSTNAME=$(hostname)
IP_ADDRESS=$(get_local_ip_address)
DATE=$(date "+%Y-%m-%d %H:%M:%S")

# Display the MOTD
echo "==========================================================="
echo "  Welcome to $HOSTNAME"
echo "  System IP Address: $IP_ADDRESS"
echo "  Last Updated: $DATE"
echo "==========================================================="
EOF

    # Make the script executable
    chmod +x "$MOTD_FILE"
    
    echo "MOTD has been updated at $MOTD_FILE"
    
    # Test the MOTD script
    echo "Current MOTD:"
    bash "$MOTD_FILE"
}

# Function to ensure the MOTD is displayed at login
setup_motd_display() {
    if [ -d "/etc/update-motd.d" ]; then
        # Ubuntu/Debian style - already handled by the system
        echo "MOTD will be displayed automatically at login (Ubuntu/Debian style)"
    else
        # For other distributions, check if we need to modify profile
        if ! grep -q "cat /etc/motd.d/ip-address" /etc/profile; then
            echo "# Display IP address MOTD" >> /etc/profile
            echo "if [ -f /etc/motd.d/ip-address ]; then" >> /etc/profile
            echo "    bash /etc/motd.d/ip-address" >> /etc/profile
            echo "fi" >> /etc/profile
            echo "MOTD display added to /etc/profile for system-wide effect"
        else
            echo "MOTD display already configured in /etc/profile"
        fi
    fi
}

# Main execution
echo "Setting up IP address MOTD..."
update_motd
setup_motd_display

echo -e "\nScript completed. The system IP address will be displayed at login."
echo "Note: You may need to run this script with sudo for system-wide effect."
