-- ClearSaverOutputs.lua
-- Deletes existing Saver outputs just before rendering.
-- • Movies: deletes the single file (e.g., .mov, .mp4, .mxf)
-- • Sequences: deletes frames ONLY within current render range
-- Opt-out: Put "[KEEP]" in a Saver's Comments to skip it

local comp = fu:GetCurrentComp()
if not comp then return end

local function lower(s) return (s or ""):lower() end

local IMAGE_EXT = {
  exr=true, dpx=true, tif=true, tiff=true, png=true, jpg=true, jpeg=true, tga=true, bmp=true, webp=true
}

local function is_image_ext(ext)
  return IMAGE_EXT[lower(ext or "")]
end

local function rm(path)
  if bmd.fileexists(path) then
    os.remove(path)
    print("[PreRender] Deleted: " .. path)
  end
end

local function join(a,b)
  if not a or a=="" then return b end
  if a:sub(-1) == "/" then return a..b end
  return a.."/"..b
end

-- Render range
local attrs = comp:GetAttrs() or {}
local R0 = attrs.COMPN_RenderStart or attrs.COMPN_GlobalStart or comp.CurrentTime or 0
local R1 = attrs.COMPN_RenderEnd   or attrs.COMPN_GlobalEnd   or comp.CurrentTime or 0
if R1 < R0 then R0, R1 = R1, R0 end

-- Policy for sequences: "delete_range" | "delete_all" | "none"
local SEQ_POLICY = "delete_range"

-- For each Saver…
for _, s in pairs(comp:GetToolList(false, "Saver")) do
  -- Skip disabled or explicitly kept savers
  local sattrs = s:GetAttrs() or {}
  if sattrs.TOOLB_PassThrough == true then goto continue end
  local comments = lower(s.Comments and s.Comments[comp.CurrentTime] or "")
  if comments:find("%[keep%]") then
    print("[PreRender] Skipping Saver (KEEP): " .. (sattrs.TOOLB_Name or "<unnamed>"))
    goto continue
  end

  local clip = s.Clip and s.Clip[comp.CurrentTime] or nil
  if not clip or clip == "" then goto continue end

  local pf = bmd.parseFilename(clip)
  local dir   = pf.Path or ""
  local file  = pf.FullName or ""       -- filename + ext
  local ext   = pf.Extension or ""

  -- Single-file output (e.g., .mov/.mp4/.mxf/etc.)
  if not is_image_ext(ext) then
    rm(join(dir, file))
    goto continue
  end

  -- Image sequence handling
  if SEQ_POLICY == "none" then goto continue end

  -- Determine a generic "base" to match variations:
  -- Supports name.####.ext and name_####.ext (any padding)
  -- If we happen to have a numbered filename in 'file', strip the number to get base.
  local base = file
  base = base:gsub("%.%d+%."..ext.."$", "")   -- name.####.ext
  base = base:gsub("_%d+%."..ext.."$", "")    -- name_####.ext
  base = base:gsub("%."..ext.."$", "")        -- name.ext (no visible number in 'clip')

  local files = bmd.readdir(dir)
  if files then
    for _, f in ipairs(files) do
      -- match both base.####.ext and base_####.ext
      local num = f:match("^"..base.."%.(%d+)%.%w+$") or f:match("^"..base.."_([0-9]+)%.%w+$")
      local fext = lower(f:match("%.(%w+)$") or "")
      if num and lower(fext) == lower(ext) then
        local fn = tonumber(num)
        local in_range = (SEQ_POLICY == "delete_all") or (fn and fn >= R0 and fn <= R1)
        if in_range then
          rm(join(dir, f))
        end
      end
    end
  end

  ::continue::
end
