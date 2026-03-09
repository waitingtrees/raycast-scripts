#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Image to SVG to 4K PNG
# @raycast.mode fullOutput
# @raycast.packageName Image Conversion

# Optional parameters:
# @raycast.icon 🎨

# Documentation:
# @raycast.description Trace an image to black & white SVG, then render as 4K PNG with transparent background
# @raycast.author assistant2

INKSCAPE="/Applications/Inkscape.app/Contents/MacOS/inkscape"
POTRACE="/opt/homebrew/bin/potrace"
MAGICK="/opt/homebrew/bin/magick"
WIDTH=3840

# Get the currently selected file in Finder
IMG_FILE=$(osascript -e 'tell application "Finder" to POSIX path of (selection as alias)' 2>/dev/null)

if [ -z "$IMG_FILE" ]; then
    echo "❌ No file selected in Finder"
    exit 1
fi

if [ ! -f "$IMG_FILE" ]; then
    echo "❌ File not found: $IMG_FILE"
    exit 1
fi

# Validate it's an image
EXT="${IMG_FILE##*.}"
EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
case "$EXT_LOWER" in
    png|jpg|jpeg|tiff|tif|bmp|webp|gif|heic|svg) ;;
    *)
        echo "❌ Not a supported image format: .$EXT"
        exit 1
        ;;
esac

if [ ! -f "$POTRACE" ]; then
    echo "❌ potrace not found. Run: brew install potrace"
    exit 1
fi

if [ ! -f "$INKSCAPE" ]; then
    echo "❌ Inkscape not found. Install from https://inkscape.org"
    exit 1
fi

BASENAME="${IMG_FILE%.*}"
BMP_FILE="${BASENAME}_trace.bmp"
SVG_FILE="${BASENAME}.svg"
PNG_FILE="${BASENAME}-4k.png"

echo "📥 Input: $(basename "$IMG_FILE")"
echo ""

# Step 1: Convert to high-contrast black & white BMP for potrace
echo "⚡ Step 1/3: Converting to black & white bitmap..."
"$MAGICK" "$IMG_FILE" \
    -colorspace Gray \
    -threshold 50% \
    -type Bilevel \
    BMP3:"$BMP_FILE" 2>&1

if [ ! -f "$BMP_FILE" ]; then
    echo "❌ Failed to create bitmap"
    exit 1
fi

# Step 2: Trace bitmap to SVG with potrace
echo "⚡ Step 2/3: Tracing shape to SVG..."
"$POTRACE" "$BMP_FILE" \
    -s \
    --tight \
    -o "$SVG_FILE" 2>&1

# Clean up temp bitmap
rm -f "$BMP_FILE"

if [ ! -f "$SVG_FILE" ]; then
    echo "❌ Failed to trace SVG"
    exit 1
fi

echo "   ✅ SVG saved: $(basename "$SVG_FILE")"

# Step 3: Render SVG to 4K PNG
echo "⚡ Step 3/3: Rendering 4K PNG..."
"$INKSCAPE" "$SVG_FILE" \
    --export-type=png \
    --export-filename="$PNG_FILE" \
    --export-width=$WIDTH \
    --export-background-opacity=0 \
    2>&1

if [ -f "$PNG_FILE" ]; then
    DIMENSIONS=$(sips -g pixelWidth -g pixelHeight "$PNG_FILE" 2>/dev/null | grep pixel | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
    echo "   ✅ PNG saved: $(basename "$PNG_FILE") (${DIMENSIONS})"
    echo ""
    echo "✅ Done! Opening in Finder..."
    open -R "$PNG_FILE"
else
    echo "❌ 4K PNG render failed"
    exit 1
fi
