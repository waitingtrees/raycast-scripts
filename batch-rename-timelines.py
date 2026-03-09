#!/usr/bin/env python3

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Batch Rename Timelines
# @raycast.mode fullOutput
# @raycast.packageName DaVinci Resolve

# Optional parameters:
# @raycast.icon ✏️
# @raycast.argument1 {"type": "text", "placeholder": "Find"}
# @raycast.argument2 {"type": "text", "placeholder": "Replace"}

# Documentation:
# @raycast.description Find & replace in all timeline names in the current Resolve bin
# @raycast.author assistant2

import sys
import os

RESOLVE_SCRIPT_API = "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/Modules/"
sys.path.append(RESOLVE_SCRIPT_API)

try:
    import DaVinciResolveScript as dvr_script
except ImportError:
    print("❌ Could not import DaVinciResolveScript module.")
    sys.exit(1)

def get_timelines_in_folder(folder):
    """Get all timeline clips from a media pool folder."""
    timelines = []
    clips = folder.GetClipList()
    if clips:
        for clip in clips:
            clip_type = clip.GetClipProperty("Type")
            if clip_type == "Timeline":
                timelines.append(clip)
    return timelines

def main():
    find_str = sys.argv[1]
    replace_str = sys.argv[2]

    resolve = dvr_script.scriptapp("Resolve")
    if not resolve:
        print("❌ Could not connect to DaVinci Resolve. Is it running?")
        sys.exit(1)

    project = resolve.GetProjectManager().GetCurrentProject()
    if not project:
        print("❌ No project is currently open.")
        sys.exit(1)

    media_pool = project.GetMediaPool()
    current_folder = media_pool.GetCurrentFolder()
    folder_name = current_folder.GetName() if current_folder else "Unknown"

    # Get all timelines in the project
    timeline_count = project.GetTimelineCount()
    if not timeline_count:
        print("⚠️ No timelines in the project.")
        sys.exit(0)

    # Collect timelines that match
    matches = []
    for i in range(1, timeline_count + 1):
        tl = project.GetTimelineByIndex(i)
        if tl:
            name = tl.GetName()
            if find_str in name:
                matches.append((tl, name, name.replace(find_str, replace_str)))

    if not matches:
        print(f"⚠️ No timelines contain \"{find_str}\"")
        print(f"   Searched {timeline_count} timeline(s)")
        sys.exit(0)

    print(f"📂 Bin: {folder_name}")
    print(f"🔍 Find: \"{find_str}\" → Replace: \"{replace_str}\"")
    print(f"📄 {len(matches)} match(es) out of {timeline_count} timeline(s)\n")

    renamed = 0
    failed = 0

    for tl, old_name, new_name in matches:
        print(f"  {old_name}")
        print(f"  → {new_name}...", end=" ", flush=True)
        if tl.SetName(new_name):
            print("✅", flush=True)
            renamed += 1
        else:
            print("❌ (name may already exist)", flush=True)
            failed += 1

    print(f"\n{'='*40}")
    print(f"✅ Renamed: {renamed}")
    if failed:
        print(f"❌ Failed:  {failed}")

if __name__ == "__main__":
    main()
