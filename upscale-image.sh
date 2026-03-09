#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Upscale Image (4x)
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🔍
# @raycast.packageName Image Tools

# Documentation:
# @raycast.description Upscale image to 4x resolution using Real-ESRGAN AI
# @raycast.author assistant2

# Get the currently selected file in Finder
IMAGE_FILE=$(osascript -e 'tell application "Finder" to POSIX path of (selection as alias)' 2>/dev/null)

# Check if a file was selected
if [ -z "$IMAGE_FILE" ]; then
    exit 1
fi

# Check if file exists
if [ ! -f "$IMAGE_FILE" ]; then
    exit 1
fi

# Get file extension and base name
EXTENSION="${IMAGE_FILE##*.}"
BASENAME="${IMAGE_FILE%.*}"

# Set output filename
OUTPUT_FILE="${BASENAME}_upscaled.png"

# Run Real-ESRGAN (silent mode - suppress all output)
~/.realesrgan/realesrgan-ncnn-vulkan \
    -i "$IMAGE_FILE" \
    -o "$OUTPUT_FILE" \
    -n realesrgan-x4plus \
    -s 4 \
    -m ~/.realesrgan/models \
    >/dev/null 2>&1

# Exit with the return code from realesrgan
exit $?
