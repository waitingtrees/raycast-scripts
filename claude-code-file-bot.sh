#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Claude Code File Bot
# @raycast.mode silent
# @raycast.packageName Claude

# Optional parameters:
# @raycast.icon 🤖
# @raycast.argument1 { "type": "text", "placeholder": "What do you want done?" }

# Documentation:
# @raycast.description Run Claude Code on the selected Finder file with a prompt
# @raycast.author assistant2

# Get all selected Finder files
FILE_PATHS=$(osascript -e 'tell application "Finder"
  set sel to selection
  if (count of sel) is 0 then return ""
  set paths to {}
  repeat with f in sel
    set end of paths to POSIX path of (f as alias)
  end repeat
  set AppleScript'\''s text item delimiters to linefeed
  return paths as text
end tell' 2>/dev/null)

if [ -z "$FILE_PATHS" ]; then
  echo "❌ No files selected in Finder"
  exit 1
fi

# Build file list for the prompt
FILE_LIST=""
while IFS= read -r f; do
  FILE_LIST="$FILE_LIST
- $f"
done <<< "$FILE_PATHS"

$HOME/.local/bin/claude --dangerously-skip-permissions -p "Files:$FILE_LIST

$1" &>/dev/null &

echo "✅ Running"
