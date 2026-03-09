#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Open Book
# @raycast.mode silent
# @raycast.packageName Reading

# Optional parameters:
# @raycast.icon 📖

# Documentation:
# @raycast.description Pick an epub from your Books folder and read it in epy (or open Finder selection)
# @raycast.author assistant2

EPY="$HOME/Library/Python/3.10/bin/epy"
BOOKS_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Books"

open_in_ghostty_tab() {
  local book="$1"

  osascript - "$EPY" "$book" <<'APPLESCRIPT'
    on run argv
      set epyPath to item 1 of argv
      set bookPath to item 2 of argv

      tell application "System Events"
        set frontProcessName to name of first process whose frontmost is true
        set ghosttyRunning to exists process "Ghostty"
      end tell

      if ghosttyRunning then
        tell application "System Events" to tell process "Ghostty"
          set ghosttyHasWindows to (count of windows) > 0
          set frontmost to true
        end tell
      else
        set ghosttyHasWindows to false
      end if

      if not ghosttyRunning or not ghosttyHasWindows then
        tell application "Ghostty" to activate
        delay 0.3
      else
        tell application "System Events" to tell process "Ghostty"
          keystroke "t" using command down
        end tell
        delay 0.15
      end if

      set cmd to quoted form of epyPath & space & quoted form of bookPath

      -- Save clipboard, paste command (faster + reliable), restore clipboard
      set oldClip to the clipboard
      set the clipboard to cmd
      delay 0.1
      tell application "System Events" to tell process "Ghostty"
        keystroke "v" using command down
        delay 0.2
        key code 36
      end tell
      delay 0.1
      set the clipboard to oldClip

      tell application "Ghostty" to activate
    end run
APPLESCRIPT
}

# Check if Finder has an epub selected
finder_file=$(osascript -e '
tell application "Finder"
  try
    set sel to selection as alias list
    if (count of sel) > 0 then
      set f to POSIX path of (item 1 of sel)
      if f ends with ".epub" then
        return f
      end if
    end if
  end try
end tell
return ""
' 2>/dev/null)

if [ -n "$finder_file" ]; then
  open_in_ghostty_tab "$finder_file"
  echo "📖 Opening Finder selection"
  exit 0
fi

# No Finder epub selected — show picker dialog
books=()
paths=()
while IFS= read -r file; do
  filename=$(basename "$file")
  display=$(echo "$filename" | sed 's/^_OceanofPDF\.com_//; s/\.epub$//; s/_/ /g')
  books+=("$display")
  paths+=("$file")
done < <(find "$BOOKS_DIR" -maxdepth 1 -name "*.epub" | sort)

if [ ${#books[@]} -eq 0 ]; then
  echo "❌ No epub files found"
  exit 1
fi

# Build AppleScript list string
osa_list=""
for b in "${books[@]}"; do
  osa_list+="\"$b\", "
done
osa_list="${osa_list%, }"

chosen=$(osascript -e "choose from list {${osa_list}} with title \"Open Book\" with prompt \"Pick a book to read:\"")

if [ "$chosen" = "false" ] || [ -z "$chosen" ]; then
  exit 0
fi

# Find the matching file path
for i in "${!books[@]}"; do
  if [ "${books[$i]}" = "$chosen" ]; then
    book_path="${paths[$i]}"
    break
  fi
done

if [ -z "$book_path" ]; then
  echo "❌ Could not find book"
  exit 1
fi

open_in_ghostty_tab "$book_path"

echo "📖 Opening: $chosen"
