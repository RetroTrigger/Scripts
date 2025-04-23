#!/bin/bash

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if the script is run with root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}This script requires root privileges for some operations.${NC}"
        echo -e "${YELLOW}Please run with sudo.${NC}"
        exit 1
    fi
}

# Detect if GNOME is running
check_gnome() {
    if ! command -v gnome-shell &> /dev/null; then
        echo -e "${RED}Error: GNOME Shell is not installed.${NC}"
        echo -e "${YELLOW}This script is intended for GNOME desktop environments.${NC}"
        exit 1
    fi

    # Check GNOME version
    GNOME_VERSION=$(gnome-shell --version | awk '{print $3}')
    echo -e "${BLUE}Detected GNOME Shell version: ${GNOME_VERSION}${NC}"
}

# Check if required tools are installed
check_requirements() {
    echo -e "${BLUE}Checking requirements...${NC}"
    
    local missing_packages=()
    
    # Check for gnome-extensions command
    if ! command -v gnome-extensions &> /dev/null; then
        echo -e "${YELLOW}gnome-extensions command not found.${NC}"
        
        # Add to missing packages based on distribution
        if command -v apt &> /dev/null; then
            missing_packages+=("gnome-shell-extensions")
        elif command -v dnf &> /dev/null; then
            missing_packages+=("gnome-extensions-app")
        elif command -v pacman &> /dev/null; then
            missing_packages+=("gnome-shell-extensions")
        fi
    fi
    
    # Check for dconf-cli
    if ! command -v dconf &> /dev/null; then
        echo -e "${YELLOW}dconf-cli not found.${NC}"
        
        if command -v apt &> /dev/null; then
            missing_packages+=("dconf-cli")
        elif command -v dnf &> /dev/null; then
            missing_packages+=("dconf")
        elif command -v pacman &> /dev/null; then
            missing_packages+=("dconf")
        fi
    fi
    
    # Check for curl
    if ! command -v curl &> /dev/null; then
        echo -e "${YELLOW}curl not found.${NC}"
        missing_packages+=("curl")
    fi
    
    # Check for unzip
    if ! command -v unzip &> /dev/null; then
        echo -e "${YELLOW}unzip not found.${NC}"
        missing_packages+=("unzip")
    fi
    
    # Install missing packages
    if [ ${#missing_packages[@]} -gt 0 ]; then
        echo -e "${YELLOW}Installing required packages: ${missing_packages[*]}${NC}"
        
        if command -v apt &> /dev/null; then
            apt update && apt install -y "${missing_packages[@]}"
        elif command -v dnf &> /dev/null; then
            dnf install -y "${missing_packages[@]}"
        elif command -v pacman &> /dev/null; then
            pacman -Sy --noconfirm "${missing_packages[@]}"
        else
            echo -e "${RED}Unsupported package manager. Please install the following packages manually:${NC}"
            echo -e "${RED}${missing_packages[*]}${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}All requirements satisfied.${NC}"
}

# Function to install extensions by UUID
install_extension_by_uuid() {
    local uuid="$1"
    local name="$2"
    
    echo -e "${BLUE}Installing extension: ${name} (${uuid})${NC}"
    
    # Check if extension is already installed
    if gnome-extensions list | grep -q "$uuid"; then
        echo -e "${GREEN}Extension ${name} is already installed.${NC}"
        
        # Check if it's enabled
        if ! gnome-extensions list --enabled | grep -q "$uuid"; then
            echo -e "${YELLOW}Enabling extension: ${name}${NC}"
            gnome-extensions enable "$uuid"
        fi
        
        return 0
    fi
    
    # Create temp directory
    local temp_dir=$(mktemp -d)
    local extension_zip="${temp_dir}/${uuid}.zip"
    
    # Download the extension
    echo -e "${BLUE}Downloading extension from extensions.gnome.org...${NC}"
    
    # Determine GNOME Shell version for API compatibility
    local shell_version=$(gnome-shell --version | awk '{print $3}' | cut -d. -f1,2)
    
    # Download using curl
    if ! curl -s -o "$extension_zip" "https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?shell_version=${shell_version}"; then
        echo -e "${RED}Failed to download extension.${NC}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Install the extension
    echo -e "${BLUE}Installing...${NC}"
    if gnome-extensions install "$extension_zip"; then
        echo -e "${GREEN}Successfully installed ${name}.${NC}"
        echo -e "${YELLOW}Enabling extension...${NC}"
        gnome-extensions enable "$uuid"
        echo -e "${GREEN}Extension ${name} enabled.${NC}"
    else
        echo -e "${RED}Failed to install extension.${NC}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    return 0
}

# List of extensions to install
# Format: "uuid|name"
EXTENSIONS=(
    "just-perfection@justperfection.channel|Just Perfection"
    "transparent-top-bar@ftpix.com|Transparent Top Bar"
    "blur-my-shell@aunetx|Blur My Shell"
    "appindicatorsupport@rgcjonas.gmail.com|App Indicator Support"
    # Add more extensions here in the same format
    # For example:
    # "user-themes@gnome-shell-extensions.gcampax.github.com|User Themes"
    # "dash-to-dock@micxgx.gmail.com|Dash to Dock"
)

# Function to display the menu and handle user choices
show_menu() {
    while true; do
        echo -e "\n${BLUE}===== GNOME Extensions Installer =====${NC}"
        echo -e "${YELLOW}1.${NC} Install all predefined extensions"
        echo -e "${YELLOW}2.${NC} Install extensions individually"
        echo -e "${YELLOW}3.${NC} Add a new extension to the list"
        echo -e "${YELLOW}4.${NC} Enable all installed extensions"
        echo -e "${YELLOW}5.${NC} Disable all installed extensions"
        echo -e "${YELLOW}6.${NC} List all installed extensions"
        echo -e "${YELLOW}7.${NC} Backup extension settings"
        echo -e "${YELLOW}8.${NC} Restore extension settings"
        echo -e "${YELLOW}9.${NC} Exit"
        echo -e "${BLUE}=====================================${NC}"
        
        read -p "Choose an option (1-9): " choice
        
        case $choice in
            1)
                install_all_extensions
                ;;
            2)
                install_extensions_individually
                ;;
            3)
                add_new_extension
                ;;
            4)
                enable_all_extensions
                ;;
            5)
                disable_all_extensions
                ;;
            6)
                list_installed_extensions
                ;;
            7)
                backup_extension_settings
                ;;
            8)
                restore_extension_settings
                ;;
            9)
                echo -e "${GREEN}Exiting...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please try again.${NC}"
                ;;
        esac
    done
}

