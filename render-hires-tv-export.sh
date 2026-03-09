#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Render Hi-Res TV Export
# @raycast.mode silent
# @raycast.packageName DaVinci Resolve

# Optional parameters:
# @raycast.icon 📦

# Documentation:
# @raycast.description Render current timeline with 05 Hi Res TV Export preset
# @raycast.author assistant2

# Switch to Dia immediately
osascript -e 'tell application "Dia" to activate'

export RESOLVE_SCRIPT_API="/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting"
export RESOLVE_SCRIPT_LIB="/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fusionscript.so"
export PYTHONPATH="$PYTHONPATH:$RESOLVE_SCRIPT_API/Modules/"

nohup python3 -c "
import sys
import time

try:
    import DaVinciResolveScript as dvr_script
except ImportError:
    sys.exit(0)

try:
    resolve = dvr_script.scriptapp('Resolve')
    if not resolve:
        sys.exit(0)
except:
    sys.exit(0)

project = resolve.GetProjectManager().GetCurrentProject()
if not project:
    sys.exit(0)

timeline = project.GetCurrentTimeline()
if not timeline:
    sys.exit(0)

# Switch to Deliver Page
resolve.OpenPage('deliver')
time.sleep(3)

# Load preset and add to queue
preset_name = '05 hi res tv export'

if not project.LoadRenderPreset(preset_name):
    sys.exit(0)

max_retries = 5
attempt = 0
job_id = None

while attempt < max_retries:
    job_id = project.AddRenderJob()
    if job_id:
        break
    time.sleep(1)
    attempt += 1

if not job_id:
    sys.exit(0)

# Start Rendering
project.StartRendering([job_id])
time.sleep(1.5)
" &
