#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Fusion Batch Key
# @raycast.mode silent
# @raycast.packageName Video

# Optional parameters:
# @raycast.icon 🟢

# Documentation:
# @raycast.description Key selected green screen .mov files through open Fusion comp
# @raycast.author assistant2

FUSCRIPT="/Applications/Blackmagic Fusion 20/Fusion.app/Contents/Libraries/fuscript"

# Get selected Finder files
selected=$(osascript -e '
tell application "Finder"
    set sel to selection
    if sel is {} then return ""
    set paths to {}
    repeat with f in sel
        set end of paths to POSIX path of (f as alias)
    end repeat
    set AppleScript'\''s text item delimiters to linefeed
    return paths as text
end tell')

if [ -z "$selected" ]; then
    echo "❌ No files selected in Finder"
    exit 1
fi

# Filter to .mov files
mov_files=()
while IFS= read -r line; do
    [[ "$line" == *.mov ]] && mov_files+=("$line")
done <<< "$selected"

if [ ${#mov_files[@]} -eq 0 ]; then
    echo "❌ No .mov files selected"
    exit 1
fi

# Output folder = "GS OUT" sibling to the folder containing selected files
input_folder=$(dirname "${mov_files[0]}")
parent_folder=$(dirname "$input_folder")
output_folder="$parent_folder/GS OUT"
mkdir -p "$output_folder"

# Build temp Lua script
lua_script=$(mktemp /tmp/fusion_batch_XXXXXX.lua)

cat > "$lua_script" << 'LUAHEAD'
local fu = Fusion("localhost")
if not fu then print("ERROR: Cannot connect to Fusion. Is it running?"); return end
local comp = fu.CurrentComp
if not comp then print("ERROR: No comp open in Fusion."); return end

-- Auto-discover first Loader in the comp
local loader = nil
for _, l in pairs(comp:GetToolList(false, "Loader")) do loader = l; break end
if not loader then print("ERROR: No Loader found in comp"); return end

-- Find or auto-create Saver
local saver = nil
for _, s in pairs(comp:GetToolList(false, "Saver")) do saver = s; break end

if not saver then
    print("No Saver found — creating one...")
    comp:Lock()

    -- Find end-of-chain tools: tools whose main output isn't feeding anything
    local end_tool = nil
    for _, t in pairs(comp:GetToolList()) do
        -- Skip masks and the Loader itself
        if t.ID ~= "PolylineMask" and t.ID ~= "Loader" then
            local main_out = t:FindMainOutput(1)
            if main_out then
                local connected = main_out:GetConnectedInputs()
                -- No downstream connections = end of chain
                if not connected or #connected == 0 then
                    end_tool = t
                    -- Prefer a DeltaKeyer if we find one
                    if t.ID == "DeltaKeyer" then break end
                end
            end
        end
    end

    if not end_tool then
        print("ERROR: Could not find end of node chain")
        comp:Unlock()
        return
    end

    -- Place saver to the right of the end tool
    local flow = comp.CurrentFrame.FlowView
    local lx, ly = flow:GetPos(end_tool)
    saver = comp:AddTool("Saver", lx + 2, ly)

    -- Connect to the end tool's output
    saver:FindMainInput(1):ConnectTo(end_tool:FindMainOutput(1))

    -- ProRes 4444 HW with alpha
    saver.OutputFormat = "QuickTimeMovies"
    saver["QuickTimeMovies.Compression"] = "AppleProResHW 4444_ap4h"
    saver.ProcessWhenBlendIs00 = 0

    comp:Unlock()
    print("Saver created and connected to " .. end_tool.Name)
end

print("Loader: " .. loader.Name)
print("Saver:  " .. saver.Name)

local files = {
LUAHEAD

# Add each file with its frame count
for f in "${mov_files[@]}"; do
    frames=$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 "$f")
    outname="$(basename "${f%.mov}")_keyed.mov"
    # Escape paths for Lua
    escaped_in=$(printf '%s' "$f" | sed 's/\\/\\\\/g; s/"/\\"/g')
    escaped_out=$(printf '%s' "$output_folder/$outname" | sed 's/\\/\\\\/g; s/"/\\"/g')
    echo "    { input = \"$escaped_in\", output = \"$escaped_out\", frames = $frames }," >> "$lua_script"
done

cat >> "$lua_script" << 'LUATAIL'
}

for i, file in ipairs(files) do
    local name = file.input:match("([^/]+)$")
    print(string.format("\n=== [%d/%d] %s ===", i, #files, name))

    comp:Lock()

    -- Set loader clip
    loader.Clip = file.input

    -- Match comp settings to source media
    local attrs = loader:GetAttrs()
    local width = attrs.TOOLIT_Clip_Width and attrs.TOOLIT_Clip_Width[1]
    local height = attrs.TOOLIT_Clip_Height and attrs.TOOLIT_Clip_Height[1]
    if width and height and width > 0 and height > 0 then
        comp:SetPrefs({
            ["Comp.FrameFormat.Width"] = width,
            ["Comp.FrameFormat.Height"] = height,
        })
        print(string.format("  Resolution: %dx%d", width, height))
    end

    -- Set frame range
    local last_frame = file.frames - 1
    comp:SetAttrs({ COMPN_GlobalStart = 0, COMPN_GlobalEnd = last_frame })
    comp:SetAttrs({ COMPN_RenderStart = 0, COMPN_RenderEnd = last_frame })

    -- Set saver output
    saver.Clip = file.output

    comp:Unlock()

    local ok = comp:Render({ Start = 0, End = last_frame, Wait = true })
    if ok then
        print("  DONE: " .. file.output)
    else
        print("  FAILED: " .. name)
    end
end

print("\n=== Batch complete ===")
LUATAIL

# Run in background so Raycast returns immediately
(
    "$FUSCRIPT" "$lua_script" 2>&1
    rm -f "$lua_script"
    afplay /System/Library/Sounds/Glass.aiff
) &
disown

echo "⚡ Keying ${#mov_files[@]} clips → $(basename "$output_folder")/"
