#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Create Bins
# @raycast.mode silent
# @raycast.packageName DaVinci Resolve

# Optional parameters:
# @raycast.icon 📁

# Documentation:
# @raycast.description Flatten clips, rebuild bins immediately, and sort (no background watcher required)
# @raycast.author assistant2

export RESOLVE_SCRIPT_API="/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/Modules/"
export RESOLVE_SCRIPT_LIB="/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fusionscript.so"
export PYTHONPATH="$PYTHONPATH:$RESOLVE_SCRIPT_API"

result=$(/opt/homebrew/bin/python3 << 'PYEOF' 2>&1
import os
import sys, traceback, time
sys.path.append("/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/Modules/")
import DaVinciResolveScript as bmd
from collections import defaultdict

def get_resolve():
    dvr = bmd.scriptapp("Resolve")
    if not dvr: return None, None, None
    pm = dvr.GetProjectManager()
    proj = pm.GetCurrentProject()
    mp = proj.GetMediaPool() if proj else None
    return dvr, proj, mp

dvr, project, mPool = get_resolve()
if not project:
    print("❌ Could not connect to Resolve or no project open")
    sys.exit(1)

project_name = project.GetName()
root = mPool.GetRootFolder()

def find_subfolder(parent, name):
    key = name.strip().lower()
    for s in (parent.GetSubFolderList() or []):
        if s.GetName().strip().lower() == key:
            return s
    return None

def ensure_subfolder(media_pool, parent, name, retries=4, delay=0.7):
    # Handles temporary sync contention by retrying and re-checking.
    last_err = None
    for _ in range(retries):
        existing = find_subfolder(parent, name)
        if existing:
            return existing
        try:
            created = media_pool.AddSubFolder(parent, name)
            if created:
                time.sleep(0.08)
                return created
        except Exception as e:
            last_err = e
        time.sleep(delay)

    existing = find_subfolder(parent, name)
    if existing:
        return existing
    if last_err:
        raise RuntimeError(f"Could not create '{name}': {last_err}")
    raise RuntimeError(f"Could not create '{name}'")

def create_bins_now(media_pool, root_folder):
    seq = ensure_subfolder(media_pool, root_folder, "seq")
    media = ensure_subfolder(media_pool, root_folder, "media")
    footage = ensure_subfolder(media_pool, media, "footage")
    audio = ensure_subfolder(media_pool, media, "audio")
    gfx = ensure_subfolder(media_pool, media, "gfx")

    interview = ensure_subfolder(media_pool, footage, "interview")
    broll = ensure_subfolder(media_pool, footage, "broll")
    mx = ensure_subfolder(media_pool, audio, "mx")
    sfx = ensure_subfolder(media_pool, audio, "sfx")
    on_location = ensure_subfolder(media_pool, audio, "on location")
    logos = ensure_subfolder(media_pool, gfx, "logos")
    ae = ensure_subfolder(media_pool, gfx, "ae")
    fusion_comps = ensure_subfolder(media_pool, gfx, "fusion comps")
    compound = ensure_subfolder(media_pool, gfx, "compound clips")

    return {
        'interview': interview,
        'broll': broll,
        'mx': mx,
        'sfx': sfx,
        'on location': on_location,
        'logos': logos,
        'ae': ae,
        'fusion comps': fusion_comps,
        'gfx': gfx,
        'compound clips': compound,
        'seq': seq
    }

def import_raw_timeline(media_pool, seq_folder):
    template_path = "$HOME/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/raw.drt"
    if not os.path.exists(template_path):
        print(f"❌ Critical: raw.drt not found at {template_path}")
        return False

    def timeline_count(folder):
        count = 0
        for clip in (folder.GetClipList() or []):
            try:
                if (clip.GetClipProperty() or {}).get("Type") == "Timeline":
                    count += 1
            except Exception:
                pass
        return count

    # Re-acquire handles because Resolve can invalidate stale objects quickly.
    for attempt in range(1, 4):
        _, live_project, live_mpool = get_resolve()
        if not live_project or not live_mpool:
            time.sleep(1.0)
            continue

        folder_index = {}
        index_folders(live_mpool.GetRootFolder(), folder_index)
        live_seq = folder_index.get("seq") or folder_index.get("timelines")
        if not live_seq:
            print(f"  Attempt {attempt}/3: seq folder not ready yet")
            time.sleep(1.0)
            continue

        before = timeline_count(live_seq)
        try:
            live_mpool.SetCurrentFolder(live_seq)
            import_options = {"timelineImportOption": "UseProjectSettings"}
            imported = live_mpool.ImportTimelineFromFile(template_path, import_options)
            time.sleep(0.5)
            after = timeline_count(live_seq)
            if imported or after > before:
                print("  Imported raw timeline template into seq")
                return True
        except Exception as e:
            print(f"  Attempt {attempt}/3: raw.drt import threw: {e}")

        # Fallback import call without options for API edge cases.
        try:
            imported = live_mpool.ImportTimelineFromFile(template_path)
            time.sleep(0.5)
            after = timeline_count(live_seq)
            if imported or after > before:
                print("  Imported raw timeline template into seq (fallback)")
                return True
        except Exception as e:
            print(f"  Attempt {attempt}/3 fallback failed: {e}")

        time.sleep(1.0)

    print("❌ Critical: Failed to import raw.drt into seq")
    return False

def index_folders(parent, idx):
    try:
        for s in (parent.GetSubFolderList() or []):
            key = s.GetName().strip().lower()
            if key not in idx:
                idx[key] = s
            index_folders(s, idx)
    except Exception:
        pass

def resolve_targets(current_mpool):
    root_local = current_mpool.GetRootFolder()
    current_mpool.SetCurrentFolder(root_local)  # Focus root for stability
    folder_index = {}
    index_folders(root_local, folder_index)
    return root_local, {
        'interview': folder_index.get("interview"),
        'broll': folder_index.get("broll"),
        'mx': folder_index.get("mx"),
        'sfx': folder_index.get("sfx"),
        'on location': folder_index.get("on location"),
        'logos': folder_index.get("logos"),
        'ae': folder_index.get("ae"),
        'fusion comps': folder_index.get("fusion comps"),
        'gfx': folder_index.get("gfx"),
        'compound clips': folder_index.get("compound clips"),
        'seq': folder_index.get("seq") or folder_index.get("timelines")
    }

# ============================================================
# STEP 1: Flatten ALL clips to root
# ============================================================
print("Step 1: Flattening all clips to root...")

def collect_subfolder_clips(folder, is_root=False):
    clips = []
    if not is_root:
        try:
            cl = folder.GetClipList()
            if cl: clips.extend(cl)
        except: pass
    try:
        subs = folder.GetSubFolderList()
        if subs:
            for s in subs:
                clips.extend(collect_subfolder_clips(s, False))
    except: pass
    return clips

all_sub_clips = collect_subfolder_clips(root, True)
if all_sub_clips:
    mPool.MoveClips(all_sub_clips, root)
    print(f"  Moved {len(all_sub_clips)} clips to root.")
    time.sleep(0.75)

# ============================================================
# STEP 2: Delete existing bins
# ============================================================
print("Step 2: Deleting bins...")
try:
    subs = root.GetSubFolderList()
    if subs:
        mPool.DeleteFolders(subs)
        print(f"  Deleted {len(subs)} bins.")
except Exception as e:
    print(f"  ⚠️ Delete error: {e}")

# ============================================================
# STEP 3: Recreate bins now (no background watcher dependency)
# ============================================================
print("Step 3: Creating required bins...")
dvr, project, mPool = get_resolve()
if not mPool:
    print("❌ Critical: Could not reconnect to Media Pool.")
    sys.exit(1)

root = mPool.GetRootFolder()
mPool.SetCurrentFolder(root)
try:
    created_targets = create_bins_now(mPool, root)
    if not import_raw_timeline(mPool, created_targets['seq']):
        sys.exit(1)
except Exception as e:
    print(f"❌ Critical: Could not create required bins: {e}")
    sys.exit(1)

# Re-index after creation to get stable handles.
dvr, project, mPool = get_resolve()
if not mPool:
    print("❌ Critical: Could not reconnect to Media Pool after bin creation.")
    sys.exit(1)
root, targets = resolve_targets(mPool)

print("  Target bins identified:")
for k, v in targets.items():
    if v: print(f"    - {k}")

# ============================================================
# STEP 4: Collect fresh clip handles and classify
# ============================================================
print("\nStep 4: Sorting clips...")

def dur_to_secs(dur_str, fps_str="23.976"):
    try:
        parts = dur_str.replace(';', ':').split(':')
        fps = float(fps_str) if fps_str else 23.976
        return int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2]) + int(parts[3]) / fps
    except: return 0

