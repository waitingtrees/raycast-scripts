#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Download YouTube Audio List
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🎵
# @raycast.packageName Media

# Documentation:
# @raycast.description Download audio from a list of YouTube videos in clipboard as MP3
# @raycast.author assistant2

# Function to download a single URL
download_url() {
    local url="$1"
    local original_url="$url"
    local invidious_url=""

    echo "----------------------------------------"
    echo "Processing: $url"

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

    # Try method 1: YouTube with iOS client
    echo "Attempting download from YouTube..."
    yt-dlp -x --audio-format mp3 \
        --cookies-from-browser safari \
        --user-agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        --extractor-args "youtube:player_client=ios,web" \
        --no-warnings \
        "$url"

    if [ $? -eq 0 ]; then
        echo "✓ Audio downloaded!"
        return 0
    fi

    # Try method 2: If we have an Invidious URL, try downloading directly from it
    if [ -n "$invidious_url" ]; then
        echo "YouTube failed, trying Invidious instance directly..."
        yt-dlp -x --audio-format mp3 \
            --no-check-certificate \
            --referer "$invidious_url" \
            --no-warnings \
            "$invidious_url"

        if [ $? -eq 0 ]; then
            echo "✓ Audio downloaded!"
            return 0
        fi
    fi

    # Try method 3: YouTube without cookies (sometimes cookies cause issues)
    echo "Trying YouTube without cookies..."
    yt-dlp -x --audio-format mp3 \
        --user-agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        --extractor-args "youtube:player_client=android" \
        --no-warnings \
        "$url"

    if [ $? -eq 0 ]; then
        echo "✓ Audio downloaded!"
        return 0
    fi

    # All methods failed
    echo "✗ Download failed for: $original_url"
    return 1
}

# Download to Downloads folder
cd ~/Downloads || { echo "Failed to access Downloads folder"; exit 1; }

# Get content from clipboard
clipboard_content=$(pbpaste)

if [ -z "$clipboard_content" ]; then
    echo "Clipboard is empty!"
    exit 1
fi

# Count total lines
total_lines=$(echo "$clipboard_content" | grep -cve '^\s*$')
current=0
failed=0

echo "Found $total_lines items in clipboard."

# Loop through each line in the clipboard
while IFS= read -r line; do
    # Clean the line: remove quotes and trim whitespace
    cleaned_line=$(echo "$line" | tr -d '"' | tr -d "'" | xargs)

    # Extract URL from the line (handles numbered lists, descriptions, etc.)
    cleaned_line=$(echo "$cleaned_line" | grep -oE 'https?://[^ )]+')


    # Skip empty lines
    if [[ -z "$cleaned_line" ]]; then
        continue
    fi
    
    ((current++))
    echo ""
    echo "[$current/$total_lines] Starting..."
    
    download_url "$cleaned_line"
    if [ $? -ne 0 ]; then
        ((failed++))
    fi
    
    # Add a small delay to be nice to YouTube servers
    sleep 2
    
done <<< "$clipboard_content"

echo ""
echo "========================================"
echo "Batch processing complete!"
if [ $failed -eq 0 ]; then
    echo "All $total_lines downloads successful."
else
    echo "$failed out of $total_lines downloads failed."
fi
exit 0
