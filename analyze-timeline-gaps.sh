#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Analyze Timeline Gaps
# @raycast.mode fullOutput
# @raycast.packageName DaVinci Resolve

# Optional parameters:
# @raycast.icon 📊
# @raycast.description Find and analyze gaps between clips in current DaVinci Resolve timeline

# Create a temporary Python script
TEMP_SCRIPT=$(mktemp /tmp/analyze_gaps.XXXXXX.py)

cat > "$TEMP_SCRIPT" << 'PYTHON_SCRIPT'
#!/usr/bin/env python3
import sys

# DaVinci Resolve API setup
try:
    sys.path.append("/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/Modules")
    import DaVinciResolveScript as dvr_script
    resolve = dvr_script.scriptapp("Resolve")
except ImportError:
    print("❌ Could not import DaVinci Resolve scripting module")
    sys.exit(1)

def get_timeline_items_with_positions(timeline):
    """Get all timeline items with their positions"""
    items = []

    track_count = timeline.GetTrackCount("video")

    for track_index in range(1, track_count + 1):
        track_items = timeline.GetItemListInTrack("video", track_index)

        for item in track_items:
            start_frame = item.GetStart()
            end_frame = item.GetEnd()
            duration = item.GetDuration()
            name = item.GetName()

            items.append({
                'item': item,
                'track': track_index,
                'start': start_frame,
                'end': end_frame,
                'duration': duration,
                'name': name
            })

    # Sort by start frame
    items.sort(key=lambda x: x['start'])

    return items

def find_gaps(items, min_gap_frames=30):
    """Find gaps between clips"""
    gaps = []

    for i in range(len(items) - 1):
        current_end = items[i]['end']
        next_start = items[i + 1]['start']

        gap_size = next_start - current_end

        if gap_size >= min_gap_frames:
            gaps.append({
                'gap_start': current_end,
                'gap_end': next_start,
                'gap_frames': gap_size,
                'before_clip': items[i]['name'],
                'after_clip': items[i + 1]['name']
            })

    return gaps

def main():
    if not resolve:
        print("❌ Could not connect to DaVinci Resolve")
        print("Make sure DaVinci Resolve is running")
        return

    project_manager = resolve.GetProjectManager()
    project = project_manager.GetCurrentProject()

    if not project:
        print("❌ No project is currently open")
        return

    timeline = project.GetCurrentTimeline()

    if not timeline:
        print("❌ No timeline is currently open")
        return

    print(f"📋 Timeline: {timeline.GetName()}")
    print(f"📁 Project: {project.GetName()}")

    # Get frame rate for reference
    frame_rate = float(timeline.GetSetting('timelineFrameRate'))
    print(f"🎬 Frame rate: {frame_rate} fps\n")

    # Get all items
    items = get_timeline_items_with_positions(timeline)
    print(f"📹 Found {len(items)} clips on video tracks\n")

    # Use default minimum gap (30 frames / ~1 second at 24fps)
    min_gap_frames = 30
    min_gap_seconds = min_gap_frames / frame_rate

    print(f"🔍 Looking for gaps of {min_gap_frames} frames or more ({min_gap_seconds:.2f}s)\n")
    print("=" * 70)

    # Find gaps
    gaps = find_gaps(items, min_gap_frames)

    if gaps:
        print(f"\n🔴 FOUND {len(gaps)} GAP(S):\n")

        for i, gap in enumerate(gaps, 1):
            gap_seconds = gap['gap_frames'] / frame_rate
            gap_timecode_start = int(gap['gap_start'] / frame_rate)
            gap_timecode_end = int(gap['gap_end'] / frame_rate)

            print(f"Gap {i}:")
            print(f"  📍 Location: frames {gap['gap_start']} to {gap['gap_end']}")
            print(f"  ⏱️  Duration: {gap['gap_frames']} frames ({gap_seconds:.2f} seconds)")
            print(f"  ⬅️  After clip: {gap['before_clip']}")
            print(f"  ➡️  Before clip: {gap['after_clip']}")
            print()

        print("=" * 70)

        # Calculate segments
        segments = []
        last_end = items[0]['start']

        for i, gap in enumerate(gaps):
            segment_frames = gap['gap_start'] - last_end
            segment_seconds = segment_frames / frame_rate
            segments.append({
                'num': i + 1,
                'frames': segment_frames,
                'seconds': segment_seconds
            })
            last_end = gap['gap_end']

        # Add final segment
        final_frames = items[-1]['end'] - last_end
        final_seconds = final_frames / frame_rate
        segments.append({
            'num': len(gaps) + 1,
            'frames': final_frames,
            'seconds': final_seconds
        })

        print(f"\n📊 TIMELINE SEGMENTS ({len(segments)} continuous sections):\n")
        for seg in segments:
            print(f"  Segment {seg['num']}: {seg['frames']} frames ({seg['seconds']:.2f}s)")

    else:
        print("\n✅ No significant gaps found - timeline is continuous!")

    print("\n" + "=" * 70)

if __name__ == "__main__":
    main()
PYTHON_SCRIPT

# Run Python script
python3 "$TEMP_SCRIPT"
EXIT_CODE=$?

# Clean up temp script
rm -f "$TEMP_SCRIPT"

exit $EXIT_CODE
