#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Download Twitter Media
# @raycast.mode silent
# @raycast.packageName Media

# Optional parameters:
# @raycast.icon 🐦

# Documentation:
# @raycast.description Downloads a GIF or video from a Twitter/X URL in clipboard, saves to Desktop & copies to clipboard
# @raycast.author assistant2

URL=$(pbpaste | tr -d '[:space:]')

if [[ ! "$URL" =~ ^https?://(twitter\.com|x\.com|vxtwitter\.com|fxtwitter\.com)/ ]]; then
  echo "❌ No Twitter/X URL in clipboard"
  exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TMP_MP4="/tmp/twitter_media_${TIMESTAMP}.mp4"

# Download the video
if ! yt-dlp -q -o "$TMP_MP4" "$URL" 2>/dev/null; then
  echo "❌ Failed to download from Twitter"
  rm -f "$TMP_MP4"
  exit 1
fi

# Detect GIF vs video: Twitter GIFs are looping MP4s with NO audio track
AUDIO_STREAMS=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$TMP_MP4" 2>/dev/null | wc -l | tr -d ' ')

if [ "$AUDIO_STREAMS" -eq 0 ]; then
  # No audio = Twitter GIF — convert to actual GIF
  OUTPUT="$HOME/Desktop/twitter_gif_${TIMESTAMP}.gif"
  if ffmpeg -y -i "$TMP_MP4" -vf "fps=15,scale='min(480,iw)':-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer" -loop 0 "$OUTPUT" 2>/dev/null; then
    osascript -e "set the clipboard to (read (POSIX file \"$OUTPUT\") as GIF picture)"
    echo "✅ GIF saved to Desktop & copied to clipboard"
  else
    # Fallback to MP4 if GIF conversion fails
    OUTPUT="$HOME/Desktop/twitter_video_${TIMESTAMP}.mp4"
    mv "$TMP_MP4" "$OUTPUT"
    osascript -e "set the clipboard to (POSIX file \"$OUTPUT\")"
    echo "⚠️ Saved as MP4 instead (GIF conversion failed) & copied to clipboard"
    exit 0
  fi
  rm -f "$TMP_MP4"
else
  # Has audio = real video — keep as MP4
  OUTPUT="$HOME/Desktop/twitter_video_${TIMESTAMP}.mp4"
  mv "$TMP_MP4" "$OUTPUT"
  osascript -e "set the clipboard to (POSIX file \"$OUTPUT\")"
  echo "✅ Video saved to Desktop & copied to clipboard"
fi
