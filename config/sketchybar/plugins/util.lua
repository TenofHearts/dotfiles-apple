local sbar = require('sketchybar')
local M = {}
-- Keep IPC traffic proportional to actual changes. Merge nested properties so
-- partial updates (e.g. icon.color) do not invalidate cached icon text.
local previous = setmetatable({}, {__mode='k'})
local function changed(cache, properties)
  local result, dirty = {}, false
  for key, value in pairs(properties) do
    if type(value) == 'table' then
      if type(cache[key]) ~= 'table' then cache[key] = {} end
      local nested = changed(cache[key], value)
      if nested then result[key], dirty = nested, true end
    elseif cache[key] ~= value or value == 'toggle' then
      result[key], cache[key], dirty = value, value, true
    end
  end
  return dirty and result or nil
end
function M.set(item, properties)
  previous[item] = previous[item] or {}
  local delta = changed(previous[item], properties)
  if delta then item:set(delta) end
end
function M.quote(value) return "'" .. value:gsub("'", "'\"'\"'") .. "'" end
function M.hex(value) return (value:gsub('.', function(c) return string.format('%02x', c:byte()) end)) end
function M.trim(value) return value:match('^%s*(.-)%s*$') end
function M.exec(command, callback)
  sbar.exec(command, function(result, code)
    if code ~= 0 then io.stderr:write('SketchyBar command failed: ', command, '\n') end
    callback(result, code)
  end)
end
-- JXA is only a bridge to macOS APIs unavailable from stock Lua.
function M.macos(script, callback)
  M.exec('/usr/bin/osascript -l JavaScript -e ' .. M.quote(script), callback)
end
return M
