#!/bin/bash

for zip in *.zip; do
  # Check if the .zip file still exists (not removed or renamed)
  if [ ! -f "$zip" ]; then
    continue
  fi

  # Announce the filename
  echo "Processing $zip..."

  # Create a temporary directory to unzip files
  tmp_dir=$(mktemp -d)

  # Unzip the contents into the temporary directory
  unzip -q "$zip" -d "$tmp_dir"

  # Create the final directory named after the ZIP file
  dirname=$(basename "$zip" .zip)
  if [ ! -d "$dirname" ]; then
    mkdir "$dirname"
  fi

  # Move all contents from the temp directory to the final directory
  shopt -s dotglob  # Include hidden files
  mv "$tmp_dir"/* "$dirname"/

  # If there's a nested directory with the same name as the zip file, move its contents up
  nested_dir="$dirname/$dirname"
  if [ -d "$nested_dir" ]; then
    mv "$nested_dir"/* "$dirname"/
    rmdir "$nested_dir"
  fi

  # Clean up the temporary directory
  rmdir "$tmp_dir"

  # Delete the zip file
  rm -f "$zip"

  # Announce completion
  echo "$zip done"
done
