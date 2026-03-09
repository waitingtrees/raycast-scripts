#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title XML Extract Premiere
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 📹

# Documentation:
# @raycast.description Convert selected Premiere Pro project to XML/EDL for DaVinci Resolve
# @raycast.author assistant2

# Get selected file from Finder
PRPROJ_FILE=$(osascript -e 'tell application "Finder" to get POSIX path of (selection as alias)')

if [ ! -f "$PRPROJ_FILE" ]; then
    echo "No file selected"
    exit 1
fi

# Run Python converter
# Capture stdout to OUTPUT variable, let stderr go to console/log
OUTPUT=$(python3 ~/.config/claude-code/helpers/prproj_to_xml.py "$PRPROJ_FILE")

if [ $? -eq 0 ]; then
    # Filter for valid output files
    FILES=$(echo "$OUTPUT" | grep -E "\.(xml|edl|otio)$")
    COUNT=$(echo "$FILES" | wc -l | tr -d ' ')
    
    if [ "$COUNT" -eq 0 ]; then
         echo "No files created"
         exit 1
    elif [ "$COUNT" -eq 1 ]; then
        echo "Created $(basename "$FILES")"
    else
        echo "Created $COUNT files"
    fi
else
    echo "Error converting project"
    exit 1
fi
