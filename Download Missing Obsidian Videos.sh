#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Download Missing Obsidian Videos
# @raycast.mode silent
# @raycast.packageName Media

# Optional parameters:
# @raycast.icon 🎧

# Documentation:
# @raycast.description Download missing Sound Sanctuary Obsidian Series videos as MP3
# @raycast.author assistant2

CHANNEL_URL="https://www.youtube.com/channel/UC7GZzOWjuG4wMua82uEguXQ"
DOWNLOAD_DIR="/Users/assistant2/Library/Mobile Documents/com~apple~CloudDocs/SOUND SANCTUARY/The Obsidian Series"

echo "=== Sound Sanctuary - The Obsidian Series ==="
echo "Missing Video Downloader"
echo ""

# Check for yt-dlp
if ! command -v yt-dlp &> /dev/null; then
    echo "❌ Error: yt-dlp is not installed!"
    echo "Install with: brew install yt-dlp"
    exit 1
fi

# Verify download directory exists
if [ ! -d "$DOWNLOAD_DIR" ]; then
    echo "❌ Error: Download directory not found"
    echo "   $DOWNLOAD_DIR"
    exit 1
fi

cd "$DOWNLOAD_DIR" || exit 1

# Step 1: Get existing video numbers from local folder (MP3 files)
echo "📂 Scanning local folder..."
LOCAL_NUMBERS=()
HIGHEST_LOCAL=0

while IFS= read -r file; do
    # Extract number from start of filename
    if [[ "$file" =~ ^([0-9]+) ]]; then
        NUM="${BASH_REMATCH[1]}"
        NUM_INT=$((10#$NUM))  # Convert to integer
        LOCAL_NUMBERS+=("$NUM_INT")
        if [ "$NUM_INT" -gt "$HIGHEST_LOCAL" ]; then
            HIGHEST_LOCAL=$NUM_INT
        fi
    fi
done < <(ls -1 *.mp3 2>/dev/null)

echo "   Found ${#LOCAL_NUMBERS[@]} MP3 files"
echo "   Highest number: $HIGHEST_LOCAL"
echo ""

# Step 2: Fetch channel video list
echo "🔍 Fetching channel video list..."
CHANNEL_VIDEOS=$(yt-dlp --flat-playlist --print "%(title)s|||%(id)s" "$CHANNEL_URL" 2>/dev/null)

if [ -z "$CHANNEL_VIDEOS" ]; then
    echo "❌ Error: Could not fetch channel videos"
    exit 1
fi

TOTAL_CHANNEL=$(echo "$CHANNEL_VIDEOS" | wc -l | xargs)
echo "   Found $TOTAL_CHANNEL videos on channel"
echo ""

# Step 3: Find videos with numbers higher than what we have
echo "🔎 Checking for new videos..."
MISSING_VIDEOS=()
MISSING_TITLES=()

while IFS= read -r line; do
    TITLE=$(echo "$line" | cut -d'|' -f1)
    VIDEO_ID=$(echo "$line" | cut -d'|' -f4)

    # Extract number from title
    if [[ "$TITLE" =~ ^([0-9]+) ]]; then
        NUM="${BASH_REMATCH[1]}"
        NUM_INT=$((10#$NUM))

        # Check if this number is higher than our highest local
        if [ "$NUM_INT" -gt "$HIGHEST_LOCAL" ]; then
            MISSING_VIDEOS+=("$NUM_INT|$VIDEO_ID|$TITLE")
            MISSING_TITLES+=("$TITLE")
        fi
    fi
done <<< "$CHANNEL_VIDEOS"

# Step 4: Report findings
if [ ${#MISSING_VIDEOS[@]} -eq 0 ]; then
    echo "✅ You're all caught up! No new videos to download."
    exit 0
fi

echo "📋 Found ${#MISSING_VIDEOS[@]} new video(s):"
echo ""

# Sort by number and display
SORTED_VIDEOS=$(printf '%s\n' "${MISSING_VIDEOS[@]}" | sort -t'|' -k1 -n)

while IFS='|' read -r NUM VIDEO_ID TITLE; do
    printf "   %03d - %s\n" "$NUM" "$TITLE"
done <<< "$SORTED_VIDEOS"

echo ""

# Step 5: Ask for confirmation via dialog
VIDEO_LIST=""
COUNT=0
while IFS='|' read -r NUM VIDEO_ID TITLE; do
    COUNT=$((COUNT + 1))
    if [ $COUNT -le 5 ]; then
        VIDEO_LIST+="• $TITLE\n"
    fi
done <<< "$SORTED_VIDEOS"

if [ ${#MISSING_VIDEOS[@]} -gt 5 ]; then
    REMAINING=$((${#MISSING_VIDEOS[@]} - 5))
    VIDEO_LIST+="...and $REMAINING more"
fi

RESPONSE=$(osascript -e "display dialog \"Download ${#MISSING_VIDEOS[@]} new video(s) as MP3?\n\n$(echo -e "$VIDEO_LIST")\" buttons {\"Cancel\", \"Download\"} default button \"Download\" with title \"Obsidian Series Downloader\"" 2>/dev/null)

if [[ ! "$RESPONSE" =~ "Download" ]]; then
    echo "❌ Download cancelled."
    exit 0
fi

# Step 6: Download each missing video as MP3
echo "⬇️  Starting downloads..."
echo ""

DOWNLOADED=0
FAILED=0
TOTAL=${#MISSING_VIDEOS[@]}

while IFS='|' read -r NUM VIDEO_ID TITLE; do
    CURRENT=$((DOWNLOADED + FAILED + 1))

    # Create clean filename: "089 // Chime Box" -> "089-Chime Box"
    CLEAN_NAME=$(echo "$TITLE" | sed 's/ \/\/ /-/')

    echo "[$CURRENT/$TOTAL] 🔄 Downloading: $CLEAN_NAME"

    yt-dlp \
        -x \
        --audio-format mp3 \
        --audio-quality 0 \
        --cookies-from-browser safari \
        --user-agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        --extractor-args "youtube:player_client=ios,web" \
        --output "$CLEAN_NAME.%(ext)s" \
        "https://www.youtube.com/watch?v=$VIDEO_ID" 2>&1

    if [ $? -eq 0 ]; then
        echo "✅ Saved as: $CLEAN_NAME.mp3"
        DOWNLOADED=$((DOWNLOADED + 1))
    else
        echo "❌ Failed: $TITLE"
        FAILED=$((FAILED + 1))
    fi
    echo ""
done <<< "$SORTED_VIDEOS"

# Step 7: Summary
echo "=== Download Complete ==="
echo "✅ Successfully downloaded: $DOWNLOADED"
if [ $FAILED -gt 0 ]; then
    echo "❌ Failed: $FAILED"
fi
echo ""

# Show notification
osascript -e "display notification \"Downloaded $DOWNLOADED of $TOTAL videos\" with title \"Obsidian Series\" sound name \"Glass\""
