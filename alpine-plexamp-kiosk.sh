#!/bin/sh
#
# Alpine Linux Plexamp Kiosk Installation Script
# 
# This script transforms a minimal Alpine Linux installation into a dedicated
# Plexamp music kiosk. It sets up:
#   - Cage (Wayland kiosk compositor) for fullscreen display
#   - Flatpak for running Plexamp (handles glibc compatibility)
#   - PipeWire for audio (supports USB DAC, HDMI, onboard audio)
#   - Auto-login and auto-start on boot
#   - Daily auto-updates for Flatpak packages
#
# Requirements:
#   - Fresh Alpine Linux installation (tested on 3.19+)
#   - Network connectivity
#   - Root privileges
#   - Plex Pass subscription (required for Plexamp)
#
# One-liner install (run as root):
#   wget -O - https://raw.githubusercontent.com/RetroTrigger/.Scripts/master/alpine-plexamp-kiosk.sh | sh
#
# Manual usage:
#   chmod +x alpine-plexamp-kiosk.sh
#   sudo ./alpine-plexamp-kiosk.sh
#
# After installation:
#   1. Reboot the system
#   2. System auto-logs in and launches Plexamp
#   3. Sign in with your Plex account (first run only)
#

set -e

# ============================================================================
# Configuration
# ============================================================================

KIOSK_USER="kiosk"
KIOSK_HOME="/home/${KIOSK_USER}"

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    printf "\033[1;34m[INFO]\033[0m %s\n" "$1"
}

log_success() {
    printf "\033[1;32m[OK]\033[0m %s\n" "$1"
}

log_warn() {
    printf "\033[1;33m[WARN]\033[0m %s\n" "$1"
}

log_error() {
    printf "\033[1;31m[ERROR]\033[0m %s\n" "$1"
}

