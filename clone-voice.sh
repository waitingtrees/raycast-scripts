#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Clone Voice
# @raycast.mode silent
# @raycast.packageName Audio

# Optional parameters:
# @raycast.icon 🎙️
# @raycast.argument1 { "type": "text", "placeholder": "Text to speak" }
# @raycast.argument2 { "type": "dropdown", "placeholder": "Model", "data": [{"title": "Qwen3 Pro", "value": "qwen-pro"}, {"title": "Chatterbox", "value": "chatterbox"}] }

# Documentation:
# @raycast.description Clone a voice from selected Finder audio file(s) and generate new speech
# @raycast.author assistant2

QWEN_DIR="$HOME/qwen3-tts"
PYTHON="$QWEN_DIR/.venv/bin/python"
QWEN_SCRIPT="$QWEN_DIR/clone_voice.py"
CHATTERBOX_SCRIPT="$QWEN_DIR/clone_voice_chatterbox.py"

# Get selected files from Finder
SELECTED=$(osascript -e '
tell application "Finder"
    set theSelection to selection
    if (count of theSelection) is 0 then
        return ""
    end if
    set filePaths to ""
    repeat with theItem in theSelection
        set filePaths to filePaths & POSIX path of (theItem as alias) & linefeed
    end repeat
    return filePaths
end tell' 2>/dev/null)

if [ -z "$SELECTED" ]; then
    echo "❌ No files selected in Finder. Select a reference audio file first."
    exit 1
fi

TEXT="$1"
if [ -z "$TEXT" ]; then
    echo "❌ No text provided."
    exit 1
fi

# Model selection (defaults to qwen-pro if not specified)
MODEL_CHOICE="${2:-qwen-pro}"

# Collect valid audio files
AUDIO_FILES=()
FIRST_DIR=""
while IFS= read -r FILE; do
    [ -z "$FILE" ] && continue

    EXT="${FILE##*.}"
    EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
    case "$EXT_LOWER" in
        wav|mp3|m4a|aac|flac|ogg|aiff|aif)
            AUDIO_FILES+=("$FILE")
            [ -z "$FIRST_DIR" ] && FIRST_DIR=$(dirname "$FILE")
            ;;
        *)
            echo "⚠️ Skipping non-audio file: $(basename "$FILE")"
            ;;
    esac
done <<< "$SELECTED"

if [ ${#AUDIO_FILES[@]} -eq 0 ]; then
    echo "❌ No audio files selected."
    exit 1
fi

# If multiple files, concatenate into one combined reference
if [ ${#AUDIO_FILES[@]} -gt 1 ]; then
    COMBINED="/tmp/qwen_tts_combined_$$.wav"

    INPUTS=""
    FILTER=""
    for i in "${!AUDIO_FILES[@]}"; do
        INPUTS="$INPUTS -i \"${AUDIO_FILES[$i]}\""
        FILTER="${FILTER}[$i:a]"
    done
    FILTER="${FILTER}concat=n=${#AUDIO_FILES[@]}:v=0:a=1[out]"

    eval ffmpeg -y -v error $INPUTS -filter_complex "\"$FILTER\"" -map "\"[out]\"" -ar 24000 -ac 1 -c:a pcm_s16le "\"$COMBINED\"" 2>&1
    if [ $? -ne 0 ]; then
        echo "❌ Failed to combine audio files."
        exit 1
    fi

    REF_AUDIO="$COMBINED"
else
    REF_AUDIO="${AUDIO_FILES[0]}"
    COMBINED=""
fi

# Output goes next to the first selected file, with versioning
FIRST_FILE="${AUDIO_FILES[0]}"
FIRST_EXT="${FIRST_FILE##*.}"
FIRST_BASE=$(basename "$FIRST_FILE" ".$FIRST_EXT")
OUTPUT="$FIRST_DIR/${FIRST_BASE}_cloned.wav"

if [ -f "$OUTPUT" ]; then
    VER=2
    while [ -f "$FIRST_DIR/${FIRST_BASE}_cloned_v${VER}.wav" ]; do
        VER=$((VER + 1))
    done
    OUTPUT="$FIRST_DIR/${FIRST_BASE}_cloned_v${VER}.wav"
fi

# Run the selected model
case "$MODEL_CHOICE" in
    chatterbox)
        RESULT=$("$PYTHON" "$CHATTERBOX_SCRIPT" "$REF_AUDIO" "$TEXT" "$OUTPUT" 2>&1)
        ;;
    qwen-pro)
        RESULT=$("$PYTHON" "$QWEN_SCRIPT" "$REF_AUDIO" "$TEXT" "$OUTPUT" --model pro 2>&1)
        ;;
    qwen-lite)
        RESULT=$("$PYTHON" "$QWEN_SCRIPT" "$REF_AUDIO" "$TEXT" "$OUTPUT" --model lite 2>&1)
        ;;
esac
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Generated: $(basename "$OUTPUT")"
    afplay /System/Library/Sounds/Submarine.aiff &
else
    echo "❌ Failed: $RESULT"
fi

# Cleanup combined temp file
[ -n "$COMBINED" ] && rm -f "$COMBINED"
