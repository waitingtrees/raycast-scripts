#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Re-Render
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🔨
# @raycast.packageName Hammer Macros

# Documentation:
# @raycast.description Shortcat: ADD → RE → REN workflow
# @raycast.author assistant2

osascript <<'EOF'
-- Hyper+S to open Shortcat
tell application "System Events"
    key code 1 using {control down, shift down, command down, option down}
end tell
delay 0.3

-- Type "ADD"
tell application "System Events"
    keystroke "ADD"
end tell
delay 0.3

-- Press Enter
tell application "System Events"
    key code 36
end tell
delay 0.3

-- Hyper+S to open Shortcat again
tell application "System Events"
    key code 1 using {control down, shift down, command down, option down}
end tell
delay 0.3

-- Type "RE"
tell application "System Events"
    keystroke "RE"
end tell
delay 0.3

-- Press Enter
tell application "System Events"
    key code 36
end tell
delay 0.3

-- Hyper+S to open Shortcat again
tell application "System Events"
    key code 1 using {control down, shift down, command down, option down}
end tell
delay 0.3

-- Type "REN"
tell application "System Events"
    keystroke "REN"
end tell
delay 0.3

-- Press Enter
tell application "System Events"
    key code 36
end tell
EOF
