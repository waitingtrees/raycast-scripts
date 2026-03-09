#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Quick Export
# @raycast.mode silent
# @raycast.packageName DaVinci Resolve
# @raycast.icon 🚀

export RESOLVE_SCRIPT_API="/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting"
export RESOLVE_SCRIPT_LIB="/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fusionscript.so"
export PYTHONPATH="$PYTHONPATH:$RESOLVE_SCRIPT_API/Modules/"

python3 -c "
import DaVinciResolveScript as dvr_script
import sys
import time




try:
    resolve = dvr_script.scriptapp('Resolve')
except:
    sys.exit(0)

if not resolve:
    sys.exit(0)

project = resolve.GetProjectManager().GetCurrentProject()
if not project:

    sys.exit(0)

# 1. Switch to Deliver Page
resolve.OpenPage('deliver')

# CRITICAL: Wait for NAS/Database to initialize (Buffer for gray buttons)
time.sleep(3) 

# 2. Load Preset
preset_name = '06 quick export'
if not project.LoadRenderPreset(preset_name):

    sys.exit(0)

# 3. Clear Queue
project.DeleteAllRenderJobs()

# 4. RETRY LOOP (The fix for NAS lag)
# We try to add the job. If it fails, we wait 1s and try again.
# We do this up to 10 times.

max_retries = 10
attempt = 0
job_id = None

while attempt < max_retries:
    job_id = project.AddRenderJob()
    
    if job_id:
        # Success! Break the loop
        break
    else:
        # Failed (Buttons likely still gray/crunching)
        time.sleep(1)
        attempt += 1

if job_id:
    project.StartRendering([job_id])
    time.sleep(1.5) # Keep alive to send command
else:

    sys.exit(0)
"