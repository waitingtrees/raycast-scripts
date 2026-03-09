#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Offload Media
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📷
# @raycast.packageName Video Automation

# Documentation:
# @raycast.description Offload media from SD cards (Sony FX6, MixPre, Track E) to project folders
# @raycast.author assistant2

# =============================================================================
# CAMERA FILE ORGANIZATION - Offload Script
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
FOOTAGE_SUBPATH="04 Resources/01 Footage/01 Interview"
UNSORTED_SUBPATH="04 Resources/01 Footage/99 Unsorted"
AUDIO_SUBPATH="04 Resources/02 Audio/On_Location"

# Folders to ignore on MixPre
MIXPRE_IGNORE=("SETTINGS" "SOUNDDEV" "TRASH" "UNDO" "FALSETAKES")

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
log_info() { echo "$1"; }
log_success() { echo "✓ $1"; }
log_error() { echo "❌ $1" >&2; }

# -----------------------------------------------------------------------------
# Get Finder Window Target
# -----------------------------------------------------------------------------
get_finder_path() {
    osascript -e 'tell application "Finder"
        if (count of Finder windows) > 0 then
            return POSIX path of (target of front Finder window as alias)
        else
            return ""
        end if
    end tell' 2>/dev/null || echo ""
}

# -----------------------------------------------------------------------------
# Find Project Root
# -----------------------------------------------------------------------------
find_project_root() {
    local dir="$1"
    dir="${dir%/}"
    while [[ "$dir" != "/" && -n "$dir" ]]; do
        if [[ -d "$dir/04 Resources" ]]; then
            # Validation: Look for known project siblings
            if [[ -d "$dir/01 Project Files" ]] || [[ -d "$dir/02 Documents" ]] || [[ -d "$dir/03 Exports" ]]; then
                echo "$dir"
                return 0
            fi
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

# -----------------------------------------------------------------------------
# Utilities
# -----------------------------------------------------------------------------
human_size() {
    local bytes="$1"
    echo "$bytes" | awk '{
        split("B KB MB GB TB", v)
        s=1
        while($1>=1024 && s<5){$1/=1024; s++}
        printf "%.1f %s", $1, v[s]
    }'
}

check_disk_space() {
    local dest="$1"
    local needed_bytes="$2"
    local available_kb
    available_kb=$(df -k "$dest" | tail -1 | awk '{print $4}')
    local available_bytes=$((available_kb * 1024))

    if [[ $needed_bytes -gt $available_bytes ]]; then
        log_error "Insufficient disk space!"
        log_error "Need: $(human_size "$needed_bytes")"
        log_error "Available: $(human_size "$available_bytes")"
        return 1
    fi
    return 0
}

calculate_dir_size() {
    local path="$1"
    shift
    local patterns=("$@")
    local total=0
    # Uses find to sum sizes. Redirects stderr to avoid permission warnings on weird system files
    for pattern in "${patterns[@]}"; do
        local size
        size=$(find "$path" -type f -iname "$pattern" -print0 2>/dev/null | xargs -0 stat -f%z 2>/dev/null | awk '{s+=$1} END {print s+0}')
        total=$((total + size))
    done
    echo "$total"
}

