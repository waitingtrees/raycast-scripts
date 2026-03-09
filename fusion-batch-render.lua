-- Fusion Studio Batch Render Script
-- Loads comps from manifest (if provided) or uses already-open comps.
-- Sets all comps to 4K 23.976, configures Savers to ProRes 4444 .mov,
-- outputs to the frontmost Finder window's directory, then renders all.

local manifest_path = arg and arg[1] or nil

-- Connect to running Fusion instance
local fu = bmd.scriptapp("Fusion")
if not fu then
    print("ERROR: Could not connect to Fusion Studio")
    os.exit(1)
end

-- If manifest provided, load those comps into Fusion Studio
if manifest_path then
    local f = io.open(manifest_path, "r")
    if f then
        print("=== Loading comps from manifest ===")
        for line in f:lines() do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" then
                print("  Loading: " .. line)
                fu:LoadComp(line, false)
            end
        end
        f:close()
    end
end

-- Get all open comps
local comps = fu:GetCompList()
if not comps or #comps == 0 then
    print("ERROR: No compositions open in Fusion")
    os.exit(1)
end

print(string.format("Found %d open comp(s)", #comps))

-- Step 1: Set all comps to 3840x2160 @ 23.976
print("\n=== Setting frame format: 3840x2160 @ 23.976 ===")
for i, comp in pairs(comps) do
    comp:SetPrefs({
        ["Comp.FrameFormat.Width"] = 3840,
        ["Comp.FrameFormat.Height"] = 2160,
        ["Comp.FrameFormat.Rate"] = 23.976,
    })
    print(string.format("  [%d] %s — frame format set", i, comp:GetAttrs().COMPS_Name))
end

-- Step 2: Get frontmost Finder window path via AppleScript
print("\n=== Getting output directory from Finder ===")
local handle = io.popen('osascript -e \'tell application "Finder" to get POSIX path of (target of front window as alias)\' 2>&1')
local base_dir = handle:read("*a")
handle:close()

base_dir = base_dir:match("^%s*(.-)%s*$")

if not base_dir or base_dir == "" or base_dir:find("error") then
    print("ERROR: Could not get Finder window path. Make sure a Finder window is open.")
    os.exit(1)
end

if base_dir:sub(-1) ~= "/" then
    base_dir = base_dir .. "/"
end

print("  Output directory: " .. base_dir)

-- Step 3: Configure Saver nodes
print("\n=== Configuring Saver nodes ===")
for i, comp in pairs(comps) do
    local comp_name = comp:GetAttrs().COMPS_Name

    -- Clean comp name: strip " - Composition X.comp" suffix and trim
    local cleaned = comp_name:gsub("%s*%-%s*Composition%s*%d+%.comp$", "")
    -- Also strip .comp extension if present
    cleaned = cleaned:gsub("%.comp$", "")
    cleaned = cleaned:match("^%s*(.-)%s*$")

    local output_path = base_dir .. cleaned .. ".mov"

    local savers = comp:GetToolList(false, "Saver")
    for j, saver in pairs(savers) do
        saver.Clip = output_path
        saver.OutputFormat = "QuickTimeMovies"
        saver["QuickTimeMovies.Compression"] = "Apple ProRes 4444_ap4h"
        saver["QuickTimeMovies.Advanced"] = 1
        saver.CreateDir = 0
        print(string.format("  [%d] %s → %s", i, saver:GetAttrs().TOOLS_Name, output_path))
    end
end

-- Step 4: Render all comps sequentially
print("\n=== Rendering ===")
for i, comp in pairs(comps) do
    local comp_name = comp:GetAttrs().COMPS_Name
    print(string.format("  [%d/%d] Rendering: %s ...", i, #comps, comp_name))

    comp:Render({ Tool = comp:GetToolList(false, "Saver"), Wait = true })

    print(string.format("  [%d/%d] Done: %s", i, #comps, comp_name))
end

-- Step 5: Completion
print(string.format("\n=== All %d comp(s) rendered successfully! ===", #comps))