# Get clips from the SAME root handle we used for targets
root_clips = root.GetClipList() or []
batches = defaultdict(list)
skipped = 0

for clip in root_clips:
    try:
        p = clip.GetClipProperty()
        name = p.get('Clip Name', '').lower()
        ctype = p.get('Type', '')
        path = p.get('File Path', '').lower()
        ext = path.rsplit('.', 1)[-1] if '.' in path else ''
        secs = dur_to_secs(p.get('Duration'), p.get('FPS'))
        
        dest = None
        if ctype == 'Timeline': dest = 'seq'
        elif ctype == 'Compound': dest = 'compound clips'
        elif 'dji' in name or 'dji' in path or 'gopro' in name or 'gopro' in path:
            # DJI and GoPro camera clips should always land in B-roll.
            dest = 'broll'
        elif 'zoom' in name or 'on_location' in path or (ctype == 'Audio' and secs > 600):
            dest = 'on location'
        elif ext in ['mov', 'mp4'] and ('gfx' in path or 'render' in path): dest = 'ae'
        elif ext == 'braw': dest = 'broll'
        elif ext == 'mxf': dest = 'interview' if 'interview' in path else 'broll'
        elif ctype == 'Still': dest = 'gfx'
        elif ctype == 'Audio': dest = 'sfx' if secs <= 10 else 'mx'

        if dest in targets and targets[dest]:
            batches[dest].append(clip)
        else:
            skipped += 1
    except: skipped += 1

