#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Process Batch Car Video
# @raycast.mode compact
# @raycast.packageName Video Automation
# @raycast.icon 🚗

# Documentation:
# @raycast.description Scans current Finder folder for car project assets and builds Resolve timeline.
# @raycast.author assistant2
# @raycast.authorURL https://raycast.com

# 1. Get current Finder path
PROJECT_ROOT=$(osascript -e 'tell application "Finder" to get POSIX path of (target of front window as alias)')

if [ -z "$PROJECT_ROOT" ]; then
  echo "Error: No Finder window open or could not get path."
  exit 1
fi

echo "Scanning Project: $PROJECT_ROOT"

# 2. Run the Python Script
# NOTE: User needs to ensure the python path is correct.
# We assume the main.py is in a fixed location, likely where the user installed the BatchCarSystem.
# Adjust the path below to where you actually keep the script!
SCRIPT_PATH="$HOME/batch car project/BatchCarSystem/main.py"

python3 "$SCRIPT_PATH" --root "$PROJECT_ROOT"

if [ $? -eq 0 ]; then
  echo "Batch Complete! Check '05 Delivery'."
else
  echo "Error running batch script."
  exit 1
fi
