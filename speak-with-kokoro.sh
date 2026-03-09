#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Speak with Kokoro
# @raycast.mode silent
# @raycast.packageName TTS

# Optional parameters:
# @raycast.icon 🔊

# Documentation:
# @raycast.description Toggle: speak selected/clipboard text or stop speaking
# @raycast.author assistant2

SOCK="$HOME/.local/share/kokoro/kokoro.sock"
STATE="$HOME/.local/share/kokoro/speaking"

# If currently speaking, stop and exit
if [ -f "$STATE" ]; then
  echo -n "__STOP__" | /usr/bin/nc -U "$SOCK" 2>/dev/null
  exit 0
fi

# Try to copy selected text (if any)
OLD_CLIP=$(pbpaste 2>/dev/null)
osascript -e 'tell application "System Events" to keystroke "c" using command down' 2>/dev/null
sleep 0.3
TEXT=$(pbpaste 2>/dev/null)

# If nothing new was copied, fall back to existing clipboard
if [ -z "$TEXT" ]; then
  TEXT="$OLD_CLIP"
fi

if [ -z "$TEXT" ]; then
  exit 0
fi

echo -n "$TEXT" | /usr/bin/nc -U "$SOCK" 2>/dev/null
