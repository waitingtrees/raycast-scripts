#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Invert Video Colors
# @raycast.mode fullOutput
# @raycast.packageName Video Tools

# Optional parameters:
# @raycast.icon 🎨

# Documentation:
# @raycast.description Inverts colors in a video file using FFmpeg
# @raycast.author assistant2

# Check if FFmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "❌ FFmpeg is not installed. Install it with: brew install ffmpeg"
    exit 1
fi

# Get selected file from Finder
selected_file=$(osascript -e 'tell application "Finder" to set theFile to selection as alias' -e 'POSIX path of theFile' 2>/dev/null)

if [ -z "$selected_file" ]; then
    echo "❌ No file selected in Finder"
    exit 1
fi

# Check if file exists
if [ ! -f "$selected_file" ]; then
    echo "❌ File not found: $selected_file"
    exit 1
fi

# Get file info
filename=$(basename "$selected_file")
dir=$(dirname "$selected_file")
extension="${filename##*.}"
name="${filename%.*}"

# Create output filename
output_file="${dir}/${name}_inverted.${extension}"

echo "⚡ Inverting colors in video..."
echo "📁 Input: $filename"

# Invert colors using FFmpeg negate filter
if ffmpeg -i "$selected_file" -vf "negate" -c:a copy "$output_file" -y 2>&1 | grep -E "(time=|error|Error)"; then
    if [ -f "$output_file" ]; then
        echo ""
        echo "✅ Video color inversion complete!"
        echo "📁 Output: ${name}_inverted.${extension}"

        # Open output file location in Finder
        open -R "$output_file"
    else
        echo ""
        echo "❌ Failed to create output file"
        exit 1
    fi
else
    echo ""
    echo "❌ FFmpeg processing failed"
    exit 1
fi
