#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title EPUB to PDF
# @raycast.mode silent
# @raycast.packageName Conversion

# Optional parameters:
# @raycast.icon 📖

# Documentation:
# @raycast.description Convert selected .epub file(s) in Finder to PDF
# @raycast.author assistant2

export PATH="/opt/homebrew/bin:$PATH"

# Get selected files from Finder
selected=$(osascript -e '
tell application "Finder"
    set selectedItems to selection
    if (count of selectedItems) is 0 then
        return ""
    end if
    set filePaths to ""
    repeat with anItem in selectedItems
        set filePaths to filePaths & POSIX path of (anItem as alias) & linefeed
    end repeat
    return filePaths
end tell
' 2>/dev/null)

if [ -z "$selected" ]; then
    echo "❌ No files selected in Finder"
    exit 1
fi

count=0
errors=0

while IFS= read -r filepath; do
    [ -z "$filepath" ] && continue

    if [[ "$filepath" != *.epub ]]; then
        echo "⚠️  Skipping non-epub: $(basename "$filepath")"
        continue
    fi

    output="${filepath%.epub}.pdf"
    basename=$(basename "$filepath")

    echo "⚡ Converting: $basename"

    if ebook-convert "$filepath" "$output" 2>&1; then
        echo "✅ Created: $(basename "$output")"
        ((count++))
    else
        echo "❌ Failed: $basename"
        ((errors++))
    fi
done <<< "$selected"

if [ "$count" -gt 0 ]; then
    echo ""
    echo "✅ Done — $count file(s) converted"
fi

if [ "$errors" -gt 0 ]; then
    echo "❌ $errors file(s) failed"
fi
