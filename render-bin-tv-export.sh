#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Render Bin TV Export
# @raycast.mode silent
# @raycast.packageName DaVinci Resolve

# Optional parameters:
# @raycast.icon 📦

# Documentation:
# @raycast.description Render all sequences in the current media pool bin with TV Export preset
# @raycast.author assistant2

# Switch to Dia immediately
osascript -e 'tell application "Dia" to activate'

export RESOLVE_SCRIPT_API="/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting"
export RESOLVE_SCRIPT_LIB="/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fusionscript.so"
export PYTHONPATH="$PYTHONPATH:$RESOLVE_SCRIPT_API/Modules/"

nohup python3 -c "
import sys
import time
import os

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

# 1. Get timeline names from the current bin
media_pool = project.GetMediaPool()
current_folder = media_pool.GetCurrentFolder()
bin_name = current_folder.GetName()

clips = current_folder.GetClipList()
target_names = set()
for clip in clips:
    if clip.GetClipProperty('Type') == 'Timeline':
        target_names.add(clip.GetName())

if not target_names:
    sys.exit(0)

# 2. Switch to Deliver Page
resolve.OpenPage('deliver')
time.sleep(3)

# 3. Clear Queue
project.DeleteAllRenderJobs()

# 4. Find matching timelines, load preset, and add to queue
preset_name = '01 tv export'
job_ids = []
timeline_count = project.GetTimelineCount()
found = set()

for i in range(1, timeline_count + 1):
    timeline = project.GetTimelineByIndex(i)
    name = timeline.GetName()

    if name not in target_names:
        continue

    found.add(name)
    project.SetCurrentTimeline(timeline)

    if not project.LoadRenderPreset(preset_name):
        continue

    max_retries = 5
    attempt = 0
    job_id = None

    while attempt < max_retries:
        job_id = project.AddRenderJob()
        if job_id:
            break
        time.sleep(1)
        attempt += 1

    if job_id:
        job_ids.append(job_id)

    # Stop early if we found all targets
    if found == target_names:
        break

if not job_ids:
    sys.exit(0)

# 5. Start Rendering
project.StartRendering(job_ids)

# 6. Wait for render to finish
time.sleep(2)
while project.IsRenderingInProgress():
    time.sleep(1)

# 7. Reveal first rendered file in Media Storage
first_job_id = job_ids[0]
job_list = project.GetRenderJobList()
target_path = None
for job in job_list:
    if job.get('JobId') == first_job_id:
        target_dir = job.get('TargetDir', '')
        output_file = job.get('OutputFilename', '')
        if target_dir and output_file:
            target_path = os.path.join(target_dir, output_file)
        break

if target_path:
    resolve.OpenPage('media')
    time.sleep(1)
    ms = resolve.GetMediaStorage()
    ms.RevealInStorage(target_path)
" &
