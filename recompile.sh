#!/bin/sh

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Move current config to default config
if [ -f config.h ]; then
    echo "Moving config.h to config.def.h..."
    mv config.h config.def.h
else
    echo "Warning: config.h not found. Using existing config.def.h"
fi

# Clean and install
echo "Cleaning and reinstalling DWM..."
make clean
make install

# Restart DWM
echo "Restarting DWM..."
if pgrep -x "dwm" > /dev/null; then
    pkill -x dwm
    # DWM should automatically restart if you're using a display manager
    # or have it set up in your .xinitrc/.xsession
else
    echo "DWM is not currently running. Please start it manually."
fi

echo "DWM recompilation and restart complete!"
