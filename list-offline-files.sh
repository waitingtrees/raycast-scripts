#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title List Offline Files
# @raycast.mode fullOutput
# @raycast.packageName DaVinci Resolve

# Optional parameters:
# @raycast.icon 🎬
# @raycast.description List all offline/missing media files in current DaVinci Resolve timeline

# Create a temporary Python script to get offline files from DaVinci Resolve
TEMP_SCRIPT=$(mktemp /tmp/get_offline_files.XXXXXX.py)

cat > "$TEMP_SCRIPT" << 'PYTHON_SCRIPT'
import sys
import os

try:
    # Try to import DaVinci Resolve API
    sys.path.append("/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/Modules")
    import DaVinciResolveScript as dvr

    resolve = dvr.scriptapp("Resolve")
    if not resolve:
        print("❌ Could not connect to DaVinci Resolve")
        print("Make sure DaVinci Resolve is running")
        sys.exit(1)

    project_manager = resolve.GetProjectManager()
    project = project_manager.GetCurrentProject()

    if not project:
        print("❌ No project is currently open")
        sys.exit(1)

    timeline = project.GetCurrentTimeline()

    if not timeline:
        print("❌ No timeline is currently selected")
        sys.exit(1)

    print(f"📋 Timeline: {timeline.GetName()}")
    print(f"📁 Project: {project.GetName()}\n")

    # Get all timeline items (clips)
    offline_files = []
    online_files = []

    # Iterate through video and audio tracks
    for track_type in ["video", "audio"]:
        for track_index in range(1, timeline.GetTrackCount(track_type) + 1):
            items = timeline.GetItemListInTrack(track_type, track_index)
            for item in items:
                media_pool_item = item.GetMediaPoolItem()
                if media_pool_item:
                    clip_property = media_pool_item.GetClipProperty()
                    file_path = clip_property.get("File Path")
                    clip_name = clip_property.get("Clip Name", "Unknown")

                    if file_path:
                        if not os.path.exists(file_path):
                            offline_files.append((clip_name, file_path))
                        else:
                            online_files.append(file_path)

    # Remove duplicates
    offline_files = list(set(offline_files))
    online_files = list(set(online_files))

    # Output results
    if offline_files:
        print(f"🔴 OFFLINE FILES ({len(offline_files)}):")
        print("=" * 60)
        for clip_name, file_path in sorted(offline_files):
            print(f"\n❌ {clip_name}")
            print(f"   {file_path}")
        print("\n" + "=" * 60)
    else:
        print("✅ All files are online!")

    print(f"\n📊 Summary:")
    print(f"   Online:  {len(online_files)} files")
    print(f"   Offline: {len(offline_files)} files")

except Exception as e:
    print(f"❌ ERROR: {str(e)}")
    sys.exit(1)
PYTHON_SCRIPT

# Run Python script
python3 "$TEMP_SCRIPT"
EXIT_CODE=$?

# Clean up temp script
rm -f "$TEMP_SCRIPT"

exit $EXIT_CODE
