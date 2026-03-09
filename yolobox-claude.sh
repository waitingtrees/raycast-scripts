#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Yolobox Claude
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🤖
# @raycast.packageName Developer Utils

# Get the current Finder directory
current_dir=$(osascript -e 'tell application "Finder" to get POSIX path of (insertion location as alias)')

# Check if Ghostty is running
ghostty_running=$(osascript -e 'tell application "System Events" to (name of processes) contains "Ghostty"' 2>/dev/null)

if [ "$ghostty_running" = "true" ]; then
    # Ghostty is running, activate and open new tab
    osascript <<EOF
tell application "Ghostty"
    activate
end tell
delay 0.5
tell application "System Events"
    tell process "Ghostty"
        set frontmost to true
        delay 0.2
        keystroke "t" using command down
        delay 0.5
        keystroke "cd \"$current_dir\" && ~/.local/bin/yolobox"
        keystroke return
        delay 2.0
        tell application "Ghostty" to activate
        keystroke "claude"
        keystroke return
    end tell
end tell
EOF
else
    # Ghostty not running, launch it in the directory
    osascript <<EOF
do shell script "open -a Ghostty"
delay 1.5
tell application "System Events"
    tell process "Ghostty"
        set frontmost to true
        delay 0.2
        keystroke "cd \"$current_dir\" && ~/.local/bin/yolobox"
        keystroke return
        delay 0.5
        tell application "Ghostty" to activate
        keystroke "claude"
        keystroke return
    end tell
end tell
EOF
fi
