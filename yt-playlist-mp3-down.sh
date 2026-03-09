#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Download YouTube Playlist Audio
# @raycast.mode fullOutput
# @raycast.packageName Media

# Optional parameters:
# @raycast.icon 🎶

# Documentation:
# @raycast.description Download all videos from a YouTube playlist as MP3
# @raycast.author assistant2

# Get URL from clipboard
url=$(pbpaste)

if [ -z "$url" ]; then
    echo "❌ Clipboard is empty!"
    exit 1
fi

# Validate it looks like a playlist URL
if [[ ! "$url" =~ (list=|/playlist) ]]; then
    echo "⚠️ URL doesn't look like a playlist. Use the single video script instead."
    echo "URL: $url"
    exit 1
fi

# Download to Downloads folder
cd ~/Downloads

echo "⚡ Downloading playlist as MP3..."
echo "$url"
echo ""

# Try method 1: YouTube with cookies + iOS client
yt-dlp -x --audio-format mp3 \
    --cookies-from-browser safari \
    --user-agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
    --extractor-args "youtube:player_client=ios,web" \
    --yes-playlist \
    --no-warnings \
    -o "%(playlist_title)s/%(title)s.%(ext)s" \
    "$url" 2>/dev/null

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Playlist downloaded to Downloads folder!"
    exit 0
fi

# Try method 2: YouTube without cookies
echo ""
echo "Retrying without cookies..."
yt-dlp -x --audio-format mp3 \
    --user-agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
    --extractor-args "youtube:player_client=android" \
    --yes-playlist \
    --no-warnings \
    -o "%(playlist_title)s/%(title)s.%(ext)s" \
    "$url" 2>/dev/null

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Playlist downloaded to Downloads folder!"
    exit 0
fi

echo ""
echo "❌ Download failed. Try updating yt-dlp: yt-dlp -U"
exit 1
