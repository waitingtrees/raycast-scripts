#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title StrFlow Audit
# @raycast.mode silent
# @raycast.packageName Knowledge

# Optional parameters:
# @raycast.icon 🧠

# Documentation:
# @raycast.description Exports recent StrFlow notes and launches Claude Code to run the knowledge audit skill
# @raycast.author assistant2

# --- Config ---
DB_PATH="$HOME/Library/Group Containers/KXMRPURL69.app.strflow/LocalFiles/data/database.sqlite"
EXPORT_DIR="$HOME/Documents/The Cole Chandler/The Cole Chandler/claude/knowledge audit/strflow logs"
TIMESTAMP=$(date +"%Y-%m-%d-%H%M")
EXPORT_FILE="$EXPORT_DIR/strflow-export-$TIMESTAMP.md"
DAYS=7

# Core Data epoch offset (seconds between 1970-01-01 and 2001-01-01)
CD_EPOCH=978307200
SECONDS_IN_DAYS=$((DAYS * 86400))

# --- Ensure export directory exists ---
mkdir -p "$EXPORT_DIR"

# --- Export notes from last 7 days ---
NOTE_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM ZCDNOTE WHERE ZDATE > (strftime('%s', 'now') - $CD_EPOCH - $SECONDS_IN_DAYS);")

if [ "$NOTE_COUNT" -eq 0 ]; then
    echo "❌ No StrFlow notes found in the last $DAYS days."
    exit 1
fi

# Build the markdown export header
{
    echo "# StrFlow Export — $(date +"%B %d, %Y at %I:%M %p")"
    echo ""
    echo "**Notes from the last $DAYS days: $NOTE_COUNT total**"
    echo ""
    echo "---"
    echo ""
} > "$EXPORT_FILE"

# Export as JSON, then use jq to format each note as markdown
sqlite3 -json "$DB_PATH" "
    SELECT
        datetime(n.ZDATE + $CD_EPOCH, 'unixepoch', 'localtime') as date,
        COALESCE(n.ZTITLE, '(untitled)') as title,
        COALESCE(GROUP_CONCAT(t.ZNAME, ', '), '') as tags,
        COALESCE(n.ZPLAINTEXT, '') as plaintext
    FROM ZCDNOTE n
    LEFT JOIN Z_5TAGS nt ON n.Z_PK = nt.Z_5NOTES1
    LEFT JOIN ZCDTAG t ON nt.Z_8TAGS = t.Z_PK
    WHERE n.ZDATE > (strftime('%s', 'now') - $CD_EPOCH - $SECONDS_IN_DAYS)
    GROUP BY n.Z_PK
    ORDER BY n.ZDATE DESC;
" | jq -r '.[] | "## " + .title + "\n**Date:** " + .date + (if (.tags | length) > 0 then "\n**Tags:** " + .tags else "" end) + "\n\n" + .plaintext + "\n\n---\n"' >> "$EXPORT_FILE"

# --- Launch Ghostty + Claude Code with the skill ---
if pgrep -x "Ghostty" > /dev/null; then
    osascript <<EOF
tell application "Ghostty"
    activate
end tell

tell application "System Events"
    keystroke "t" using command down
    delay 0.3
    keystroke "claude --dangerously-skip-permissions"
    delay 0.1
    keystroke return
    delay 2.0
    keystroke return
    delay 0.5
    keystroke "/strflow-audit '$EXPORT_FILE'"
    delay 0.1
    keystroke return
end tell
EOF
else
    open -a Ghostty
    sleep 1.5

    osascript <<EOF
tell application "Ghostty"
    activate
end tell

tell application "System Events"
    keystroke "t" using command down
    delay 0.3
    keystroke "claude --dangerously-skip-permissions"
    delay 0.1
    keystroke return
    delay 2.0
    keystroke return
    delay 0.5
    keystroke "/strflow-audit '$EXPORT_FILE'"
    delay 0.1
    keystroke return
end tell
EOF
fi

echo "✅ Exported $NOTE_COUNT notes → launching audit"
