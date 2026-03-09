#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Copy PDF Text
# @raycast.mode silent
# @raycast.packageName File Utils

# Optional parameters:
# @raycast.icon 📄
# @raycast.argument1 { "type": "text", "placeholder": "PDF file path", "optional": true }

# Documentation:
# @raycast.description Extract text from selected PDF in Finder and copy to clipboard
# @raycast.author assistant2

# Get the selected file from Finder if no argument provided
if [ -z "$1" ]; then
    selected_file=$(osascript -e 'tell application "Finder" to set selectedItems to selection as alias list
    if selectedItems is {} then return ""
    POSIX path of (item 1 of selectedItems)')
else
    selected_file="$1"
fi

# Check if a file was selected
if [ -z "$selected_file" ]; then
    echo "No file selected in Finder"
    exit 1
fi

# Check if the file exists
if [ ! -f "$selected_file" ]; then
    echo "File not found: $selected_file"
    exit 1
fi

# Check if it's a PDF
if [[ ! "$selected_file" =~ \.pdf$ ]]; then
    echo "Selected file is not a PDF"
    exit 1
fi

# Extract text and copy to clipboard
pdftotext "$selected_file" - | pbcopy

if [ $? -eq 0 ]; then
    echo "PDF text copied to clipboard!"
else
    echo "Failed to extract text from PDF"
    exit 1
fi
