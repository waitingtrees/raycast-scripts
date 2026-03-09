#!/Library/Frameworks/Python.framework/Versions/3.10/bin/python3

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Foolcat Video Report
# @raycast.mode silent
# @raycast.packageName Video Tools

# Optional parameters:
# @raycast.icon 🎞️
# @raycast.argument1 { "type": "dropdown", "placeholder": "Apply LUT?", "optional": true, "data": [{"title": "Apply Sony LUT", "value": "true"}, {"title": "No LUT", "value": "false"}] }

# Documentation:
# @raycast.description Generates a contact sheet PDF for video files in selected folder
# @raycast.author assistant2

import os
import sys
import subprocess
import json
import glob
import time
import shutil
import tempfile
import math
from pathlib import Path
from datetime import datetime

# Try to import required libraries
try:
    from reportlab.pdfgen import canvas
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.units import inch
except ImportError:
    print("Error: Missing required libraries")
    sys.exit(1)

# Configuration
LUT_PATH = "/Library/Application Support/Blackmagic Design/DaVinci Resolve/LUT/NOBOX_SLog3SG3C_CO3StrongFilm_D65w_Rec709(1).cube"
VIDEO_EXTENSIONS = {'.mov', '.mp4', '.mxf', '.braw', '.r3d', '.avi', '.mkv', '.webm'}
FRAMES_PER_VIDEO = 6
THUMB_WIDTH = 1.8 * inch
TEMP_DIR = Path(tempfile.mkdtemp(prefix="foolcat_clone_"))

def get_finder_selection():
    """Get selected files from Finder using AppleScript"""
    script = '''
    tell application "Finder"
        set selectionList to selection
        if selectionList is {} then
            if exists folder of front window then
                set selectionList to {folder of front window}
            end if
        end if
        
        set pathList to {}
        repeat with i in selectionList
            set end of pathList to POSIX path of (i as alias)
        end repeat
        return pathList
    end tell
    '''
    try:
        result = subprocess.run(['osascript', '-e', script], capture_output=True, text=True)
        if result.returncode != 0:
            return []
        
        raw_output = result.stdout.strip()
        if not raw_output:
            return []
            
        return [p.strip() for p in raw_output.split(', ')]
    except Exception:
        return []

def find_videos(paths):
    videos = []
    video_paths = set() 
    
    for path_str in paths:
        path = Path(path_str)
        if path.is_file():
            if path.suffix.lower() in VIDEO_EXTENSIONS and path not in video_paths:
                videos.append(path)
                video_paths.add(path)
        elif path.is_dir():
            for root, _, files in os.walk(path):
                for file in files:
                    p = Path(root) / file
                    if p.suffix.lower() in VIDEO_EXTENSIONS and p not in video_paths:
                        videos.append(p)
                        video_paths.add(p)
    return sorted(videos)

def format_bytes(size):
    power = 2**10
    n = size
    power_labels = {0 : '', 1: 'K', 2: 'M', 3: 'G', 4: 'T'}
    count = 0
    while n > power:
        n /= power
        count += 1
    return f"{n:.2f} {power_labels[count]}B"

def format_duration(seconds):
    seconds = int(seconds)
    minutes = seconds // 60
    rem_seconds = seconds % 60
    return f"{minutes}m {rem_seconds}s"

