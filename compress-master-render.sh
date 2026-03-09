#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Compress Master Render
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🎬
# @raycast.packageName Video Tools

# Documentation:
# @raycast.description Creates a 40MB compressed copy of Master Render at 1920x1080
# @raycast.author assistant2

# Get selected file from Finder
SOURCE_FILE=$(osascript -e 'tell application "Finder" to set selectedItems to selection' -e 'if length of selectedItems is 0 then return ""' -e 'POSIX path of (item 1 of selectedItems as alias)')

# Check if a file was selected
if [ -z "$SOURCE_FILE" ]; then
    echo "Error: No file selected in Finder!"
    exit 1
fi

# Check if source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: Source file not found!"
    exit 1
fi

# Get the directory and filename
OUTPUT_DIR=$(dirname "$SOURCE_FILE")
FILENAME=$(basename "$SOURCE_FILE")
FILENAME_NO_EXT="${FILENAME%.*}"
EXTENSION="${FILENAME##*.}"
OUTPUT_FILE="$OUTPUT_DIR/${FILENAME_NO_EXT}_LowRes.$EXTENSION"

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg not installed"
    exit 1
fi

# Compress with suppressed output
ffmpeg -i "$SOURCE_FILE" \
    -vf "scale=1920:1080:flags=lanczos" \
    -c:v libx264 \
    -preset slow \
    -crf 23 \
    -b:v 4800k \
    -maxrate 5000k \
    -bufsize 10000k \
    -c:a aac \
    -b:a 192k \
    -movflags +faststart \
    -y \
    "$OUTPUT_FILE" \
    -loglevel error -stats

if [ $? -eq 0 ]; then
    echo "✅ Compressed to $(du -h "$OUTPUT_FILE" | cut -f1)"
else
    echo "❌ Compression failed"
    exit 1
fi
