#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Auto Bins
# @raycast.mode silent
# @raycast.packageName DaVinci Resolve

# Optional parameters:
# @raycast.icon 📁

# Documentation:
# @raycast.description Toggle the auto bin creator LaunchAgent on/off
# @raycast.author assistant2

set -u

PLIST="$HOME/Library/LaunchAgents/com.user.resolve-auto-bins.plist"
LABEL="com.user.resolve-auto-bins"
UID_VAL=$(id -u)
TARGET="gui/$UID_VAL/$LABEL"
DOMAIN="gui/$UID_VAL"

is_loaded() {
    launchctl print "$TARGET" >/dev/null 2>&1
}

get_state() {
    launchctl print "$TARGET" 2>/dev/null | awk -F'= ' '/^[[:space:]]*state = / {print $2; exit}'
}

get_pid() {
    launchctl print "$TARGET" 2>/dev/null | awk -F'= ' '/^[[:space:]]*pid = / {print $2; exit}'
}

if is_loaded; then
    # Currently loaded: disable watcher/daemon.
    if ! launchctl bootout "$TARGET" >/dev/null 2>&1; then
        launchctl bootout "$DOMAIN" "$PLIST" >/dev/null 2>&1 || true
    fi
    sleep 0.2

    if is_loaded; then
        state=$(get_state)
        pid=$(get_pid)
        echo "⚠️ Auto Bins still ON (state: ${state:-unknown}, pid: ${pid:-unknown})"
        exit 1
    fi

    echo "❌ Auto Bins OFF (watcher/daemon unloaded)"
else
    # Not loaded: enable watcher/daemon.
    if [ ! -f "$PLIST" ]; then
        echo "❌ Missing LaunchAgent plist: $PLIST"
        exit 1
    fi

    if ! launchctl bootstrap "$DOMAIN" "$PLIST" >/dev/null 2>&1; then
        # If already loaded in an unusual state, try to kickstart it.
        if is_loaded; then
            launchctl kickstart -k "$TARGET" >/dev/null 2>&1 || true
        else
            echo "❌ Failed to load Auto Bins LaunchAgent"
            exit 1
        fi
    fi

    sleep 0.2
    if ! is_loaded; then
        echo "❌ Auto Bins did not load"
        exit 1
    fi

    state=$(get_state)
    pid=$(get_pid)
    echo "✅ Auto Bins ON (state: ${state:-unknown}, pid: ${pid:-unknown})"
fi
