#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Launch Claude Talking
# @raycast.mode silent
# @raycast.packageName Claude

# Optional parameters:
# @raycast.icon 🎙

# Documentation:
# @raycast.description Launches Claude Code in talking mode with Kokoro TTS
# @raycast.author assistant2

# Ensure Kokoro daemon is running
if ! pgrep -f kokoro-daemon > /dev/null 2>&1; then
  launchctl load ~/Library/LaunchAgents/com.user.kokoro-daemon.plist 2>/dev/null
  sleep 1
fi

# Stop any current speech
echo -n "__STOP__" | /usr/bin/nc -U ~/.local/share/kokoro/kokoro.sock 2>/dev/null

# Check if Ghostty is running
if pgrep -x "Ghostty" > /dev/null; then
    osascript <<EOF
tell application "Ghostty"
    activate
end tell

tell application "System Events"
    keystroke "t" using command down
    delay 0.2
    keystroke "~/.local/bin/claude-talking"
    delay 0.1
    keystroke return
    delay 0.6
    keystroke return
end tell
EOF
else
    open -a Ghostty
    sleep 1.5

    osascript <<EOF
tell application "Ghostty"
    activate
end tell

tell application "System Events"
    keystroke "t" using command down
    delay 0.2
    keystroke "~/.local/bin/claude-talking"
    delay 0.1
    keystroke return
    delay 0.6
    keystroke return
end tell
EOF
fi
