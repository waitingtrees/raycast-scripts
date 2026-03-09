#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Dump Downloads to Finder
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📦
# @raycast.packageName File Management

# Documentation:
# @raycast.description Moves all Downloads files to the current Finder window
# @raycast.author assistant2

osascript <<'APPLESCRIPT'
set downloadsPath to (path to downloads folder) as text
set downloadsPosix to POSIX path of downloadsPath

tell application "Finder"
    if (count of Finder windows) = 0 then return

    -- Find frontmost non-Downloads window
    set destinationPath to missing value
    repeat with i from 1 to (count of Finder windows)
        try
            set win to Finder window i
            set winPath to POSIX path of (target of win as text)
            if winPath is not equal to downloadsPosix then
                set destinationPath to target of win
                exit repeat
            end if
        end try
    end repeat

    if destinationPath is missing value then return

    set allItems to every item of (path to downloads folder)
    if (count of allItems) = 0 then return

    repeat with item_ in allItems
        try
            set fileName to name of item_
            set fileExists to false
            try
                set testFile to ((destinationPath as text) & fileName) as alias
                set fileExists to true
            end try
            if not fileExists then move item_ to destinationPath
        end try
    end repeat
end tell
APPLESCRIPT
