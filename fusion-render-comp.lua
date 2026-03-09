-- Fusion Studio Single Comp Render Script
-- Renders the currently active comp as 4K ProRes 4444 .mov,
-- outputs to the frontmost Finder window's directory,
-- then reveals the rendered file in a new Finder tab.

-- Connect to running Fusion instance
local fu = bmd.scriptapp("Fusion")
if not fu then
    print("ERROR: Could not connect to Fusion Studio")
    os.exit(1)
end

-- Get the current (active) comp
local comp = fu.CurrentComp
if not comp then
    print("ERROR: No active composition in Fusion")
    os.exit(1)
end

local comp_name = comp:GetAttrs().COMPS_Name
print("Active comp: " .. comp_name)

-- Set frame format: 3840x2160 @ 23.976
print("\n=== Setting frame format: 3840x2160 @ 23.976 ===")
comp:SetPrefs({
    ["Comp.FrameFormat.Width"] = 3840,
    ["Comp.FrameFormat.Height"] = 2160,
    ["Comp.FrameFormat.Rate"] = 23.976,
})

-- Get frontmost Finder window path via AppleScript
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

-- Clean comp name: strip " - Composition X.comp" suffix and .comp extension
local cleaned = comp_name:gsub("%s*%-%s*Composition%s*%d+%.comp$", "")
cleaned = cleaned:gsub("%.comp$", "")
cleaned = cleaned:match("^%s*(.-)%s*$")

local output_path = base_dir .. cleaned .. ".mov"

-- Configure Saver nodes
print("\n=== Configuring Saver nodes ===")
local savers = comp:GetToolList(false, "Saver")
if not savers or #savers == 0 then
    print("ERROR: No Saver nodes found in comp")
    os.exit(1)
end

for j, saver in pairs(savers) do
    saver.Clip = output_path
    saver.OutputFormat = "QuickTimeMovies"
    saver["QuickTimeMovies.Compression"] = "Apple ProRes 4444_ap4h"
    saver["QuickTimeMovies.Advanced"] = 1
    saver.CreateDir = 0
    print(string.format("  %s -> %s", saver:GetAttrs().TOOLS_Name, output_path))
end

-- Render
print("\n=== Rendering ===")
comp:Render({ Tool = savers, Wait = true })
print("=== Render complete! ===")

-- Reveal in Finder (new tab)
print("\n=== Revealing in Finder ===")
local reveal_cmd = string.format('osascript -e \'tell application "Finder"\nactivate\ntell front window\nmake new tab\nend tell\nreveal POSIX file "%s"\nend tell\'', output_path)
os.execute(reveal_cmd)

print("Done: " .. output_path)
