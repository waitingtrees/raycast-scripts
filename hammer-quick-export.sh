#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Quick Export
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🔨
# @raycast.packageName Hammer Macros

# Documentation:
# @raycast.description Shortcat: QUICK → Enter x3 → REPLACE workflow
# @raycast.author assistant2

osascript <<'EOF'
-- Hyper+S to open Shortcat
tell application "System Events"
    key code 1 using {control down, shift down, command down, option down}
end tell
delay 0.3

-- Type "QUICK"
tell application "System Events"
    keystroke "QUICK"
end tell
delay 0.3

-- Press Enter three times
tell application "System Events"
    key code 36
end tell
delay 0.3

tell application "System Events"
    key code 36
end tell
delay 0.3

tell application "System Events"
    key code 36
end tell
delay 0.3

-- Hyper+S to open Shortcat again
tell application "System Events"
    key code 1 using {control down, shift down, command down, option down}
end tell
delay 0.3

-- Type "REPLACE"
tell application "System Events"
    keystroke "REPLACE"
end tell
delay 0.3

-- Press Enter
tell application "System Events"
    key code 36
end tell
EOF