def get_video_metadata(file_path):
    try:
        cmd = [
            'ffprobe', 
            '-v', 'error', 
            '-select_streams', 'v:0', 
            '-show_entries', 'stream=width,height,duration,nb_frames,avg_frame_rate,codec_name,codec_long_name,bit_rate', 
            '-show_entries', 'stream_tags=creation_time,timecode',
            '-show_entries', 'format=duration,size,bit_rate',
            '-show_entries', 'format_tags=major_brand,model,creation_time',
            '-show_streams', '-show_format',
            '-of', 'json', 
            str(file_path)
        ]
        
        audio_cmd = [
             'ffprobe', '-v', 'error', 
             '-select_streams', 'a', 
             '-show_entries', 'stream=channels', 
             '-of', 'json', 
             str(file_path)
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)
        data = json.loads(result.stdout)
        
        audio_result = subprocess.run(audio_cmd, capture_output=True, text=True)
        audio_data = json.loads(audio_result.stdout)
        
        stream = data.get('streams', [{}])[0]
        fmt = data.get('format', {})
        s_tags = stream.get('tags', {})
        f_tags = fmt.get('tags', {})
        
        duration = float(fmt.get('duration', stream.get('duration', 0)))
        size_bytes = int(fmt.get('size', 0))
        nb_frames = int(stream.get('nb_frames', 0))
        if nb_frames == 0 and duration > 0:
             fps_val = stream.get('avg_frame_rate', '24/1')
             if '/' in fps_val:
                 num, den = map(int, fps_val.split('/'))
                 fps = num / den if den else 0
             else:
                 fps = float(fps_val)
             nb_frames = int(duration * fps)

        width = int(stream.get('width', 0))
        height = int(stream.get('height', 0))
        aspect = f"{width/height:.2f}:1" if height else "?"
        codec = stream.get('codec_long_name', stream.get('codec_name', 'Unknown'))
        if 'ProRes' in codec: codec = 'Apple ProRes'
        
        bitrate_bps = int(fmt.get('bit_rate', stream.get('bit_rate', 0)))
        bitrate_str = f"{bitrate_bps / (1024*1024 * 8):.2f} MB/s"

        fps_str = stream.get('avg_frame_rate', '0/0')
        if '/' in fps_str:
            n, d = map(int, fps_str.split('/'))
            fps = n/d if d else 0
        else:
            fps = float(fps_str)
        
        date_str = f_tags.get('creation_time', s_tags.get('creation_time', ''))
        creation_formatted = "Unknown Date"
        time_formatted = ""
        if date_str:
            try:
                dt = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
                creation_formatted = dt.strftime("%b %-d %Y")
                time_formatted = dt.strftime("%I:%M %p")
            except:
                pass
        
        timecode = s_tags.get('timecode', '00:00:00:00')
        
        audio_channels = 0
        for a_stream in audio_data.get('streams', []):
            audio_channels += int(a_stream.get('channels', 0))
            
        camera = f_tags.get('model', f_tags.get('major_brand', ''))
        type_ext = Path(file_path).suffix.upper().replace('.', '') + " movie"

        return {
            'filename': Path(file_path).name,
            'path': str(file_path),
            'duration_sec': duration,
            'duration_fmt': f"{int(duration)}s",
            'frames': nb_frames,
            'size_bytes': size_bytes,
            'size_str': format_bytes(size_bytes),
            'resolution': f"{width}x{height}",
            'aspect': aspect,
            'codec': codec,
            'bitrate': bitrate_str,
            'fps': f"{fps:.2f} FPS",
            'date': creation_formatted,
            'time': time_formatted,
            'timecode': f"TC {timecode}",
            'channels': f"{audio_channels} audio channels",
            'camera': camera,
            'type': type_ext
        }
    except Exception:
        return None

def extract_frames(video_path, duration, apply_lut):
    frames = []
    step = duration / (FRAMES_PER_VIDEO + 1)
    video_stem = video_path.stem
    
    for i in range(1, FRAMES_PER_VIDEO + 1):
        timestamp = step * i
        out_path = TEMP_DIR / f"{video_stem}_frame_{i}.jpg"
        
        vf_filter = f"scale=480:-1" 
        if apply_lut and os.path.exists(LUT_PATH):
            vf_filter += f",lut3d='{LUT_PATH}'"
            
        cmd = [
            'ffmpeg', '-ss', str(timestamp), 
            '-i', str(video_path),
            '-vframes', '1',
            '-vf', vf_filter,
            '-q:v', '2',
            '-y', 
            '-loglevel', 'quiet', # Silence ffmpeg
            str(out_path)
        ]
        
        subprocess.run(cmd, capture_output=True)
        if out_path.exists():
            frames.append(out_path)
            
    return frames

def calculate_total_stats(meta_list):
    total_clips = len(meta_list)
    total_frames = sum(m['frames'] for m in meta_list)
    total_dur_sec = sum(m['duration_sec'] for m in meta_list)
    total_size = sum(m['size_bytes'] for m in meta_list)
    
    return {
        'clips': total_clips,
        'frames': total_frames,
        'duration': format_duration(total_dur_sec),
        'size': format_bytes(total_size)
    }

def resolve_output_path(source_path_str):
    """
    Tries to find '02 Documents' folder by traversing up from '04 Resources'
    """
    try:
        path = Path(source_path_str).resolve()
        
        # Check if we are inside a standard project structure
        # Heuristic: Look for '04 Resources' part in path
        parts = list(path.parts)
        if '04 Resources' in parts:
            # Find the index
            idx = parts.index('04 Resources')
            # Project root is everything before '04 Resources'
            project_root = Path(*parts[:idx])
            
            # Check if 02 Documents exists
            docs_dir = project_root / '02 Documents'
            if docs_dir.exists() and docs_dir.is_dir():
                return docs_dir
    except Exception:
        pass
        
    # Fallback to Desktop
    return Path.home() / "Desktop"