# Function to install all predefined extensions
install_all_extensions() {
    echo -e "\n${BLUE}Installing all predefined extensions...${NC}"
    
    for extension in "${EXTENSIONS[@]}"; do
        uuid=$(echo "$extension" | cut -d'|' -f1)
        name=$(echo "$extension" | cut -d'|' -f2)
        install_extension_by_uuid "$uuid" "$name"
    done
    
    echo -e "\n${GREEN}Finished installing extensions.${NC}"
    echo -e "${YELLOW}Note: You may need to restart GNOME Shell for some extensions to work properly.${NC}"
    echo -e "${YELLOW}You can restart GNOME Shell by pressing Alt+F2, typing 'r', and pressing Enter.${NC}"
}

# Function to install extensions individually
install_extensions_individually() {
    echo -e "\n${BLUE}Available extensions:${NC}"
    
    for i in "${!EXTENSIONS[@]}"; do
        name=$(echo "${EXTENSIONS[$i]}" | cut -d'|' -f2)
        echo -e "${YELLOW}$((i+1)).${NC} $name"
    done
    
    echo -e "${YELLOW}0.${NC} Return to main menu"
    
    read -p "Choose an extension to install (0-${#EXTENSIONS[@]}): " extension_choice
    
    if [ "$extension_choice" -eq 0 ]; then
        return
    elif [ "$extension_choice" -ge 1 ] && [ "$extension_choice" -le "${#EXTENSIONS[@]}" ]; then
        extension="${EXTENSIONS[$((extension_choice-1))]}"
        uuid=$(echo "$extension" | cut -d'|' -f1)
        name=$(echo "$extension" | cut -d'|' -f2)
        install_extension_by_uuid "$uuid" "$name"
    else
        echo -e "${RED}Invalid choice.${NC}"
    fi
}

