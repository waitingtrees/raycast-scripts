-- Export Fusion Composition clips from the current DaVinci Resolve timeline
-- Outputs .comp files to the frontmost Finder window directory
-- Writes exported file paths to a temp manifest for downstream scripts

local resolve = bmd.scriptapp("Resolve")
if not resolve then
    print("ERROR: Could not connect to DaVinci Resolve")
    os.exit(1)
end

local project = resolve:GetProjectManager():GetCurrentProject()
local timeline = project:GetCurrentTimeline()
if not timeline then
    print("ERROR: No timeline is currently open")
    os.exit(1)
end

print("Timeline: " .. timeline:GetName())

-- Get output directory from frontmost Finder window
local handle = io.popen('osascript -e \'tell application "Finder" to get POSIX path of (target of front window as alias)\' 2>&1')
local base_dir = handle:read("*a"):match("^%s*(.-)%s*$")
handle:close()

if not base_dir or base_dir == "" or base_dir:find("error") then
    print("ERROR: Could not get Finder window path")
    os.exit(1)
end
if base_dir:sub(-1) ~= "/" then base_dir = base_dir .. "/" end
print("Output: " .. base_dir)

-- Scan timeline for Fusion Composition clips only
local exported = {}
local track_count = timeline:GetTrackCount("video")

for t = 1, track_count do
    local items = timeline:GetItemListInTrack("video", t)
    if items then
        for _, item in ipairs(items) do
            local is_fusion_comp = false
            local mpi = item:GetMediaPoolItem()

            if item:GetFusionCompCount() > 0 then
                if mpi then
                    -- Clip from media pool — check type
                    local clip_type = mpi:GetClipProperty("Type")
                    if clip_type == "Fusion Composition" then
                        is_fusion_comp = true
                    end
                else
                    -- Generated clip with no media pool item
                    -- Skip known non-comp types: Adjustment Clips, transitions, titles
                    local name = item:GetName()
                    if name ~= "Adjustment Clip" and name ~= "Cross Dissolve" then
                        is_fusion_comp = true
                    end
                end
            end

            if is_fusion_comp then
                local comp_count = item:GetFusionCompCount()
                local comp_names = item:GetFusionCompNameList() or {}
                local item_name = item:GetName()

                for ci = 1, comp_count do
                    local comp_name = comp_names[ci] or ("Comp" .. ci)
                    -- Build filename: use item name if meaningful, else comp name
                    local filename = item_name
                    if filename == "Fusion Composition" then
                        filename = comp_name
                    end
                    -- Sanitize filename
                    filename = filename:gsub("[/\\:]", "_"):match("^%s*(.-)%s*$")

                    local out_path = base_dir .. filename .. ".comp"
                    local ok = item:ExportFusionComp(out_path, ci)
                    if ok then
                        table.insert(exported, out_path)
                        print(string.format("  Exported: %s", out_path))
                    else
                        print(string.format("  FAILED: %s", out_path))
                    end
                end
            end
        end
    end
end

if #exported == 0 then
    print("No Fusion Composition clips found on timeline")
    os.exit(1)
end

-- Write manifest for downstream scripts
local manifest_path = "/tmp/fusion-export-manifest.txt"
local f = io.open(manifest_path, "w")
for _, path in ipairs(exported) do
    f:write(path .. "\n")
end
f:close()

print(string.format("\nExported %d comp(s) — manifest: %s", #exported, manifest_path))
