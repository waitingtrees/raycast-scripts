#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Launch Claude YOLO
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🔥
# @raycast.packageName Claude

# Documentation:
# @raycast.description Launches Ghostty and starts Claude Code with --dangerously-skip-permissions
# @raycast.author assistant2

# Check if Ghostty is running
if pgrep -x "Ghostty" > /dev/null; then
    # Ghostty is already running
    osascript <<EOF
tell application "Ghostty"
    activate
end tell

tell application "System Events"
    keystroke "t" using command down
    delay 0.2
    keystroke "claude --dangerously-skip-permissions"
    delay 0.1
    keystroke return
    delay 0.6
    keystroke return
end tell
EOF
else
    # Ghostty is not running, launch it and wait
    open -a Ghostty
    sleep 1.5

    # Now create a new tab and type claude
    osascript <<EOF
tell application "Ghostty"
    activate
end tell

tell application "System Events"
    keystroke "t" using command down
    delay 0.2
    keystroke "claude --dangerously-skip-permissions"
    delay 0.1
    keystroke return
    delay 0.6
    keystroke return
end tell
EOF
fi