# ============================================================
# STEP 5: Perform the move batches
# ============================================================
def add_keyword(clip, keyword):
    if keyword not in {'interview', 'broll'}:
        return
    try:
        existing = clip.GetMetadata('Keywords') or ''
        kw_set = set(k.strip() for k in existing.split(',') if k.strip())
        if keyword not in kw_set:
            kw_set.add(keyword)
            clip.SetMetadata('Keywords', ', '.join(sorted(kw_set)))
    except Exception:
        pass

moved = 0
for key, clips in batches.items():
    if not clips: continue
    target = targets.get(key)
    
    try:
        # MoveClips can fail if Cloud Sync is "syncing folder structure"
        # We try 3 times, with a short wait, using the SAME mPool handle
        success = False
        for attempt in range(3):
            if mPool.MoveClips(clips, target):
                success = True
                break
            print(f"  ⏳ Cloud Sync busy for {key}, retrying...")
            time.sleep(3.0)
            
        if success:
            moved += len(clips)
            print(f"  ✅ Moved {len(clips)} to {key}")
            for c in clips:
                add_keyword(c, key)
        else:
            # If batch fails, try moving one-by-one to pinpoint the issue
            print(f"  ⚠️ Batch {key} failed. Attempting individual moves...")
            for c in clips:
                if mPool.MoveClips([c], target):
                    moved += 1
                    add_keyword(c, key)
                time.sleep(0.1)
    except Exception as e:
        print(f"  ⚠️ Error moving {key}: {e}")

# Save if possible
try:
    project.SaveProject()
except:
    pass

print(f"\n✅ {project_name}: {moved} clips sorted.")
if skipped:
    print(f"ℹ️ Skipped {skipped} clips (no matching rule or missing target bin).")
PYEOF
)
status=$?

error_lines=$(printf '%s\n' "$result" | /usr/bin/grep -Ei '❌|traceback|⚠️ .*error|⚠️ could not' || true)
if [ "$status" -ne 0 ] || [ -n "$error_lines" ]; then
    err_msg="$error_lines"
    if [ -z "$err_msg" ]; then
        err_msg="$result"
    fi
    if [ -z "$err_msg" ]; then
        err_msg="❌ Create Bins failed with exit code $status"
    fi
    printf '%s' "$err_msg" | /usr/bin/pbcopy
    echo "$err_msg"
    exit 1
fi