# Function to add a new extension to the list
add_new_extension() {
    echo -e "\n${BLUE}Add a new extension to the list${NC}"
    echo -e "${YELLOW}You can find extensions at https://extensions.gnome.org${NC}"
    
    read -p "Enter the extension UUID (e.g., just-perfection@justperfection.channel): " uuid
    read -p "Enter the extension name (e.g., Just Perfection): " name
    
    # Validate input
    if [ -z "$uuid" ] || [ -z "$name" ]; then
        echo -e "${RED}UUID and name cannot be empty.${NC}"
        return
    fi
    
    # Add to the list
    EXTENSIONS+=("$uuid|$name")
    
    # Update the script
    sed -i "/^EXTENSIONS=(/,/^)/ c\\
EXTENSIONS=(\\
$(for ext in "${EXTENSIONS[@]}"; do echo "    \"$ext\""; done)\\
)
" "$0"
    
    echo -e "${GREEN}Added extension: $name ($uuid)${NC}"
    echo -e "${YELLOW}Would you like to install this extension now? (y/n)${NC}"
    read -p "" install_now
    
    if [ "$install_now" = "y" ] || [ "$install_now" = "Y" ]; then
        install_extension_by_uuid "$uuid" "$name"
    fi
}

# Function to enable all installed extensions
enable_all_extensions() {
    echo -e "\n${BLUE}Enabling all installed extensions...${NC}"
    
    for extension in $(gnome-extensions list); do
        echo -e "${YELLOW}Enabling: $extension${NC}"
        gnome-extensions enable "$extension"
    done
    
    echo -e "${GREEN}All extensions enabled.${NC}"
}

# Function to disable all installed extensions
disable_all_extensions() {
    echo -e "\n${BLUE}Disabling all installed extensions...${NC}"
    
    for extension in $(gnome-extensions list --enabled); do
        echo -e "${YELLOW}Disabling: $extension${NC}"
        gnome-extensions disable "$extension"
    done
    
    echo -e "${GREEN}All extensions disabled.${NC}"
}

# Function to list all installed extensions
list_installed_extensions() {
    echo -e "\n${BLUE}Installed GNOME Extensions:${NC}"
    echo -e "${YELLOW}Enabled:${NC}"
    gnome-extensions list --enabled
    
    echo -e "\n${YELLOW}Disabled:${NC}"
    for ext in $(gnome-extensions list); do
        if ! gnome-extensions list --enabled | grep -q "$ext"; then
            echo "$ext"
        fi
    done
}

