#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Create Project Folder with Note
# @raycast.mode silent
# @raycast.packageName System

# Optional parameters:
# @raycast.icon 📁
# @raycast.argument1 { "type": "text", "placeholder": "Project Name" }

# Documentation:
# @raycast.description Creates Cole's video project folder structure in current Finder location

PROJECT_NAME="$1"

# Get the current Finder window path
CURRENT_DIR=$(osascript -e 'tell application "Finder" to POSIX path of (insertion location as alias)')

# Create the main project folder
mkdir -p "$CURRENT_DIR$PROJECT_NAME"

# Create the complete folder structure
mkdir -p "$CURRENT_DIR$PROJECT_NAME/01 Project Files"/{AE,DaVinci,Illustrator,PR}
mkdir -p "$CURRENT_DIR$PROJECT_NAME/02 Documents"
mkdir -p "$CURRENT_DIR$PROJECT_NAME/03 Exports"/{Finals,Proofs}
mkdir -p "$CURRENT_DIR$PROJECT_NAME/04 Resources/01 Footage"/{01\ Interview,02\ B-Roll,03\ Photos}
mkdir -p "$CURRENT_DIR$PROJECT_NAME/04 Resources/01 Footage/04 AI"/{INPUT,OUTPUT}
mkdir -p "$CURRENT_DIR$PROJECT_NAME/04 Resources/02 Audio"/{Mastered\ Audio,Music,On_Location,SFX,VO}
mkdir -p "$CURRENT_DIR$PROJECT_NAME/04 Resources/02 Audio/AI"/{ENHANCED,RAW}
mkdir -p "$CURRENT_DIR$PROJECT_NAME/04 Resources/02 Audio/Mixed"/{Audio_IN,Audio_OUT}
mkdir -p "$CURRENT_DIR$PROJECT_NAME/04 Resources/03 GFX"/{01\ LOGOS,AI,PSD,Stills,Renders,Fusion}
mkdir -p "$CURRENT_DIR$PROJECT_NAME/04 Resources/04 AE"
mkdir -p "$CURRENT_DIR$PROJECT_NAME/04 Resources/05 Color"/{CC_IN,CC_OUT}

# Create a .md file in the Documents folder with the project name
touch "$CURRENT_DIR$PROJECT_NAME/02 Documents/$PROJECT_NAME.md"
