#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle DND
# @raycast.mode silent
# @raycast.packageName System

# Optional parameters:
# @raycast.icon 🔕

# Documentation:
# @raycast.description Toggle Do Not Disturb — block all notification banners (texts, apps, everything)
# @raycast.author assistant2

STATE_FILE="$HOME/.cache/.dnd-state"
mkdir -p "$HOME/.cache"

if [ -f "$STATE_FILE" ]; then
    shortcuts run "DND Off" 2>/dev/null
    rm -f "$STATE_FILE"
    echo "🔔 Notifications ON"
else
    shortcuts run "DND On" 2>/dev/null
    touch "$STATE_FILE"
    echo "🔕 Do Not Disturb — all banners silenced"
fi
