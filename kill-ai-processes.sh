#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Kill AI Processes
# @raycast.mode silent
# @raycast.packageName Utilities

# Optional parameters:
# @raycast.icon 🧹

# Documentation:
# @raycast.description Kills orphaned Claude Code and OpenCode subprocesses
# @raycast.author assistant2

# Find the current interactive claude session (the one with a TTY, not '??')
# We want to keep that one alive
current_claude_pids=$(ps -eo pid,tty,comm | grep claude | grep -v '??' | grep -v grep | awk '{print $1}')

# Count before
opencode_count=$(ps aux | grep -i opencode | grep -v grep | wc -l | tr -d ' ')
claude_orphan_count=$(ps -eo pid,tty,args | grep '$HOME/.local/bin/claude' | grep '??' | grep -v grep | wc -l | tr -d ' ')
total=$((opencode_count + claude_orphan_count))

if [ "$total" -eq 0 ]; then
  echo "✅ No orphaned AI processes found"
  exit 0
fi

# Kill all opencode processes
if [ "$opencode_count" -gt 0 ]; then
  ps aux | grep -i opencode | grep -v grep | awk '{print $2}' | xargs kill 2>/dev/null
fi

# Kill orphaned claude processes (those with '??' TTY = no terminal)
# This preserves any claude running in an active terminal session
if [ "$claude_orphan_count" -gt 0 ]; then
  ps -eo pid,tty,args | grep '$HOME/.local/bin/claude' | grep '??' | grep -v grep | awk '{print $1}' | xargs kill 2>/dev/null
fi

echo "🧹 Killed $total orphaned AI processes ($claude_orphan_count claude, $opencode_count opencode)"
