#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Download YouTube Audio
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🎵
# @raycast.packageName Media

# Documentation:
# @raycast.description Download audio from YouTube video as MP3
# @raycast.author assistant2

# Get URL from clipboard
url=$(pbpaste)
original_url="$1"
invidious_url=""

# Extract video ID from Invidious URL and keep both URLs
if [[ "$url" =~ (inv\.|invidious\.) ]]; then
    # Extract video ID from Invidious URL (format: https://inv.domain.com/watch?v=VIDEO_ID)
    video_id=$(echo "$url" | grep -oE '[?&]v=([^&]+)' | cut -d'=' -f2)
    if [ -n "$video_id" ]; then
        invidious_url="$url"
        url="https://www.youtube.com/watch?v=$video_id"
        echo "Detected Invidious URL, will try YouTube first..."
    fi
fi

# Download to Downloads folder
cd ~/Downloads

# Try method 1: YouTube with iOS client
echo "Attempting download from YouTube..."
yt-dlp -x --audio-format mp3 \
    --cookies-from-browser safari \
    --user-agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
    --extractor-args "youtube:player_client=ios,web" \
    --no-warnings \
    "$url" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✓ Audio downloaded to Downloads folder!"
    exit 0
fi

# Try method 2: If we have an Invidious URL, try downloading directly from it
if [ -n "$invidious_url" ]; then
    echo "YouTube failed, trying Invidious instance directly..."
    yt-dlp -x --audio-format mp3 \
        --no-check-certificate \
        --referer "$invidious_url" \
        --no-warnings \
        "$invidious_url" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "✓ Audio downloaded to Downloads folder!"
        exit 0
    fi
fi

# Try method 3: YouTube without cookies (sometimes cookies cause issues)
echo "Trying YouTube without cookies..."
yt-dlp -x --audio-format mp3 \
    --user-agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
    --extractor-args "youtube:player_client=android" \
    --no-warnings \
    "$url" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✓ Audio downloaded to Downloads folder!"
    exit 0
fi

# All methods failed
echo "✗ Download failed with all methods."
echo "Please try updating yt-dlp: yt-dlp -U"
exit 1
