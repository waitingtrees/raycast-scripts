#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Split SVG Graphics
# @raycast.mode silent
# @raycast.packageName Graphics

# Optional parameters:
# @raycast.icon 🪓

# Documentation:
# @raycast.description Auto-detect groups in an SVG and export each as a transparent 4K PNG
# @raycast.author assistant2

# Get SVG file from Finder selection
SVG_FILE=$(osascript -e '
tell application "Finder"
    set sel to selection
    if (count of sel) is 0 then
        return ""
    end if
    set theFile to item 1 of sel as alias
    return POSIX path of theFile
end tell' 2>/dev/null)

# Fallback: check clipboard for a file path
if [ -z "$SVG_FILE" ]; then
    CLIP=$(pbpaste 2>/dev/null)
    if [ -f "$CLIP" ] && [[ "$CLIP" == *.svg ]]; then
        SVG_FILE="$CLIP"
    fi
fi

if [ -z "$SVG_FILE" ]; then
    echo "❌ No SVG file selected in Finder (or on clipboard)"
    exit 1
fi

if [[ "$SVG_FILE" != *.svg ]]; then
    echo "❌ Selected file is not an SVG: $SVG_FILE"
    exit 1
fi

echo "⚡ Splitting: $(basename "$SVG_FILE")"
echo ""

# Set cairo library path for cairosvg
CAIRO_PREFIX=$(brew --prefix cairo 2>/dev/null)
if [ -n "$CAIRO_PREFIX" ]; then
    export DYLD_LIBRARY_PATH="$CAIRO_PREFIX/lib"
fi

# Run the Python backend
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
python3 "$SCRIPT_DIR/split-svg-graphics.py" "$SVG_FILE"

if [ $? -eq 0 ]; then
    # Open the output folder
    BASE_NAME="${SVG_FILE%.svg}"
    OUTPUT_DIR="${BASE_NAME}_Export"
    if [ -d "$OUTPUT_DIR" ]; then
        open "$OUTPUT_DIR"
    fi
    echo ""
    echo "✅ Done! Output folder opened."
else
    echo ""
    echo "❌ Export failed. Check that cairosvg and Pillow are installed:"
    echo "   pip3 install cairosvg Pillow numpy"
fi
