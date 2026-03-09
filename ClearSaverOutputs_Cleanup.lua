-- ClearSaverOutputs_Cleanup.lua — Option 1 finalize
-- Swaps "*.rendering.TIMESTAMP.ext" -> final filename after render, and restores Saver paths.

local comp = fu:GetCurrentComp(); if not comp then return end

local function join(a,b)
  if not a or a=="" then return b end
  if a:sub(-1)=="/" then return a..b end
  return a.."/"..b
end
local function now_ms()
  return tostring(os.time())..tostring(math.floor((os.clock()%1)*1000))
end
local function state_path()
  local tmp = os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or "/tmp"
  local compname = (comp:GetAttrs().COMPN_FileName or "untitled"):gsub("[^%w]+","_")
  return join(tmp, "fusion_clear_"..compname..".lst")
end
local function nap(sec)
  local t0 = os.clock()
  while (os.clock()-t0) < (sec or 0) do end
end

-- Read state
local p = state_path()
local f = io.open(p, "r"); if not f then return end
local maps = {}
for line in f:lines() do
  local kind, rest = line:match("^(%w+)|(.+)$")
  if kind == "MAP" then
    local tool, final, tmp = rest:match("^([^|]+)|([^|]+)|(.+)$")
    table.insert(maps, {tool=tool, final=final, tmp=tmp})
  end
end
f:close()

if #maps == 0 then return end

-- Helper: try to delete or rename old final if it exists
local function park_old(final)
  if not bmd.fileexists(final) then return true end
  -- Try a few deletes first (handles stale handles on some SMB/NAS)
  for _=1,3 do if os.remove(final) then return true end; nap(0.12) end
  -- Fallback: rename to .old (usually succeeds even if someone had it selected)
  local base = final:gsub("%.%w+$","")
  local ext  = final:match("%.([%w]+)$") or "dat"
  local old  = string.format("%s.%s.%s.old", base, ext, now_ms())
  if os.rename(final, old) then
    print("[PostRender] Parked old: "..old)
    -- Best-effort cleanup (don’t block render completion if busy)
    os.remove(old)
    return true
  end
  return false
end

-- Do swaps and restore Saver paths
local savers = comp:GetToolList(false, "Saver")
for _, m in ipairs(maps) do
  -- Move temp -> final
  if bmd.fileexists(m.tmp) then
    if park_old(m.final) then
      local ok = os.rename(m.tmp, m.final)
      if not ok then
        -- As a last resort, try a tiny wait then retry once
        nap(0.2)
        ok = os.rename(m.tmp, m.final)
      end
      if ok then
        print("[PostRender] Finalized: "..m.final)
      else
        print("[PostRender] WARNING: could not move temp to final: "..m.tmp.." -> "..m.final)
      end
    else
      print("[PostRender] WARNING: could not clear final path: "..m.final)
    end
  end

  -- Restore Saver Clip path (if still set to the temp)
  for _, s in pairs(savers) do
    local clip = s.Clip and s.Clip[comp.CurrentTime] or ""
    if clip == m.tmp then s.Clip = m.final end
  end
end

-- Clean state
os.remove(p)
