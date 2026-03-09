-- Render_Clean_Silent.lua
-- One-shot "clean + silent" render for Fusion Studio
-- • Movies (.mov/.mp4/.mxf…): always render to a temp name, then swap into place
-- • Image sequences: delete frames in your render range (configurable below)
-- • Put "[KEEP]" in a Saver's Comments to skip cleanup for that Saver
-- • Suppresses the "Render Completed" dialog

local comp = fu:GetCurrentComp(); if not comp then return end

----------------------------------------------------------------------
-- Config
----------------------------------------------------------------------
local MOVIE_EXT = { mov=true, mp4=true, mxf=true, avi=true, m4v=true, mpg=true, mpeg=true, mkv=true }
local IMAGE_EXT = { exr=true, dpx=true, tif=true, tiff=true, png=true, jpg=true, jpeg=true, tga=true, bmp=true, webp=true }
-- Sequence cleanup: "delete_range" | "delete_all" | "none"
local SEQ_POLICY = "delete_range"

----------------------------------------------------------------------
-- Utils
----------------------------------------------------------------------
local function lower(s) return (s or ""):lower() end
local function is_movie_ext(ext) return MOVIE_EXT[lower(ext or "")] end
local function is_image_ext(ext) return IMAGE_EXT[lower(ext or "")] end
local function join(a,b) if not a or a=="" then return b end; if a:sub(-1)=="/" then return a..b end; return a.."/"..b end
local function now_ms() return tostring(os.time())..tostring(math.floor((os.clock()%1)*1000)) end
local function nap(sec) local t0=os.clock(); while (os.clock()-t0) < (sec or 0) do end end

local function copy_file(src, dst)
  local fi = io.open(src, "rb"); if not fi then return false, "open src fail" end
  local fo = io.open(dst, "wb"); if not fo then fi:close(); return false, "open dst fail" end
  while true do
    local chunk = fi:read(1024*1024)
    if not chunk then break end
    fo:write(chunk)
  end
  fi:close(); fo:close()
  return true
end

----------------------------------------------------------------------
-- Render range
----------------------------------------------------------------------
local a = comp:GetAttrs() or {}
local R0 = a.COMPN_RenderStart or a.COMPN_GlobalStart or comp.CurrentTime or 0
local R1 = a.COMPN_RenderEnd   or a.COMPN_GlobalEnd   or comp.CurrentTime or R0
if R1 < R0 then R0, R1 = R1, R0 end

----------------------------------------------------------------------
-- Pre-clean + temp redirection
----------------------------------------------------------------------
local maps = {}  -- { tool=<name>, final=<abs>, tmp=<abs> }
local savers = comp:GetToolList(false, "Saver")

for _, s in pairs(savers) do
  local sa = s:GetAttrs() or {}
  if sa.TOOLB_PassThrough == true then goto continue end

  local comments = lower(s.Comments and s.Comments[comp.CurrentTime] or "")
  if comments:find("%[keep%]") then goto continue end

  local clip = s.Clip and s.Clip[comp.CurrentTime] or ""
  if clip == "" then goto continue end

  local pf = bmd.parseFilename(clip)
  local dir, file, ext = pf.Path or "", pf.FullName or "", pf.Extension or ""

  if is_movie_ext(ext) then
    -- Always render movies to a temp name; we finalize after render
    local tmp = file:gsub("%."..ext.."$", "") .. ".rendering." .. now_ms() .. "." .. ext
    local final_abs = join(dir, file)
    local tmp_abs   = join(dir, tmp)
    -- if a previous temp exists, nuke it
    if bmd.fileexists(tmp_abs) then os.remove(tmp_abs) end
    s.Clip = tmp_abs
    table.insert(maps, { tool=(sa.TOOLB_Name or "Saver"), final=final_abs, tmp=tmp_abs })
    print(string.format("[CleanRender] Movie redirect: %s -> %s", final_abs, tmp_abs))

  elseif is_image_ext(ext) and SEQ_POLICY ~= "none" then
    -- Clean image sequence frames (range or all)
    local base = file:gsub("%.%d+%."..ext.."$", ""):gsub("_%d+%."..ext.."$", ""):gsub("%."..ext.."$", "")
    local files = bmd.readdir(dir)
    if files then
      for _, f in ipairs(files) do
        local num = f:match("^"..base.."%.(%d+)%.%w+$") or f:match("^"..base.."_([0-9]+)%.%w+$")
        local fext = lower(f:match("%.(%w+)$") or "")
        if num and fext == lower(ext) then
          local fn = tonumber(num)
          local in_range = (SEQ_POLICY=="delete_all") or (fn and fn>=R0 and fn<=R1)
          if in_range then
            local p = join(dir, f)
            if os.remove(p) then print("[CleanRender] Deleted frame: "..p) end
          end
        end
      end
    end
  end

  ::continue::
end

----------------------------------------------------------------------
-- Silent render
----------------------------------------------------------------------
comp:Lock()  -- suppress UI popups (including "Render Completed")
local ok = comp:Render({ Start=R0, End=R1, Wait=true, RenderAll=true })
comp:Unlock()

if not ok then
  print("[CleanRender] Render failed")
  return
end

----------------------------------------------------------------------
-- Finalize movie outputs: swap tmp -> final and restore Saver paths
----------------------------------------------------------------------
-- Helper: clear final path (delete or park-old)
local function clear_final(final)
  if not bmd.fileexists(final) then return true end
  -- try a couple fast deletes (SMB/NAS sometimes needs a tick)
  for _=1,3 do if os.remove(final) then return true end; nap(0.12) end
  -- fallback: rename to .old
  local base = final:gsub("%.%w+$","")
  local ext  = final:match("%.([%w]+)$") or "dat"
  local old  = string.format("%s.%s.%s.old", base, ext, now_ms())
  if os.rename(final, old) then
    -- best-effort cleanup; don't block if still busy
    os.remove(old)
    return true
  end
  return false
end

for _, m in ipairs(maps) do
  -- If temp exists, move it into place
  if bmd.fileexists(m.tmp) then
    if clear_final(m.final) then
      local moved = os.rename(m.tmp, m.final)
      if not moved then
        -- final fallback: copy bytes then remove temp
        local okcopy = copy_file(m.tmp, m.final)
        if okcopy then os.remove(m.tmp) end
      end
      print("[CleanRender] Finalized: "..m.final)
    else
      print("[CleanRender] WARNING: could not clear final path: "..m.final)
    end
  end
end

-- Restore any Saver paths that still point to a temp
for _, s in pairs(savers) do
  local clip = s.Clip and s.Clip[comp.CurrentTime] or ""
  for _, m in ipairs(maps) do
    if clip == m.tmp then s.Clip = m.final end
  end
end

print("[CleanRender] Done.")
