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

# Notify client listeners via ntfy.sh
CLIENTS_DIR="$HOME/raycast scripts/clients"
if [ -d "$CLIENTS_DIR" ]; then
  for client_dir in "$CLIENTS_DIR"/*/; do
    client_name=$(basename "$client_dir")
    if [ "$client_name" != "*" ]; then
      curl -sf -d "update" "https://ntfy.sh/waitingtrees-${client_name}-scripts" > /dev/null 2>&1 &
    fi
  done
  wait
fi

echo "✅ Synced to GitHub"
