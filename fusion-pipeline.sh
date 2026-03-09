#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Fusion Pipeline (Export + Render)
# @raycast.mode fullOutput
# @raycast.packageName Video

# Optional parameters:
# @raycast.icon 🎬

# Documentation:
# @raycast.description Export Fusion Comps from Resolve timeline, open in Fusion Studio, render all as 4K ProRes 4444
# @raycast.author assistant2

FUSCRIPT="/Applications/Blackmagic Fusion 20/Fusion.app/Contents/Libraries/fuscript"
SCRIPT_DIR="$HOME/raycast scripts"
MANIFEST="/tmp/fusion-export-manifest.txt"

if [ ! -x "$FUSCRIPT" ]; then
    echo "❌ fuscript not found"
    exit 1
fi

# Step 1: Export Fusion Composition clips from Resolve
echo "⚡ Step 1/2: Exporting Fusion Comps from Resolve..."
"$FUSCRIPT" -l lua "$SCRIPT_DIR/fusion-export-from-resolve.lua" 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Export from Resolve failed"
    exit 1
fi

if [ ! -f "$MANIFEST" ]; then
    echo "❌ No comps exported (manifest not found)"
    exit 1
fi

COMP_COUNT=$(wc -l < "$MANIFEST" | tr -d ' ')
echo ""
echo "✅ Exported $COMP_COUNT comp(s)"
echo ""

# Step 2: Load in Fusion Studio, configure, and render
echo "⚡ Step 2/2: Loading comps in Fusion Studio and rendering..."
"$FUSCRIPT" -l lua "$SCRIPT_DIR/fusion-batch-render.lua" "$MANIFEST" 2>&1

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Fusion Studio render failed"
    exit 1
fi

# Cleanup
rm -f "$MANIFEST"

echo ""
echo "✅ Pipeline complete"
