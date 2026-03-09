-- ClearSaverOutputs.lua — Option 1
-- Movies: write to a temp ".rendering.TIMESTAMP.ext" name; final swap happens in PostRender.
-- Sequences: delete frames within the render range (configurable).
-- Opt-out per Saver: put "[KEEP]" anywhere in the Saver's Comments.

local comp = fu:GetCurrentComp(); if not comp then return end

local function lower(s) return (s or ""):lower() end
local function now_ms()
  return tostring(os.time())..tostring(math.floor((os.clock()%1)*1000))
end
local function join(a,b)
  if not a or a=="" then return b end
  if a:sub(-1)=="/" then return a..b end
  return a.."/"..b
end

-- Which extensions count as "movie" outputs
local MOVIE_EXT = { mov=true, mp4=true, mxf=true, avi=true, m4v=true, mpg=true, mpeg=true, mkv=true }
local IMAGE_EXT = { exr=true, dpx=true, tif=true, tiff=true, png=true, jpg=true, jpeg=true, tga=true, bmp=true, webp=true }
local function is_movie_ext(ext) return MOVIE_EXT[lower(ext or "")] end
local function is_image_ext(ext) return IMAGE_EXT[lower(ext or "")] end

-- Where we pass info to PostRender
local function state_path()
  local tmp = os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or "/tmp"
  local compname = (comp:GetAttrs().COMPN_FileName or "untitled"):gsub("[^%w]+","_")
  return join(tmp, "fusion_clear_"..compname..".lst")
end
local STATE = {}
local function remember(line) table.insert(STATE, line) end
local function save_state()
  if #STATE == 0 then return end
  local f = io.open(state_path(), "w")
  if not f then return end
  for _, L in ipairs(STATE) do f:write(L.."\n") end
  f:close()
end

-- Render range for sequence cleanup
local a = comp:GetAttrs() or {}
local R0 = a.COMPN_RenderStart or a.COMPN_GlobalStart or comp.CurrentTime or 0
local R1 = a.COMPN_RenderEnd   or a.COMPN_GlobalEnd   or comp.CurrentTime or 0
if R1 < R0 then R0, R1 = R1, R0 end

-- Sequence cleanup policy: "delete_range" | "delete_all" | "none"
local SEQ_POLICY = "delete_range"

for _, s in pairs(comp:GetToolList(false, "Saver")) do
  local sa = s:GetAttrs() or {}
  if sa.TOOLB_PassThrough == true then goto continue end
  local comments = lower(s.Comments and s.Comments[comp.CurrentTime] or "")
  if comments:find("%[keep%]") then goto continue end

  local clip = s.Clip and s.Clip[comp.CurrentTime] or nil
  if not clip or clip=="" then goto continue end

  local pf = bmd.parseFilename(clip)
  local dir, file, ext = pf.Path or "", pf.FullName or "", pf.Extension or ""

  if is_movie_ext(ext) then
    -- Always render to a temp file first (final swap in PostRender)
    local tmp = file:gsub("%."..ext.."$", "") .. ".rendering." .. now_ms() .. "." .. ext
    local final_abs = join(dir, file)
    local tmp_abs   = join(dir, tmp)
    s.Clip = tmp_abs
    remember("MAP|"..(sa.TOOLB_Name or "Saver").."|"..final_abs.."|"..tmp_abs)
    print("[PreRender] Movie redirect: "..final_abs.."  ->  "..tmp_abs)
    goto continue
  end

  if is_image_ext(ext) and SEQ_POLICY ~= "none" then
    -- Clean up only frames in-range (or all, depending on policy)
    local base = file:gsub("%.%d+%."..ext.."$", ""):gsub("_%d+%."..ext.."$", ""):gsub("%."..ext.."$", "")
    local files = bmd.readdir(dir)
    if files then
      for _, f in ipairs(files) do
        local num = f:match("^"..base.."%.(%d+)%.%w+$") or f:match("^"..base.."_([0-9]+)%.%w+$")
        local fext = (f:match("%.(%w+)$") or ""):lower()
        if num and fext == lower(ext) then
          local fn = tonumber(num)
          local in_range = (SEQ_POLICY=="delete_all") or (fn and fn>=R0 and fn<=R1)
          if in_range then
            local p = join(dir, f)
            if os.remove(p) then print("[PreRender] Deleted: "..p) end
          end
        end
      end
    end
  end

  ::continue::
end

save_state()
