#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Fusion Batch Render
# @raycast.mode silent
# @raycast.packageName Video

# Optional parameters:
# @raycast.icon 🎬

# Documentation:
# @raycast.description Set all Fusion comps to 4K ProRes 4444, output to Finder window, render all
# @raycast.author assistant2

FUSCRIPT="/Applications/Blackmagic Fusion 20/Fusion.app/Contents/Libraries/fuscript"
SCRIPT="$HOME/raycast scripts/fusion-batch-render.lua"

if [ ! -x "$FUSCRIPT" ]; then
    echo "❌ fuscript not found at: $FUSCRIPT"
    exit 1
fi

if [ ! -f "$SCRIPT" ]; then
    echo "❌ Lua script not found at: $SCRIPT"
    exit 1
fi

"$FUSCRIPT" -q -l lua "$SCRIPT" >/dev/null 2>&1
