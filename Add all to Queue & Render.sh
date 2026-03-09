#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Render All TV Export
# @raycast.mode silent
# @raycast.packageName DaVinci Resolve
# @raycast.icon 🦾

# Switch to Dia immediately
osascript -e 'tell application "Dia" to activate'

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

# 1. Identify Target Timelines
def get_timelines_from_folder(folder):
    '''Recursively get all timeline names from a folder and its subfolders'''
    timeline_names = []

    # Get timelines in current folder
    clips = folder.GetClipList()
    for clip in clips:
        if clip.GetClipProperty('Type') == 'Timeline':
            timeline_names.append(clip.GetName())

    # Recursively search subfolders
    subfolders = folder.GetSubFolderList()
    for subfolder in subfolders:
        timeline_names.extend(get_timelines_from_folder(subfolder))

    return timeline_names

media_pool = project.GetMediaPool()
root_folder = media_pool.GetRootFolder()
subfolders = root_folder.GetSubFolderList()

seq_bin = None
for folder in subfolders:
    if folder.GetName() == 'seq':
        seq_bin = folder
        break

target_timeline_names = []
if seq_bin:
    target_timeline_names = get_timelines_from_folder(seq_bin)

    if not target_timeline_names:
        notify('Found seq bin but no timelines in it or its subfolders')
        sys.exit(0)
else:
    # If no seq bin, we will render ALL timelines
    target_timeline_names = None 

# 2. Switch to Deliver Page
resolve.OpenPage('deliver')
time.sleep(1) # Wait for page switch

# 3. Clear Queue
project.DeleteAllRenderJobs()

# 4. Iterate and Add to Queue
preset_name = '01 tv export'
job_ids = []

timeline_count = project.GetTimelineCount()
found_count = 0

for i in range(1, timeline_count + 1):
    timeline = project.GetTimelineByIndex(i)
    name = timeline.GetName()
    
    # Filter if we are targeting specific timelines
    if target_timeline_names is not None:
        if name not in target_timeline_names:
            continue
    
    project.SetCurrentTimeline(timeline)
    # Small delay to ensure switch happens? usually synchronous but good to be safe
    # time.sleep(0.5) 
    
    if not project.LoadRenderPreset(preset_name):
        print(f'Preset not found for {name}: {preset_name}')
        continue
        
    # Add to Render Queue
    # Retry loop for adding job (as per original script logic for NAS lag)
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
        found_count += 1
    else:
        print(f'Failed to add timeline {name} to queue')

if not job_ids:
    notify('No jobs added to render queue')
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