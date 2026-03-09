#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Start Queued Renders
# @raycast.mode silent
# @raycast.packageName DaVinci Resolve
# @raycast.icon ▶️

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

# Switch to Deliver Page
resolve.OpenPage('deliver')
time.sleep(1)

# Get all render jobs
all_jobs = project.GetRenderJobList()

if not all_jobs:
    sys.exit(0)

# Filter for unrendered jobs (not Complete)
unrendered_jobs = []
for job in all_jobs:
    status = project.GetRenderJobStatus(job)
    # Status can be: 'Ready', 'Rendering', 'Complete', 'Failed', 'Cancelled'
    if status.get('JobStatus') != 'Complete':
        unrendered_jobs.append(job['JobId'])

if not unrendered_jobs:
    sys.exit(0)

# Start rendering unrendered jobs
project.StartRendering(unrendered_jobs)
time.sleep(1)
"