# -----------------------------------------------------------------------------
# Detection Logic
# -----------------------------------------------------------------------------
detect_sony_cards() {
    local cards=()
    for vol in /Volumes/*/; do
        vol="${vol%/}"
        local vol_name=$(basename "$vol")
        [[ "$vol_name" == "Macintosh HD"* ]] && continue

        # Check for Sony Structure (two possible paths)
        local clip_dir=""
        if [[ -d "$vol/PRIVATE/XDROOT/Clip" ]]; then
            clip_dir="$vol/PRIVATE/XDROOT/Clip"
        elif [[ -d "$vol/XDROOT/Clip" ]]; then
            clip_dir="$vol/XDROOT/Clip"
        fi

        if [[ -n "$clip_dir" ]]; then
            if find "$clip_dir" -maxdepth 1 -name "*.MXF" -print -quit 2>/dev/null | grep -q .; then
                cards+=("$vol")
            fi
        fi
    done
    [[ ${#cards[@]} -gt 0 ]] && printf '%s\n' "${cards[@]}" || true
}

detect_generic_cards() {
    local cards=()
    for vol in /Volumes/*/; do
        vol="${vol%/}"
        local vol_name=$(basename "$vol")
        [[ "$vol_name" == "Macintosh HD"* ]] && continue

        # Has DCIM but NOT XDROOT
        if [[ -d "$vol/DCIM" ]] && [[ ! -d "$vol/PRIVATE/XDROOT" ]]; then
            if find "$vol/DCIM" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mxf" \) -print -quit 2>/dev/null | grep -q .; then
                cards+=("$vol")
            fi
        fi
    done
    [[ ${#cards[@]} -gt 0 ]] && printf '%s\n' "${cards[@]}" || true
}

detect_mixpre() {
    for vol in /Volumes/*/; do
        vol="${vol%/}"
        vol_name=$(basename "$vol")
        [[ "$vol_name" == "Macintosh HD"* ]] && continue

        if [[ "$vol_name" == *"MixPre"* ]] || [[ "$vol_name" == *"MIXPRE"* ]] || [[ "$vol_name" == *"mixpre"* ]]; then
            if find "$vol" -maxdepth 1 -type d -regex '.*/[0-9][0-9]-[0-9][0-9]-[0-9][0-9]' -print -quit 2>/dev/null | grep -q .; then
                echo "$vol"
                return 0
            fi
        fi
    done
    return 1
}

detect_tracke() {
    local cards=()
    for vol in /Volumes/*/; do
        vol="${vol%/}"
        local vol_name=$(basename "$vol")
        [[ "$vol_name" == "Macintosh HD"* ]] && continue

        if find "$vol" -maxdepth 1 -type d -name "LAV*_*" -print -quit 2>/dev/null | grep -q .; then
            if find "$vol"/LAV*_* -maxdepth 1 -type f -iname "*.wav" -print -quit 2>/dev/null | grep -q .; then
                cards+=("$vol")
            fi
        fi
    done
    [[ ${#cards[@]} -gt 0 ]] && printf '%s\n' "${cards[@]}" || true
}

# -----------------------------------------------------------------------------
# Copy Logic
# -----------------------------------------------------------------------------
copy_sony_files() {
    local source_vol="$1"
    local dest_base="$2"
    local clip_dir=""

    # Determine which path structure exists
    if [[ -d "$source_vol/PRIVATE/XDROOT/Clip" ]]; then
        clip_dir="$source_vol/PRIVATE/XDROOT/Clip"
    elif [[ -d "$source_vol/XDROOT/Clip" ]]; then
        clip_dir="$source_vol/XDROOT/Clip"
    fi

    local cam_a_count=0
    local cam_b_count=0
    local sidecar_count=0

    mkdir -p "$dest_base/CAM A"
    mkdir -p "$dest_base/CAM B"

    while IFS= read -r -d '' mxf_file; do
        local filename=$(basename "$mxf_file")
        local base="${mxf_file%.MXF}"
        local dest_cam

        # Determine Camera Letter
        if [[ "$filename" == *"CAMA"* ]] || [[ "$filename" == *"CAM_A"* ]] || [[ "$filename" == *"CAM A"* ]]; then
            dest_cam="CAM A"
        elif [[ "$filename" == *"CAMB"* ]] || [[ "$filename" == *"CAM_B"* ]] || [[ "$filename" == *"CAM B"* ]]; then
            dest_cam="CAM B"
        else
            dest_cam="CAM A" # Default
        fi

        local dest_dir="$dest_base/$dest_cam"

        # RSYNC MAGIC:
        # -a: archive (times, perms)
        # --backup --suffix: If file exists & differs, rename old one to _DUP_Timestamp
        # Note: We rely on rsync to check size/time. We do NOT manually check.
        
        rsync -ah --backup --suffix="_DUP_$(date +%s)" --partial "$mxf_file" "$dest_dir/"

        if [[ "$dest_cam" == "CAM A" ]]; then cam_a_count=$((cam_a_count + 1)); else cam_b_count=$((cam_b_count + 1)); fi

        # Copy sidecars (XML, BIM, M01)
        for ext in XML BIM M01; do
            if [[ -f "${base}.${ext}" ]]; then
                rsync -ah --update --partial "${base}.${ext}" "$dest_dir/"
                sidecar_count=$((sidecar_count + 1))
            fi
        done
    done < <(find "$clip_dir" -maxdepth 1 -type f -name "*.MXF" -print0 2>/dev/null)

    log_info "   → CAM A: $cam_a_count clips"
    log_info "   → CAM B: $cam_b_count clips"
    [[ $sidecar_count -gt 0 ]] && log_info "   → Sidecars: $sidecar_count"
    
    # Return count for summary
    echo "$((cam_a_count + cam_b_count))"
}

copy_generic_files() {
    local source_vol="$1"
    local dest_dir="$2"
    local count=0

    mkdir -p "$dest_dir"

    # Find video files
    while IFS= read -r -d '' file; do
        rsync -ah --backup --suffix="_DUP_$(date +%s)" --partial "$file" "$dest_dir/"
        count=$((count + 1))
    done < <(find "$source_vol/DCIM" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mxf" \) -print0 2>/dev/null)

    log_info "   → Unsorted: $count files"
    echo "$count"
}

copy_mixpre_audio() {
    # MixPre: Copy ONLY the most recent date folder
    local source_vol="$1"
    local dest_dir="$2"

    mkdir -p "$dest_dir"

    # Find the most recent date folder by modification time (not alphabetically)
    local latest_folder
    latest_folder=$(ls -td "$source_vol"/*/ 2>/dev/null | grep -E '/[0-9]{2}-[0-9]{2}-[0-9]{2}/$' | head -1)
    latest_folder="${latest_folder%/}"  # Remove trailing slash

    if [[ -z "$latest_folder" ]]; then
        echo "0"
        return 0
    fi

    local folder_name=$(basename "$latest_folder")
    local dest_folder="$dest_dir/$folder_name"
    mkdir -p "$dest_folder"

    # Count files
    local file_count=$(find "$latest_folder" -type f -iname "*.wav" 2>/dev/null | wc -l | tr -d ' ')

    # Rsync
    rsync -ah --update --partial "$latest_folder/" "$dest_folder/"

    log_info "   → $folder_name/: $file_count files"
    echo "$file_count"
}

copy_tracke_audio() {
    # Track E: Copy ONLY the most recent LAV folder
    local source_vol="$1"
    local dest_dir="$2"

    mkdir -p "$dest_dir"

    # Find the most recent LAV*_ folder by modification time
    local latest_folder
    latest_folder=$(ls -td "$source_vol"/LAV*_*/ 2>/dev/null | head -1)
    latest_folder="${latest_folder%/}"  # Remove trailing slash

    if [[ -z "$latest_folder" ]]; then
        echo "0"
        return 0
    fi

    local folder_name=$(basename "$latest_folder")
    local dest_folder="$dest_dir/$folder_name"
    mkdir -p "$dest_folder"

    local file_count=$(find "$latest_folder" -type f -iname "*.wav" 2>/dev/null | wc -l | tr -d ' ')

    rsync -ah --update --partial "$latest_folder/" "$dest_folder/"

    log_info "   → $folder_name/: $file_count files"
    echo "$file_count"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

echo "Camera File Organization"
echo "========================"
echo ""

# 1. Location Check
FINDER_PATH=$(get_finder_path)
if [[ -z "$FINDER_PATH" ]]; then
    log_error "No Finder window open."
    exit 1
fi

PROJECT_ROOT=$(find_project_root "$FINDER_PATH") || {
    log_error "Invalid Project Location."
    log_error "Please navigate to a project folder containing '04 Resources'."
    exit 1
}
log_info "Project: $(basename "$PROJECT_ROOT")"

# 2. Card Detection
SONY_CARDS=$(detect_sony_cards)
GENERIC_CARDS=$(detect_generic_cards)
MIXPRE_VOL=$(detect_mixpre || echo "")
TRACKE_CARDS=$(detect_tracke)

if [[ -z "$SONY_CARDS" ]] && [[ -z "$GENERIC_CARDS" ]] && [[ -z "$MIXPRE_VOL" ]] && [[ -z "$TRACKE_CARDS" ]]; then
    log_error "No media cards detected."
    exit 1
fi

# 3. Disk Space Check
log_info "Calculating transfer size..."
total_size=0

# Sum up Sony
if [[ -n "$SONY_CARDS" ]]; then
    while IFS= read -r card; do
        [[ -n "$card" ]] || continue
        clip_path=""
        if [[ -d "$card/PRIVATE/XDROOT/Clip" ]]; then
            clip_path="$card/PRIVATE/XDROOT/Clip"
        elif [[ -d "$card/XDROOT/Clip" ]]; then
            clip_path="$card/XDROOT/Clip"
        fi
        [[ -n "$clip_path" ]] && total_size=$((total_size + $(calculate_dir_size "$clip_path" "*.MXF" "*.XML" "*.BIM" "*.M01")))
    done <<< "$SONY_CARDS"
fi
# Sum up Generic
if [[ -n "$GENERIC_CARDS" ]]; then
    while IFS= read -r card; do [[ -n "$card" ]] && \
    total_size=$((total_size + $(calculate_dir_size "$card/DCIM" "*.mp4" "*.mov" "*.mxf"))); done <<< "$GENERIC_CARDS"
fi
# Sum up MixPre
if [[ -n "$MIXPRE_VOL" ]]; then
    total_size=$((total_size + $(calculate_dir_size "$MIXPRE_VOL" "*.WAV" "*.wav")))
fi
# Sum up Track E
if [[ -n "$TRACKE_CARDS" ]]; then
    while IFS= read -r card; do [[ -n "$card" ]] && \
    total_size=$((total_size + $(calculate_dir_size "$card" "*.WAV" "*.wav"))); done <<< "$TRACKE_CARDS"
fi

if [[ $total_size -gt 0 ]]; then
    if ! check_disk_space "$PROJECT_ROOT" "$total_size"; then exit 1; fi
    log_success "Space OK (~$(human_size "$total_size"))"
else
    log_info "No recognized media files found on cards."
    exit 0
fi
echo ""

# 4. Processing
total_video=0
total_audio=0

# Process Sony
if [[ -n "$SONY_CARDS" ]]; then
    while IFS= read -r card; do
        [[ -z "$card" ]] && continue
        log_info "📹 Sony FX6 ($(basename "$card"))..."
        count=$(copy_sony_files "$card" "$PROJECT_ROOT/$FOOTAGE_SUBPATH")
        total_video=$((total_video + count))
    done <<< "$SONY_CARDS"
    echo ""
fi

# Process Generic
if [[ -n "$GENERIC_CARDS" ]]; then
    while IFS= read -r card; do
        [[ -z "$card" ]] && continue
        log_info "📷 Generic ($(basename "$card"))..."
        count=$(copy_generic_files "$card" "$PROJECT_ROOT/$UNSORTED_SUBPATH")
        total_video=$((total_video + count))
    done <<< "$GENERIC_CARDS"
    echo ""
fi

# Process MixPre (most recent folder only)
if [[ -n "$MIXPRE_VOL" ]]; then
    log_info "🎤 MixPre ($(basename "$MIXPRE_VOL"))..."
    count=$(copy_mixpre_audio "$MIXPRE_VOL" "$PROJECT_ROOT/$AUDIO_SUBPATH")
    total_audio=$((total_audio + count))
    echo ""
fi

# Process Track E (all LAV folders)
if [[ -n "$TRACKE_CARDS" ]]; then
    while IFS= read -r card; do
        [[ -z "$card" ]] && continue
        log_info "🎙 Track E ($(basename "$card"))..."
        count=$(copy_tracke_audio "$card" "$PROJECT_ROOT/$AUDIO_SUBPATH")
        total_audio=$((total_audio + count))
    done <<< "$TRACKE_CARDS"
    echo ""
fi

# 5. Final Summary & Sound
afplay /System/Library/Sounds/Hero.aiff &