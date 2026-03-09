#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Restart Kokoro
# @raycast.mode silent
# @raycast.packageName TTS

# Optional parameters:
# @raycast.icon 🔄

# Documentation:
# @raycast.description Restart the Kokoro TTS daemon
# @raycast.author assistant2

launchctl unload ~/Library/LaunchAgents/com.user.kokoro-daemon.plist 2>/dev/null
sleep 1
launchctl load ~/Library/LaunchAgents/com.user.kokoro-daemon.plist 2>/dev/null
