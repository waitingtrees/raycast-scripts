#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Transcribe Audio
# @raycast.mode silent
# @raycast.packageName File Utils

# Optional parameters:
# @raycast.icon 🎤

# Documentation:
# @raycast.description Transcribe selected audio files in Finder to a single text file
# @raycast.author assistant2

WHISPER_PATH="/Users/assistant2/Library/Python/3.10/bin/whisper"

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

# Check if files were selected
if [ -z "$selected_files" ]; then
    echo "❌ No files selected in Finder"
    exit 1
fi

# Get directory of first audio file
first_file=$(echo "$selected_files" | head -n 1)
output_dir=$(dirname "$first_file")

# Create output file in same directory as audio files with timestamp
timestamp=$(date +"%Y%m%d_%H%M%S")
output_file="$output_dir/transcription_$timestamp.txt"

echo "🎤 Starting transcription..."
echo "📝 Output will be saved to: $(basename "$output_file")"
echo ""

# Counter for processed files
count=0
total=$(echo "$selected_files" | wc -l | xargs)

# Process each file
while IFS= read -r file; do
    if [ -z "$file" ]; then
        continue
    fi

    count=$((count + 1))
    filename=$(basename "$file")

    # Check if file exists
    if [ ! -f "$file" ]; then
        echo "⚠️  Skipping (not found): $filename"
        continue
    fi

    # Check if it's an audio/video file (common extensions)
    if [[ ! "$file" =~ \.(mp3|wav|m4a|flac|ogg|aac|mp4|mov|avi|mkv)$ ]]; then
        echo "⚠️  Skipping (not audio/video): $filename"
        continue
    fi

    echo "[$count/$total] 🔄 Transcribing: $filename"

    # Add filename as header to output file
    echo "=== $filename ===" >> "$output_file"
    echo "" >> "$output_file"

    # Create temp directory
    temp_dir=$(mktemp -d)

    # Boost audio volume using ffmpeg normalization (for quiet files)
    boosted_audio="$temp_dir/boosted_audio.wav"
    ffmpeg -i "$file" -af "loudnorm=I=-16:TP=-1.5:LRA=11" "$boosted_audio" -y > /dev/null 2>&1

    # Use boosted audio if ffmpeg succeeded, otherwise use original
    if [ -f "$boosted_audio" ]; then
        audio_to_transcribe="$boosted_audio"
    else
        audio_to_transcribe="$file"
    fi

    # Transcribe using Whisper (small model for faster processing, auto-detect language)
    "$WHISPER_PATH" "$audio_to_transcribe" --model small --output_dir "$temp_dir" --output_format txt 2>&1 | grep -v "^Detecting language"

    # Get the transcription text file (Whisper creates it with the same name as input)
    if [ -f "$boosted_audio" ]; then
        base_name="boosted_audio"
    else
        base_name=$(basename "$file" | sed 's/\.[^.]*$//')
    fi
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

    # Clean up temp directory
    rm -rf "$temp_dir"

done <<< "$selected_files"

echo ""
echo "✨ All done! Transcription saved to:"
echo "   $output_file"
