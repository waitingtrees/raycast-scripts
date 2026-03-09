#!/bin/bash

WATCH_FOLDER="$HOME/Frame Watch Folder"

# Delete files older than 7 days
find "$WATCH_FOLDER" -type f -mtime +7 -delete

# Log the cleanup
echo "$(date): Cleaned Frame.io watch folder" >> "$HOME/cc scripts/frameio-cleanup.log"