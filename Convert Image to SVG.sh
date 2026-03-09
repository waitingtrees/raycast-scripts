#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Convert Image to SVG
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 🖼️
# @raycast.packageName Image Conversion

# Documentation:
# @raycast.description Convert a raster image (PNG, JPEG, etc.) to SVG using Inkscape's trace bitmap feature
# @raycast.author assistant2

INKSCAPE="/Applications/Inkscape.app/Contents/MacOS/inkscape"

# Get the currently selected file in Finder
IMAGE_FILE=$(osascript -e 'tell application "Finder" to POSIX path of (selection as alias)' 2>/dev/null)

# Check if a file was selected
if [ -z "$IMAGE_FILE" ]; then
    echo "❌ Error: No file selected in Finder"
    echo "Please select an image file in Finder and try again"
    exit 1
fi

# Check if file exists
if [ ! -f "$IMAGE_FILE" ]; then
    echo "❌ Error: File not found: $IMAGE_FILE"
    exit 1
fi

# Check if Inkscape is installed
if [ ! -f "$INKSCAPE" ]; then
    echo "❌ Error: Inkscape not found at $INKSCAPE"
    echo "Please install Inkscape from https://inkscape.org"
    exit 1
fi

# Get filename without extension
BASENAME="${IMAGE_FILE%.*}"
OUTPUT_FILE="${BASENAME}.svg"

echo "Converting: $(basename "$IMAGE_FILE")"
echo "Output: $(basename "$OUTPUT_FILE")"
echo ""

# Use Inkscape to import image, trace it, delete original bitmap, and export as SVG
# The actions workflow:
# 1. Import happens automatically when file is opened
# 2. select-all: Select the imported bitmap
# 3. object-trace: Trace the bitmap to vector paths
#    Format: {scans},{smooth},{stack},{remove_background},{speckles},{smooth_corners},{optimize}
#    - scans: 2 (for simple icons with few colors)
#    - smooth: true (smooth curves)
#    - stack: true (stack similar colors)
#    - remove_background: true (remove white background)
#    - speckles: 4 (suppress small spots)
#    - smooth_corners: 1.0 (corner smoothing threshold)
#    - optimize: 0.2 (path optimization tolerance)
# 4. select-by-element:image: Select original bitmap images
# 5. delete: Remove the original bitmap
# 6. export-filename: Set output filename
# 7. export-do: Perform the export
"$INKSCAPE" "$IMAGE_FILE" \
    --actions="select-all;object-trace:2,true,true,true,4,1.0,0.2;select-clear;select-by-element:image;delete;export-filename:$OUTPUT_FILE;export-plain-svg;export-do" \
    2>&1

if [ -f "$OUTPUT_FILE" ]; then
    echo ""
    echo "✅ Successfully created: $OUTPUT_FILE"

    # Open the SVG in Finder
    open -R "$OUTPUT_FILE"
else
    echo ""
    echo "❌ Conversion may have failed. Check if output file was created."
    exit 1
fi
