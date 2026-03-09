#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Clear Downloads to Trash
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🗑️
# @raycast.packageName System

# Documentation:
# @raycast.description Moves all files from Downloads, Desktop, and Frame Watch Folder to Trash
# @raycast.author assistant2

# Bulk delete all items from Downloads, Desktop, and Frame Watch Folder in one sweep each
# Uses single AppleScript call per folder instead of per-file for much faster execution

osascript <<'EOF'
tell application "Finder"
    -- Delete all items from Downloads
    try
        delete every item of folder "Downloads" of home
    end try

    -- Delete all items from Desktop
    try
        delete every item of folder "Desktop" of home
    end try

    -- Delete all items from Frame Watch Folder
    try
        delete every item of (POSIX file "$HOME/Frame Watch Folder" as alias)
    end try
end tell
EOF