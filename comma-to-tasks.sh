#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Comma to Tasks
# @raycast.mode silent

# Optional parameters:
# @raycast.icon ✅

# Get selected text by copying it
osascript -e 'tell application "System Events" to keystroke "c" using command down' 2>/dev/null
sleep 0.1
selected_text=$(pbpaste)

# Exit if no text
if [ -z "$selected_text" ]; then
    echo "No text selected"
    exit 1
fi

# Convert comma-separated text to markdown tasks
# - Split by comma
# - Trim whitespace
# - Capitalize first letter
# - Remove trailing period
# - Format as markdown checkbox
result=$(echo "$selected_text" | python3 -c "
import sys

text = sys.stdin.read().strip()

# Remove trailing period from the entire string
if text.endswith('.'):
    text = text[:-1]

# Split by comma and process each item
items = [item.strip() for item in text.split(',')]
items = [item for item in items if item]  # Remove empty items

# Capitalize first letter of each item and format as task
tasks = []
for item in items:
    if item:
        capitalized = item[0].upper() + item[1:] if len(item) > 1 else item.upper()
        tasks.append(f'- [ ] {capitalized}')

print('\n'.join(tasks))
")

# Copy result to clipboard
echo "$result" | pbcopy

# Paste the result back (replacing selection)
osascript -e 'tell application "System Events" to keystroke "v" using command down' 2>/dev/null
