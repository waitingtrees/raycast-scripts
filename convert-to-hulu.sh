#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Convert to Hulu Spec
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📺
# @raycast.packageName Video

# Documentation:
# @raycast.description Convert to Hulu/NBCU spec (ProRes 422 HQ, 29.97fps DF30, 4:2:2, interlaced TFF, 24-bit PCM)
# @raycast.author assistant2

# Get selected files from Finder
file_paths=$(osascript -e '
tell application "Finder"
    set theSelection to selection as alias list
    set posixPaths to {}
    repeat with theItem in theSelection
        set end of posixPaths to POSIX path of theItem
    end repeat
    set AppleScript'\''s text item delimiters to linefeed
    return posixPaths as text
end tell
' 2>/dev/null)

[ -z "$file_paths" ] && exit 1

# Create a standalone worker script with all commands
worker_script="/tmp/hulu_convert_$$.sh"

cat > "$worker_script" << 'WORKER_EOF'
#!/bin/bash
while IFS= read -r input_file; do
    [ -z "$input_file" ] && continue
    extension="${input_file##*.}"
    extension_lower=$(echo "$extension" | tr "[:upper:]" "[:lower:]")
    [[ ! "$extension_lower" =~ ^(mp4|mov|mxf|avi|mkv|m4v)$ ]] && continue

    dir=$(dirname "$input_file")
    bname=$(basename "$input_file" ".$extension")
    prefix="${bname%_*}"
    suffix="${bname##*_}"
    output_file="${dir}/${prefix}_HULU_${suffix}.mov"

    # Hulu/NBCU specs: ProRes 422 HQ, 1920x1080, 29.97fps DF30, interlaced TFF, 4:2:2 10-bit, 24-bit 48kHz PCM
    /opt/homebrew/bin/ffmpeg -y -i "$input_file" \
        -c:v prores_ks \
        -profile:v 3 \
        -pix_fmt yuv422p10le \
        -s 1920x1080 \
        -r 30000/1001 \
        -flags +ildct+ilme \
        -top 1 \
        -timecode "00:00:00;00" \
        -c:a pcm_s24le \
        -ar 48000 \
        -ac 2 \
        -movflags +faststart \
        "$output_file" </dev/null 2>/dev/null
done
afplay /System/Library/Sounds/Glass.aiff
rm "$0"
WORKER_EOF

chmod +x "$worker_script"

# Run worker script in background with caffeinate to prevent sleep
echo "$file_paths" | caffeinate -i nohup "$worker_script" > /dev/null 2>&1 &
disown

exit 0