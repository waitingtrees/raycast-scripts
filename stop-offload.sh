#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Stop Offload
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🛑
# @raycast.packageName Video Automation

# Documentation:
# @raycast.description Immediately kills the offload script and any active rsync processes.
# @raycast.author assistant2

# 1. Kill the main script logic
# -f matches the full command line name
pkill -f "offload-media.sh" 2>/dev/null

# 2. Kill the actual file transfer process
# This stops the data writing immediately
pkill -f "rsync" 2>/dev/null

# 3. Kill the Python report generator (if it reached that stage)
pkill -f "generate_footage_report.py" 2>/dev/null

echo "🛑 Offload aborted"
