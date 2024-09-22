#!/bin/bash

# Create a directory if it doesn't exist
create_directory() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
    fi
}

# Determine the target directory name
get_folder_name() {
    folder="$1"

    # Handle folders starting with "The" or "the"
    if [[ "$folder" =~ ^[Tt][Hh][Ee]\  ]]; then
        # Extract the second word
        second_word=$(echo "$folder" | cut -d' ' -f2)

        # Check if the first character of the second word is a digit
        if [[ "${second_word:0:1}" =~ [0-9] ]]; then
            echo "#"
        else
            echo "${second_word:0:1}" | tr '[:lower:]' '[:upper:]'
        fi
    elif [[ "$folder" =~ ^[0-9] ]]; then
        # Handle folders starting with a number
        echo "#"
    else
        # Use the first letter of the folder name
        echo "${folder:0:1}" | tr '[:lower:]' '[:upper:]'
    fi
}

# Main function to sort folders
sort_folders_by_letter() {
    folders=(*/)
    total_folders=${#folders[@]}
    current_folder=0

    for folder in "${folders[@]}"; do
        folder="${folder%/}"  # Remove trailing slash

        # Skip if not a directory
        if [ ! -d "$folder" ]; then
            continue
        fi

        folder_name=$(get_folder_name "$folder")
        create_directory "$folder_name"
        
        mv "$folder" "$folder_name/" 2>/dev/null
        
        # Update progress
        ((current_folder++))
        progress=$((current_folder * 100 / total_folders))
        echo -ne "Progress: ["
        for ((i=0; i<progress/2; i++)); do echo -n "#"; done
        for ((i=progress/2; i<50; i++)); do echo -n " "; done
        echo -ne "] $progress% \r"
    done

    echo -e "\nDone!"
}

# Run the sorting function
sort_folders_by_letter
