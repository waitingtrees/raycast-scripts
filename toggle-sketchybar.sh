#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle SketchyBar
# @raycast.mode silent
# @raycast.packageName System

# Optional parameters:
# @raycast.icon 🍫

# Documentation:
# @raycast.description Toggle SketchyBar on or off
# @raycast.author assistant2

if pgrep -x sketchybar > /dev/null; then
    brew services stop sketchybar
    echo "⏸️ SketchyBar stopped"
else
    brew services start sketchybar
    echo "▶️ SketchyBar started"
fi
