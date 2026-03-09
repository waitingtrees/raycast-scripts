#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Quit Production Apps
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🎬
# @raycast.packageName Production Tools

# Documentation:
# @raycast.description Quits all video production applications
# @raycast.author assistant2

# Save and quit DaVinci Resolve
if pgrep -x "Resolve" > /dev/null; then
    echo "Saving DaVinci Resolve project..."
    python3 "$HOME/.config/claude-code/helpers/save_resolve_projects.py" 2>/dev/null
    sleep 0.5

    # Quit Resolve using pkill (more reliable than AppleScript)
    pkill -x "Resolve" 2>/dev/null

    # Wait briefly and force kill if still running
    sleep 1
    if pgrep -x "Resolve" > /dev/null; then
        pkill -9 -x "Resolve" 2>/dev/null
    fi
    echo "Quit DaVinci Resolve"
fi

# List of other apps to quit
apps=(
    "Fusion"
    "Fusion Studio"
    "Blender"
    "Steam"
    "On-Together"
    "Affinity"
)

# Quit exact app names gracefully
for app in "${apps[@]}"; do
    if pgrep -x "$app" > /dev/null; then
        osascript -e "tell application \"$app\" to quit" 2>/dev/null || killall "$app" 2>/dev/null
        echo "Quit $app"
    fi
done

# Save and quit After Effects
ae_process=$(pgrep -fl "After Effects" | head -1)
if [ -n "$ae_process" ]; then
    echo "Saving After Effects project..."
    ae_app=$(osascript -e 'tell application "System Events" to get name of first process whose name contains "After Effects"' 2>/dev/null)
    if [ -n "$ae_app" ]; then
        # Try to save via ExtendScript
        osascript <<EOF 2>/dev/null
tell application "$ae_app"
    activate
    do script "app.project.save(); app.quit();"
end tell
EOF
        sleep 2
    fi
    # Force quit if still running
    if pgrep -fl "After Effects" > /dev/null; then
        pkill -f "After Effects" 2>/dev/null
        sleep 1
        pkill -9 -f "After Effects" 2>/dev/null
    fi
    echo "Quit After Effects"
fi

# Save and quit Premiere Pro
pr_process=$(pgrep -fl "Premiere Pro" | head -1)
if [ -n "$pr_process" ]; then
    echo "Saving Premiere Pro project..."
    pr_app=$(osascript -e 'tell application "System Events" to get name of first process whose name contains "Premiere Pro"' 2>/dev/null)
    if [ -n "$pr_app" ]; then
        # Try to save via ExtendScript
        osascript <<EOF 2>/dev/null
tell application "$pr_app"
    activate
    do script "app.project.save(); app.quit();"
end tell
EOF
        sleep 2
    fi
    # Force quit if still running
    if pgrep -fl "Premiere Pro" > /dev/null; then
        pkill -f "Premiere Pro" 2>/dev/null
        sleep 1
        pkill -9 -f "Premiere Pro" 2>/dev/null
    fi
    echo "Quit Premiere Pro"
fi

# Quit other Adobe apps by pattern (handles yearly versions)
adobe_apps=("Adobe Media Encoder" "Adobe Photoshop")

for app in "${adobe_apps[@]}"; do
    pkill -f "$app" 2>/dev/null && echo "Quit $app"
done

# Kill orphaned AI processes
current_claude_pids=$(ps -eo pid,tty,comm | grep claude | grep -v '??' | grep -v grep | awk '{print $1}')
opencode_count=$(ps aux | grep -i opencode | grep -v grep | wc -l | tr -d ' ')
claude_orphan_count=$(ps -eo pid,tty,args | grep '/Users/assistant2/.local/bin/claude' | grep '??' | grep -v grep | wc -l | tr -d ' ')
ai_total=$((opencode_count + claude_orphan_count))

if [ "$ai_total" -gt 0 ]; then
    if [ "$opencode_count" -gt 0 ]; then
        ps aux | grep -i opencode | grep -v grep | awk '{print $2}' | xargs kill 2>/dev/null
    fi
    if [ "$claude_orphan_count" -gt 0 ]; then
        ps -eo pid,tty,args | grep '/Users/assistant2/.local/bin/claude' | grep '??' | grep -v grep | awk '{print $1}' | xargs kill 2>/dev/null
    fi
    echo "Killed $ai_total orphaned AI processes"
fi

echo "Production apps closed"