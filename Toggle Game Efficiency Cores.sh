#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Game Efficiency Cores
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🎮
# @raycast.packageName System

PROCESS_NAME="On-Together"
STATE_FILE="/tmp/game-ecore-state"

PIDS=$(pgrep -f "$PROCESS_NAME")

if [ -z "$PIDS" ]; then
    echo "On-Together is not running"
    exit 1
fi

if [ -f "$STATE_FILE" ]; then
    # Currently throttled, switch back to normal
    for p in $PIDS; do
        taskpolicy -B -p "$p"
    done
    pkill -f "cpulimit" 2>/dev/null
    rm "$STATE_FILE"
    echo "On-Together → Normal mode"
else
    # Move to E-cores + limit CPU per process
    for p in $PIDS; do
        taskpolicy -b -p "$p"
        /opt/homebrew/bin/cpulimit -p "$p" -l 3 -b
    done
    touch "$STATE_FILE"
    echo "On-Together → Throttled (E-cores + 3% CPU)"
fi
