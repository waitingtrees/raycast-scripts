#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Convert SVG to 4K PNG
# @raycast.mode fullOutput
# @raycast.packageName Image Conversion

# Optional parameters:
# @raycast.icon 🖼️

# Documentation:
# @raycast.description Convert an SVG to a 4K PNG with transparent background using Inkscape
# @raycast.author assistant2

INKSCAPE="/Applications/Inkscape.app/Contents/MacOS/inkscape"
WIDTH=3840

# Get the currently selected file in Finder
SVG_FILE=$(osascript -e 'tell application "Finder" to POSIX path of (selection as alias)' 2>/dev/null)

if [ -z "$SVG_FILE" ]; then
    echo "❌ No file selected in Finder"
    exit 1
fi

if [[ ! "$SVG_FILE" =~ \.svg$ ]]; then
    echo "❌ Selected file is not an SVG: $(basename "$SVG_FILE")"
    exit 1
fi

if [ ! -f "$SVG_FILE" ]; then
    echo "❌ File not found: $SVG_FILE"
    exit 1
fi

if [ ! -f "$INKSCAPE" ]; then
    echo "❌ Inkscape not found. Install from https://inkscape.org"
    exit 1
fi

BASENAME="${SVG_FILE%.svg}"
OUTPUT_FILE="${BASENAME}-4k.png"

echo "Converting: $(basename "$SVG_FILE")"
echo "Output: $(basename "$OUTPUT_FILE")"
echo "Width: ${WIDTH}px (transparent background)"
echo ""

"$INKSCAPE" "$SVG_FILE" \
    --export-type=png \
    --export-filename="$OUTPUT_FILE" \
    --export-width=$WIDTH \
    --export-background-opacity=0 \
    2>&1

if [ -f "$OUTPUT_FILE" ]; then
    DIMENSIONS=$(sips -g pixelWidth -g pixelHeight "$OUTPUT_FILE" 2>/dev/null | grep pixel | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
    echo ""
    echo "✅ Created: $(basename "$OUTPUT_FILE") (${DIMENSIONS})"
    open -R "$OUTPUT_FILE"
else
    echo ""
    echo "❌ Conversion failed"
    exit 1
fi