def create_pdf(videos, apply_lut, output_path, source_path_str):
    
    # 1. Gather all metadata
    meta_list = []
    valid_videos = []
    
    for v in videos:
        m = get_video_metadata(v)
        if m:
            meta_list.append(m)
            valid_videos.append(v)
            
    if not meta_list:
        return

    totals = calculate_total_stats(meta_list)
    
    c = canvas.Canvas(str(output_path), pagesize=A4)
    width, height = A4
    
    # Colors
    DARK_BG = (0.1, 0.1, 0.1)
    ROW_BG_1 = (0.15, 0.15, 0.15)
    ROW_BG_2 = (0.18, 0.18, 0.18)
    TEXT_WHITE = (1, 1, 1)
    TEXT_GRAY = (0.7, 0.7, 0.7)
    
    margin_x = 30
    margin_y = 30
    current_y = height - 50
    
    # --- PAGE HEADER (TOTAL STATS) ---
    c.setFillColorRGB(*DARK_BG)
    c.rect(0, 0, width, height, fill=1)
    
    c.setFillColorRGB(*TEXT_WHITE)
    c.setFont("Helvetica-Bold", 11)
    
    lut_status = "LUT" if apply_lut else "None"
    header_line = f"{totals['clips']} clips • {totals['frames']} frames ({totals['duration']}) • {totals['size']} • Color Conversion: {lut_status}"
    c.drawString(margin_x, current_y, header_line)
    
    current_y -= 15
    c.setFont("Helvetica", 9)
    c.setFillColorRGB(*TEXT_GRAY)
    c.drawString(margin_x, current_y, str(source_path_str))
    
    current_y -= 30 
    
    # Layout Config
    # Metadata Height: ~6 lines * 10pt = 60pt + spacing = 80pt
    # Thumbnail Row: Width = PageWidth - 2*Margin. 6 images.
    available_width = width - (2 * margin_x)
    thumb_w = (available_width / 6) - 2 # 2px gap
    thumb_h = thumb_w * (9/16)
    
    row_height = 80 + thumb_h + 20 # Metadata + Thumbs + Padding
    row_index = 0
    
    for i, video in enumerate(valid_videos):
        meta = meta_list[i]
        
        # Check page break
        if current_y - row_height < margin_y:
            c.showPage()
            c.setFillColorRGB(*DARK_BG)
            c.rect(0, 0, width, height, fill=1)
            current_y = height - 50
            row_index = 0
        
        # Row Background
        row_bg = ROW_BG_1 if row_index % 2 == 0 else ROW_BG_2
        c.setFillColorRGB(*row_bg)
        # Draw background for entire block
        c.rect(0, current_y - row_height, width, row_height, fill=1, stroke=0)
        
        # --- Metadata Block ---
        text_x = margin_x
        text_y = current_y - 15
        
        c.setFillColorRGB(*TEXT_WHITE)
        
        # Line 1: Filename
        c.setFont("Helvetica-Bold", 10)
        c.drawString(text_x, text_y, meta['filename'])
        
        # Line 2: Date
        c.setFont("Helvetica", 8)
        c.setFillColorRGB(*TEXT_GRAY)
        text_y -= 12
        c.drawString(text_x, text_y, f"{meta['date']} • {meta['time']}")
        
        # Line 3: Type • Frames • Size
        text_y -= 10
        c.drawString(text_x, text_y, f"{meta['type']} • {meta['frames']} frames ({meta['duration_fmt']}) • {meta['size_str']}")
        
        # Line 4: Res • Codec • FPS
        text_y -= 10
        c.drawString(text_x, text_y, f"{meta['resolution']} ({meta['aspect']}) • {meta['codec']} ({meta['bitrate']}) • {meta['fps']}")

        # Line 5: TC • Channels
        text_y -= 10
        c.drawString(text_x, text_y, f"{meta['timecode']} • {meta['channels']}")
        
        # Line 6: Camera
        if meta['camera']:
            text_y -= 10
            c.drawString(text_x, text_y, meta['camera'])
            
        # --- Thumbnails (Below Metadata) ---
        thumb_y_pos = text_y - thumb_h - 10
        thumb_x_pos = margin_x
        
        frames = extract_frames(video, meta['duration_sec'], apply_lut)
        
        for frame_path in frames:
            try:
                c.drawImage(str(frame_path), thumb_x_pos, thumb_y_pos, width=thumb_w, height=thumb_h, preserveAspectRatio=True)
                thumb_x_pos += thumb_w + 2
            except Exception:
                pass
                
        current_y -= (row_height + 5) # Move down for next item
        row_index += 1
        
    c.save()

def main():
    if len(sys.argv) > 1:
        # Args passed as strings.
        # "true" is passed if the first item (value true) is selected and default.
        apply_lut = (sys.argv[1].lower() == 'true')
    else:
        # Default fallback if no args? Usually Raycast passes args if defined.
        # If dropdown 1 is default, it passes that value.
        apply_lut = True 
    
    paths = get_finder_selection()
    
    if not paths:
        print("Error: No file selected")
        sys.exit(0)
        
    videos = find_videos(paths)
    if not videos:
        print("Error: No videos found")
        sys.exit(0)
        
    # Determine Output Path
    source_root = str(Path(paths[0]).parent) if len(paths) == 1 else str(paths[0])
    if os.path.isdir(paths[0]): source_root = paths[0]
    
    output_dir = resolve_output_path(source_root)
    output_pdf = output_dir / f"Report - {datetime.now().strftime('%Y-%m-%d at %H.%M.%S')}.pdf"
    
    try:
        create_pdf(videos, apply_lut, output_pdf, source_root)
        print("Report Generated")
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        sys.exit(1)
    finally:
        shutil.rmtree(TEMP_DIR)

if __name__ == "__main__":
    main()
