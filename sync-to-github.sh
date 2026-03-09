#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sync Scripts to GitHub
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🔄

# Documentation:
# @raycast.description Syncs raycast scripts to GitHub repository
# @raycast.author assistant2

# Copy everything from raycast scripts to GitHub scripts folder
rsync -av --delete --exclude='.DS_Store' "/Users/assistant2/raycast scripts/" "/Users/assistant2/Documents/GitHub/scripts/raycast scripts/"

# Push to GitHub
cd /Users/assistant2/Documents/GitHub/scripts
git add .
git commit -m "Auto-sync raycast scripts - $(date +%Y-%m-%d\ %H:%M:%S)"
echo "✅ Committed locally (no push)"
