#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Move Downloads to Finder
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📥
# @raycast.packageName File Management

# Documentation:
# @raycast.description Moves files from Downloads to the active Finder window (auto-routes footage/music in project folders)
# @raycast.author assistant2

osascript <<'APPLESCRIPT'
set downloadsPath to (path to downloads folder) as text
set downloadsPosix to POSIX path of downloadsPath

-- File extension lists
set videoExtensions to {"mov", "mp4", "avi", "mkv", "mxf", "m4v", "webm", "mpg", "mpeg", "m2v", "r3d", "braw", "avi"}
set audioExtensions to {"mp3", "wav", "aiff", "aif", "flac", "m4a", "ogg", "aac", "wma"}
set documentExtensions to {"pdf", "docx", "doc", "xlsx", "xls", "pptx", "ppt", "txt", "rtf"}

-- Helper function to get file extension (must be outside tell block)
on getExtension(fileName)
    set AppleScript's text item delimiters to "."
    set nameParts to text items of fileName
    set AppleScript's text item delimiters to ""
    if (count of nameParts) > 1 then
        return item -1 of nameParts
    else
        return ""
    end if
end getExtension

tell application "Finder"
    -- Check if any windows are open
    if (count of Finder windows) = 0 then
        return
    end if

    -- Find Downloads window and destination window
    set downloadsWindow to missing value
    set destinationWindow to missing value
    set destinationPath to missing value
    set destinationPosix to ""

    repeat with win in Finder windows
        try
            set winTarget to target of win
            set winPath to POSIX path of (winTarget as text)

            if winPath = downloadsPosix then
                set downloadsWindow to win
            else if destinationWindow is missing value then
                set destinationWindow to win
                set destinationPath to winTarget
                set destinationPosix to winPath
            end if
        end try
    end repeat

    -- If frontmost is Downloads, find next window as destination
    try
        set frontWindow to Finder window 1
        set frontTarget to target of frontWindow
        set frontPath to POSIX path of (frontTarget as text)

        if frontPath = downloadsPosix then
            -- Frontmost is Downloads, look for next non-Downloads window
            if (count of Finder windows) > 1 then
                repeat with i from 2 to (count of Finder windows)
                    try
                        set win to Finder window i
                        set winTarget to target of win
                        set winPath to POSIX path of (winTarget as text)
                        if winPath is not equal to downloadsPosix then
                            set destinationWindow to win
                            set destinationPath to winTarget
                            set destinationPosix to winPath
                            exit repeat
                        end if
                    end try
                end repeat
            end if
        else
            -- Frontmost is not Downloads, use it as destination
            set destinationWindow to frontWindow
            set destinationPath to frontTarget
            set destinationPosix to frontPath
        end if
    end try

    -- Check if we have a valid destination
    if destinationWindow is missing value or destinationPath is missing value then
        return
    end if

    -- Find project root by looking for "04 Resources" in path or parent folders
    set projectRoot to missing value
    set brollFolder to missing value
    set musicFolder to missing value
    set documentsFolder to missing value
    set audioOutFolder to missing value

    -- Check if we're inside a project structure
    if destinationPosix contains "04 Resources" or destinationPosix contains "02 Documents" then
        -- Extract project root (everything before the numbered folder)
        set projectRootPosix to destinationPosix
        if destinationPosix contains "04 Resources" then
            set AppleScript's text item delimiters to "04 Resources"
            set pathParts to text items of destinationPosix
            set projectRootPosix to item 1 of pathParts
            set AppleScript's text item delimiters to ""
        else if destinationPosix contains "02 Documents" then
            set AppleScript's text item delimiters to "02 Documents"
            set pathParts to text items of destinationPosix
            set projectRootPosix to item 1 of pathParts
            set AppleScript's text item delimiters to ""
        end if

        -- Build paths to special folders
        set brollPosix to projectRootPosix & "04 Resources/01 Footage/02 B-Roll/"
        set musicPosix to projectRootPosix & "04 Resources/02 Audio/Music/"
        set documentsPosix to projectRootPosix & "02 Documents/"
        set audioOutPosix to projectRootPosix & "04 Resources/02 Audio/Mixed/Audio_OUT/"

        try
            set brollFolder to POSIX file brollPosix as alias
        end try
        try
            set musicFolder to POSIX file musicPosix as alias
        end try
        try
            set documentsFolder to POSIX file documentsPosix as alias
        end try
        try
            set audioOutFolder to POSIX file audioOutPosix as alias
        end try
    else
        -- Check if 04 Resources exists as child of destination
        try
            set resourcesTest to POSIX file (destinationPosix & "04 Resources/") as alias
            set brollPosix to destinationPosix & "04 Resources/01 Footage/02 B-Roll/"
            set musicPosix to destinationPosix & "04 Resources/02 Audio/Music/"
            set documentsPosix to destinationPosix & "02 Documents/"
            set audioOutPosix to destinationPosix & "04 Resources/02 Audio/Mixed/Audio_OUT/"
            try
                set brollFolder to POSIX file brollPosix as alias
            end try
            try
                set musicFolder to POSIX file musicPosix as alias
            end try
            try
                set documentsFolder to POSIX file documentsPosix as alias
            end try
            try
                set audioOutFolder to POSIX file audioOutPosix as alias
            end try
        end try
    end if

    set filesToMove to {}
    set moveCount to 0
    set brollCount to 0
    set musicCount to 0
    set docsCount to 0
    set audioOutCount to 0
    set skippedCount to 0

    if downloadsWindow is not missing value then
        -- Primary flow: Downloads window is open, get selected files
        set theSelection to selection

        if (count of theSelection) = 0 then
            return
        end if

        -- Filter selection to only Downloads items
        repeat with item_ in theSelection
            try
                set itemPath to POSIX path of (item_ as text)
                if itemPath starts with downloadsPosix then
                    set end of filesToMove to item_
                end if
            end try
        end repeat

        if (count of filesToMove) = 0 then
            return
        end if
    else
        -- Fallback flow: No Downloads window, move ALL files from Downloads
        set downloadsFolder to (path to downloads folder)
        set allItems to every item of downloadsFolder

        if (count of allItems) = 0 then
            return
        end if

        set filesToMove to allItems
    end if

    -- Move the files with smart routing
    repeat with item_ in filesToMove
        try
            set fileName to name of item_
            set fileExt to my getExtension(fileName)
            set lowExt to do shell script "echo " & quoted form of fileExt & " | tr '[:upper:]' '[:lower:]'"

            set targetFolder to destinationPath
            set wasRouted to false

            -- Check if file has "-esv" in name and audioOut folder exists
            if audioOutFolder is not missing value and fileName contains "-esv" then
                set targetFolder to audioOutFolder
                set wasRouted to "audioout"
            -- Check if video file and broll folder exists
            else if brollFolder is not missing value and lowExt is in videoExtensions then
                set targetFolder to brollFolder
                set wasRouted to "broll"
            -- Check if audio file and music folder exists
            else if musicFolder is not missing value and lowExt is in audioExtensions then
                set targetFolder to musicFolder
                set wasRouted to "music"
            -- Check if document file and documents folder exists
            else if documentsFolder is not missing value and lowExt is in documentExtensions then
                set targetFolder to documentsFolder
                set wasRouted to "docs"
            end if

            -- Check if file already exists at destination
            set fileExists to false
            try
                set existingFile to (targetFolder as text) & fileName
                set testFile to existingFile as alias
                set fileExists to true
            end try

            if fileExists then
                set skippedCount to skippedCount + 1
            else
                -- Use shell mv instead of Finder move to ensure cross-volume (NAS) transfers
                -- complete fully before the source is removed. Finder's move can return early.
                set sourcePosix to POSIX path of (item_ as text)
                set destPosix to POSIX path of (targetFolder as text)
                do shell script "mv -n " & quoted form of sourcePosix & " " & quoted form of destPosix
                set moveCount to moveCount + 1

                if wasRouted = "broll" then
                    set brollCount to brollCount + 1
                else if wasRouted = "music" then
                    set musicCount to musicCount + 1
                else if wasRouted = "docs" then
                    set docsCount to docsCount + 1
                else if wasRouted = "audioout" then
                    set audioOutCount to audioOutCount + 1
                end if
            end if
        end try
    end repeat

end tell
APPLESCRIPT