die() {
    log_error "$1"
    exit 1
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

preflight_checks() {
    log_info "Running pre-flight checks..."

    # Check if running on Alpine Linux
    if [ ! -f /etc/alpine-release ]; then
        die "This script is designed for Alpine Linux only."
    fi
    log_success "Alpine Linux detected: $(cat /etc/alpine-release)"

    # Check for root privileges
    if [ "$(id -u)" -ne 0 ]; then
        die "This script must be run as root. Use: sudo $0"
    fi
    log_success "Running as root"

    # Check network connectivity
    if ! ping -c 1 -W 5 dl-cdn.alpinelinux.org >/dev/null 2>&1; then
        die "No network connectivity. Please check your internet connection."
    fi
    log_success "Network connectivity verified"
}

# ============================================================================
# Repository Setup
# ============================================================================

setup_repositories() {
    log_info "Setting up Alpine repositories..."

    # Backup original repositories file
    cp /etc/apk/repositories /etc/apk/repositories.bak

    # Get Alpine version for repository URLs
    ALPINE_VERSION=$(cat /etc/alpine-release | cut -d'.' -f1,2)

    # Ensure community repository is enabled
    if ! grep -q "^[^#].*community" /etc/apk/repositories; then
        log_info "Enabling community repository..."
        cat > /etc/apk/repositories <<EOF
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community
EOF
    fi

    # Update package index
    apk update
    log_success "Repositories configured"
}

# ============================================================================
# Package Installation
# ============================================================================

install_packages() {
    log_info "Installing required packages..."

    # Core system packages
    # Note: Using seatd instead of elogind for seat management
    # Do NOT use both - they conflict
    apk add --no-cache \
        dbus \
        dbus-x11 \
        polkit

    # Wayland and Cage kiosk compositor
    apk add --no-cache \
        cage \
        wlroots \
        xwayland \
        mesa-dri-gallium \
        mesa-egl \
        libinput \
        seatd \
        seatd-openrc

    # Flatpak for running Plexamp
    apk add --no-cache \
        flatpak

    # Audio stack (PipeWire)
    apk add --no-cache \
        pipewire \
        pipewire-pulse \
        pipewire-alsa \
        wireplumber

    # Auto-login support
    apk add --no-cache \
        agetty

    # Cron for auto-updates
    apk add --no-cache \
        dcron

    # Fonts for UI
    apk add --no-cache \
        font-dejavu \
        font-noto \
        fontconfig

    # Useful utilities
    apk add --no-cache \
        sudo \
        bash

    log_success "All packages installed"
}

# ============================================================================
# Kiosk User Setup
# ============================================================================

setup_kiosk_user() {
    log_info "Setting up kiosk user..."

    # Create kiosk user if it doesn't exist
    if ! id "${KIOSK_USER}" >/dev/null 2>&1; then
        adduser -D -s /bin/sh -h "${KIOSK_HOME}" "${KIOSK_USER}"
        log_success "Created user: ${KIOSK_USER}"
    else
        log_warn "User ${KIOSK_USER} already exists"
    fi

    # Add user to required groups
    addgroup "${KIOSK_USER}" audio 2>/dev/null || true
    addgroup "${KIOSK_USER}" video 2>/dev/null || true
    addgroup "${KIOSK_USER}" input 2>/dev/null || true
    addgroup "${KIOSK_USER}" plugdev 2>/dev/null || true
    addgroup "${KIOSK_USER}" seat 2>/dev/null || true

    # Create config directories
    mkdir -p "${KIOSK_HOME}/.config"
    mkdir -p "${KIOSK_HOME}/.local/share/flatpak"

    log_success "Kiosk user configured"
}

# ============================================================================
# Auto-login Configuration
# ============================================================================

setup_autologin() {
    log_info "Configuring auto-login..."

    # Install agetty for auto-login support
    # Modify inittab to auto-login on tty1

    # Backup original inittab
    cp /etc/inittab /etc/inittab.bak

    # Check if auto-login is already configured
    if grep -q "autologin.*${KIOSK_USER}" /etc/inittab; then
        log_warn "Auto-login already configured"
        return
    fi

    # Comment out default tty1 entry and add auto-login
    sed -i 's|^tty1::respawn:/sbin/getty|#tty1::respawn:/sbin/getty|' /etc/inittab

    # Add auto-login entry for tty1
    echo "" >> /etc/inittab
    echo "# Plexamp Kiosk auto-login" >> /etc/inittab
    echo "tty1::respawn:/sbin/agetty --autologin ${KIOSK_USER} --noclear tty1 linux" >> /etc/inittab

    log_success "Auto-login configured for ${KIOSK_USER} on tty1"
}

# ============================================================================
# Flatpak Configuration
# ============================================================================

setup_flatpak() {
    log_info "Setting up Flatpak and Plexamp..."

    # Add Flathub repository (system-wide)
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    log_info "Installing Plexamp from Flathub (this may take a while)..."
    flatpak install -y --noninteractive flathub com.plexamp.Plexamp

    # Allow kiosk user to run flatpak apps
    chown -R "${KIOSK_USER}:${KIOSK_USER}" "${KIOSK_HOME}/.local"

    log_success "Plexamp installed via Flatpak"
}

# ============================================================================
# Cage Wayland Compositor Configuration
# ============================================================================

setup_cage() {
    log_info "Configuring Cage kiosk compositor..."

    # Create the Cage startup script
    cat > "${KIOSK_HOME}/.config/cage-start.sh" <<'EOF'
#!/bin/sh
#
# Cage startup script for Plexamp kiosk
#

# Wait for services to be ready
sleep 2

# Start PipeWire audio
pipewire &
sleep 1
wireplumber &
sleep 1
pipewire-pulse &
sleep 1

# Launch Plexamp via Flatpak
exec flatpak run com.plexamp.Plexamp
EOF

    chmod +x "${KIOSK_HOME}/.config/cage-start.sh"

    # Create user profile to auto-start Cage on login
    cat > "${KIOSK_HOME}/.profile" <<'EOF'
# Plexamp Kiosk auto-start

# Only start on tty1
if [ "$(tty)" = "/dev/tty1" ]; then
    # Set XDG runtime directory for Wayland (required before starting compositor)
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    
    # Create runtime directory if it doesn't exist
    if [ ! -d "$XDG_RUNTIME_DIR" ]; then
        mkdir -p "$XDG_RUNTIME_DIR"
        chmod 700 "$XDG_RUNTIME_DIR"
    fi

    # Set environment variables
    export XDG_SESSION_TYPE=wayland
    export XDG_CURRENT_DESKTOP=cage
    export QT_QPA_PLATFORM=wayland
    export MOZ_ENABLE_WAYLAND=1
    
    # For Electron apps (Plexamp) - may need XWayland
    export ELECTRON_OZONE_PLATFORM_HINT=auto

    # Wait for seatd service to be fully ready
    while [ ! -S /run/seatd.sock ]; do
        sleep 0.5
    done

    # Start Cage with Plexamp
    # User must be in 'seat' group for this to work
    exec cage -- "$HOME/.config/cage-start.sh"
fi
EOF

    chown -R "${KIOSK_USER}:${KIOSK_USER}" "${KIOSK_HOME}"

    log_success "Cage compositor configured"
}

# ============================================================================
# PipeWire Audio Configuration
# ============================================================================

setup_audio() {
    log_info "Configuring PipeWire audio..."

    # Create PipeWire config directory
    mkdir -p "${KIOSK_HOME}/.config/pipewire/pipewire.conf.d"
    mkdir -p "${KIOSK_HOME}/.config/wireplumber/main.lua.d"

    # Create a basic PipeWire configuration
    cat > "${KIOSK_HOME}/.config/pipewire/pipewire.conf.d/10-clock-rate.conf" <<'EOF'
# Higher quality audio settings
context.properties = {
    default.clock.rate          = 48000
    default.clock.allowed-rates = [ 44100 48000 88200 96000 ]
    default.clock.quantum       = 1024
    default.clock.min-quantum   = 32
    default.clock.max-quantum   = 2048
}
EOF

    # Create WirePlumber configuration for audio device handling
    cat > "${KIOSK_HOME}/.config/wireplumber/main.lua.d/50-audio-config.lua" <<'EOF'
-- WirePlumber audio configuration for Plexamp kiosk
-- This allows all audio devices to be available

-- Enable all ALSA devices
alsa_monitor.enabled = true

-- Enable USB audio devices
rule = {
  matches = {
    {
      { "device.name", "matches", "alsa_card.*" },
    },
  },
  apply_properties = {
    ["device.disabled"] = false,
  },
}
EOF

    chown -R "${KIOSK_USER}:${KIOSK_USER}" "${KIOSK_HOME}/.config"

    log_success "PipeWire audio configured"
}

# ============================================================================
# Enable Services
# ============================================================================

enable_services() {
    log_info "Enabling system services..."

    # Enable D-Bus
    rc-update add dbus default
    rc-service dbus start 2>/dev/null || true

    # Enable seatd (required for Cage to access DRM/GPU)
    # Note: Do NOT enable elogind alongside seatd - they conflict
    rc-update add seatd default
    rc-service seatd start 2>/dev/null || true

    # Enable cron for auto-updates
    rc-update add dcron default
    rc-service dcron start 2>/dev/null || true

    # Create XDG runtime directory setup
    mkdir -p /etc/local.d
    cat > /etc/local.d/xdg-runtime.start <<EOF
#!/bin/sh
# Create XDG runtime directories for users
mkdir -p /run/user/$(id -u ${KIOSK_USER})
chown ${KIOSK_USER}:${KIOSK_USER} /run/user/$(id -u ${KIOSK_USER})
chmod 700 /run/user/$(id -u ${KIOSK_USER})
EOF
    chmod +x /etc/local.d/xdg-runtime.start
    rc-update add local default

    log_success "Services enabled"
}

# ============================================================================
# Flatpak Auto-Update Configuration
# ============================================================================

setup_auto_update() {
    log_info "Setting up Flatpak auto-updates..."

    # Create daily update script
    cat > /etc/periodic/daily/flatpak-update <<'EOF'
#!/bin/sh
#
# Daily Flatpak auto-update script
# Updates all Flatpak packages including Plexamp
#

# Log file
LOG="/var/log/flatpak-update.log"

echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting Flatpak update" >> "$LOG"

# Update all Flatpak packages
if flatpak update -y --noninteractive >> "$LOG" 2>&1; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Update completed successfully" >> "$LOG"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Update failed" >> "$LOG"
fi

# Keep log file from growing too large (keep last 1000 lines)
if [ -f "$LOG" ]; then
    tail -n 1000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi
EOF

    chmod +x /etc/periodic/daily/flatpak-update

    # Ensure periodic daily runs (Alpine uses run-parts)
    # dcron should handle /etc/periodic automatically

    log_success "Flatpak auto-updates configured (runs daily at 2am)"
}

# ============================================================================
# Finishing Touches
# ============================================================================

finish_setup() {
    log_info "Finalizing setup..."

    # Create a helper script to switch audio outputs
    cat > "${KIOSK_HOME}/switch-audio.sh" <<'EOF'
#!/bin/sh
#
# Helper script to switch audio output devices
#
# Usage: ./switch-audio.sh
# Lists available sinks and allows you to set a default
#

echo "Available audio outputs:"
echo "========================"
pactl list sinks short

echo ""
echo "To set a default output, run:"
echo "  pactl set-default-sink <sink_name>"
echo ""
echo "Example:"
echo "  pactl set-default-sink alsa_output.usb-xxx"
EOF
    chmod +x "${KIOSK_HOME}/switch-audio.sh"

    # Create a restart script for convenience
    cat > "${KIOSK_HOME}/restart-plexamp.sh" <<'EOF'
#!/bin/sh
#
# Restart Plexamp kiosk session
#
pkill -u "$(whoami)" cage 2>/dev/null
sleep 1
# Session will restart automatically via login
EOF
    chmod +x "${KIOSK_HOME}/restart-plexamp.sh"

    chown -R "${KIOSK_USER}:${KIOSK_USER}" "${KIOSK_HOME}"

    log_success "Setup complete"
}

# ============================================================================
# Print Final Instructions
# ============================================================================

print_instructions() {
    echo ""
    echo "============================================================================"
    echo "  PLEXAMP KIOSK INSTALLATION COMPLETE"
    echo "============================================================================"
    echo ""
    echo "  Next steps:"
    echo "  1. Reboot the system:  reboot"
    echo "  2. The system will auto-login and start Plexamp"
    echo "  3. Sign in with your Plex account (first run only)"
    echo ""
    echo "  Useful commands (run as ${KIOSK_USER}):"
    echo "  - Switch audio output:  ~/switch-audio.sh"
    echo "  - Restart Plexamp:      ~/restart-plexamp.sh"
    echo "  - Manual Flatpak update: flatpak update"
    echo ""
    echo "  Auto-updates:"
    echo "  - Flatpak packages update daily at 2am"
    echo "  - Check update log: /var/log/flatpak-update.log"
    echo ""
    echo "  SSH access (if enabled):"
    echo "  - You can SSH in for remote management"
    echo "  - Switch to tty2 (Ctrl+Alt+F2) for a login shell"
    echo ""
    echo "  Troubleshooting:"
    echo "  - Check Cage logs: journalctl --user -u cage (if using systemd)"
    echo "  - View audio devices: pactl list sinks"
    echo "  - Test audio: speaker-test -c 2"
    echo ""
    echo "============================================================================"
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo ""
    echo "============================================================================"
    echo "  ALPINE LINUX PLEXAMP KIOSK INSTALLER"
    echo "============================================================================"
    echo ""

    preflight_checks
    setup_repositories
    install_packages
    setup_kiosk_user
    setup_autologin
    setup_flatpak
    setup_cage
    setup_audio
    enable_services
    setup_auto_update
    finish_setup
    print_instructions
}

# Run main function
main "$@"
