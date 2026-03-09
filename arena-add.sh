#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Arena Add
# @raycast.mode compact
# @raycast.packageName Are.na

# Optional parameters:
# @raycast.icon 🔲
# @raycast.argument1 { "type": "text", "placeholder": "channel (blank = last used)", "optional": true }

# Documentation:
# @raycast.description Add clipboard (text, URL, file, image, PDF, GIF) to an Are.na channel
# @raycast.author assistant2

export PATH="/opt/homebrew/bin:$PATH"

source "$(dirname "$0")/.env"
LAST_CHANNEL_FILE="$HOME/.arena-last-channel"
CHANNEL_CACHE="$HOME/.arena-channels-cache"
CHANNEL_INPUT="${1:-}"

# Channel list (id|title|slug) — cached for 1 hour
refresh_channels() {
  if [ -f "$CHANNEL_CACHE" ] && [ $(($(date +%s) - $(stat -f%m "$CHANNEL_CACHE"))) -lt 3600 ]; then
    return
  fi
  curl -s "https://api.are.na/v3/users/constant/contents?per=100" \
    -H "Authorization: Bearer $ARENA_TOKEN" | \
    python3 -c "
import sys, json
d = json.load(sys.stdin)
for i in d.get('data', []):
    if i.get('type') == 'Channel':
        print(f\"{i['id']}|{i['title']}|{i['slug']}\")
" > "$CHANNEL_CACHE" 2>/dev/null
}

# Resolve channel from input
resolve_channel() {
  if [ -z "$CHANNEL_INPUT" ]; then
    if [ -f "$LAST_CHANNEL_FILE" ]; then
      cat "$LAST_CHANNEL_FILE"
      return 0
    else
      echo "❌ No channel specified and no previous channel"
      return 1
    fi
  fi

  refresh_channels

  MATCH=$(grep -i "$CHANNEL_INPUT" "$CHANNEL_CACHE" | head -1)
  if [ -z "$MATCH" ]; then
    echo "❌ No channel matching '$CHANNEL_INPUT'"
    return 1
  fi

  echo "$MATCH" > "$LAST_CHANNEL_FILE"
  echo "$MATCH"
}

# Detect if clipboard has file(s) from Finder — returns newline-separated paths
get_clipboard_files() {
  osascript -e '
    try
      set theItems to the clipboard as «class furl»
      return POSIX path of theItems
    on error
      try
        -- Multiple files come as a list of aliases
        set theFiles to paragraphs of (do shell script "osascript -e '\''tell application \"Finder\" to get POSIX path of (the clipboard as alias)'\''")
        set out to ""
        repeat with f in theFiles
          set out to out & f & linefeed
        end repeat
        return out
      on error
        return ""
      end try
    end try
  ' 2>/dev/null | sed '/^$/d'
}

# Try to extract raw clipboard image/PDF data to a temp file
# Checks: PNG, JPEG, TIFF, GIF, PDF (in priority order)
get_clipboard_raw_media() {
  local FORMATS="PNGf:png JPEGFFType:jpg TIFF:tiff GIFf:gif PDF :pdf"

  for entry in $FORMATS; do
    local CLASS="${entry%%:*}"
    local EXT="${entry##*:}"

    HAS=$(osascript -e "try
      the clipboard as «class $CLASS»
      return \"yes\"
    on error
      return \"no\"
    end try" 2>/dev/null)

    if [ "$HAS" = "yes" ]; then
      local TEMP=$(mktemp /tmp/arena-clip-XXXXXX."$EXT")
      osascript -e "set f to open for access POSIX file \"$TEMP\" with write permission
      write (the clipboard as «class $CLASS») to f
      close access f" 2>/dev/null

      if [ -s "$TEMP" ]; then
        echo "$TEMP"
        return 0
      else
        rm -f "$TEMP"
      fi
    fi
  done
  return 1
}

# Upload a file via presigned S3 URL, return the S3 URL
upload_file() {
  local FILE_PATH="$1"
  local FILENAME=$(basename "$FILE_PATH")
  local MIME=$(file --mime-type -b "$FILE_PATH")

  # Sanitize filename for JSON
  local SAFE_NAME=$(python3 -c "import json,sys; print(json.loads(json.dumps(sys.argv[1])))" "$FILENAME")

  PRESIGN=$(curl -s --max-time 15 -X POST "https://api.are.na/v3/uploads/presign" \
    -H "Authorization: Bearer $ARENA_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"files\": [{\"filename\": $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$FILENAME"), \"content_type\": \"$MIME\"}]}")

  UPLOAD_URL=$(echo "$PRESIGN" | python3 -c "import sys,json; print(json.load(sys.stdin)['files'][0]['upload_url'])" 2>/dev/null)
  S3_KEY=$(echo "$PRESIGN" | python3 -c "import sys,json; print(json.load(sys.stdin)['files'][0]['key'])" 2>/dev/null)

  if [ -z "$UPLOAD_URL" ] || [ -z "$S3_KEY" ]; then
    return 1
  fi

  curl -s --max-time 120 -X PUT "$UPLOAD_URL" -H "Content-Type: $MIME" --data-binary "@$FILE_PATH" > /dev/null 2>&1

  echo "https://s3.amazonaws.com/arena_images-temp/$S3_KEY"
}

# --- Main ---

CHANNEL_INFO=$(resolve_channel)
if [ $? -ne 0 ]; then
  echo "$CHANNEL_INFO"
  exit 1
fi

CHANNEL_ID=$(echo "$CHANNEL_INFO" | cut -d'|' -f1)
CHANNEL_TITLE=$(echo "$CHANNEL_INFO" | cut -d'|' -f2)

# Priority: 1) Finder file(s), 2) raw image/PDF data, 3) text/URL

# 1) Check for file(s) copied from Finder
FINDER_FILES=$(get_clipboard_files)
if [ -n "$FINDER_FILES" ]; then
  FAIL=0
  COUNT=0
  while IFS= read -r fp; do
    [ -z "$fp" ] && continue
    [ ! -f "$fp" ] && continue
    S3_URL=$(upload_file "$fp")
    if [ -z "$S3_URL" ]; then
      FAIL=$((FAIL + 1))
      continue
    fi
    ESCAPED=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$S3_URL")
    curl -s --max-time 15 -X POST "https://api.are.na/v3/blocks" \
      -H "Authorization: Bearer $ARENA_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"value\": $ESCAPED, \"channel_ids\": [$CHANNEL_ID]}" > /dev/null 2>&1
    COUNT=$((COUNT + 1))
  done <<< "$FINDER_FILES"

  if [ $COUNT -gt 0 ]; then
    MSG="✅ Added $COUNT file"
    [ $COUNT -gt 1 ] && MSG="${MSG}s"
    MSG="$MSG to $CHANNEL_TITLE"
    [ $FAIL -gt 0 ] && MSG="$MSG ($FAIL failed)"
    echo "$MSG"
  else
    echo "❌ Upload failed"
  fi
  exit 0
fi

# 2) Check for raw image/PDF clipboard data
TEMP_MEDIA=$(get_clipboard_raw_media)
if [ -n "$TEMP_MEDIA" ]; then
  S3_URL=$(upload_file "$TEMP_MEDIA")
  rm -f "$TEMP_MEDIA"
  if [ -z "$S3_URL" ]; then
    echo "❌ Upload failed"
    exit 1
  fi
  VALUE="$S3_URL"
else
  # 3) Text/URL flow
  VALUE=$(pbpaste)
  if [ -z "$VALUE" ]; then
    echo "❌ Clipboard is empty"
    exit 1
  fi
fi

# Create block via v3 API
ESCAPED_VALUE=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$VALUE")
RESULT=$(curl -s --max-time 15 -X POST "https://api.are.na/v3/blocks" \
  -H "Authorization: Bearer $ARENA_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"value\": $ESCAPED_VALUE, \"channel_ids\": [$CHANNEL_ID]}" 2>&1)

if echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('id') else 1)" 2>/dev/null; then
  echo "✅ Added to $CHANNEL_TITLE"
else
  ERR=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error', d.get('message', 'Unknown error')))" 2>/dev/null)
  echo "❌ $ERR"
  exit 1
fi
