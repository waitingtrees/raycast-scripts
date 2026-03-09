#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Launch Dia (Debug Mode)
# @raycast.mode silent
# @raycast.packageName Browser

# Optional parameters:
# @raycast.icon 🌐

# Documentation:
# @raycast.description Launch Dia browser with Chrome DevTools Protocol enabled on port 9222
# @raycast.author assistant2

# Check if Dia is already running with debug port
if curl -s http://127.0.0.1:9222/json/version > /dev/null 2>&1; then
  echo "⚠️ Dia already running with CDP on port 9222"
  exit 0
fi

# Quit Dia if running without debug mode
if pgrep -x "Dia" > /dev/null 2>&1; then
  osascript -e 'tell application "Dia" to quit'
  sleep 2
fi

# Launch Dia with remote debugging
open -a "Dia" --args --remote-debugging-port=9222

# Wait for CDP to become available
for i in {1..10}; do
  if curl -s http://127.0.0.1:9222/json/version > /dev/null 2>&1; then
    echo "✅ Dia launched with CDP on port 9222"
    exit 0
  fi
  sleep 1
done

echo "❌ Dia launched but CDP not responding on port 9222"
exit 1
