#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Convert AI to High-Res PNG
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 🎨
# @raycast.packageName Image Conversion

# Documentation:
# @raycast.description Convert Adobe Illustrator file to high-resolution PNG (1200 DPI) with accurate CMYK color conversion
# @raycast.author assistant2

# Get the currently selected file in Finder
AI_FILE=$(osascript -e 'tell application "Finder" to POSIX path of (selection as alias)' 2>/dev/null)

# Check if a file was selected
if [ -z "$AI_FILE" ]; then
    echo "❌ Error: No file selected in Finder"
    echo "Please select an AI file in Finder and try again"
    exit 1
fi

# Check if file exists
if [ ! -f "$AI_FILE" ]; then
    echo "❌ Error: File not found: $AI_FILE"
    exit 1
fi

# Check if file is an AI file
if [[ ! "$AI_FILE" =~ \.ai$ ]]; then
    echo "Error: File must be an .ai file"
    exit 1
fi

# Get the output filename (same name, different extension)
OUTPUT_FILE="${AI_FILE%.ai}.png"

# Convert using Ghostscript with high quality settings
gs -dSAFER -dBATCH -dNOPAUSE -sDEVICE=png16m -r1200 -dUseCIEColor -sOutputFile="$OUTPUT_FILE" "$AI_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Converted to: $OUTPUT_FILE"
else
    echo "❌ Conversion failed"
    exit 1
fi
