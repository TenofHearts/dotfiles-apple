#!/usr/bin/env lua
-- Float Finder windows showing the root of a mounted disk image.
local tree = os.getenv('DOTFILES_LUA_TREE') or os.getenv('HOME') .. '/.local/share/dotfiles-lua'
package.path = tree .. '/share/lua/5.5/?.lua;' .. package.path
package.cpath = tree .. '/lib/lua/5.5/?.so;' .. package.cpath
local uv, json = require('luv'), require('dkjson')
local M = {}

function M.image_volume_names(info)
  local names = {}
  for _, image in ipairs(info.images or {}) do
    for _, entity in ipairs(image['system-entities'] or {}) do
      local mount = entity['mount-point'] or ''
      if mount:match('^/Volumes/') then
        names[mount:match('([^/]+)/?$')] = true
      end
    end
  end
  return names
end

-- Bound each subprocess, including the plist-to-JSON conversion, to five seconds.
local function run(command, args)
  local output, status = {}, nil
  local stdout, timer = uv.new_pipe(false), uv.new_timer()
  local process
  process = uv.spawn(command, {args=args, stdio={nil, stdout, nil}}, function(code)
    status = code
    timer:stop(); timer:close()
    process:close()
  end)
  if not process then stdout:close(); timer:close(); return nil end
  stdout:read_start(function(err, data)
    if err then status = 1 end
    if data then output[#output+1] = data
    else stdout:read_stop(); stdout:close() end
  end)
  timer:start(5000, 0, function() process:kill('sigkill') end)
  uv.run()
  if status == 0 then return table.concat(output) end
end

function M.matches(window, window_id, names)
  return tostring(window['window-id']) == window_id
    and window['app-bundle-id'] == 'com.apple.finder'
    and names[window['window-title']] == true
end

local function main()
  local window_id = os.getenv('AEROSPACE_WINDOW_ID')
  if not window_id then return end
  local aerospace = uv.os_getenv('PATH') and 'aerospace' or '/opt/homebrew/bin/aerospace'
  -- Finder can publish its title shortly after the window is detected.
  for _, delay in ipairs({0, 300, 1000}) do
    if delay > 0 then uv.sleep(delay) end
    local raw = run('/bin/zsh', {'-o', 'pipefail', '-c',
      '/usr/bin/hdiutil info -plist | /usr/bin/plutil -convert json -o - -- -'})
    local info = raw and json.decode(raw)
    if type(info) ~= 'table' then return end
    local names = M.image_volume_names(info)
    if not next(names) then return end
    raw = run(aerospace, {'list-windows', '--all', '--json', '--format',
      '%{window-id} %{app-bundle-id} %{window-title}'})
    local windows = raw and json.decode(raw)
    if type(windows) ~= 'table' then return end
    local found = false
    for _, window in ipairs(windows) do
      if tostring(window['window-id']) == window_id then
        found = true
        if M.matches(window, window_id, names) then
          run(aerospace, {'layout', '--window-id', window_id, 'floating'})
          return
        end
      end
    end
    if not found then return end
  end
end

main()
return M
