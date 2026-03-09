#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Render All Savers
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🔨
# @raycast.packageName Hammer Macros

# Documentation:
# @raycast.description Shortcat: RENDER ALL → START workflow
# @raycast.author assistant2

osascript <<'EOF'
-- Hyper+S to open Shortcat
tell application "System Events"
    key code 1 using {control down, shift down, command down, option down}
end tell
delay 0.4

-- Type "RENDER ALL"
tell application "System Events"
    keystroke "RENDER ALL"
end tell
delay 0.4

-- Press Enter
tell application "System Events"
    key code 36
end tell
delay 0.4

-- Hyper+S to open Shortcat again
tell application "System Events"
    key code 1 using {control down, shift down, command down, option down}
end tell
delay 0.4

-- Type "START"
tell application "System Events"
    keystroke "START"
end tell
delay 0.4

-- Press Enter
tell application "System Events"
    key code 36
end tell
EOF
