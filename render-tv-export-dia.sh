#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Render TV Export
# @raycast.mode silent
# @raycast.packageName DaVinci Resolve
# @raycast.icon 🚀

# Switch to Dia immediately
osascript -e 'tell application "Dia" to activate'

# Kick off the render in the background
export RESOLVE_SCRIPT_API="/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting"
export RESOLVE_SCRIPT_LIB="/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fusionscript.so"
export PYTHONPATH="$PYTHONPATH:$RESOLVE_SCRIPT_API/Modules/"

python3 -c "
import DaVinciResolveScript as dvr_script
import sys
import time
import os

def notify(message):
    msg = message.replace('\"', '\\\"')
    os.system(f'osascript -e \'display notification \"{msg}\" with title \"Resolve Render Failed\" sound name \"Basso\"\'')

try:
    resolve = dvr_script.scriptapp('Resolve')
except:
    sys.exit(0)

if not resolve:
    sys.exit(0)

project = resolve.GetProjectManager().GetCurrentProject()
if not project:
    notify('No Project Loaded')
    sys.exit(0)

# 1. Switch to Deliver Page
resolve.OpenPage('deliver')

# CRITICAL: Wait for NAS/Database to initialize (Buffer for gray buttons)
time.sleep(3)

# 2. Load Preset
preset_name = '01 tv export'
if not project.LoadRenderPreset(preset_name):
    notify(f'Preset not found: {preset_name}')
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

    # 5. Wait for render to finish
    time.sleep(2)
    while project.IsRenderingInProgress():
        time.sleep(1)

    # 6. Get the rendered file path
    job_list = project.GetRenderJobList()
    target_path = None
    for job in job_list:
        if job.get('JobId') == job_id:
            target_dir = job.get('TargetDir', '')
            output_file = job.get('OutputFilename', '')
            if target_dir and output_file:
                target_path = os.path.join(target_dir, output_file)
            break

    # 7. Switch to Media page and reveal the file
    if target_path:
        resolve.OpenPage('media')
        time.sleep(1)
        ms = resolve.GetMediaStorage()
        ms.RevealInStorage(target_path)
else:
    notify('Timed out waiting for Render Page (NAS lagging?)')
    sys.exit(0)
" &
