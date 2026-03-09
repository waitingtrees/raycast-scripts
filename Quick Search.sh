#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Quick Search
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🔍

# Get selected text using AppleScript
selected_text=$(osascript -e 'tell application "System Events" to keystroke "c" using command down' 2>/dev/null && sleep 0.1 && pbpaste)

# If no selection, try clipboard
if [ -z "$selected_text" ]; then
    selected_text=$(pbpaste)
fi

# URL encode the text
encoded_text=$(echo "$selected_text" | perl -pe 's/([^A-Za-z0-9_.~-])/sprintf("%%%02X",ord($1))/ge')

# Open in default browser
open "https://www.google.com/search?q=${encoded_text}"