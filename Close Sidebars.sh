#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Close Sidebars
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📖
# @raycast.packageName Reading

# Documentation:
# @raycast.description Press left bracket then right bracket to close sidebars
# @raycast.author assistant2

osascript -e 'tell application "System Events" to keystroke "["'
sleep 0.1
osascript -e 'tell application "System Events" to keystroke "]"'
