#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sort Seq Bin
# @raycast.mode silent
# @raycast.packageName DaVinci Resolve

# Optional parameters:
# @raycast.icon 🎬

# Documentation:
# @raycast.description Sort media from seq bin into organized bins in DaVinci Resolve
# @raycast.author assistant2

result=$(/opt/homebrew/bin/python3 << 'PYTHON' 2>&1
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

# --- Build bin lookup by walking the folder tree ---
def find_bins(folder, path=""):
    bins = {}
    name = folder.GetName()
    current = f"{path}/{name}" if path else name
    bins[current.lower()] = folder
    subs = folder.GetSubFolderList()
    if subs:
        for s in subs:
            bins.update(find_bins(s, current))
    return bins

all_bins = find_bins(root)

# --- Locate target bins ---
targets = {
    'ae': None, 'broll': None, 'interview': None,
    'sfx': None, 'mx': None, 'on location': None, 'gfx': None
}
for path, folder in all_bins.items():
    for key in targets:
        if path.endswith("/" + key):
            targets[key] = folder

seq_bin = None
for path, folder in all_bins.items():
    if path.endswith("/seq"):
        seq_bin = folder
        break

if not seq_bin:
    print("❌ No seq bin found")
    sys.exit(1)

clips = seq_bin.GetClipList()
if not clips:
    sys.exit(0)

# --- Duration parser ---
def dur_to_secs(dur_str, fps_str="23.976"):
    if not dur_str:
        return 0
    try:
        fps = float(fps_str) if fps_str else 23.976
    except ValueError:
        fps = 23.976
    parts = dur_str.replace(';', ':').split(':')
    if len(parts) != 4:
        return 0
    h, m, s, f = int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3])
    return h * 3600 + m * 60 + s + f / fps

# --- Classify each clip ---
from collections import defaultdict
batches = defaultdict(list)  # target_bin_key -> [clip, ...]
skipped = 0

for clip in clips:
    props = clip.GetClipProperty()
    name = props.get('Clip Name', '')
    clip_type = props.get('Type', '')
    duration = props.get('Duration', '')
    fps = props.get('FPS', '')
    file_path = props.get('File Path', '')

    # Skip timelines and clips with no file
    if clip_type == 'Timeline' or not file_path:
        skipped += 1
        continue

    ext = file_path.rsplit('.', 1)[-1].lower() if '.' in file_path else ''
    secs = dur_to_secs(duration, fps)
    name_lower = name.lower()
    path_lower = file_path.lower()
    dest = None

    # --- Rule 1: ZOOM recordings → on location (always) ---
    if name.upper().startswith('ZOOM'):
        dest = 'on location'

    # --- Rule 2: DJI / GoPro clips → broll ---
    elif 'dji' in name_lower or 'dji' in path_lower or 'gopro' in name_lower or 'gopro' in path_lower:
        dest = 'broll'

    # --- Rule 3: Audio with On_Location in path → on location ---
    elif 'on_location' in path_lower and clip_type == 'Audio':
        dest = 'on location'

    # --- Rule 4: .mov → ae ---
    elif ext == 'mov':
        dest = 'ae'

    # --- Rule 5: .mxf → interview or broll by path ---
    elif ext == 'mxf':
        if 'interview' in path_lower:
            dest = 'interview'
        else:
            dest = 'broll'

    # --- Rule 6: Stills → gfx ---
    elif clip_type == 'Still':
        dest = 'gfx'

    # --- Rule 7: Remaining audio by duration ---
    elif clip_type == 'Audio':
        if secs > 600:
            dest = 'on location'
        elif secs <= 10:
            dest = 'sfx'
        else:
            dest = 'mx'

    if dest and targets.get(dest):
        batches[dest].append(clip)
    else:
        skipped += 1

# --- Helper to add keyword to a clip without duplicating ---
def add_keyword(clip, keyword):
    existing = clip.GetMetadata('Keywords') or ''
    kw_set = set(k.strip() for k in existing.split(',') if k.strip())
    if keyword not in kw_set:
        kw_set.add(keyword)
        clip.SetMetadata('Keywords', ', '.join(sorted(kw_set)))

# --- Move clips in batches and tag with bin keyword ---
moved = 0
errors = 0
for dest_key, clip_list in batches.items():
    target_folder = targets[dest_key]
    result = mp.MoveClips(clip_list, target_folder)
    if result:
        moved += len(clip_list)
        for clip in clip_list:
            add_keyword(clip, dest_key)
    else:
        errors += len(clip_list)

if errors:
    print(f"❌ Failed moving {errors} clips from seq bin")
    sys.exit(1)
PYTHON
)
status=$?

error_lines=$(printf '%s\n' "$result" | /usr/bin/grep -Ei '❌|traceback|error' || true)
if [ "$status" -ne 0 ] || [ -n "$error_lines" ]; then
    err_msg="$error_lines"
    if [ -z "$err_msg" ]; then
        err_msg="$result"
    fi
    if [ -z "$err_msg" ]; then
        err_msg="❌ Sort Seq Bin failed with exit code $status"
    fi
    printf '%s' "$err_msg" | /usr/bin/pbcopy
    echo "$err_msg"
    exit 1
fi
