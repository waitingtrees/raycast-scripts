#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Copy to Frame.io Watch Folder
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📁
# @raycast.packageName Frame.io

# Documentation:
# @raycast.description Copies the frontmost Finder file to Frame.io watch folder with auto-versioning

# Set your watch folder path
WATCH_FOLDER="$HOME/Frame Watch Folder"
VERSIONS_FILE="$WATCH_FOLDER/.versions"

# Create watch folder if it doesn't exist
mkdir -p "$WATCH_FOLDER"

# Create versions tracker if it doesn't exist
touch "$VERSIONS_FILE"

# Get the frontmost Finder file
FILE_PATH=$(osascript -e 'tell application "Finder" to set selectedItems to selection as alias list
if length of selectedItems is greater than 0 then
    return POSIX path of (item 1 of selectedItems)
end if')

# Check if we got a file
if [ -z "$FILE_PATH" ]; then
    echo "❌ No file selected in Finder"
    exit 1
fi

# Get filename and extension
FILENAME=$(basename "$FILE_PATH")
NAME="${FILENAME%.*}"
EXT="${FILENAME##*.}"

# Look up current version for this base name
CURRENT_VERSION=$(grep "^${NAME}=" "$VERSIONS_FILE" 2>/dev/null | cut -d= -f2)
NEXT_VERSION=$(( ${CURRENT_VERSION:-0} + 1 ))

# Update the version tracker
if grep -q "^${NAME}=" "$VERSIONS_FILE" 2>/dev/null; then
    sed -i '' "s/^${NAME}=.*/${NAME}=${NEXT_VERSION}/" "$VERSIONS_FILE"
else
    echo "${NAME}=${NEXT_VERSION}" >> "$VERSIONS_FILE"
fi

# Copy with version suffix
VERSIONED_NAME="${NAME}_v${NEXT_VERSION}.${EXT}"
cp "$FILE_PATH" "$WATCH_FOLDER/$VERSIONED_NAME"

echo "✅ Copied ${VERSIONED_NAME} to Frame.io watch folder"