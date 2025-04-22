#!/bin/bash

set -euo pipefail

INPUT_DIR="$PWD"
OUTPUT_DIR="$INPUT_DIR/squashed"
MOUNT_DIR="$INPUT_DIR/ps3_mount"
WORK_DIR="$INPUT_DIR/work"
THREADS=$(nproc)

echo "📦 Ensuring required tools are installed..."

install_if_missing() {
    if ! command -v "$1" &>/dev/null; then
        echo "❌ Required tool '$1' not found. Please install it."
        exit 1
    fi
}

for cmd in mksquashfs cp grep awk find mount umount; do
    install_if_missing "$cmd"
done

# Clean working directories from previous runs
sudo umount "$MOUNT_DIR" &>/dev/null || true
sudo rm -rf "$MOUNT_DIR" "$WORK_DIR"
mkdir -p "$MOUNT_DIR" "$WORK_DIR" "$OUTPUT_DIR"

shopt -s nullglob nocaseglob

# Find both ISOs and PS3 folders
mapfile -t ISO_LIST < <(find "$INPUT_DIR" -maxdepth 1 -type f -iname '*.iso')
mapfile -t PS3_LIST < <(find "$INPUT_DIR" -maxdepth 1 -type d -name '*.ps3')

if [ ${#ISO_LIST[@]} -eq 0 ] && [ ${#PS3_LIST[@]} -eq 0 ]; then
    echo "❌ No .iso files or .ps3 folders found in $INPUT_DIR"
    exit 1
fi

# Process ISO files
for ISO in "${ISO_LIST[@]}"; do
    BASENAME="$(basename "$ISO" .iso)"
    OUTPUT_FILE="$OUTPUT_DIR/$BASENAME.squashfs"
    EXTRACT_DIR="$WORK_DIR/$BASENAME.ps3"

    if [ -f "$OUTPUT_FILE" ]; then
        echo "⏭️  Skipping (already exists): $BASENAME.squashfs"
        continue
    fi

    echo "🔄 Processing ISO: $BASENAME"

    sudo mount -o loop,ro "$ISO" "$MOUNT_DIR"

    mkdir -p "$EXTRACT_DIR"
    echo "📥 Copying files (ignoring symlink loops)..."
    rsync -a --info=name0 --info=progress2 --safe-links --exclude='.DS_Store' --exclude='.AppleDouble' \
        --exclude='._*' "$MOUNT_DIR/" "$EXTRACT_DIR/" 2>/dev/null || true

    sudo umount "$MOUNT_DIR"

    echo "🗜️ Compressing to: $OUTPUT_FILE"
    mksquashfs "$EXTRACT_DIR" "$OUTPUT_FILE" -comp zstd -b 131072 -noappend -processors "$THREADS" -all-root 2>&1 | grep --line-buffered '[0-9]\{1,3\}%' | awk '{printf "\r🗜️ Progress: %s", $0}' && echo

    echo "✅ Created: $OUTPUT_FILE"
    sudo rm -rf "$EXTRACT_DIR"
done

# Process PS3 folders
for PS3_DIR in "${PS3_LIST[@]}"; do
    BASENAME="$(basename "$PS3_DIR" .ps3)"
    OUTPUT_FILE="$OUTPUT_DIR/$BASENAME.squashfs"

    if [ -f "$OUTPUT_FILE" ]; then
        echo "⏭️  Skipping (already exists): $BASENAME.squashfs"
        continue
    fi

    echo "🔄 Processing PS3 folder: $BASENAME"

    echo "🗜️ Compressing to: $OUTPUT_FILE"
    mksquashfs "$PS3_DIR" "$OUTPUT_FILE" -comp zstd -b 131072 -noappend -processors "$THREADS" -all-root 2>&1 | grep --line-buffered '[0-9]\{1,3\}%' | awk '{printf "\r🗜️ Progress: %s", $0}' && echo

    echo "✅ Created: $OUTPUT_FILE"
done

# Final cleanup
sudo rm -rf "$MOUNT_DIR" "$WORK_DIR"
echo "🏁 Done processing all ISOs and PS3 folders."
