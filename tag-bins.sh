#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Tag Bins
# @raycast.mode silent
# @raycast.packageName DaVinci Resolve

# Optional parameters:
# @raycast.icon 🏷

# Documentation:
# @raycast.description Tag all media pool clips with keyword matching their bin name
# @raycast.author assistant2

result=$(/opt/homebrew/bin/python3 << 'PYTHON'
import sys
sys.path.append('/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/Modules')
import DaVinciResolveScript as dvr

resolve = dvr.scriptapp('Resolve')
if not resolve:
    print("❌ Could not connect to DaVinci Resolve")
    sys.exit(1)

pm = resolve.GetProjectManager()
proj = pm.GetCurrentProject()
if not proj:
    print("❌ No project open")
    sys.exit(1)

mp = proj.GetMediaPool()
root = mp.GetRootFolder()

tagged = 0
skipped = 0

def tag_folder(folder, parent_path=""):
    global tagged, skipped
    name = folder.GetName()
    current_path = f"{parent_path}/{name}" if parent_path else name

    clips = folder.GetClipList()
    if clips:
        keyword = name.lower()
        for clip in clips:
            props = clip.GetClipProperty()
            clip_type = props.get('Type', '')
            # Skip timelines and compound clips
            if clip_type == 'Timeline':
                skipped += 1
                continue

            existing = clip.GetMetadata('Keywords') or ''
            # Build keyword set from existing
            kw_set = set(k.strip() for k in existing.split(',') if k.strip())

            if keyword not in kw_set:
                kw_set.add(keyword)
                result = clip.SetMetadata('Keywords', ', '.join(sorted(kw_set)))
                if result:
                    tagged += 1
                else:
                    skipped += 1
            else:
                skipped += 1

    subs = folder.GetSubFolderList()
    if subs:
        for s in subs:
            tag_folder(s, current_path)

# Start from root but skip the root folder itself (Master)
subs = root.GetSubFolderList()
if subs:
    for s in subs:
        tag_folder(s)

parts = [f"✅ Tagged {tagged} clips"]
if skipped:
    parts.append(f"{skipped} skipped")
print(" · ".join(parts))
PYTHON
)

echo "$result"