# Function to backup extension settings
backup_extension_settings() {
    echo -e "\n${BLUE}Backing up extension settings...${NC}"
    
    # Get the date for the backup filename
    local date_str=$(date +"%Y%m%d_%H%M%S")
    local backup_dir="$HOME/.gnome_extension_backups"
    local backup_file="${backup_dir}/gnome_extensions_${date_str}.dconf"
    
    # Create backup directory if it doesn't exist
    mkdir -p "$backup_dir"
    
    # Get a list of installed extensions
    local extensions=$(gnome-extensions list)
    local extension_settings_paths=()
    
    # Find dconf paths for extension settings
    for ext in $extensions; do
        # Common patterns for extension settings paths
        for path in "/org/gnome/shell/extensions/${ext}/" "/org/gnome/shell/extensions/" "/org/gnome/desktop/"; do
            if dconf dump "$path" &> /dev/null; then
                extension_settings_paths+=("$path")
            fi
        done
    done
    
    # If no extension settings found
    if [ ${#extension_settings_paths[@]} -eq 0 ]; then
        echo -e "${YELLOW}No extension settings found.${NC}"
        return 1
    fi
    
    # Backup the settings
    echo -e "${GREEN}Found settings for extensions. Backing up to: ${backup_file}${NC}"
    
    # Create a backup file with extension info
    echo "# GNOME Extension Settings Backup - $(date)" > "$backup_file"
    echo "# Installed Extensions:" >> "$backup_file"
    for ext in $extensions; do
        echo "# - $ext" >> "$backup_file"
    done
    echo "" >> "$backup_file"
    
    # Dump settings for each path
    for path in "${extension_settings_paths[@]}"; do
        echo -e "${BLUE}Backing up settings from: ${path}${NC}"
        echo "# Settings from $path" >> "$backup_file"
        echo "[${path}]" >> "$backup_file"
        dconf dump "$path" >> "$backup_file"
        echo "" >> "$backup_file"
    done
    
    echo -e "${GREEN}Backup completed successfully to: ${backup_file}${NC}"
    echo -e "${YELLOW}You can use this file to restore your extension settings later.${NC}"
}

# Function to restore extension settings
restore_extension_settings() {
    echo -e "\n${BLUE}Restoring extension settings...${NC}"
    
    local backup_dir="$HOME/.gnome_extension_backups"
    
    # Check if backup directory exists
    if [ ! -d "$backup_dir" ]; then
        echo -e "${RED}No backup directory found.${NC}"
        return 1
    fi
    
    # List available backups
    local backups=("$backup_dir"/*.dconf)
    
    if [ ${#backups[@]} -eq 0 ] || [ ! -f "${backups[0]}" ]; then
        echo -e "${RED}No backup files found.${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Available backup files:${NC}"
    for i in "${!backups[@]}"; do
        local filename=$(basename "${backups[$i]}")
        echo -e "${YELLOW}$((i+1)).${NC} $filename ($(date -r "${backups[$i]}" '+%Y-%m-%d %H:%M:%S'))"
    done
    
    echo -e "${YELLOW}0.${NC} Return to main menu"
    
    read -p "Choose a backup to restore (0-${#backups[@]}): " backup_choice
    
    if [ "$backup_choice" -eq 0 ]; then
        return 0
    elif [ "$backup_choice" -ge 1 ] && [ "$backup_choice" -le "${#backups[@]}" ]; then
        local selected_backup="${backups[$((backup_choice-1))]}"
        
        echo -e "${YELLOW}Restoring from: $(basename "$selected_backup")${NC}"
        echo -e "${RED}Warning: This will overwrite your current extension settings.${NC}"
        read -p "Continue? (y/n): " confirm
        
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            # Parse the backup file and restore settings
            local current_path=""
            while IFS= read -r line; do
                # Check for path headers in the format [/org/gnome/path/]
                if [[ $line =~ ^\[(.*?)\]$ ]]; then
                    current_path="${BASH_REMATCH[1]}"
                    echo -e "${BLUE}Restoring settings to: ${current_path}${NC}"
                # Skip comments and empty lines
                elif [[ $line =~ ^#.*$ ]] || [[ -z $line ]]; then
                    continue
                # If we have a path, collect settings until the next path or EOF
                elif [ -n "$current_path" ]; then
                    # Append to a temporary file
                    echo "$line" >> "${temp_dir}/temp_settings"
                fi
                
                # If we have a blank line and settings to restore, apply them
                if [ -z "$line" ] && [ -f "${temp_dir}/temp_settings" ] && [ -n "$current_path" ]; then
                    dconf load "$current_path" < "${temp_dir}/temp_settings"
                    rm -f "${temp_dir}/temp_settings"
                fi
            done < "$selected_backup"
            
            # In case there's no final blank line
            if [ -f "${temp_dir}/temp_settings" ] && [ -n "$current_path" ]; then
                dconf load "$current_path" < "${temp_dir}/temp_settings"
                rm -f "${temp_dir}/temp_settings"
            fi
            
            echo -e "${GREEN}Settings restored successfully.${NC}"
            echo -e "${YELLOW}You may need to restart GNOME Shell for changes to take effect.${NC}"
            echo -e "${YELLOW}Press Alt+F2, type 'r', and press Enter to restart GNOME Shell.${NC}"
        else
            echo -e "${YELLOW}Restore canceled.${NC}"
        fi
    else
        echo -e "${RED}Invalid choice.${NC}"
    fi
}

# Main function
main() {
    echo -e "${BLUE}===== GNOME Extensions Installer =====${NC}"
    echo -e "${YELLOW}This script will help you install and manage GNOME extensions.${NC}"
    
    # Create a temporary directory for operations
    temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" EXIT
    
    check_root
    check_gnome
    check_requirements
    
    show_menu
}

# Start the script
main
