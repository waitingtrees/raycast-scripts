#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Get Camera Info from Video
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 🎥
# @raycast.packageName Media Utils

# Documentation:
# @raycast.description Extracts camera model and log/gamma info from selected video file
# @raycast.author assistant2

# Get the selected file from Finder
VIDEO_PATH=$(osascript -e 'tell application "Finder" to set selectedItems to selection as alias list
if length of selectedItems is greater than 0 then
    return POSIX path of (item 1 of selectedItems)
end if')

# Check if we got a file
if [ -z "$VIDEO_PATH" ]; then
    echo "❌ No file selected in Finder"
    echo ""
    echo "Please select a video file in Finder and run this script again."
    exit 1
fi

# Check if exiftool is installed
if ! command -v exiftool &> /dev/null; then
    echo "❌ Error: exiftool is not installed"
    echo ""
    echo "Install with: brew install exiftool"
    exit 1
fi

# Check if file exists
if [ ! -f "$VIDEO_PATH" ]; then
    echo "❌ Error: File not found: $VIDEO_PATH"
    exit 1
fi

# Extract metadata
METADATA=$(exiftool "$VIDEO_PATH" 2>&1)

# Extract camera info
CAMERA_MAKE=$(echo "$METADATA" | grep -i "Device Manufacturer" | head -1 | sed 's/.*: //')
CAMERA_MODEL=$(echo "$METADATA" | grep -i "Device Model Name" | head -1 | sed 's/.*: //')
GAMMA=$(echo "$METADATA" | grep -i "Acquisition Record Group Item Value" | head -1 | sed 's/.*: //')

# Check for XML sidecar file (common with MXF files)
if [[ "$VIDEO_PATH" == *.MXF ]] || [[ "$VIDEO_PATH" == *.mxf ]]; then
    # Get the base filename without extension
    DIR_PATH=$(dirname "$VIDEO_PATH")
    BASE_NAME=$(basename "$VIDEO_PATH" .MXF)
    BASE_NAME=$(basename "$BASE_NAME" .mxf)

    # Look for XML sidecar with M01 suffix (Sony naming convention)
    XML_PATH="${DIR_PATH}/${BASE_NAME}M01.XML"

    if [ -f "$XML_PATH" ]; then
        # Parse XML for camera info
        if [ -z "$CAMERA_MAKE" ]; then
            CAMERA_MAKE=$(grep -o 'manufacturer="[^"]*"' "$XML_PATH" | sed 's/manufacturer="//;s/"//')
        fi

        if [ -z "$CAMERA_MODEL" ]; then
            CAMERA_MODEL=$(grep -o 'modelName="[^"]*"' "$XML_PATH" | head -1 | sed 's/modelName="//;s/"//')
        fi

        if [ -z "$GAMMA" ]; then
            GAMMA=$(grep -o 'name="CaptureGammaEquation" value="[^"]*"' "$XML_PATH" | sed 's/.*value="//;s/"//')
        fi
    fi
fi

# Fallback to other metadata fields if primary ones aren't found
if [ -z "$CAMERA_MAKE" ]; then
    CAMERA_MAKE=$(echo "$METADATA" | grep -i "^Make" | head -1 | sed 's/.*: //')
fi

if [ -z "$CAMERA_MODEL" ]; then
    CAMERA_MODEL=$(echo "$METADATA" | grep -i "^Model" | head -1 | sed 's/.*: //')
fi

if [ -z "$GAMMA" ]; then
    GAMMA=$(echo "$METADATA" | grep -i "Gamma\|Color Profile\|Picture Profile" | head -1 | sed 's/.*: //')
fi

# Format camera name
CAMERA_NAME=""
if [ -n "$CAMERA_MAKE" ] && [ -n "$CAMERA_MODEL" ]; then
    # Handle Sony camera model names
    if [[ "$CAMERA_MODEL" == "ILCE-"* ]]; then
        case "$CAMERA_MODEL" in
            "ILCE-7M3") CAMERA_NAME="Sony A7 III ($CAMERA_MODEL)" ;;
            "ILCE-7M4") CAMERA_NAME="Sony A7 IV ($CAMERA_MODEL)" ;;
            "ILCE-7RM3") CAMERA_NAME="Sony A7R III ($CAMERA_MODEL)" ;;
            "ILCE-7RM4") CAMERA_NAME="Sony A7R IV ($CAMERA_MODEL)" ;;
            "ILCE-7RM5") CAMERA_NAME="Sony A7R V ($CAMERA_MODEL)" ;;
            "ILCE-7SM3") CAMERA_NAME="Sony A7S III ($CAMERA_MODEL)" ;;
            "ILCE-6400") CAMERA_NAME="Sony A6400 ($CAMERA_MODEL)" ;;
            "ILCE-6600") CAMERA_NAME="Sony A6600 ($CAMERA_MODEL)" ;;
            *) CAMERA_NAME="$CAMERA_MAKE $CAMERA_MODEL" ;;
        esac
    elif [[ "$CAMERA_MODEL" == "ILME-"* ]]; then
        case "$CAMERA_MODEL" in
            "ILME-FX3") CAMERA_NAME="Sony FX3 ($CAMERA_MODEL)" ;;
            "ILME-FX6"*) CAMERA_NAME="Sony FX6 ($CAMERA_MODEL)" ;;
            "ILME-FX30") CAMERA_NAME="Sony FX30 ($CAMERA_MODEL)" ;;
            "ILME-FX9"*) CAMERA_NAME="Sony FX9 ($CAMERA_MODEL)" ;;
            *) CAMERA_NAME="$CAMERA_MAKE $CAMERA_MODEL" ;;
        esac
    else
        CAMERA_NAME="$CAMERA_MAKE $CAMERA_MODEL"
    fi
