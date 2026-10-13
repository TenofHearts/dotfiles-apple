local sbar = require('sketchybar')
local M = {}
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
