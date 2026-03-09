#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Start Break
# @raycast.mode silent
# @raycast.packageName Utilities

# Optional parameters:
# @raycast.icon 👀

# Documentation:
# @raycast.description Click "Start this break now" in LookAway menu bar
# @raycast.author assistant2

osascript -e '
tell application "System Events"
    tell process "LookAway"
        -- Click the menu bar icon
        click menu bar item 1 of menu bar 2
        delay 0.5
        -- Hover over "Your break begins in" to open submenu
        set breakItem to menu item 1 of menu 1 of menu bar item 1 of menu bar 2
        -- Try to find the menu item that starts with "Your break begins in"
        set foundIt to false
        repeat with mi in menu items of menu 1 of menu bar item 1 of menu bar 2
            set itemName to name of mi
            if itemName starts with "Your break begins in" then
                -- Hover to reveal submenu
                click mi
                delay 0.3
                -- Click "Start this break now" in the submenu
                click menu item "Start this break now" of menu 1 of mi
                set foundIt to true
                exit repeat
            end if
        end repeat
        if not foundIt then
            error "Could not find break menu item"
        end if
    end tell
end tell
' 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Break started"
else
    echo "❌ Could not click LookAway button — make sure the app is running"
fi
