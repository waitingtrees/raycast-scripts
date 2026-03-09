#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Jump to Fusion Clean
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🎬
# @raycast.packageName DaVinci Resolve

# Documentation:
# @raycast.description Switches to Fusion page and loads Cole Fusion 2512 layout
# @raycast.author assistant2

python3 << 'EOF'
import sys
sys.path.append('/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/Modules')
import DaVinciResolveScript as dvr

resolve = dvr.scriptapp("Resolve")
resolve.OpenPage("fusion")
resolve.LoadLayoutPreset("Cole Fusion 2512")

# Get composition and show Viewer1
fusion = resolve.Fusion()
comp = fusion.GetCurrentComp()
if comp:
    comp.DoAction("Fusion_View_Show", {"view": "Viewer1"})
EOF

# Wait for Resolve to switch pages and load layout
sleep 2.0

# Automate UI to ensure Single Viewer and Hidden Toolbar
# F4 (KeyCode 118) toggles Single/Dual Viewer
# "Show Toolbar" in Fusion menu toggles the toolbar
osascript -e '
tell application "DaVinci Resolve" to activate
delay 0.5
tell application "System Events"
    tell process "DaVinci Resolve"
        # Force Single Viewer (F4)
        key code 118
        
        # Toggle Toolbar (Hide it)
        # Note: We assume the Layout Preset loads with Toolbar visible, so this click hides it.
        # We try to find "Show Toolbar". If it says "Hide Toolbar", we leave it alone.
        try
            if exists menu item "Show Toolbar" of menu "Fusion" of menu bar 1 then
                click menu item "Show Toolbar" of menu "Fusion" of menu bar 1
            end if
        end try
    end tell
end tell'