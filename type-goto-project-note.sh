#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Go to Project Note
# @raycast.mode silent
# @raycast.packageName System

# Optional parameters:
# @raycast.icon 📝

# Documentation:
# @raycast.description Opens Finder to the project's .md note in 02 Documents

# Get the current Finder window path
CURRENT_DIR=$(osascript -e 'tell application "Finder" to POSIX path of (insertion location as alias)' 2>/dev/null)

if [ -z "$CURRENT_DIR" ]; then
    osascript -e 'display notification "No Finder window found" with title "Project Note" sound name "Basso"'
    exit 1
fi

# Walk up the directory tree to find folder containing "02 Documents"
SEARCH_DIR="$CURRENT_DIR"
PROJECT_ROOT=""

while [ "$SEARCH_DIR" != "/" ]; do
    if [ -d "$SEARCH_DIR/02 Documents" ]; then
        PROJECT_ROOT="$SEARCH_DIR"
        break
    fi
    SEARCH_DIR=$(dirname "$SEARCH_DIR")
done

if [ -z "$PROJECT_ROOT" ]; then
    osascript -e 'display notification "No project folder found (no 02 Documents)" with title "Project Note" sound name "Basso"'
    exit 1
fi

# Find the .md file in 02 Documents
DOCS_DIR="$PROJECT_ROOT/02 Documents"
MD_FILE=$(find "$DOCS_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | head -1)

if [ -z "$MD_FILE" ]; then
    osascript -e 'display notification "No .md file found in 02 Documents" with title "Project Note" sound name "Basso"'
    exit 1
fi

# Reveal the file in Finder (selects it)
open -R "$MD_FILE"