elif [ -n "$CAMERA_MODEL" ]; then
    CAMERA_NAME="$CAMERA_MODEL"
elif [ -n "$CAMERA_MAKE" ]; then
    CAMERA_NAME="$CAMERA_MAKE camera"
fi

# Format gamma/log info
GAMMA_INFO=""
if [ -n "$GAMMA" ]; then
    # Capitalize and format gamma name
    GAMMA_FORMATTED=$(echo "$GAMMA" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')
    GAMMA_INFO="using $GAMMA_FORMATTED gamma"
fi

# Output result
echo "🎥 Camera Information"
echo "===================="
echo ""

if [ -n "$CAMERA_NAME" ]; then
    if [ -n "$GAMMA_INFO" ]; then
        echo "This footage was shot with a $CAMERA_NAME $GAMMA_INFO."
    else
        echo "This footage was shot with a $CAMERA_NAME."
    fi
else
    echo "⚠️  No camera metadata found in this file."
fi

echo ""
echo "📋 DaVinci Resolve Settings:"
echo "----------------------------"

if [[ "$CAMERA_MAKE" == "Sony" ]] && [[ -n "$GAMMA" ]]; then
    echo "Camera: Sony"

    # Provide specific DaVinci Resolve gamma setting
    case "$GAMMA" in
        *"s-log3"*|*"slog3"*)
            if [[ "$GAMMA" == *"cine"* ]]; then
                echo "Gamma: S-Log3 Cine"
                echo "Color Space: S-Gamut3.Cine"
            else
                echo "Gamma: S-Log3"
                echo "Color Space: S-Gamut3"
            fi
            ;;
        *"s-log2"*|*"slog2"*)
            echo "Gamma: S-Log2"
            echo "Color Space: S-Gamut"
            ;;
        *)
            echo "Gamma: $GAMMA_FORMATTED"
            ;;
    esac
elif [ -n "$CAMERA_MAKE" ]; then
    echo "Camera: $CAMERA_MAKE"
    if [ -n "$GAMMA" ]; then
        echo "Gamma: $GAMMA_FORMATTED"
    fi
fi

echo ""
echo "📄 File: $(basename "$VIDEO_PATH")"
