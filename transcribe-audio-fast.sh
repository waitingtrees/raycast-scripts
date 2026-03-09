#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Transcribe Audio (Fast)
# @raycast.mode silent
# @raycast.packageName File Utils

# Optional parameters:
# @raycast.icon ⚡

# Documentation:
# @raycast.description Fast transcribe for clean/studio-recorded audio. Uses base model, no preprocessing.
# @raycast.author assistant2

WHISPER_PATH="$HOME/Library/Python/3.10/bin/whisper"

# Get selected files from Finder
selected_files=$(osascript -e 'tell application "Finder"
set selectedItems to selection as alias list
if selectedItems is {} then return ""
set fileList to {}
repeat with anItem in selectedItems
    set end of fileList to POSIX path of anItem
end repeat
set AppleScript'"'"'s text item delimiters to linefeed
fileList as text
end tell')

if [ -z "$selected_files" ]; then
    echo "❌ No files selected in Finder"
    exit 1
fi

first_file=$(echo "$selected_files" | head -n 1)
output_dir=$(dirname "$first_file")
timestamp=$(date +"%Y%m%d_%H%M%S")
output_file="$output_dir/transcription_$timestamp.txt"

echo "⚡ Fast transcription starting..."
echo "📝 Output: $(basename "$output_file")"
echo ""

count=0
total=$(echo "$selected_files" | wc -l | xargs)

while IFS= read -r file; do
    if [ -z "$file" ]; then
        continue
    fi

    count=$((count + 1))
    filename=$(basename "$file")

    if [ ! -f "$file" ]; then
        echo "⚠️  Skipping (not found): $filename"
        continue
    fi

    if [[ ! "$file" =~ \.(mp3|wav|m4a|flac|ogg|aac|mp4|mov|avi|mkv)$ ]]; then
        echo "⚠️  Skipping (not audio/video): $filename"
        continue
    fi

    echo "[$count/$total] ⚡ Transcribing: $filename"

    echo "=== $filename ===" >> "$output_file"
    echo "" >> "$output_file"

    temp_dir=$(mktemp -d)

    # Base model, no preprocessing — fast and accurate for clean audio
    "$WHISPER_PATH" "$file" --model base --output_dir "$temp_dir" --output_format txt 2>/dev/null

    base_name=$(basename "$file" | sed 's/\.[^.]*$//')
    transcription_file="$temp_dir/$base_name.txt"

    if [ -f "$transcription_file" ]; then
        cat "$transcription_file" >> "$output_file"
        echo "" >> "$output_file"
        echo "" >> "$output_file"
        echo "✅ Done: $filename"
    else
        echo "❌ Failed: $filename"
        echo "[Transcription failed]" >> "$output_file"
        echo "" >> "$output_file"
    fi

    rm -rf "$temp_dir"

done <<< "$selected_files"

echo ""
echo "⚡ All done! Transcription saved to:"
echo "   $output_file"
