#!/bin/bash

# Get selected Finder folder
PARENT=$(osascript -e 'tell application "Finder" to if selection is not {} then POSIX path of (item 1 of (get selection) as alias)')

# List of subfolders
CHOICE=$(echo -e "04 Resources/02 Audio/On_Location\n04 Resources/01 Footage/01 Interview\n04 Resources/04 AE" | \
  osascript -e 'choose from list paragraphs of (do shell script "cat") with prompt "Jump to subfolder:"')

# If user made a choice, open the subfolder
if [ "$CHOICE" != "false" ]; then
  open "$PARENT/$CHOICE"
fi
