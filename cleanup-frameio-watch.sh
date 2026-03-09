#!/bin/bash

WATCH_FOLDER="/Users/assistant2/Frame Watch Folder"

# Delete files older than 7 days
find "$WATCH_FOLDER" -type f -mtime +7 -delete

# Log the cleanup
echo "$(date): Cleaned Frame.io watch folder" >> "/Users/assistant2/cc scripts/frameio-cleanup.log"