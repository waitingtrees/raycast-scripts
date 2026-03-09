#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toolbar
# @raycast.mode silent
# @raycast.packageName DaVinci Resolve

# Optional parameters:
# @raycast.icon 🎬

# Documentation:
# @raycast.description Toggle toolbar on DaVinci Resolve Fusion page
# @raycast.author assistant2

osascript -e '
tell application "System Events"
    tell process "Resolve"
        click menu item "Show Toolbar" of menu "Fusion" of menu bar 1
    end tell
end tell
' 2>/dev/null

