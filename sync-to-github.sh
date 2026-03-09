#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sync Scripts to GitHub
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🔄

# Documentation:
# @raycast.description Commits and pushes raycast scripts to GitHub
# @raycast.author assistant2

cd "$HOME/raycast scripts" || exit 1

# Check for changes
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  echo "✅ Already up to date"
  exit 0
fi

git add -A
git commit -m "Sync scripts — $(date +%Y-%m-%d\ %H:%M:%S)"
git push
echo "✅ Synced to GitHub"
