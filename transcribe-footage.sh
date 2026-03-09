#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Transcribe Footage
# @raycast.mode fullOutput
# @raycast.packageName Media

# Optional parameters:
# @raycast.icon 🎙️
# @raycast.argument1 { "type": "text", "placeholder": "Question about the footage" }

# Documentation:
# @raycast.description Extract audio from selected video files, transcribe, and analyze with Claude
# @raycast.author assistant2

WHISPER="$HOME/Library/Python/3.10/bin/whisper"
source "$(dirname "$0")/.env"
WORK_DIR="$HOME/Downloads/transcribe-$(date +%Y%m%d-%H%M%S)"
QUESTION="$1"

# Get all selected Finder files
FILE_PATHS=$(osascript -e 'tell application "Finder"
  set sel to selection
  if (count of sel) is 0 then return ""
  set paths to {}
  repeat with f in sel
    set end of paths to POSIX path of (f as alias)
  end repeat
  set AppleScript'\''s text item delimiters to linefeed
  return paths as text
end tell' 2>/dev/null)

if [ -z "$FILE_PATHS" ]; then
  echo "❌ No files selected in Finder"
  exit 1
fi

mkdir -p "$WORK_DIR"

# Count files
FILE_COUNT=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  ((FILE_COUNT++))
done <<< "$FILE_PATHS"
echo "📂 $FILE_COUNT file(s) selected"
echo "📁 Working in: $WORK_DIR"
echo ""

# Step 1: Extract audio as MP3 (small files = fast NAS reads + fast API uploads)
# MXF files often have 4-8 audio streams where only 1-2 have signal.
# We do ONE fast pass to sample all streams, check volumes locally, then extract the best.

find_best_audio_stream() {
  local file="$1"
  local tmpdir="$2"

  # Get audio stream indices (metadata only, fast)
  local streams
  streams=$(ffprobe -v quiet -show_entries stream=index,codec_type "$file" 2>/dev/null | \
    python3 -c "
import sys
idx = None
streams = []
for line in sys.stdin:
    line = line.strip()
    if line.startswith('index='):
        idx = line.split('=')[1]
    elif line == 'codec_type=audio' and idx:
        streams.append(idx)
        idx = None
    elif line.startswith('[/STREAM]'):
        idx = None
print(' '.join(streams))
" 2>/dev/null)

  [ -z "$streams" ] && echo "" && return

  # Single ffmpeg pass: extract 10s sample from ALL audio streams at once
  # This reads the file only ONCE instead of N times (critical for NAS speed)
  local args=(-i "$file" -t 10)
  for s in $streams; do
    args+=(-map "0:$s" -c:a pcm_s16le "$tmpdir/_probe_s${s}.wav")
  done
  args+=(-y -loglevel error)
  ffmpeg "${args[@]}" 2>/dev/null

  # Now check volumes on LOCAL files (instant)
  local best_stream=""
  local best_vol=-999
  for s in $streams; do
    local probe_file="$tmpdir/_probe_s${s}.wav"
    [ ! -f "$probe_file" ] && continue
    local vol
    vol=$(ffmpeg -i "$probe_file" -af "volumedetect" -f null /dev/null 2>&1 | \
      grep "mean_volume" | sed 's/.*mean_volume: //' | sed 's/ dB//')
    [ -z "$vol" ] && continue

    local is_better
    is_better=$(python3 -c "print('yes' if $vol > $best_vol else 'no')" 2>/dev/null)
    if [ "$is_better" = "yes" ]; then
      best_vol="$vol"
      best_stream="$s"
    fi
    rm -f "$probe_file"
  done

  # Only return if meaningful audio (> -70 dB)
  local has_signal
  has_signal=$(python3 -c "print('yes' if $best_vol > -70 else 'no')" 2>/dev/null)
  if [ "$has_signal" = "yes" ]; then
    echo "$best_stream"
  else
    echo ""
  fi
}

echo "⚡ Extracting audio to local disk..."
AUDIO_FILES=()
FAIL=0
while IFS= read -r filepath; do
  [ -z "$filepath" ] && continue
  fname=$(basename "$filepath" | sed 's/\.[^.]*$//')
  outfile="$WORK_DIR/${fname}.mp3"
  echo "  📁 $(basename "$filepath")"

  # Count audio streams
  STREAM_COUNT=$(ffprobe -v quiet -show_entries stream=codec_type "$filepath" 2>/dev/null | grep -c "codec_type=audio")

  if [ "$STREAM_COUNT" -le 1 ]; then
    # Single audio stream — just extract it directly
    echo "     ↳ Single audio stream"
    ffmpeg -i "$filepath" -vn -ac 1 -ar 16000 -b:a 64k \
      -af "highpass=f=200,loudnorm=I=-16:TP=-1.5:LRA=11" \
      "$outfile" -y -loglevel error
  else
    # Multiple streams — find the loudest one
    echo "     ↳ $STREAM_COUNT audio streams, finding best..."
    BEST=$(find_best_audio_stream "$filepath" "$WORK_DIR")
    if [ -z "$BEST" ]; then
      echo "     ⚠️  No usable audio found, skipping"
      ((FAIL++))
      continue
    fi
    echo "     ↳ Using stream $BEST"
    ffmpeg -i "$filepath" -map 0:$BEST -vn -ac 1 -ar 16000 -b:a 64k \
      -af "highpass=f=200,loudnorm=I=-16:TP=-1.5:LRA=11" \
      "$outfile" -y -loglevel error
  fi

  if [ $? -eq 0 ] && [ -s "$outfile" ]; then
    AUDIO_FILES+=("$outfile")
  else
    echo "     ⚠️  Extraction failed"
    ((FAIL++))
  fi
done <<< "$FILE_PATHS"

if [ "$FAIL" -gt 0 ]; then
  echo "⚠️  $FAIL file(s) had issues"
fi
echo "✅ Audio extracted (${#AUDIO_FILES[@]} files)"
echo ""

# Step 2: Transcribe each audio file
# Chain: Groq Whisper API → Gemini → local Whisper

transcribe_groq() {
  local file="$1"
  local result
  result=$(curl -s --max-time 120 "https://api.groq.com/openai/v1/audio/transcriptions" \
    -H "Authorization: Bearer $GROQ_KEY" \
    -F "model=whisper-large-v3-turbo" \
    -F "file=@$file" \
    -F "response_format=text" 2>&1)

  [ -z "$result" ] && return 1

  # Groq returns plain text on success, JSON on error
  # If python can parse it as JSON with an "error" key, it's a failure
  IS_ERROR=$(echo "$result" | python3 -c "
import sys, json
try:
    r = json.load(sys.stdin)
    print('yes' if 'error' in r else 'no')
except:
    print('no')
" 2>/dev/null)

  if [ "$IS_ERROR" = "yes" ]; then
    return 1
  fi

  echo "$result"
  return 0
}

transcribe_gemini() {
  local file="$1"
  local b64
  b64=$(base64 -i "$file")

  local models=("gemini-2.0-flash" "gemini-2.5-flash" "gemini-2.5-flash-lite")
  for model in "${models[@]}"; do
    local response
    response=$(curl -s --max-time 180 \
      "https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=$GEMINI_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"contents\":[{\"parts\":[{\"inlineData\":{\"mimeType\":\"audio/mpeg\",\"data\":\"$b64\"}},{\"text\":\"Transcribe this audio exactly as spoken. Return only the transcription text, no commentary.\"}]}]}")

    local result
    result=$(echo "$response" | python3 -c "
import sys, json
try:
    r = json.load(sys.stdin)
    if 'candidates' in r:
        print(r['candidates'][0]['content']['parts'][0]['text'])
    elif 'error' in r and r['error'].get('code') == 429:
        print('RATE_LIMITED')
    else:
        print('ERROR')
except:
    print('ERROR')
" 2>/dev/null)

    if [ "$result" = "RATE_LIMITED" ]; then
      continue
    elif [ "$result" = "ERROR" ] || [ -z "$result" ]; then
      continue
    else
      echo "$result"
      return 0
    fi
  done
  return 1
}

transcribe_local() {
  local file="$1"
  local outdir="$2"
  "$WHISPER" "$file" --model small --language en --output_format txt --output_dir "$outdir" 2>/dev/null
}

echo "⚡ Transcribing audio..."
for mp3 in "${AUDIO_FILES[@]}"; do
  [ ! -f "$mp3" ] && continue
  basename=$(basename "$mp3" .mp3)
  txtfile="$WORK_DIR/${basename}.txt"
  echo "  🎙️  $basename"

  # Try Groq API first
  TRANSCRIPT=$(transcribe_groq "$mp3")
  if [ $? -eq 0 ] && [ -n "$TRANSCRIPT" ]; then
    echo "$TRANSCRIPT" > "$txtfile"
    echo "     ✓ (Groq API)"
    continue
  fi

  # Try Gemini
  echo "     ↳ Groq unavailable, trying Gemini..."
  TRANSCRIPT=$(transcribe_gemini "$mp3")
  if [ $? -eq 0 ] && [ -n "$TRANSCRIPT" ]; then
    echo "$TRANSCRIPT" > "$txtfile"
    echo "     ✓ (Gemini)"
    continue
  fi

  # Local whisper fallback
  echo "     ↳ APIs unavailable, using local Whisper..."
  transcribe_local "$mp3" "$WORK_DIR"
  echo "     ✓ (local Whisper)"
done
echo "✅ Transcription complete"
echo ""

# Step 3: Combine all transcripts
COMBINED=""
for mp3 in "${AUDIO_FILES[@]}"; do
  basename=$(basename "$mp3" .mp3)
  txtfile="$WORK_DIR/${basename}.txt"
  if [ -f "$txtfile" ]; then
    COMBINED="${COMBINED}
## ${basename}

$(cat "$txtfile")

"
  fi
done

if [ -z "$COMBINED" ]; then
  echo "❌ No transcriptions produced"
  exit 1
fi

# Save raw transcripts
echo "$COMBINED" > "$WORK_DIR/transcripts.md"

# Step 4: Analyze with Claude
echo "⚡ Analyzing with Claude..."
OUTPUT_FILE="$WORK_DIR/analysis.md"

claude --dangerously-skip-permissions -p "$(cat <<EOF
Here are transcriptions from video footage files:

$COMBINED

---

Based on these transcriptions, answer the following:

$QUESTION

Format your response as clean, well-organized markdown. Include a "## Source Clips" section at the end listing which clip(s) each piece of information came from.
EOF
)" > "$OUTPUT_FILE" 2>/dev/null

echo "✅ Analysis complete"
echo ""
echo "📄 Analysis: $OUTPUT_FILE"
echo "📄 Raw transcripts: $WORK_DIR/transcripts.md"
open "$OUTPUT_FILE"
