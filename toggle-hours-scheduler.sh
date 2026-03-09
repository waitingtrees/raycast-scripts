#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Hours Scheduler
# @raycast.mode silent
# @raycast.packageName Automation

# Optional parameters:
# @raycast.icon 🕐

# Documentation:
# @raycast.description Enable/disable hourly Dayflow hours logging (9:30am-4:30pm)
# @raycast.author assistant2

PLIST="$HOME/Library/LaunchAgents/com.assistant2.log-hours.plist"
LABEL="com.assistant2.log-hours"

if launchctl list | grep -q "$LABEL"; then
    launchctl bootout gui/$(id -u) "$PLIST" 2>/dev/null
    echo "Stopped hours scheduler"
else
    launchctl bootstrap gui/$(id -u) "$PLIST" 2>/dev/null
    echo "Started hours scheduler (runs at :30 from 9:30am-4:30pm)"
fi
