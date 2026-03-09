#!/usr/bin/env python3

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Split Interviews to Timelines
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 🎬
# @raycast.packageName DaVinci Resolve

# Documentation:
# @raycast.description Duplicates timeline for each clip on Audio Track "MX" (or 4)
# @raycast.author assistant2

import sys
import os

# Platform dependent path for the DaVinci Resolve Scripting API
# This assumes macOS as per user context
RESOLVE_SCRIPT_API = "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/Modules/"
sys.path.append(RESOLVE_SCRIPT_API)

try:
    import DaVinciResolveScript as dvr_script
except ImportError:
    print("Error: Could not import DaVinciResolveScript module.")
    print(f"Ensure the module is at: {RESOLVE_SCRIPT_API}")
    print("And that DaVinci Resolve is installed.")
    sys.exit(1)

def main():
    try:
        resolve = dvr_script.scriptapp("Resolve")
        if not resolve:
            print("Error: Could not connect to DaVinci Resolve.")
            print("Please ensure DaVinci Resolve is running.")
            sys.exit(1)

        project_manager = resolve.GetProjectManager()
        project = project_manager.GetCurrentProject()
        if not project:
            print("Error: No project is currently open.")
            sys.exit(1)

        timeline = project.GetCurrentTimeline()
        if not timeline:
            print("Error: No timeline is currently active.")
            sys.exit(1)
            
        media_pool = project.GetMediaPool()

        # Find Audio Track "MX" or default to Track 4
        track_type = "audio"
        track_index = 4 # Default
        found_mx = False

        # Get track count
        track_count = timeline.GetTrackCount(track_type)
        
        for i in range(1, track_count + 1):
            name = timeline.GetTrackName(track_type, i)
            if name and name.lower() == "mx":
                track_index = i
                found_mx = True
                break
        
        if found_mx:
            print(f"Found track 'MX' at index {track_index}.")
        else:
            print(f"Track 'MX' not found. Defaulting to Audio Track {track_index}.")

        clips = timeline.GetItemListInTrack(track_type, track_index)
        
        if not clips:
            print(f"No clips found on {track_type} track {track_index}.")
            sys.exit(0)

        print(f"Found {len(clips)} clips on Audio Track {track_index}. Collecting data...")

        # Collect data first to avoid issues if active timeline changes
        clip_data = []
        for clip in clips:
            duration = clip.GetEnd() - clip.GetStart()
            # Filter out clips shorter than 5 seconds (assuming 24fps, 120 frames. Let's be safe with 100 frames ~ 4s)
            if duration < 100:
                continue
                
            clip_data.append({
                "start": clip.GetStart(),
                "end": clip.GetEnd(),
                "name": clip.GetName()
            })

        print(f"Processing {len(clip_data)} valid clips (filtered out short clips)...")

        original_timeline = timeline
        success_count = 0
        name_counters = {} # To track duplicate names
        
        for data in clip_data:
            # Ensure we are on the original timeline before duplicating
            project.SetCurrentTimeline(original_timeline)
            
            start_frame = data["start"]
            end_frame = data["end"]
            raw_name = data["name"]
            
            # Sanitize filename
            safe_name = "".join([c for c in raw_name if c.isalpha() or c.isdigit() or c==' ' or c=='_']).rstrip()
            
            # Handle duplicates
            if safe_name in name_counters:
                name_counters[safe_name] += 1
                unique_name = f"{safe_name}_{name_counters[safe_name]}"
            else:
                name_counters[safe_name] = 1
                unique_name = safe_name
            
            new_timeline_name = f"Interview_{unique_name}"

            print(f"Creating timeline: {new_timeline_name}...")
            print(f"  Range: {start_frame} - {end_frame}")
            
            # Duplicate the original timeline
            new_timeline = original_timeline.DuplicateTimeline(new_timeline_name)
            
            if new_timeline:
                # Switch to the new timeline
                project.SetCurrentTimeline(new_timeline)
                
                # 1. Set In/Out points (needed for cleanup)
                new_timeline.SetMarkInOut(start_frame, end_frame)
                
                # 2. Cleanup: Delete clips completely outside the range
                print("  Cleaning up outside clips...")
                items_to_delete = []
                
                # Check Video Tracks
                video_track_count = new_timeline.GetTrackCount("video")
                for i in range(1, video_track_count + 1):
                    items = new_timeline.GetItemListInTrack("video", i)
                    if items:
                        for item in items:
                            if item.GetEnd() <= start_frame or item.GetStart() >= end_frame:
                                items_to_delete.append(item)

                # Check Audio Tracks
                audio_track_count = new_timeline.GetTrackCount("audio")
                for i in range(1, audio_track_count + 1):
                    items = new_timeline.GetItemListInTrack("audio", i)
                    if items:
                        for item in items:
                            if item.GetEnd() <= start_frame or item.GetStart() >= end_frame:
                                items_to_delete.append(item)
                
                if items_to_delete:
                    new_timeline.DeleteClips(items_to_delete)
                    print(f"  Deleted {len(items_to_delete)} clips outside range.")
                
                # 3. Clear In/Out points (User request)
                new_timeline.ClearMarkInOut()
                
                success_count += 1
            else:
                print(f"Failed to duplicate timeline for: {raw_name}")

        print(f"Successfully created {success_count} new timelines.")

    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
