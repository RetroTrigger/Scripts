#!/bin/bash
set -e

# COLORS
GREEN='\e[32m'
NC='\e[0m'

# === Dependency Installer ===
install_dependencies() {
    MISSING=()

    echo -e "${GREEN}Checking dependencies...${NC}"

    # Command -> Package mapping
    declare -A TOOL_TO_PACKAGE=(
        [zenity]="zenity"
        [mksquashfs]="squashfs-tools"
        [cmake]="cmake"
        [git]="git"
        [make]="build-essential"
        [gcc]="build-essential"
    )

    for TOOL in "${!TOOL_TO_PACKAGE[@]}"; do
        if ! command -v "$TOOL" &>/dev/null; then
            MISSING+=("${TOOL_TO_PACKAGE[$TOOL]}")
        fi
    done

    if (( ${#MISSING[@]} > 0 )); then
        echo -e "${GREEN}Installing missing packages: ${MISSING[*]}${NC}"
        sudo apt update
        sudo apt install -y "${MISSING[@]}"
    else
        echo -e "${GREEN}All required packages are already installed.${NC}"
    fi

    if ! command -v extract-xiso &>/dev/null; then
        echo -e "${GREEN}Building extract-xiso from source...${NC}"
        git clone https://github.com/XboxDev/extract-xiso.git
        cd extract-xiso
        mkdir -p build && cd build
        cmake ..
        make
        sudo cp extract-xiso /usr/local/bin/
        cd ../..
        rm -rf extract-xiso
    else
        echo -e "${GREEN}extract-xiso is already installed.${NC}"
    fi
}

# Format seconds as MM:SS
format_time() {
    printf "%02d:%02d" $(( $1 / 60 )) $(( $1 % 60 ))
}

# === Start ===
install_dependencies

# Ask for main folder containing Xbox game folders
SOURCE_DIR=$(zenity --file-selection --directory --title="Select the parent folder containing Xbox game subfolders")
[ -z "$SOURCE_DIR" ] && exit 1

# Get list of subfolders
GAMES=()
while IFS= read -r -d '' folder; do
    GAMES+=("$(basename "$folder")")
done < <(find "$SOURCE_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

# Present Shift/Ctrl multi-select UI
GAME_LIST=$(printf "%s\n" "${GAMES[@]}")
GAME_SELECTION=$(echo "$GAME_LIST" | zenity --list \
    --title="Select Games to Convert" \
    --text="Use Shift or Ctrl to select multiple folders" \
    --column="Game Folder" --multiple --separator=":" \
    --height=500 --width=400)

[ -z "$GAME_SELECTION" ] && exit 1

# Ask for output directory
DEST_DIR=$(zenity --file-selection --directory --title="Select destination for .iso.squashfs files")
[ -z "$DEST_DIR" ] && exit 1

# Compression choice
zenity --question --title="Compression Option" \
  --text="Use MAXIMUM compression?\n(This is slower but saves more space)\n\nYes = zstd -Xcompression-level 22\nNo = zstd default (faster)"
USE_MAX_COMPRESSION=$?

# === Conversion Loop with Progress and ETA ===
(
IFS=":" read -ra SELECTED <<< "$GAME_SELECTION"
TOTAL=${#SELECTED[@]}
COUNT=0
START_TIME=$(date +%s)

for GAME_NAME in "${SELECTED[@]}"; do
    SRC_PATH="$SOURCE_DIR/$GAME_NAME"
    OUT_FILE="$DEST_DIR/$GAME_NAME.iso.squashfs"

    # Skip if already converted
    if [[ -f "$OUT_FILE" ]]; then
        echo "# Skipping $GAME_NAME (already converted)"
        COUNT=$((COUNT+1))
        echo "$((COUNT * 100 / TOTAL))"
        continue
    fi

    echo "# Converting $GAME_NAME..."
    TEMP_DIR=$(mktemp -d)

    # Build XISO
    (
        cd "$TEMP_DIR" || exit 1
        extract-xiso -c "$SRC_PATH" "${GAME_NAME}.iso"
    )

    ISO_PATH="$TEMP_DIR/${GAME_NAME}.iso"
    if [[ ! -f "$ISO_PATH" ]]; then
        echo "# Failed to create ISO for $GAME_NAME"
        rm -rf "$TEMP_DIR"
        COUNT=$((COUNT+1))
        echo "$((COUNT * 100 / TOTAL))"
        continue
    fi

    # Compress with squashfs
    if [[ "$USE_MAX_COMPRESSION" -eq 0 ]]; then
        mksquashfs "$ISO_PATH" "$OUT_FILE" -noappend -comp zstd -Xcompression-level 22 >/dev/null
    else
        mksquashfs "$ISO_PATH" "$OUT_FILE" -noappend -comp zstd >/dev/null
    fi

    rm -rf "$TEMP_DIR"
    COUNT=$((COUNT+1))

    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))
    AVG=$((ELAPSED / COUNT))
    REMAINING=$((TOTAL - COUNT))
    ETA=$((AVG * REMAINING))

    echo "# $GAME_NAME done | Elapsed: $(format_time $ELAPSED) | ETA: $(format_time $ETA)"
    echo "$((COUNT * 100 / TOTAL))"
done

) 2>/dev/null | zenity --progress \
    --title="Converting Xbox Games" \
    --text="Starting conversion..." \
    --percentage=0 \
    --auto-close

zenity --info --text="✅ All conversions complete.\nSaved in:\n$DEST_DIR"
