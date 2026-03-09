#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Start Video Review in Finder Folder
# @raycast.mode silent
# @raycast.packageName Video

# Optional parameters:
# @raycast.icon 🎬

# Documentation:
# @raycast.description Launch video-review app using the current Finder folder

set -euo pipefail

PYTHON_BIN="$(command -v python3 || true)"
APP_SCRIPT="$HOME/PROJECTS/review app/video-review/review_gui.py"

if [[ -z "$PYTHON_BIN" ]]; then
  osascript -e 'display notification "python3 not found" with title "Video Review"'
  exit 1
fi

if [[ ! -f "$APP_SCRIPT" ]]; then
  osascript -e 'display notification "review.py not found" with title "Video Review"'
  exit 1
fi

TARGET_DIR="$(osascript <<'OSA'
try
  tell application "Finder"
    if (count of windows) > 0 then
      return POSIX path of (target of front window as alias)
    else
      return POSIX path of (insertion location as alias)
    end if
  end tell
on error
  return ""
end try
OSA
)"

if [[ -z "$TARGET_DIR" || ! -d "$TARGET_DIR" ]]; then
  osascript -e 'display notification "Open a Finder folder first" with title "Video Review"'
  exit 1
fi

pkill -f "$APP_SCRIPT" >/dev/null 2>&1 || true

nohup env \
  LC_NUMERIC=C \
  QT_OPENGL=software \
  QT_DISABLE_HW_TEXTURES_CONVERSION=1 \
  "$PYTHON_BIN" "$APP_SCRIPT" "$TARGET_DIR" \
  >/tmp/video-review-gui.log 2>&1 &
