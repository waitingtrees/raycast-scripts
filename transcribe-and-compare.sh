#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Transcribe & Compare Script
# @raycast.mode silent
# @raycast.packageName Video Production

# Optional parameters:
# @raycast.icon 📝

# Documentation:
# @raycast.description Transcribe audio OR compare existing transcript against script document
# @raycast.author assistant2

WHISPER_PATH="$HOME/Library/Python/3.10/bin/whisper"
COMPARE_SCRIPT="$HOME/.config/claude-code/helpers/compare_script_transcript.py"

# Get selected file from Finder
selected_file=$(osascript -e 'tell application "Finder"
    set selectedItems to selection as alias list
    if selectedItems is {} then return ""
    return POSIX path of (item 1 of selectedItems)
end tell')

if [ -z "$selected_file" ]; then
    afplay /System/Library/Sounds/Basso.aiff &
    exit 1
fi

# Check if it's an audio/video file (needs transcription)
is_audio=false
if [[ "$selected_file" =~ \.(mp3|wav|m4a|flac|ogg|aac|mp4|mov|avi|mkv|MP4|MOV|MP3|WAV|M4A)$ ]]; then
    is_audio=true
fi

# Find project root by looking for "02 Documents" folder
find_project_root() {
    local dir="$1"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/02 Documents" ]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

project_root=$(find_project_root "$(dirname "$selected_file")")

if [ -z "$project_root" ]; then
    afplay /System/Library/Sounds/Basso.aiff &
    exit 1
fi

docs_folder="$project_root/02 Documents"
transcript_file="$docs_folder/transcription.txt"

# Check that there's at least one .docx script file in Documents folder
script_count=$(find "$docs_folder" -maxdepth 1 -name "*.docx" -type f | wc -l | xargs)

if [ "$script_count" -eq 0 ]; then
    afplay /System/Library/Sounds/Basso.aiff &
    exit 1
fi

# If not audio, we need an existing transcript
if [ "$is_audio" = false ] && [ ! -f "$transcript_file" ]; then
    afplay /System/Library/Sounds/Basso.aiff &
    exit 1
fi

# Play started sound
afplay /System/Library/Sounds/Pop.aiff &

# Run the work in a fully detached background process
nohup bash -c "
    report_file=\"$docs_folder/comparison_report.txt\"

    if [ \"$is_audio\" = true ]; then
        # AUDIO FILE: Transcribe first
        temp_dir=\$(mktemp -d)

        # Boost audio volume using ffmpeg normalization
        boosted_audio=\"\$temp_dir/boosted_audio.wav\"
        ffmpeg -i \"$selected_file\" -af \"loudnorm=I=-16:TP=-1.5:LRA=11\" \"\$boosted_audio\" -y > /dev/null 2>&1

        if [ -f \"\$boosted_audio\" ]; then
            audio_to_transcribe=\"\$boosted_audio\"
        else
            audio_to_transcribe=\"$selected_file\"
        fi

        # Run Whisper
        \"$WHISPER_PATH\" \"\$audio_to_transcribe\" --model small --output_dir \"\$temp_dir\" --output_format txt > /dev/null 2>&1

        # Find the transcription output
        if [ -f \"\$boosted_audio\" ]; then
            whisper_output=\"\$temp_dir/boosted_audio.txt\"
        else
            base_name=\$(basename \"$selected_file\" | sed 's/\.[^.]*$//')
            whisper_output=\"\$temp_dir/\$base_name.txt\"
        fi

        if [ ! -f \"\$whisper_output\" ]; then
            rm -rf \"\$temp_dir\"
            afplay /System/Library/Sounds/Basso.aiff
            exit 1
        fi

        # Save transcription to Documents folder
        cp \"\$whisper_output\" \"$transcript_file\"
        rm -rf \"\$temp_dir\"
    fi

    # ALWAYS compare using transcription.txt (whether we just created it or it existed)
    python3 \"$COMPARE_SCRIPT\" \"$transcript_file\" \"$docs_folder\" \"\$report_file\" > /dev/null 2>&1

    # Play completion sound
    afplay /System/Library/Sounds/Glass.aiff
" > /dev/null 2>&1 &

disown

exit 0
