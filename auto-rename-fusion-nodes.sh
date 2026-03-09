#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Auto Rename Fusion Nodes
# @raycast.mode silent
# @raycast.packageName Video

# Optional parameters:
# @raycast.icon 🏷️

# Documentation:
# @raycast.description Rename unnamed Fusion nodes in DaVinci Resolve (MediaIn, Background, Text, Transform, MultiMerge)
# @raycast.author assistant2

SCRIPT_DIR="$HOME/raycast scripts"

# Find fuscript — prefer Resolve's copy, fall back to Fusion Studio
FUSCRIPT="/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript"
if [ ! -x "$FUSCRIPT" ]; then
    FUSCRIPT="/Applications/Blackmagic Fusion 20/Fusion.app/Contents/Libraries/fuscript"
fi
if [ ! -x "$FUSCRIPT" ]; then
    echo "❌ fuscript not found"
    exit 1
fi

OUTPUT=$("$FUSCRIPT" -l lua "$SCRIPT_DIR/auto-rename-fusion-nodes.lua" 2>&1)

if echo "$OUTPUT" | grep -q "ERROR:"; then
    echo "❌ ${OUTPUT#*ERROR: }"
    exit 1
fi

# Extract renamed count from output
COUNT=$(echo "$OUTPUT" | grep -oE 'Renamed [0-9]+ node' | grep -oE '[0-9]+')
echo "✅ Renamed ${COUNT:-0} Fusion node(s)"
