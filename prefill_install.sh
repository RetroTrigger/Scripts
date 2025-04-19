#!/bin/bash

# Ensure that the latest app versions are installed
apt-get update && apt-get install -y curl jq unzip wget

# Define an array of directories and their respective GitHub scripts
declare -A prefill_scripts=(
    ["SteamPrefill"]="https://raw.githubusercontent.com/tpill90/steam-lancache-prefill/master/scripts/update.sh"
    ["BattleNetPrefill"]="https://raw.githubusercontent.com/tpill90/battlenet-lancache-prefill/master/scripts/update.sh"
    ["EpicPrefill"]="https://raw.githubusercontent.com/tpill90/epic-lancache-prefill/master/scripts/update.sh"
)

# Iterate over each directory and script pair
for prefill_dir in "${!prefill_scripts[@]}"; do
    # Create directory and move into it
    mkdir -p "/home/$(whoami)/$prefill_dir"
    cd "/home/$(whoami)/$prefill_dir"

    # Download the install script
    curl -o update.sh --location "${prefill_scripts[$prefill_dir]}"

    # Make the script executable and run it
    chmod +x update.sh
    ./update.sh

    # Make the main Prefill app executable (assuming it is created by the update.sh script)
    chmod +x ./"$prefill_dir"

    # Return to home directory
    cd ~
done

# Set current username
CURRENT_USER=$(whoami)

# Setup systemd service and timer for SteamPrefill
sudo bash -c "cat <<EOT > /etc/systemd/system/steamprefill.service
[Unit]
Description=SteamPrefill
After=remote-fs.target
Wants=remote-fs.target

[Service]
Type=oneshot
Nice=19
User=$CURRENT_USER
WorkingDirectory=/home/$CURRENT_USER/SteamPrefill
ExecStart=/home/$CURRENT_USER/SteamPrefill/SteamPrefill prefill --no-ansi

[Install]
WantedBy=multi-user.target
EOT"

sudo bash -c "cat <<EOT > /etc/systemd/system/steamprefill.timer
[Unit]
Description=SteamPrefill run daily
Requires=steamprefill.service

[Timer]
# Runs every day at 4am (local time)
OnCalendar=*-*-* 4:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOT"

# Enable and start the timer for SteamPrefill
sudo systemctl daemon-reload
sudo systemctl enable --now steamprefill.timer

# Setup systemd service and timer for BattleNetPrefill
sudo bash -c "cat <<EOT > /etc/systemd/system/battlenetprefill.service
[Unit]
Description=BattleNetPrefill
After=remote-fs.target
Wants=remote-fs.target

[Service]
Type=oneshot
Nice=19
User=$CURRENT_USER
WorkingDirectory=/home/$CURRENT_USER/BattleNetPrefill
ExecStart=/home/$CURRENT_USER/BattleNetPrefill/BattleNetPrefill prefill --no-ansi

[Install]
WantedBy=multi-user.target
EOT"

sudo bash -c "cat <<EOT > /etc/systemd/system/battlenetprefill.timer
[Unit]
Description=BattleNetPrefill run daily
Requires=battlenetprefill.service

[Timer]
# Runs every day at 4am (local time)
OnCalendar=*-*-* 4:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOT"

# Enable and start the timer for BattleNetPrefill
sudo systemctl daemon-reload
sudo systemctl enable --now battlenetprefill.timer

# Setup a crontab job for EpicPrefill to run daily at 4:00 AM
CRON_JOB="0 4 * * * /home/$CURRENT_USER/EpicPrefill/EpicPrefill prefill"

# Add the cron job if it doesn't already exist
(crontab -l 2>/dev/null | grep -Fv "$CRON_JOB" ; echo "$CRON_JOB") | crontab -

# Verify the crontab entry
echo "Current crontab entries:"
crontab -l
